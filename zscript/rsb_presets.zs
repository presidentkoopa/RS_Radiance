// RS_Bloom -- presets.
//
// These write the engine's own gl_bloom_* and gl_exposure_* cvars. There is no
// mod-side state and no second copy of anything: bloom is one global pass shared
// by every mod, and a private duplicate would only be a second thing to keep in
// step. They are applied from the Bloom menu's tick (RSB_BloomMenu), the only
// place the engine lets script write its cvars.
//
// WHAT THE CONTROLS ACTUALLY DO, since the names are not obvious:
//
//   threshold  how bright a pixel must be before it blooms at all, measured
//              AFTER the exposure gain -- so in a dark view (gain up to about
//              1/0.35) pixels well under full white can already cross 1.0.
//
//   knee       how gently it crosses that line. 0 is a hard cutoff, and a hard
//              cutoff makes pulsing glows pop in and out. THE KNEE MUST STAY AT
//              OR BELOW THE THRESHOLD: past it the extract lets even a black
//              pixel through at (K-T)^2/(4K), and the whole screen lifts to
//              grey (bloomextract.fp). Core() clamps it, so no preset can.
//
//   amount     blur radius. How far the glow spreads from what made it. The blur
//              has fixed taps, so past about 4 it stops getting wider.
//
//   anamorphic blur wider horizontally than vertically, so bright things streak
//              sideways the way they do through an anamorphic lens. The streak
//              also stops widening once amount times ratio passes about 4.
//
//   tint       colours the bloom independently of what produced it. A cold tint
//              over warm lights is most of what makes a scene look graded.
//
//   chromatic  offsets the colour channels radially, so bright edges break up
//              toward the screen edges the way light through glass does.
//
//   exposure   how bright the scene reads to the bloom pass only. Base() puts
//              it back to the engine defaults so every preset starts equal.
//
// None of these presets ever applied before 2026-09-14 (the old event handler
// was refused by the engine on every map load), so the values below were free to
// be corrected: every knee now sits at or below its threshold, and the streak
// ratios sit where they still widen the streak.

class RSB_Presets
{
	const COUNT = 12;

	// rsb_preset -1 is "None": leave bloom exactly as it is. It is the default,
	// because the grab lasers and the Lance are tuned around the engine's own
	// threshold (hw_vrmodes.cpp) -- any preset changes how they glow, so a
	// preset applies only when someone picks one, never on first opening the menu.
	const NO_PRESET = -1;

	static void F(String n, double v) { let c = CVar.FindCVar(n); if (c) c.SetFloat(v); }
	static void B(String n, bool v)   { let c = CVar.FindCVar(n); if (c) c.SetBool(v); }

	static int GetI(String n, int def)
	{
		let c = CVar.FindCVar(n); return c ? c.GetInt() : def;
	}
	static bool GetB(String n, bool def)
	{
		let c = CVar.FindCVar(n); return c ? c.GetBool() : def;
	}

	// Called every tic by RSB_BloomMenu while the Bloom page is open. Applies
	// the chosen preset once when it changes -- or again after "Re-apply preset"
	// sets the latch back to -1. Switched off, it leaves bloom exactly as it is.
	static void Sync()
	{
		if (!GetB("rsb_enabled", true)) return;

		int want = GetI("rsb_preset", NO_PRESET);
		if (want < 0 || want >= COUNT) return;
		if (want == GetI("rsb_preset_applied", NO_PRESET)) return;

		Apply(want);
		let latch = CVar.FindCVar("rsb_preset_applied");
		if (latch) latch.SetInt(want);
	}

	// on, amount, threshold, knee. The knee is clamped to the threshold here, so
	// no preset can ever grey the screen (see the note at the top).
	static void Core(bool on, double amount, double threshold, double knee)
	{
		B("gl_bloom", on);
		F("gl_bloom_amount", amount);
		F("gl_bloom_threshold", threshold);
		F("gl_bloom_knee", min(knee, threshold));
	}

	static void Lens(bool anamorphic, double ratio, double chromatic)
	{
		B("gl_bloom_anamorphic", anamorphic);
		F("gl_bloom_anamorphic_ratio", ratio);
		F("gl_bloom_chromatic", chromatic);
	}

	static void Tint(double r, double g, double b)
	{
		F("gl_bloom_tint_r", r);
		F("gl_bloom_tint_g", g);
		F("gl_bloom_tint_b", b);
	}

	// The engine's own exposure defaults (hw_postprocess_cvars.cpp).
	static void Exposure(double scale, double minimum, double base, double speed)
	{
		F("gl_exposure_scale", scale);
		F("gl_exposure_min", minimum);
		F("gl_exposure_base", base);
		F("gl_exposure_speed", speed);
	}

