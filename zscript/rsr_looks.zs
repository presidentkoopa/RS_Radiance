// RS_Radiance -- the Looks.
//
// A Look picks one preset per effect, then tunes a handful of values so the
// effects match each other. Presets are applied by each effect's own handler
// (it sees its preset cvar change); RSR_Handler waits for those to land and
// then calls Tune(). Bloom can only be written from menu code, so its part is
// BloomTune(), run from the Radiance page's ticker.

class RSR_Looks
{
	const COUNT = 16;   // 0 = None, 1..15 = Looks

	const L_NONE        = 0;
	const L_GOLDENHOUR  = 1;
	const L_VAPORWAVE   = 2;
	const L_FROSTBITE   = 3;
	const L_TOXIC       = 4;
	const L_STORM       = 5;
	const L_DROWNED     = 6;
	const L_SIGNALLOST  = 7;
	const L_HELLSCAPE   = 8;
	const L_LOWPOWER    = 9;
	const L_CATHEDRAL   = 10;
	const L_NEON        = 11;
	const L_REDALERT    = 12;
	const L_LANTERN     = 13;
	const L_BLACKOUT    = 14;
	const L_THERMAL     = 15;

	// Effects, for Preset().
	const FX_DARK  = 0;
	const FX_GLOW  = 1;
	const FX_FOG   = 2;
	const FX_SWEEP = 3;
	const FX_BLOOM = 4;

	// ---- setters -------------------------------------------------------

	static void F(String n, double v) { let c = CVar.FindCVar(n); if (c) c.SetFloat(v); }
	static void I(String n, int v)    { let c = CVar.FindCVar(n); if (c) c.SetInt(v); }
	static void Flag(String n, bool v) { let c = CVar.FindCVar(n); if (c) c.SetBool(v); }
	static void RGB(String pre, int r, int g, int b)
	{
		I(pre .. "_r", r); I(pre .. "_g", g); I(pre .. "_b", b);
	}
	static int GetI(String n, int def)
	{
		let c = CVar.FindCVar(n); return c ? c.GetInt() : def;
	}

	// ---- the plan: which preset each effect gets, -1 = that effect off ----

	static int Preset(int look, int fx)
	{
		//                          dark glow fog sweep bloom
		switch (look)
		{
		case L_GOLDENHOUR: return Pick(fx,   4,   4,  14,  -1,  10);
		case L_VAPORWAVE:  return Pick(fx,   1,  28,   8,   5,   3);
		case L_FROSTBITE:  return Pick(fx,   9,   5,   1,  17,  11);
		case L_TOXIC:      return Pick(fx,   9,  39,   4,   6,   2);
		case L_STORM:      return Pick(fx,  10,  -1,  19,   1,  11);
		case L_DROWNED:    return Pick(fx,   7,  11,   2,   1,   6);
		case L_SIGNALLOST: return Pick(fx,   9,  16,  -1,   6,   9);
		case L_HELLSCAPE:  return Pick(fx,  11,  37,   6,   6,   7);
		case L_LOWPOWER:   return Pick(fx,  14,  26,   9,  17,   3);
		case L_CATHEDRAL:  return Pick(fx,  15,   7,  17,  -1,  10);
		case L_NEON:       return Pick(fx,   3,  40,   8,   8,   9);
		case L_REDALERT:   return Pick(fx,   6,  14,   3,   2,   2);
		case L_LANTERN:    return Pick(fx,   5,  -1,   1,  -1,  10);
		case L_BLACKOUT:   return Pick(fx,  18,  27,  11,  -1,   4);
		case L_THERMAL:    return Pick(fx,  18,  34,  -1,  -1,   3);
		}
		return -1;
	}

	static int Pick(int fx, int d, int g, int f, int s, int b)
	{
		switch (fx)
		{
		case FX_DARK:  return d;
		case FX_GLOW:  return g;
		case FX_FOG:   return f;
		case FX_SWEEP: return s;
		case FX_BLOOM: return b;
		}
		return -1;
	}

	// ---- step 1: switch effects on/off and hand each its preset ----------
	//
	// The *_applied latches go to -1 so each handler re-applies even when the
	// preset number is the same as before: the last Look's tuning is wiped by
	// the preset's own Base().

	// Only the machine allowed to change settings writes them.
	static bool MayWrite()
	{
		return !multiplayer || players[consoleplayer].settings_controller;
	}

