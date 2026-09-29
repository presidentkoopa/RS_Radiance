// RS_Fog -- the engine.
//
// A body of mist with a real ceiling you can stand knee deep in and look down
// at. All of the drawing is the engine's -- FogSlabAt in main.fp, which is
// analytic rather than raymarched and is why this is affordable at 90Hz per eye
// at all. What this mod owns is WHEN, HOW MUCH, and WHAT DISTURBS IT.
//
// The engine had every one of these knobs and no way to reach them: no on/off,
// no menu, and nothing connecting the fog to anything that happens in the game.
// A shader that can be shouldered aside by a walking monster is worth nothing
// if no monster ever tells it.
//
// TWO HALVES.
//
// Push() sends the standing settings -- the slab, its surface, tendrils, noise,
// colour, the wake's shape and the flash colour. It is clearscope and runs from
// UiTick as well as WorldTick, so the fog changes under the options menu while
// you are looking at it.
//
// The event hooks are play scope and send DISTURBANCES and the wake's
// position: things that happened in the world, with a place and a life. Those
// cannot come from UI and should not.

class RSF_Handler : EventHandler
{
	// Disturbance modes, as documented on Level.FogDisturb.
	const D_DISC   = 0;   // fixed radius, thins the mist -- something wading
	const D_RIPPLE = 1;   // a ring travelling outward
	const D_IGNITE = 2;   // an expanding sphere that adds LIGHT, not density
	const D_GOUT   = 3;   // an expanding disc that ADDS mist -- a vent, a burst


	// ---- SURVIVING A SAVEGAME LOAD -----------------------------------------
	//
	// The engine SKIPS WorldLoaded for a non-static handler on a save restore
	// (events.cpp: `if (!handler->IsStatic() && savegamerestore) continue;`),
	// and this handler is not static. So a load arrives with the preset cvar
	// restored from the save -- along with every slider tuned on top of it --
	// while the applied latch, which is nosave, reads whatever was showing
	// before the load. The tick then sees "wanted != applied", calls it a fresh
	// pick, and stamps the whole preset over the tuning the save just restored.
	//
	// A handler FIELD is serialized with the save, so it comes back saying
	// which preset the restored cvars already belong to. Stored PLUS ONE, so a
	// save written before this field existed reads 0 and restores nothing.
	//
	// Ported from RS_Darkness, which had this first and is the reference shape.
	int savedLatch;
	// False until this handler has had a live start. Transient, so a handler
	// restored from a save comes back with it false.
	transient bool loadedLive;

	private int waderTimer;
	// The monster picked last window, so the next pick goes to someone else.
	private Actor lastWader;

	// ---- lifecycle ---------------------------------------------------------

	override void WorldLoaded(WorldEvent e)
	{
		// SyncPreset, NOT an unconditional Apply. Apply now calls Base first,
		// so applying on every map load resets every setting -- which is
		// exactly what rsf_preset_applied exists to prevent, and what the
		// cvarinfo comment on it says it prevents. This bypassed its own guard.
		loadedLive = true;
		SyncPreset();
		savedLatch = RSF.GetI("rsf_preset_applied", -1) + 1;
		Level.ClearFogDisturb();
		// No sweep is tinting the mist on a fresh map. The override is nosave,
		// so it survives in the ini; a tint left by a band that never finished
		// would otherwise open the next map already coloured.
		RSF.SetF("rsf_tint_mix", 0.0);
		Push();
	}

	override void WorldUnloaded(WorldEvent e)
	{
		// The slab is level state, not mod state. Leaving it set means the next
		// map opens inside whatever the last one was wearing.
		if (Level) { Level.ClearFogSlab(); Level.ClearFogDisturb(); }
		RSF.SetF("rsf_tint_mix", 0.0);
	}

	override void WorldTick()
	{
		if (!loadedLive) ResumeFromSave();

		SyncPreset();
		savedLatch = RSF.GetI("rsf_preset_applied", -1) + 1;
		Push();
		PushWake();
		Waders();
	}

	// A handler restored from a save. The look cvars are the save's own, so
	// match the latch to the preset they were set under rather than applying
	// anything over them.
	void ResumeFromSave()
	{
		loadedLive = true;
		if (savedLatch > 0) RSF.SetI("rsf_preset_applied", savedLatch - 1);
	}