	// Every term, neutral, before a preset runs -- so a preset states only what
	// it cares about and can never wear the leftovers of the one before it.
	// Exposure is included: it changes what blooms, and "Vanilla" is not the
	// engine defaults if an earlier tweak to it survives.
	static void Base()
	{
		Core(true, 1.4, 1.0, 0.5);
		Lens(false, 3.0, 0.0);
		Tint(1.0, 1.0, 1.0);
		Exposure(1.3, 0.35, 0.35, 0.05);
		F("gl_bloom_step", 1.0);
	}

	static void Apply(int idx)
	{
		Base();
		switch (idx)
		{
		default:
		case 0:  Off();        break;
		case 1:  Vanilla();    break;
		case 2:  Emissive();   break;
		case 3:  Subtle();     break;
		case 4:  Heavy();      break;
		case 5:  Anamorphic(); break;
		case 6:  Cold();       break;
		case 7:  Furnace();    break;
		case 8:  Lens70();     break;
		case 9:  Neon();       break;
		case 10: FogGlow();    break;
		case 11: VRClean();    break;
		}
	}

	// No bloom at all. Worth having as a preset rather than only a switch,
	// because it is the honest comparison for everything below.
	static void Off()
	{
		Core(false, 1.4, 1.0, 0.5);
	}

	// The engine's own defaults, untouched. A mild knee.
	static void Vanilla()
	{
		Core(true, 1.4, 1.0, 0.5);
	}

	// THE ONE THIS FAMILY WANTS. Not the default: it lowers the threshold, which
	// changes the laser and Lance glow, so it waits for an A/B with both.
	//
	// Threshold down to 0.62 so a glow lane, a surface stamp or a neon core
	// blooms at the brightness it is actually drawn at. The knee is as generous
	// as it can be without passing the threshold -- it was written as 1.6, which
	// would have greyed every dark room.
	static void Emissive()
	{
		Core(true, 1.6, 0.62, 0.55);
	}

	// Present but restrained. For playing rather than for looking at.
	static void Subtle()
	{
		Core(true, 1.0, 0.85, 0.7);
	}

	// Everything blooms and it spreads a long way. Hazy and soft -- from the
	// spread, not from a knee that lifts the blacks.
	static void Heavy()
	{
		Core(true, 3.2, 0.45, 0.42);
	}

	// Sideways streaks off every bright thing. The most obviously cinematic of
	// the set and the one that most changes how a corridor of lights reads.
	// Ratio 2 at spread 2 is already the widest streak this blur can draw.
	static void Anamorphic()
	{
		Core(true, 2.0, 0.6, 0.5);
		Lens(true, 2.0, 0.015);
	}

	// A cold blue cast on the bloom over whatever colour made it, which is most
	// of what makes a scene look graded rather than lit.
	static void Cold()
	{
		Core(true, 1.8, 0.6, 0.5);
		Tint(0.72, 0.86, 1.25);
	}

	// The opposite: everything blooms warm, so fires and lava dominate and cold
	// lights are pulled toward them.
	static void Furnace()
	{
		Core(true, 2.0, 0.55, 0.45);
		Tint(1.30, 0.88, 0.66);
	}

	// Dirty optics. Wide anamorphic streaks plus heavy chromatic fringing, so
	// bright edges break up toward the corners of the screen.
	static void Lens70()
	{
		Core(true, 2.6, 0.5, 0.45);
		Lens(true, 1.5, 0.06);
		Tint(1.06, 0.98, 1.10);
	}

	// ---- added 2026-09-14 ---------------------------------------------------

	// For GlowInTheDark: the neon cores and glow lanes carry, lit walls do not.
	// A threshold a little above Emissive's keeps ordinary lighting out of it;
	// a tight spread keeps the glow hugging the line that made it.
	static void Neon()
	{
		Core(true, 1.3, 0.72, 0.6);
	}

	// For torch-lit mist (RS_Fog with RS_Flashlight): a wide, soft, slightly
	// warm spread so the beam in the fog reads as light in the air rather than
	// a bright stripe.
	static void FogGlow()
	{
		Core(true, 2.8, 0.8, 0.7);
		Tint(1.05, 1.0, 0.94);
	}

	// For the headset. Anamorphic streaks and chromatic fringing read as a flat
	// screen glued to your face in VR, so both are off; the glow stays.
	static void VRClean()
	{
		Core(true, 1.5, 0.7, 0.6);
		Lens(false, 3.0, 0.0);
	}
}
