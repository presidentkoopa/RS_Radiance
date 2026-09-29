// RS_Bloom -- bloom that reacts.
//
// PENDING: needs the engine's LevelLocals.SetBloomOverride (the main lane's
// "bloom step 1"). Every engine call goes through RSB_Override
// (rsb_override.zs), so wiring this in is that one file plus the lumps listed
// in _pending/reactive/README.md.
//
// WHAT IT DOES. Five signals fold into ONE override per tic -- the engine keeps
// one bloom override slot, not a stack, so this handler is the compositor:
//
//   Flash    explosions, impacts, rails and gunfire surge bloom for a moment,
//            scaled by distance from your view and only when you can see them.
//   Breathe  follows RS_GlowInTheDark's alarm pulse, beat for beat, when that
//            mod is loaded and its pulse is up. Script sends only the depth;
//            the engine beats it on the glow shader's own timer.
//   Sweep    leans the bloom tint toward a passing RS_Sweeps band's colour
//            (read from the rsf_tint_* cvars Sweeps publishes for RS_Fog).
//   Hurt     dips and cools the bloom while your damage flash is up.
//   Dark     lowers the threshold in dark rooms and raises it in bright ones.
//
// Everything starts from the player's own gl_bloom_* values, so a preset or a
// hand-tuned setting is the resting state and every reaction is a departure
// from it. With nothing reacting the override is CLEARED, so the bloom pass is
// exactly the player's own again, not a copy of it.
//
// NO PER-EFFECT STRENGTH SLIDERS, on purpose. This runs in WorldTick, which a
// menu freezes, so a script-read slider would not move while you drag it. The
// one live depth control is the engine's gl_bloom_override_strength, which the
// renderer reads every frame. The tuning below is fixed.
//
// NETPLAY. Presentation only: the override is clearscope render state that is
// never serialized or read back. Nothing here calls random() or changes any
// actor, and the local-player parts (your camera, your damage flash, your gun
// flash) affect only what this machine draws.

class RSB_ReactiveHandler : EventHandler
{
	// ---- Flash ------------------------------------------------------------
	const FLASH_CAP        = 1.5;   // stacked flashes stop adding past this
	const FLASH_DECAY      = 0.86;  // per tic: about a third of a second to fade
	const FLASH_GAIN       = 1.1;   // intensity x (1 + gain * flash)
	const FLASH_DROP       = 0.30;  // threshold x (1 - drop * flash), so more blooms
	// spread + widen * flash. ZERO on purpose: with laser protection on
	// (gl_bloom_pin_beams), a spread that differs from the pinned look while a
	// beam is live costs a second bloom chain (~1-1.5 ms per eye,
	// EMISSIVE_BLOOM_PLAN.md Plan C). Threshold, knee, tint and intensity stay in
	// the cheap single chain (Plan B), so a flash surges through those instead.
	const FLASH_WIDEN      = 0.0;
	const EXPLOSION_WEIGHT = 1.0;   // radius damage went off
	const IMPACT_WEIGHT    = 0.55;  // a projectile hit something
	const LAUNCH_WEIGHT    = 0.30;  // a projectile left its shooter
	const RAIL_WEIGHT      = 0.70;
	const SHOT_WEIGHT      = 0.30;  // someone else's hitscan
	const OWN_SHOT_WEIGHT  = 0.45;  // your own gun, at any distance
	const EXPLOSION_RANGE  = 1400.0;
	const MUZZLE_RANGE     = 700.0;
	const MAX_TRACKED      = 512;

	// ---- Breathe ----------------------------------------------------------
	const BREATHE_DEPTH    = 0.40;  // pulse depth at a full-depth, full-level alarm

	// ---- Sweep ------------------------------------------------------------
	const SWEEP_LEAN       = 0.55;  // how far the tint leans at full mix
	const SWEEP_GAIN       = 1.15;  // the band colour, normalised, then lifted