	// The playsim stops while the menu is up, so WorldTick alone would freeze
	// the picture exactly while you drag the slider meant to change it. Every
	// fog setter used here is clearscope for this reason.
	//
	// Disturbances are NOT sent from here. They are events in the world, they
	// carry a position and a life, and firing them off menu ticks would have
	// the mist rippling while the game is paused.
	override void UiTick()
	{
		// Not until WorldTick has matched the latch to a restored save: a sync
		// here first would see the mismatch and re-apply over the save. The
		// push does not wait -- it only reads what the save put back.
		if (loadedLive) SyncPreset();
		Push();
	}

	clearscope void SyncPreset()
	{
		// An out-of-range index -- from the console, or a stale ini -- falls
		// back to the default preset. It used to run Apply's `default` case,
		// which is Off: the fog vanished and the menu showed a blank.
		int want = RSF.GetI("rsf_preset", 1);
		if (want < 0 || want >= RSF_Presets.COUNT) want = 1;
		if (want == RSF.GetI("rsf_preset_applied", -1)) return;
		RSF_Presets.Apply(want);
		RSF.SetI("rsf_preset_applied", want);
	}

	// ---- the standing settings ---------------------------------------------

	// Every look slider on the live pages is pushed from here, and UiTick runs
	// it, so the mist moves under the menu. Declared for menu_lint's live-page
	// check:
	// LINT-UI-LIVE: rsf_top rsf_density rsf_soft rsf_scatter rsf_follow rsf_bottom
	// LINT-UI-LIVE: rsf_surf_amp rsf_surf_len rsf_surf_speed rsf_surf_cross
	// LINT-UI-LIVE: rsf_noise_scale rsf_noise_depth rsf_drift_x rsf_drift_y
	// LINT-UI-LIVE: rsf_tend_density rsf_tend_spacing rsf_tend_radius rsf_tend_height
	// LINT-UI-LIVE: rsf_tend_rise rsf_tend_spread rsf_tend_lean rsf_tend_taper
	// LINT-UI-LIVE: rsf_col_r rsf_col_g rsf_col_b rsf_grad_mix rsf_grad_r rsf_grad_g rsf_grad_b rsf_pickup
	// LINT-UI-LIVE: rsf_indoor rsf_outdoor rsf_ignite_r rsf_ignite_g rsf_ignite_b
	// LINT-UI-LIVE: rsf_bow rsf_bow_width rsf_bow_thin rsf_wake_radius rsf_wake_strength rsf_wake_stretch