	static void Start(int look)
	{
		if (!MayWrite()) return;

		// Glow's own randomisers would fight the Look.
		Flag("gitd_shuffle", false);
		I("gitd_ondeath", 0);

		Effect(look, FX_DARK,  "rsd_enabled",  "rsd_preset",  "rsd_preset_applied");
		Effect(look, FX_GLOW,  "gitd_enabled", "gitd_preset", "gitd_preset_applied");
		Effect(look, FX_FOG,   "rsf_enabled",  "rsf_preset",  "rsf_preset_applied");
		Effect(look, FX_SWEEP, "rss_enabled",  "rss_preset",  "rss_preset_applied");

		// Glow texture back to "from the preset"; Tune sets one where a Look wants it.
		I("gitd_texture", 0);
		I("gitd_texture_applied", -2);

		// Bloom: nosave cvars, applied by the menu ticker. Off is its own preset.
		int bp = Preset(look, FX_BLOOM);
		Flag("rsb_enabled", true);
		I("rsb_preset", bp < 0 ? 0 : bp);
		I("rsb_preset_applied", -1);
		I("rsr_bloom_pending", look);

		Flashlight(look);
	}

	static void Effect(int look, int fx, String enabled, String preset, String latch)
	{
		int p = Preset(look, fx);
		Flag(enabled, p >= 0);
		if (p < 0) return;
		I(preset, p);
		I(latch, -1);
	}

	// True once every effect this Look uses has applied its preset.
	static bool Landed(int look)
	{
		return Has(look, FX_DARK,  "rsd_preset_applied")
			&& Has(look, FX_GLOW,  "gitd_preset_applied")
			&& Has(look, FX_FOG,   "rsf_preset_applied")
			&& Has(look, FX_SWEEP, "rss_preset_applied");
	}

	static bool Has(int look, int fx, String latch)
	{
		int p = Preset(look, fx);
		return p < 0 || GetI(latch, -1) == p;
	}

	// ---- step 2: tune the effects to each other ---------------------------