	// ---- Hurt -------------------------------------------------------------
	const HURT_FULL        = 32.0;  // damagecount that counts as a full hit
	const HURT_FOLLOW      = 0.35;  // per-tic ease toward it
	const HURT_DIP         = 0.45;  // intensity x (1 - dip * hurt)
	const HURT_COOL        = 0.50;  // tint lean toward the cold colour
	const HURT_R = 0.78; const HURT_G = 0.90; const HURT_B = 1.20;

	// ---- Dark -------------------------------------------------------------
	const DARK_LIGHT_LOW   = 80.0;  // sector light at or below: fully dark
	const DARK_LIGHT_HIGH  = 224.0; // at or above: fully bright
	const DARK_FOLLOW      = 0.04;  // per tic: a second or so to settle
	const DARK_SCALE_DARK  = 0.70;  // threshold scale in the dark
	const DARK_SCALE_LIT   = 1.10;  // and in the light

	// The renderer eases between our per-tic values over this long, so 35 Hz
	// updates do not step at the headset's 90 Hz. About two tics.
	const FADE_SECONDS     = 0.06;

	private Array<Actor> missiles;
	private Array<bool>  launched;
	private Array<Actor> flashedThisTic;
	private double flash;
	private double hurt;
	private double darkness;
	private int    lastExtralight;
	private bool   pushed;

	// ======================================================================
	// Helpers
	// ======================================================================

	clearscope static double GetF(String n, double def)
	{
		let c = CVar.FindCVar(n); return c ? c.GetFloat() : def;
	}
	clearscope static int GetI(String n, int def)
	{
		let c = CVar.FindCVar(n); return c ? c.GetInt() : def;
	}
	clearscope static bool GetB(String n, bool def)
	{
		let c = CVar.FindCVar(n); return c ? c.GetBool() : def;
	}

	// The master switch, and bloom itself: with gl_bloom off the engine ignores
	// any override, so there is nothing to compose.
	clearscope static bool On()
	{
		return GetB("rsb_reactive", false) && GetB("gl_bloom", true);
	}

	clearscope static bool Want(String effect)
	{
		return GetB(effect, false);
	}

	// What this machine is looking through. Look-only reads of consoleplayer.
	clearscope static Actor LocalCamera()
	{
		let p = players[consoleplayer];
		return p.camera ? p.camera : Actor(p.mo);
	}

	private void Release()
	{
		if (!pushed) return;
		RSB_Override.Clear();
		pushed = false;
	}

	// ======================================================================
	// Events
	// ======================================================================

	override void WorldLoaded(WorldEvent e)
	{
		// The engine clears the override on every map change and savegame load.
		pushed = false;
	}

	override void WorldThingSpawned(WorldEvent e)
	{
		let a = e.Thing;
		if (!a || !a.bMissile) return;
		if (!On() || !Want("rsb_rx_flash")) return;
		if (missiles.Size() >= MAX_TRACKED) return;
		missiles.Push(a);
		launched.Push(false);
	}

	// Radius damage is an explosion, whatever set it off: a rocket, a barrel,
	// a grenade from another mod.
	override void WorldThingDamaged(WorldEvent e)
	{
		if (!(e.DamageFlags & DMG_EXPLOSION)) return;
		if (!On() || !Want("rsb_rx_flash")) return;
		Actor at = e.Inflictor ? e.Inflictor : (e.DamageSource ? e.DamageSource : e.Thing);
		AddFlash(at, EXPLOSION_WEIGHT, EXPLOSION_RANGE);
	}

	override void WorldHitscanFired(WorldEvent e)
	{
		if (!On() || !Want("rsb_rx_flash")) return;
		Shot(e.Thing, SHOT_WEIGHT);
	}

	override void WorldRailgunFired(WorldEvent e)
	{
		if (!On() || !Want("rsb_rx_flash")) return;
		Shot(e.Thing, RAIL_WEIGHT);
	}