	clearscope void Push()
	{
		if (!Level) return;

		if (!RSF.GetB("rsf_enabled", true))
		{
			// ONCE, on the way off. Clearing every tic while disabled also
			// erased any other mod's slab for as long as the fog stayed off.
			if (RSF.GetI("rsf_standing_pushed", 0) != 0)
			{
				Level.ClearFogSlab();
				Level.SetFogTendrils(160.0, 22.0, 96.0, 0.0, 0.5, 0.4, 0.2, 0.7);
				Level.SetFogBow(0.0, 48.0, 0.6);
				RSF.SetI("rsf_standing_pushed", 0);
			}
			return;
		}
		if (RSF.GetI("rsf_standing_pushed", 0) == 0) RSF.SetI("rsf_standing_pushed", 1);

		// WHERE THE TOP SITS. Absolute is a fixed world height, which is right
		// for one flooded room and wrong for a level -- walk upstairs and you
		// are above the weather. Following the floor measures the top from the
		// floor you stand on, so the depth underfoot is the same everywhere;
		// the number is how closely the fog tracks the floors around you.
		double follow = RSF.GetF("rsf_follow", 0.35);
		Level.SetFogFollow(follow, follow);

		// HOW MUCH EACH ROOM GETS. A sky ceiling is outdoors, which every Doom
		// map already marks, so a courtyard and a cellar can want opposite
		// amounts without anything being authored for it. Both 1 is one fog
		// everywhere, which is what it was.
		Level.SetFogZones(
			RSF.GetF("rsf_indoor", 1.0),
			RSF.GetF("rsf_outdoor", 1.0));

		// RSF.RGB builds these names from a prefix, so tools\menu_lint.py cannot
		// see them read. Declared here so its E2 check does not call them dead.
		// LINT-CVARS: rsf_col_r rsf_col_g rsf_col_b rsf_grad_r rsf_grad_g rsf_grad_b
		// LINT-CVARS: rsf_tint_r rsf_tint_g rsf_tint_b rsf_ignite_r rsf_ignite_g rsf_ignite_b
		Level.SetFogSlab(
			RSF.GetF("rsf_top", 64.0),
			RSF.GetF("rsf_density", 0.55),
			RSF.GetF("rsf_soft", 24.0),
			RSF.GetF("rsf_scatter", 1.0),
			RSF.RGB("rsf_col"));

		// [FOGDYNLIGHTS] How many dynamic lights light the mist. A count, not a strength:
		// the shader reads every one per pixel of fog. The player's fog_dynlights_max caps it.
		Level.SetFogDynLights(RSF.GetI("rsf_dynlights", 0));

		Level.SetFogBottom(
			RSF.GetF("rsf_bottom", -256.0),
			RSF.GetF("rsf_bottom_period", 0.0),
			RSF.GetF("rsf_bottom_roll", 0.0));

		// THE SURFACE MOVES. A flat top reads as a sheet the moment you can see
		// it clearly. Two waves at an angle interfere, and interference is what
		// stops it looking like machinery.
		Level.SetFogSurface(
			RSF.GetF("rsf_surf_amp", 10.0),
			RSF.GetF("rsf_surf_len", 256.0),
			RSF.GetF("rsf_surf_speed", 1.0),
			RSF.GetF("rsf_surf_cross", 0.6));

		Level.SetFogNoise(
			RSF.GetF("rsf_noise_scale", 0.012),
			RSF.GetF("rsf_noise_depth", 0.45),
			RSF.GetF("rsf_drift_x", 3.0),
			RSF.GetF("rsf_drift_y", 1.5));

		Level.SetFogTendrils(
			RSF.GetF("rsf_tend_spacing", 160.0),
			RSF.GetF("rsf_tend_radius", 22.0),
			RSF.GetF("rsf_tend_height", 96.0),
			RSF.GetF("rsf_tend_density", 0.0),
			RSF.GetF("rsf_tend_rise", 0.5),
			RSF.GetF("rsf_tend_spread", 0.4),
			RSF.GetF("rsf_tend_lean", 0.2),
			RSF.GetF("rsf_tend_taper", 0.7));

		// The second colour -- or, while another mod has laid a tint over it
		// (rsf_tint_mix above 0, RS_Sweeps' fog tint), that tint. One writer
		// for the engine's gradient: this line.
		double tintMix = RSF.GetF("rsf_tint_mix", 0.0);
		if (tintMix > 0.0)
			Level.SetFogGradient(RSF.RGB("rsf_tint"), clamp(tintMix, 0.0, 1.0));
		else
			Level.SetFogGradient(RSF.RGB("rsf_grad"), RSF.GetF("rsf_grad_mix", 0.0));
		Level.SetFogPickup(RSF.GetF("rsf_pickup", 0.5));

		// What an explosion burns. Its own colour -- it used to borrow the
		// gradient colour above, which most presets leave black.
		Level.SetFogIgniteColor(RSF.RGB("rsf_ignite"));

		// What a passing sweep does to the mist. Nothing unless RS_Sweeps (or
		// anything else) is drawing sweep bands; the engine bow only acts on
		// those.
		Level.SetFogBow(
			RSF.GetF("rsf_bow", 0.0),
			RSF.GetF("rsf_bow_width", 48.0),
			RSF.GetF("rsf_bow_thin", 0.6));

		// THE WAKE'S SHAPE -- size, strength, stretch. Look settings, so from
		// here and live under the menu. Its position and direction come from
		// the playsim in PushWake. Off means strength 0, pushed every tic: just
		// not pushing it used to leave the hole frozen where it last was.
		bool wake = RSF.GetB("rsf_wake", true);
		Level.SetFogWakeShape(
			RSF.GetF("rsf_wake_radius", 56.0),
			wake ? RSF.GetF("rsf_wake_strength", 0.8) : 0.0,
			RSF.GetF("rsf_wake_stretch", 1.6));
	}

	// ---- what happens in it ------------------------------------------------

	// The player's own wake: one lagging point that thins the mist where you
	// just walked. Play scope, because it reads where the player is.
	void PushWake()
	{
		if (!RSF.GetB("rsf_enabled", true) || !RSF.GetB("rsf_wake", true)) return;
		let pmo = players[consoleplayer].mo;
		if (!pmo) return;
		Level.SetFogWakePos(pmo.pos);

		// THE DIRECTION, or the stretch does nothing. The shader only stretches
		// the wake when it has a velocity to stretch it ALONG. The stretch rides
		// along and matches what Push sent, so the two never disagree.
		Level.SetFogWakeMotion(pmo.vel.x, pmo.vel.y,
			RSF.GetF("rsf_wake_stretch", 1.6));
	}

