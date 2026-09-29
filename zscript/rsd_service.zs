// RS_Darkness -- what the darkness does to a light level, FOR THIS MACHINE'S MENU.
//
// WHY THIS IS UI-ONLY, AND WHY THAT IS THE WHOLE POINT.
//
// The question this answers -- "with the darkness settings in front of me, how
// much of a light level survives?" -- is a question about the LOCAL player's
// settings. That is exactly right for menu text and exactly wrong for anything
// that changes the world: two players with different Darkness presets would get
// different answers, and a playsim path that branched on one of them would put
// the two machines in different games.
//
// That is not hypothetical. This service's first consumer was RS_Ballistics'
// shot-out-lights floor, and it was removed as a SHIPPED NETPLAY BUG for doing
// precisely that (RS_Ballistics/zscript/rsb/lights.zs, "the darkness-aware floor
// is GONE from the decision"; Engine docs/CROSSPLATFORM_COOP_RULE.md).
//
// So the guard here is not a comment. Only the UI variant is implemented:
//
//   * a ui caller (a menu) gets the answer;
//   * a PLAY caller cannot reach GetDoubleUI at all -- the scope barrier
//     refuses it -- and the play GetDouble it can reach returns 0, which this
//     family's convention already reads as "no answer".
//
// A comment is advice. A missing function is a compile error.
//
// THE CURVE ONLY, NEVER THE SPATIAL TERMS. The distance and height terms in
// DarknessAt depend on where the player is standing and how far away a surface
// is, so an answer built on them would be true in the doorway and false three
// steps into the room. These answers are the curve at a fragment's own light
// level, which is what the shader computes before distance and height touch it.

class RSD_MenuDarknessService : Service
{
	// A real answer is never exactly 0, so a caller can treat 0.0 as "no
	// answer" -- an unknown request, no darkness mod, or a play-scope caller
	// that reached the wrong variant.
	const EPSILON = 0.0001;

	ui static double F(String n, double def)
	{
		let c = CVar.FindCVar(n); return c ? c.GetFloat() : def;
	}
	ui static int I(String n, int def)
	{
		let c = CVar.FindCVar(n); return c ? c.GetInt() : def;
	}
	ui static bool B(String n, bool def)
	{
		let c = CVar.FindCVar(n); return c ? c.GetBool() : def;
	}

	// The amount the SHADER is working with, not the menu's Amount: RS_Sweeps'
	// darkness effect adds rsd_sweep_offset while a band is crossing the level,
	// and RSD_Handler pushes the sum.
	ui static double EffectiveAdjust()
	{
		return clamp(F("rsd_adjust", 128.0) + F("rsd_sweep_offset", 0.0), 0.0, 256.0);
	}

	ui static bool CurveActive()
	{
		return B("rsd_enabled", true) && I("rsd_mode", 1) > 0;
	}

	// The fraction of `lightLevel` (Doom's 0-255) that survives the curve.
	// Transcribed from DarknessAt in main.fp -- same order, same constants, so
	// the answer matches what the player is looking at.
	ui static double Surviving(double lightLevel)
	{
		if (!CurveActive()) return 1.0;

		double base = clamp(lightLevel, 0.0, 255.0);
		if (base <= 0.0) return 1.0;      // already black; nothing to scale

		int mode = I("rsd_mode", 1);
		double A = EffectiveAdjust();
		double minLight = F("rsd_minlight", 0.0);
		double postGain = F("rsd_postgain", 0.0);

		// Pre-gain lifts the input before the curve, floored at 0: the slider
		// reaches -128, and mode 4 raises L to a power.
		double L = max(base + F("rsd_pregain", 0.0), 0.0);

		double outL;
		if (mode == 1)                    // subtract
			outL = L - A;
		else if (mode == 2)               // compress
			outL = L * (1.0 - A / 256.0);
		else if (mode == 3)               // cap brightest
			outL = min(L, 256.0 - A);
		else                              // deepen shadows -- exponential gamma
		{
			if (A <= 0.0) outL = L;
			else outL = (256.0 - (A ** (A / 256.0)))
				* ((L / 256.0) ** (1.0 + (A / (33.0 - (A / 8.0)))));
		}

		outL = max(outL, minLight);       // min light, a floor
		outL += postGain;                 // post-gain, a lift

		return clamp(outL / base, 0.0, 1.0);
	}

	// The raw sector light needed for `want` units to survive, or -1 when no
	// light level reaches it. Walked rather than solved: the four curves invert
	// differently and 256 steps once for a menu row is nothing.
	//
	// -1 IS A REAL ANSWER AND MEANS NOTHING SURVIVES. Under Blackout the curve
	// takes every light level to zero.
	ui static double FloorLight(double want)
	{
		if (want <= 0.0) return 0.0;
		if (!CurveActive()) return clamp(want, 0.0, 255.0);

		for (int lv = 0; lv <= 255; lv++)
		{
			double l = double(lv);
			if (l * Surviving(l) >= want) return l;
		}
		return -1.0;
	}

	// The ui variant, and the only one implemented. See the header.
	// NOT `override ui double` -- restating the base's scope is "Attempt to
	// change scope for virtual function" at LOAD, even when the scope is
	// exactly what the base declares. The ui-ness comes from the base.
	override double GetDoubleUI(String request, String stringArg, int intArg,
		double doubleArg, Object objectArg, Name nameArg)
	{
		// Lower-cased so a caller's "Surviving" is not a silent no-answer.
		String r = request.MakeLower();

		if (r == "active")     return CurveActive() ? 1.0 : 0.0;
		if (r == "surviving")  return max(Surviving(doubleArg), EPSILON);
		if (r == "floorlight") return FloorLight(doubleArg);

		return 0.0;   // unknown request: no answer
	}
}