	override void WorldTick()
	{
		if (!On())
		{
			missiles.Clear();
			launched.Clear();
			flashedThisTic.Clear();
			flash = 0;
			Release();
			return;
		}

		if (Want("rsb_rx_flash"))
		{
			TrackMissiles();
			OwnGunFlash();
		}
		else
		{
			missiles.Clear();
			launched.Clear();
			flash = 0;
		}

		Compose();

		// Cleared AFTER the missile pass: an explosion's damage event fires
		// during the thinkers, before this tic's WorldTick sees the missile
		// lose its MISSILE flag, and the two must not count twice.
		flashedThisTic.Clear();
	}

	// A menu freezes WorldTick. Switching the master off under a menu takes
	// the reaction off at once rather than when the menu closes.
	override void UiTick()
	{
		if (menuactive != Menu.Off && !On())
			RSB_Override.Clear();
	}

	// ======================================================================
	// Flash
	// ======================================================================

	private void Shot(Actor shooter, double weight)
	{
		if (!shooter) return;
		let p = players[consoleplayer];
		if (p.mo && shooter == p.mo)
		{
			// Your own gun is at your face: no range, no sight check.
			if (flashedThisTic.Find(shooter) != flashedThisTic.Size()) return;
			flashedThisTic.Push(shooter);
			flash = min(FLASH_CAP, flash + max(weight, OWN_SHOT_WEIGHT));
			return;
		}
		AddFlash(shooter, weight, MUZZLE_RANGE);
	}

	// Vanilla gun flashes (A_Light1/A_Light2) raise extralight on the local
	// player. Counted on the rising edge, and not on top of a hitscan event
	// from the same shot.
	private void OwnGunFlash()
	{
		let p = players[consoleplayer];
		int xl = p.extralight;
		if (xl > 0 && lastExtralight <= 0) Shot(p.mo, OWN_SHOT_WEIGHT);
		lastExtralight = xl;
	}

	// A projectile's MISSILE flag is cleared the moment it explodes
	// (P_ExplodeMissile), which is the one generic sign of an impact.
	private void TrackMissiles()
	{
		for (int i = missiles.Size() - 1; i >= 0; i--)
		{
			let m = missiles[i];
			if (!m)
			{
				missiles.Delete(i);
				launched.Delete(i);
				continue;
			}

			// Checked on the first tic rather than at spawn: the spawn event
			// runs before the missile's shooter is filled in.
			if (!launched[i])
			{
				launched[i] = true;
				if (m.target && m.Distance3D(m.target) < m.Speed * 2 + 96)
					AddFlash(m, LAUNCH_WEIGHT, MUZZLE_RANGE);
			}

			if (!m.bMissile)
			{
				AddFlash(m, IMPACT_WEIGHT, EXPLOSION_RANGE);
				missiles.Delete(i);
				launched.Delete(i);
			}
		}
	}

	private void AddFlash(Actor at, double weight, double range)
	{
		if (!at) return;
		if (flashedThisTic.Find(at) != flashedThisTic.Size()) return;
		flashedThisTic.Push(at);

		let cam = LocalCamera();
		if (!cam) return;
		double d = cam.Distance3D(at);
		if (d >= range) return;
		if (!cam.CheckSight(at, SF_IGNOREVISIBILITY)) return;

		double f = 1.0 - d / range;
		flash = min(FLASH_CAP, flash + weight * f * f);
	}

	// ======================================================================
	// The other signals
	// ======================================================================