	static void Tune(int look)
	{
		if (!MayWrite()) return;

		// THE LOOK'S BLOOM, WITHOUT WAITING FOR A MENU. BloomTune below still writes the
		// player's gl_bloom_* cvars when the Bloom page is open, which is where those belong;
		// this pushes the same numbers into the engine's look layer so the Look is complete
		// the moment it is picked. See BloomLook.
		BloomLook(look);

		// Things In The Dark: how much monsters and items keep. Default, then
		// per Look.
		F("rsd_actor_spare", 0.4);

		switch (look)
		{
		case L_GOLDENHOUR:
			F("rsd_dist", 0.75);
			F("rsd_actor_spare", 0.3);
			GITD_Presets.Window(28, 40, 0.6, 0.85, 0.55, 0.9);
			RGB("rsf_col", 240, 175, 85);
			RGB("rsf_grad", 55, 45, 115);
			F("rsf_grad_mix", 0.3);
			F("rsf_indoor", 0.4); F("rsf_outdoor", 1.1);
			F("rsf_pickup", 0.5);
			break;

		case L_VAPORWAVE:
			F("rsd_actor_spare", 0.3);
			GITD_Presets.Window(280, 340, 0.5, 0.6, 0.6, 0.75);
			GITD_Presets.Throb(0.35, 0.5, 0.35);
			RGB("rsf_col", 110, 85, 130);
			F("rsf_pickup", 0.5);
			F("rss_ambient_speed", 0.2);
			Alternate(0xFF8CD2, 0x6EE1D7);
			break;

		case L_FROSTBITE:
			F("rsd_adjust", 150);
			GITD_Presets.Window(190, 210, 0.4, 0.5, 0.6, 0.9);
			I("gitd_texture", GITD_Textures.T_FROST);
			RGB("rsf_col", 120, 140, 170);
			F("rsf_indoor", 0.5); F("rsf_outdoor", 1.4);
			I("rss_draw", 4);                 // recolour: frosts the glow it crosses
			RGB("rss_col", 190, 235, 255);
			F("rss_col_mix", 0.0);
			break;

		case L_TOXIC:
			F("rsd_adjust", 170);
			F("rsd_actor_spare", 0.3);
			GITD_Presets.Window(70, 120, 0.7, 0.95, 0.55, 0.95);
			F("rsf_top", 48);                 // low
			RGB("rsf_col", 55, 75, 20);
			F("rsf_pickup", 0.8);
			I("rss_ambient_shape", 4);        // rising spheres: bubbles
			I("rss_fill", 0);
			RGB("rss_col", 190, 255, 40);
			break;

		case L_STORM:
			F("rsd_actor_spare", 0.3);
			F("rsf_drift_x", 13.0); F("rsf_drift_y", -7.0);
			RGB("rsf_col", 95, 105, 122);
			// Lightning: one huge fast shell from the map centre, lift mode so
			// the whole room flashes, a long gap between strikes.
			RSS_Presets.Band(400.0, 1.5, 1.8, 0.0, 2, 0.2);
			RSS_Presets.Ambient(1, 3.0, 4096.0, 4);
			I("rss_ambient_org", 3);
			I("rss_ambient_timing", 1);
			RSS_Presets.Train(4000.0, 420);
			RGB("rss_col", 230, 238, 255);
			break;

		case L_DROWNED:
			F("rsd_actor_spare", 0.3);
			GITD_Presets.Window(165, 215, 0.55, 0.85, 0.5, 0.9);
			F("rsf_top", 96);
			F("rsf_density", 0.8);            // a little murkier than Swamp
			RGB("rsf_col", 20, 90, 95);
			RGB("rsf_grad", 28, 115, 110);
			F("rsf_grad_mix", 0.5);
			F("rsf_pickup", 0.6);
			RGB("rss_col", 60, 220, 200);
			break;

		case L_SIGNALLOST:
			F("rsd_adjust", 180);
			GITD_Presets.Window(118, 128, 0.85, 0.95, 0.6, 1.0);
			I("gitd_texture", GITD_Textures.T_SCANLINES);
			RGB("rss_col", 45, 255, 70);
			RGB("rss_fill", 45, 255, 70);
			break;

		case L_HELLSCAPE:
			F("rsd_actor_spare", 0.3);
			// DARK OVERHEAD, LIGHT RISING FROM THE FLOOR. The height term could only pool
			// downward until the engine learned a direction, so this Look could not be
			// built at all. The reference follows your feet at +64 -- roughly head height --
			// so the dark line rides up the stairs with you instead of sitting at one
			// absolute height the map never agreed with.
			I("rsd_height_dir", 1);
			I("rsd_height_mode", 1);
			F("rsd_height_offset", 64.0);
			F("rsd_height", 0.75);
			F("rsd_height_range", 192.0);
			RGB("rsf_col", 42, 12, 6);
			I("rss_ambient_shape", 4);        // rising spheres: embers
			I("rss_fill", 0);
			RGB("rss_col", 255, 110, 30);
			F("rss_intensity", 0.6);
			break;

		case L_LOWPOWER:
			GITD_Presets.Window(120, 160, 0.15, 0.3, 0.6, 0.9);
			RGB("rsf_col", 42, 46, 44);
			RGB("rss_col", 190, 240, 215);
			F("rss_col_mix", 0.0);
			F("rss_ambient_speed", 0.06);     // rare, slow surges
			break;

		case L_CATHEDRAL:
			F("rsd_minlight", 40);            // stairs stay readable
			GITD_Presets.Window(38, 48, 0.55, 0.7, 0.6, 0.95);
			// A faint gold floor edge so the floor is never lost.
			GITD_Presets.Lane("gitd_fg", true, 0, 255, 190, 90, 16, 0, 0.35);
			// The haze hangs above your head.
			F("rsf_bottom", 88);
			F("rsf_top", 200);
			F("rsf_density", 0.25);
			RGB("rsf_col", 120, 118, 115);
			F("rsf_grad_mix", 0.0);
			F("rsf_pickup", 0.5);
			break;

		case L_NEON:
			F("rsd_actor_spare", 0.35);
			RGB("rsf_col", 10, 5, 18);
			F("rsf_pickup", 0.5);
			Alternate(0xFF28C8, 0x28DCFF);
			RGB("rss_fill", 40, 200, 255);
			F("rss_fill_u", 48); F("rss_fill_v", 48);
			break;

		case L_REDALERT:
			F("rsd_actor_spare", 0.4);
			F("gitd_pulse_rate", 0.5);        // a slow alarm
			RGB("rsf_col", 38, 6, 6);
			RGB("rsf_grad", 20, 4, 4);
			F("rsf_pickup", 0.6);
			RGB("rss_col", 220, 25, 20);
			F("rss_col_mix", 0.0);
			F("rss_ambient_speed", 0.15);
			break;

		case L_LANTERN:
			F("rsd_adjust", 160);
			F("rsd_dist", 1.0);
			F("rsd_dist_range", 700);
			F("rsd_actor_spare", 0.25);
			RGB("rsf_col", 34, 34, 40);
			F("rsf_pickup", 0.6);
			F("rsf_scatter", 1.6);            // the lantern lights the mist
			// IT HANGS AND SWINGS. This is what makes it a lantern rather than a torch: a
			// little weight so it trails the hand, and a loose spring so it keeps moving
			// after you stop. The cone and the light it throws swing together, because the
			// smoothing is on the anchor and not on either of them.
			F("rsfl_weight", 0.08);
			F("rsfl_sway", 0.9);
			F("rsfl_sway_damp", 0.25);        // loose: it keeps swinging
			break;

		case L_BLACKOUT:
			F("rsd_actor_spare", 0.0);
			// A ROCKET DOWN A BLACK CORRIDOR SHOULD LIGHT THE MIST IT IS FLYING THROUGH.
			// Blackout is the Look this was built for: with the world this dark, a
			// projectile's own light is most of what you see by. Six rather than the full
			// eight -- the fog reads every one of them per pixel, and past about six you are
			// paying for lights you cannot pick out anyway.
			I("rsf_dynlights", 6);
			RGB("rsf_col", 8, 9, 12);
			RGB("rsf_grad", 4, 4, 6);
			F("rsf_pickup", 0.6);
			F("rsf_scatter", 1.8);
			Flag("rsf_ignite", true);
			break;

		case L_THERMAL:
			F("rsd_actor_spare", 1.0);        // monsters keep all their light
			GITD_Presets.Window(225, 255, 0.7, 0.9, 0.3, 0.4);
			break;
		}
	}