	// Things wading through it. The shader can be shouldered aside by anything
	// that moves; until now nothing told it.
	//
	// THROTTLED HARD, and this is the whole reason it is not per-actor per-tic.
	// There are 32 disturbance slots and they recycle oldest-first, so a room
	// of thirty monsters each pushing one every tic means every slot is a tenth
	// of a second old and nothing has time to read as a wake. One pick every
	// rsf_wader_every tics leaves each disturbance alive long enough to be seen.
	//
	// The pick is the nearest moving monster that did NOT go last time. Strictly
	// the nearest gave one monster every pick, so the ones further off never
	// parted the mist at all.
	void Waders()
	{
		if (!RSF.GetB("rsf_enabled", true) || !RSF.GetB("rsf_waders", true)) return;
		if (--waderTimer > 0) return;
		waderTimer = max(RSF.GetI("rsf_wader_every", 6), 1);

		let pmo = players[consoleplayer].mo;
		if (!pmo) return;

		double range = RSF.GetF("rsf_wader_range", 1024.0);
		double best = range, lastDist = range;
		Actor pick = null;

		let it = ThinkerIterator.Create("Actor");
		Actor a;
		while (a = Actor(it.Next()))
		{
			if (!a || !a.bIsMonster || a.health <= 0) continue;
			if (a.vel.xy.Length() < 1.0) continue;     // standing still parts no mist
			double d = (a.pos.xy - pmo.pos.xy).Length();
			if (a == lastWader) { lastDist = d; continue; }
			if (d < best) { best = d; pick = a; }
		}

		// Nobody else moving in range: the last one may go again.
		if (!pick && lastWader && lastDist < range) pick = lastWader;
		if (!pick) return;

		lastWader = pick;
		Level.FogDisturb(pick.pos.x, pick.pos.y, pick.pos.z,
			pick.radius * 2.2, 0.7, 0.0, 0.6, D_DISC);
	}

	override void WorldThingDied(WorldEvent e)
	{
		if (!RSF.GetB("rsf_enabled", true)) return;
		if (!e || !e.Thing) return;
		if (!RSF.GetB("rsf_death_ripple", true)) return;

		Actor t = e.Thing;
		if (!t.bIsMonster) return;

		// A ring travelling outward from the body. Big things make big rings.
		double r = clamp(GetDefaultByType(t.GetClass()).Height * 3.0, 64.0, 512.0);
		Level.FogDisturb(t.pos.x, t.pos.y, t.floorz, r,
			RSF.GetF("rsf_death_strength", 0.8),
			RSF.GetF("rsf_death_speed", 220.0),
			RSF.GetF("rsf_death_life", 0.9), D_RIPPLE);
	}

	// Anything exploding lights the mist from inside. IGNITE adds light and no
	// density, so it shows even where there is no mist -- the Off preset
	// included. Switching the mod off stops it.
	//
	// The engine fills DamageIsRadius (DMG_EXPLOSION) and DamagePosition (the
	// inflictor, else the source, else the victim) for thing damage. It used to
	// leave both unset, so this read garbage and the flash rarely fired.

	// The tic and inflictor of the last ignite, so one blast is one flash.
	private int lastIgniteTic;
	private Actor lastIgniteSrc;

	override void WorldThingDamaged(WorldEvent e)
	{
		if (!RSF.GetB("rsf_enabled", true) || !RSF.GetB("rsf_ignite", true)) return;
		if (!e || !e.Thing || !e.DamageIsRadius) return;
		if (e.Damage < RSF.GetI("rsf_ignite_min", 20)) return;

		// ONE BLAST, ONE FLASH. WorldThingDamaged fires once per thing hurt,
		// and a rocket into a pack hurts all of them at the same point on the
		// same tic -- so a crowd got one ignite per victim. The shader ADDS
		// them, so the flash was eight times too bright for hitting eight
		// things, and eight of the thirty-two disturbance slots went in one
		// tic, which starves everything else and lengthens the shader's
		// disturbance loop for the better part of a second.
		if (e.Inflictor == lastIgniteSrc && level.maptime == lastIgniteTic) return;
		lastIgniteSrc = e.Inflictor;
		lastIgniteTic = level.maptime;

		Level.FogDisturb(e.DamagePosition.x, e.DamagePosition.y, e.DamagePosition.z,
			RSF.GetF("rsf_ignite_radius", 192.0),
			RSF.GetF("rsf_ignite_strength", 1.0),
			RSF.GetF("rsf_ignite_speed", 320.0),
			RSF.GetF("rsf_ignite_life", 0.5), D_IGNITE);
	}
}