	// How deep bloom should breathe with RS_GlowInTheDark's alarm, or 0. Only
	// the DEPTH comes from here: the beat itself runs in the renderer on the
	// glow shader's own timer and rate (pulseRate 0), so it stays in phase with
	// the glows, smooth at frame rate, and alive under a menu. Scaled the way
	// main.fp section 5 scales the glow pulse -- depth times alarm level.
	clearscope static double BreatheDepth()
	{
		if (!GetB("gitd_enabled", false)) return 0;
		double depth = GetF("gitd_pulse", 0);
		double lvl = clamp(GetF("gitd_pulse_level", 0), 0.0, 1.0);
		if (depth <= 0 || lvl <= 0) return 0;
		return clamp(BREATHE_DEPTH * depth * lvl, 0.0, 1.0);
	}

	private void Compose()
	{
		double spread    = GetF("gl_bloom_amount", 1.4);
		double threshold = GetF("gl_bloom_threshold", 1.0);
		double knee      = GetF("gl_bloom_knee", 0.5);
		double tr = GetF("gl_bloom_tint_r", 1.0);
		double tg = GetF("gl_bloom_tint_g", 1.0);
		double tb = GetF("gl_bloom_tint_b", 1.0);
		double intensity = 1.0;
		bool any = false;

		// Dark first: it sets where the resting threshold sits, and a flash
		// then drops it from there.
		if (Want("rsb_rx_dark"))
		{
			let cam = LocalCamera();
			if (cam && cam.CurSector)
			{
				double lit = clamp((cam.CurSector.lightlevel - DARK_LIGHT_LOW) / (DARK_LIGHT_HIGH - DARK_LIGHT_LOW), 0.0, 1.0);
				darkness += ((1.0 - lit) - darkness) * DARK_FOLLOW;
			}
			threshold *= DARK_SCALE_LIT + (DARK_SCALE_DARK - DARK_SCALE_LIT) * darkness;
			any = true;
		}

		if (flash > 0.005)
		{
			double f = min(flash, 1.0);
			intensity *= 1.0 + FLASH_GAIN * flash;
			threshold *= 1.0 - FLASH_DROP * f;
			spread += FLASH_WIDEN * f;
			any = true;
		}
		flash *= FLASH_DECAY;
		if (flash < 0.001) flash = 0;

		double pulse = 0;
		if (Want("rsb_rx_breathe"))
		{
			pulse = BreatheDepth();
			if (pulse > 0) any = true;
		}

		if (Want("rsb_rx_sweep"))
		{
			double m = clamp(GetF("rsf_tint_mix", 0), 0.0, 1.0);
			if (m > 0)
			{
				double r = GetI("rsf_tint_r", 255) / 255.0;
				double g = GetI("rsf_tint_g", 255) / 255.0;
				double bl = GetI("rsf_tint_b", 255) / 255.0;
				double top = max(r, max(g, bl));
				if (top > 0.01)
				{
					double lean = SWEEP_LEAN * m;
					tr += (r / top * SWEEP_GAIN - tr) * lean;
					tg += (g / top * SWEEP_GAIN - tg) * lean;
					tb += (bl / top * SWEEP_GAIN - tb) * lean;
					any = true;
				}
			}
		}

		if (Want("rsb_rx_hurt"))
		{
			let p = players[consoleplayer];
			hurt += (clamp(p.damagecount / HURT_FULL, 0.0, 1.0) - hurt) * HURT_FOLLOW;
			if (hurt > 0.005)
			{
				intensity *= 1.0 - HURT_DIP * hurt;
				double cool = HURT_COOL * hurt;
				tr += (HURT_R - tr) * cool;
				tg += (HURT_G - tg) * cool;
				tb += (HURT_B - tb) * cool;
				any = true;
			}
		}
		else hurt = 0;

		if (!any)
		{
			Release();
			return;
		}

		// The engine clamps too; these keep the knee off the grey veil.
		threshold = clamp(threshold, 0.05, 4.0);
		knee = clamp(min(knee, threshold), 0.0, 8.0);
		RSB_Override.Set(max(spread, 0.1), threshold, knee, tr, tg, tb, 1.0, max(intensity, 0.0),
			FADE_SECONDS, pulse, 0.0);
		pushed = true;
	}
}