	// Sweep bands alternating between two colours, never mixed.
	static void Alternate(int ca, int cb)
	{
		Flag("rss_perband", true);
		F("rss_col_mix", 0.0);
		for (int n = 1; n <= 8; n++)
			RSS_Presets.BandSlot(n, (n % 2) ? ca : cb, 0, 0);
	}

	// ---- the flashlight: user cvars, written at once -----------------------
	//
	// Only Looks built around it touch it. The torch itself is still switched
	// on with its key.

	static void Flashlight(int look)
	{
		switch (look)
		{
		case L_LANTERN:
			I("rsfl_mount", 1);
			F("rsfl_inner", 45); F("rsfl_outer", 80);
			F("rsfl_length", 640);
			F("rsfl_density", 0.55);
			F("rsfl_spot", 1.2);
			F("rsfl_flicker", 0.14);
			F("rsfl_dust", 0.3);
			I("rsfl_r", 255); I("rsfl_g", 165); I("rsfl_b", 90);
			break;

		case L_BLACKOUT:
			I("rsfl_mount", 2);
			F("rsfl_inner", 14); F("rsfl_outer", 30);
			F("rsfl_length", 1600);
			F("rsfl_density", 0.9);
			F("rsfl_spot", 1.2);
			F("rsfl_flicker", 0.03);
			F("rsfl_dust", 0.4);
			I("rsfl_r", 220); I("rsfl_g", 235); I("rsfl_b", 255);
			break;

		case L_LOWPOWER:
			F("rsfl_density", 0.5);
			F("rsfl_flicker", 0.1);
			I("rsfl_r", 255); I("rsfl_g", 230); I("rsfl_b", 170);
			break;

		case L_DROWNED:
			I("rsfl_r", 120); I("rsfl_g", 230); I("rsfl_b", 220);
			break;

		case L_THERMAL:
			I("rsfl_r", 255); I("rsfl_g", 170); I("rsfl_b", 80);
			break;
		}
	}


	// ---- bloom, WITHOUT needing a menu (engine: Level.SetBloomLook) ---------
	//
	// BloomTune below writes the gl_bloom_* cvars and can only run from menu code, because
	// the engine refuses engine-cvar writes from play. That is why a Look rolled during play
	// used to have no bloom until the Radiance page was next opened, and why the README had
	// to say so.
	//
	// This pushes the same numbers to the engine's LOOK LAYER instead, which needs no menu.
	// The layer sits under the reactive override and over the cvars, so "React to the action"
	// still flares on top and departs from the Look rather than from the player's settings.
	//
	// THE VALUES ARE THE SAME ONES, deliberately duplicated rather than shared: BloomTune
	// writes cvars one at a time and reads whatever it does not set, while the look layer
	// takes a complete set in one call. Folding them together would mean reading the cvars
	// here to fill the gaps -- and those cvars may already hold a previous Look's values,
	// which is exactly the bug this is fixing.
	//
	// The engine's own defaults fill anything a Look does not set: amount 1.4, threshold 1.0,
	// knee 0.5, tint white.
	static void BloomLook(int look)
	{
		double amount = 1.4, threshold = 1.0, knee = 0.5;
		double r = 1.0, g = 1.0, b = 1.0;

		switch (look)
		{
		case L_GOLDENHOUR:  amount = 1.2; r = 1.12; g = 1.00; b = 0.88; break;
		case L_VAPORWAVE:                 r = 1.05; g = 0.97; b = 1.05; break;
		case L_FROSTBITE:   threshold = 1.1; break;
		case L_TOXIC:                     r = 0.95; g = 1.08; b = 0.90; break;
		case L_SIGNALLOST:                r = 0.85; g = 1.15; b = 0.90; break;
		case L_HELLSCAPE:   threshold = 0.8; break;
		case L_CATHEDRAL:   amount = 1.2; r = 1.08; g = 1.00; b = 0.90; break;
		case L_REDALERT:    threshold = 0.8; r = 1.10; g = 0.85; b = 0.85; break;
		case L_LANTERN:     amount = 1.2; r = 1.08; g = 1.00; b = 0.92; break;
		case L_BLACKOUT:    amount = 2.2; threshold = 0.9; break;
		case L_THERMAL:     threshold = 1.2; break;
		}

		// The engine caps the knee at the threshold anyway -- a knee wider than the threshold
		// makes every dark pixel emit a grey haze -- but clamping here keeps the number the
		// player would see in the menu and the number in the layer the same.
		knee = min(knee, threshold);

		level.SetBloomLook(amount, threshold, knee, r, g, b, 1.0);
	}

	// ---- bloom: MENU CODE ONLY (the engine refuses these writes elsewhere) --

	static void BloomTune(int look)
	{
		// Never in a headset: streaks and fringing read as a smear on the lens.
		F("gl_bloom_chromatic", 0.0);
		Flag("gl_bloom_anamorphic", false);

		switch (look)
		{
		case L_GOLDENHOUR:
			F("gl_bloom_amount", 1.2);
			Tint(1.12, 1.0, 0.88);
			break;
		case L_VAPORWAVE:
			Tint(1.05, 0.97, 1.05);
			break;
		case L_FROSTBITE:
			F("gl_bloom_threshold", 1.1);
			break;
		case L_TOXIC:
			Tint(0.95, 1.08, 0.9);
			break;
		case L_SIGNALLOST:
			Tint(0.85, 1.15, 0.9);
			break;
		case L_HELLSCAPE:
			F("gl_bloom_threshold", 0.8);
			break;
		case L_CATHEDRAL:
			F("gl_bloom_amount", 1.2);
			Tint(1.08, 1.0, 0.9);
			break;
		case L_REDALERT:
			F("gl_bloom_threshold", 0.8);
			Tint(1.1, 0.85, 0.85);
			break;
		case L_LANTERN:
			F("gl_bloom_amount", 1.2);
			Tint(1.08, 1.0, 0.92);
			break;
		case L_BLACKOUT:
			F("gl_bloom_amount", 2.2);
			F("gl_bloom_threshold", 0.9);
			break;
		case L_THERMAL:
			F("gl_bloom_threshold", 1.2);
			Tint(1.0, 1.0, 1.0);
			break;
		}
		F("gl_bloom_knee", min(CVar.FindCVar("gl_bloom_knee").GetFloat(),
			CVar.FindCVar("gl_bloom_threshold").GetFloat()));
	}

	static void Tint(double r, double g, double b)
	{
		F("gl_bloom_tint_r", r); F("gl_bloom_tint_g", g); F("gl_bloom_tint_b", b);
	}
}
