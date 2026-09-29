// RS_Fog -- presets.
//
// A preset is a batch of CVar writes and nothing else, exactly as in the other
// mods in this family. It owns WHAT the weather looks like. It never touches
// rsf_enabled or the event switches, because those are what the player turns on
// and off, and a preset stamping over them reads as the mod switching itself
// back on.

class RSF_Presets
{
	// How many Apply knows about. SyncPreset clamps to this, so adding a preset
	// and forgetting to raise it sends the new one to the default instead.
	const COUNT = 26;

	static void F(String n, double v) { let c = CVar.FindCVar(n); if (c) c.SetFloat(v); }
	static void I(String n, int v)    { let c = CVar.FindCVar(n); if (c) c.SetInt(v); }

	static void RGB(String pre, int r, int g, int b)
	{
		I(pre .. "_r", r); I(pre .. "_g", g); I(pre .. "_b", b);
	}

	// The body of it: where the top sits, how thick, how soft the edge, how
	// much the torch lights it, and how tightly it hugs the floor.
	static void Slab(double top, double density, double soft, double scatter, double follow)
	{
		F("rsf_top", top); F("rsf_density", density);
		F("rsf_soft", soft); F("rsf_scatter", scatter);
		F("rsf_follow", follow);
	}

	// How the surface moves, and how the body churns.
	static void Motion(double amp, double len, double speed, double swell,
		double noiseScale, double noiseDepth, double driftX, double driftY)
	{
		F("rsf_surf_amp", amp); F("rsf_surf_len", len);
		F("rsf_surf_speed", speed); F("rsf_surf_cross", swell);
		F("rsf_noise_scale", noiseScale); F("rsf_noise_depth", noiseDepth);
		F("rsf_drift_x", driftX); F("rsf_drift_y", driftY);
	}

	// Wisps rising out of it. Density 0 = none.
	static void Tendrils(double density, double spacing, double radius, double height,
		double rise, double spread, double lean, double taper)
	{
		F("rsf_tend_density", density); F("rsf_tend_spacing", spacing);
		F("rsf_tend_radius", radius);   F("rsf_tend_height", height);
		F("rsf_tend_rise", rise);       F("rsf_tend_spread", spread);
		F("rsf_tend_lean", lean);       F("rsf_tend_taper", taper);
	}

	// How much fog a room gets by whether it has sky over it. A sky ceiling is
	// outdoors, which is the marker every Doom map already carries. Both 1 is
	// one fog everywhere, which is what it was before.
	static void Zones(double indoor, double outdoor)
	{
		F("rsf_indoor", indoor); F("rsf_outdoor", outdoor);
	}

	// ---- ground the sixteen do not cover -------------------------------------
	//
	// Untouched across the whole existing set: the bottom edge (every preset is
	// a half-space), negative drift, and tendrils as the PRIMARY element rather
	// than a garnish on a thick slab.

	// Columns of steam standing in otherwise clear air. The wisps carry the
	// whole look and the slab is barely there to hold them up.
	// Closest to Swamp, and the inverse of it: a sixth of Swamp's density, with
	// tendrils two and a half times taller, thinner and further apart.
	static void Chimneys()
	{
		Zones(1.0, 1.0);
		Slab(48.0, 0.12, 26.0, 1.4, 0.45);
		Motion(6.0, 240.0, 0.5, 0.5, 0.011, 0.35, 1.0, 0.5);
		Tendrils(0.85, 230.0, 16.0, 300.0, 1.15, 0.7, 0.35, 0.85);
		RGB("rsf_col", 170, 168, 160);
		RGB("rsf_grad", 120, 112, 100);
		F("rsf_grad_mix", 0.35);
		F("rsf_pickup", 0.7);
	}

	// A layer floating at chest height with clear air underneath -- duck and
	// you can see the floor, stand and you cannot see the room.
	// Closest to Deep, which is also over your head but is a half-space filling
	// everything below its top. This is the first preset with a real BOTTOM, so
	// it is a ceiling you look up at as well as a surface you look down on.
	static void Shelf()
	{
		Zones(1.0, 1.0);
		Slab(132.0, 0.85, 22.0, 1.25, 0.5);
		F("rsf_bottom", 44.0);
		Motion(12.0, 268.0, 0.55, 0.7, 0.012, 0.5, 2.0, 1.0);
		Tendrils(0.0, 160.0, 22.0, 96.0, 0.5, 0.4, 0.2, 0.7);
		RGB("rsf_col", 146, 152, 168);
		RGB("rsf_grad", 88, 96, 116);
		F("rsf_grad_mix", 0.45);
		F("rsf_pickup", 0.55);
	}

	// Thick indoors and gone outdoors, so a window reads as a bright hole cut
	// in the fog. The exact inverse of Courtyard.
	// Closest to Cellar, but pushes the indoor gain to 1.80 against near
	// nothing outside, and takes most of its colour from the room so a lit
	// doorway blooms through it.
	static void Chapel()
	{
		Zones(1.8, 0.05);
		Slab(160.0, 0.6, 46.0, 1.5, 0.3);
		Motion(11.0, 320.0, 0.4, 0.65, 0.010, 0.42, 1.2, 0.6);
		Tendrils(0.2, 180.0, 24.0, 120.0, 0.35, 0.4, 0.2, 0.7);
		RGB("rsf_col", 158, 150, 136);
		RGB("rsf_grad", 96, 88, 76);
		F("rsf_grad_mix", 0.4);
		F("rsf_pickup", 0.85);
	}

	// Weather driven hard across open ground and stopping dead at a doorway.
	// Closest to Courtyard, but this is the widest indoor/outdoor split in the
	// set, the drift is nearly four times Courtyard's, and it is the only preset
	// that drifts SOUTH as well as east.
	static void Gale()
	{
		Zones(0.05, 1.9);
		Slab(288.0, 0.7, 80.0, 1.5, 0.15);
		Motion(9.0, 200.0, 2.0, 0.45, 0.024, 0.4, 26.0, -14.0);
		Tendrils(0.0, 160.0, 22.0, 96.0, 0.5, 0.4, 0.2, 0.7);
		RGB("rsf_col", 186, 194, 206);
		F("rsf_grad_mix", 0.0);
		F("rsf_pickup", 0.35);
	}

	// ---- 20-24: the heavy end (owner, 2026-09-18: "more denser options") -----
	//
	// The existing ladder tops out at Pea Soup (1.45 over 640 units), which was
	// the Density slider's old maximum. These five go past it, so the slider now
	// reaches 3.0 and the top reaches 1024 -- range added, nothing moved.
	//
	// Density is per 1000 units of travel below the top, so doubling it halves
	// the distance you can see into the fog. Each of these picks a different way
	// to be thick rather than just a bigger number: everywhere, underfoot, at
	// eye level, a ceiling with clear air under it, and drowned.

	// 20 -- THICK EVERYWHERE, AND BRIGHT WITH IT. Daylight in cloud: the fog is
	// its own light source rather than something the torch has to find. Barely
	// moves, takes almost no colour from the room, so it reads as distance
	// rather than as weather. Pea Soup with half again the density and a much
	// brighter body.
	static void Whiteout()
	{
		Zones(1.0, 1.0);
		Slab(768.0, 1.90, 140.0, 1.70, 0.05);
		Motion(20.0, 380.0, 0.35, 0.70, 0.008, 0.55, 1.5, 0.8);
		RGB("rsf_col", 226, 230, 238);
		RGB("rsf_grad", 176, 182, 196);
		F("rsf_grad_mix", 0.35);
		F("rsf_pickup", 0.30);
	}

	// 21 -- DENSE AND LOW. Waist height, but thick enough that your legs are
	// gone: the densest thing in the set per unit of travel, over the shortest
	// span. Nearly black on its own and takes most of its colour from the room,
	// so a lamp turns the whole pool the lamp's colour. Hugs the floor hard.
	static void Tar()
	{
		Zones(1.0, 1.0);
		Slab(140.0, 2.40, 30.0, 1.90, 0.60);
		Motion(14.0, 200.0, 0.30, 0.75, 0.016, 0.60, 1.0, 0.5);
		Tendrils(0.45, 150.0, 26.0, 120.0, 0.35, 0.45, 0.25, 0.70);
		RGB("rsf_col", 46, 44, 42);
		RGB("rsf_grad", 22, 20, 18);
		F("rsf_grad_mix", 0.50);
		F("rsf_pickup", 0.85);
	}

	// 22 -- THICK AND SICK. Toxic's colour at four times its density and four
	// times its height, with wisps standing in it. Reads as a chemical leak
	// rather than as weather, and it is the dense preset that is still clearly
	// a COLOUR rather than a grey.
	static void Sulphur()
	{
		Zones(1.0, 1.0);
		Slab(360.0, 1.80, 70.0, 1.60, 0.20);
		Motion(18.0, 232.0, 0.75, 0.70, 0.018, 0.58, 3.5, 1.8);
		Tendrils(0.55, 150.0, 22.0, 170.0, 0.80, 0.50, 0.30, 0.60);
		RGB("rsf_col", 176, 178, 96);
		RGB("rsf_grad", 124, 142, 58);
		F("rsf_grad_mix", 0.55);
		F("rsf_pickup", 0.80);
	}

	// 23 -- A THICK CEILING WITH CLEAR AIR UNDER IT. Shelf's idea at nearly
	// three times the density: standing, you see nothing; crouched, the floor
	// and everyone's feet are clear. The only dense preset you can duck out of,
	// and the reason the bottom edge exists.
	static void Bank()
	{
		Zones(1.0, 1.0);
		Slab(176.0, 2.20, 24.0, 1.50, 0.45);
		F("rsf_bottom", 56.0);
		Motion(10.0, 256.0, 0.50, 0.70, 0.013, 0.50, 2.0, 1.0);
		RGB("rsf_col", 138, 144, 156);
		RGB("rsf_grad", 84, 90, 104);
		F("rsf_grad_mix", 0.45);
		F("rsf_pickup", 0.60);
	}

	// 24 -- THE WHOLE MAP, GONE. The top is above anything Doom builds and the
	// density is the set's highest, so there is no surface to look down at and
	// no clear air anywhere: you navigate by the torch, by glow and by sound.
	// The end of the ladder -- nothing denser would look different, only slower.
	static void Drowned()
	{
		Zones(1.0, 1.0);
		Slab(1024.0, 2.80, 160.0, 2.00, 0.0);
		Motion(30.0, 400.0, 0.40, 0.75, 0.007, 0.65, 1.5, 0.8);
		RGB("rsf_col", 96, 104, 116);
		RGB("rsf_grad", 40, 46, 56);
		F("rsf_grad_mix", 0.60);
		F("rsf_pickup", 0.70);
	}


	// 25 -- KNEE DEEP AND SOLID. The density of Tar at half its height: the top
	// sits just above the knee, so you look DOWN at the surface and watch it
	// move, and it is thick enough that your boots are gone in it.
	//
	// This is the one to switch the Events on for. Everything the fog does in
	// answer to the world happens AT ITS SURFACE -- your wake, monsters parting
	// it, a death rippling it, an explosion lighting it from inside -- and at
	// chest height you are standing inside the effect instead of looking at it.
	// A crisp edge (softness 12, the tightest in the set) is what makes a wake
	// read as a wake rather than as a soft patch.
	//
	// It hugs the floor hard so stairs and ledges cut it cleanly, and takes most
	// of its colour from the room so a torch beam through it carries.
	static void KneeDeep()
	{
		Zones(1.0, 1.0);
		Slab(52.0, 2.60, 12.0, 1.80, 0.75);
		Motion(9.0, 176.0, 0.60, 0.80, 0.020, 0.55, 1.5, 0.8);
		Tendrils(0.35, 132.0, 18.0, 84.0, 0.55, 0.40, 0.20, 0.80);
		RGB("rsf_col", 150, 156, 164);
		RGB("rsf_grad", 92, 98, 108);
		F("rsf_grad_mix", 0.45);
		F("rsf_pickup", 0.80);
	}

	// EVERY TERM, NEUTRAL. Called by Apply before the preset runs, so a preset
	// only has to state what it actually cares about and can never wear the
	// leftovers of the one before it.
	//
	// This is the shape GlowInTheDark and Darkness already had and Fog did not,
	// which is exactly how seven presets ended up inheriting an indoor/outdoor
	// split they never asked for: pick Courtyard, switch to Swamp, and Swamp
	// stayed thin indoors with nothing in the menu to explain it.
	//
	// The bottom's period and roll have no menu row, so a console-set value
	// used to survive every preset change with nothing to explain it. The sweep
	// bow and the flash colour are NOT reset here: they sit on the Events page,
	// which presets never touch.
	static void Base()
	{
		Zones(1.0, 1.0);
		Slab(64.0, 0.55, 24.0, 1.0, 0.35);
		Motion(10.0, 256.0, 1.0, 0.6, 0.012, 0.45, 3.0, 1.5);
		Tendrils(0.0, 160.0, 22.0, 96.0, 0.5, 0.4, 0.2, 0.7);
		RGB("rsf_col", 168, 176, 190);
		RGB("rsf_grad", 0, 0, 0);
		F("rsf_grad_mix", 0.0);
		F("rsf_pickup", 0.5);
		F("rsf_bottom", -256.0);
		F("rsf_bottom_period", 0.0);
		F("rsf_bottom_roll", 0.0);
	}

	static void Apply(int idx)
	{
		Base();

		switch (idx)
		{
		default:
		case 0: Off();        break;
		case 1: GroundMist(); break;
		case 2: Swamp();      break;
		case 3: Smoke();      break;
		case 4: Toxic();      break;
		case 5: Blizzard();   break;
		case 6: Ember();      break;
		case 7: Deep();       break;
		case 8:  FaintHaze();  break;
		case 9:  LightMist();  break;
		case 10: HeavyMist();  break;
		case 11: Murk();       break;
		case 12: PeaSoup();    break;
		case 13: Cellar();     break;
		case 14: Courtyard();  break;
		case 15: NightAir();   break;
		case 16: Chimneys();   break;
		case 17: Shelf();      break;
		case 18: Chapel();     break;
		case 19: Gale();       break;
		case 20: Whiteout();   break;
		case 21: Tar();        break;
		case 22: Sulphur();    break;
		case 23: Bank();       break;
		case 24: Drowned();    break;
		case 25: KneeDeep();   break;
		}
	}

	// Not a look -- an off. Density 0 stops the shader at its first gate.
	static void Off()
	{
		Zones(1.0, 1.0);
		Slab(0.0, 0.0, 16.0, 1.0, 0.0);
		Tendrils(0.0, 160.0, 22.0, 96.0, 0.5, 0.4, 0.2, 0.7);
		F("rsf_grad_mix", 0.0);
	}

	// Ankle-deep, barely moving, follows the floor. The default, and the one
	// that reads as a place rather than as an effect.
	static void GroundMist()
	{
		Zones(1.0, 1.0);
		Slab(56.0, 0.45, 28.0, 1.0, 0.35);
		Motion(8.0, 288.0, 0.7, 0.6, 0.010, 0.40, 2.5, 1.2);
		Tendrils(0.0, 160.0, 22.0, 96.0, 0.5, 0.4, 0.2, 0.7);
		RGB("rsf_col", 168, 176, 190);
		F("rsf_grad_mix", 0.0);
		F("rsf_pickup", 0.55);
	}

	// Waist-high, heavy, with wisps standing out of it. Slow.
	static void Swamp()
	{
		Zones(1.0, 1.0);
		Slab(112.0, 0.7, 40.0, 1.1, 0.3);
		Motion(16.0, 224.0, 0.45, 0.75, 0.014, 0.55, 1.5, 0.8);
		Tendrils(0.5, 128.0, 26.0, 132.0, 0.35, 0.5, 0.3, 0.65);
		RGB("rsf_col", 132, 150, 128);
		RGB("rsf_grad", 90, 110, 92);
		F("rsf_grad_mix", 0.45);
		F("rsf_pickup", 0.4);
	}

	// Head-height and churning, lit hard by the torch. Reads as a fire that
	// already happened.
	static void Smoke()
	{
		Zones(1.0, 1.0);
		Slab(176.0, 0.62, 56.0, 1.5, 0.2);
		Motion(22.0, 176.0, 1.4, 0.8, 0.020, 0.75, 6.0, 3.5);
		Tendrils(0.35, 200.0, 34.0, 180.0, 0.9, 0.6, 0.45, 0.5);
		RGB("rsf_col", 92, 92, 96);
		RGB("rsf_grad", 40, 40, 44);
		F("rsf_grad_mix", 0.55);
		F("rsf_pickup", 0.7);
	}

	// Thin, bright and sick. Picks up the room's glow hard, so it goes whatever
	// colour the lighting is -- which is the point.
	static void Toxic()
	{
		Zones(1.0, 1.0);
		Slab(88.0, 0.5, 32.0, 1.3, 0.35);
		Motion(12.0, 208.0, 1.1, 0.65, 0.016, 0.5, 4.0, 2.0);
		Tendrils(0.4, 144.0, 20.0, 120.0, 0.7, 0.45, 0.25, 0.6);
		RGB("rsf_col", 150, 200, 120);
		RGB("rsf_grad", 190, 230, 90);
		F("rsf_grad_mix", 0.5);
		F("rsf_pickup", 0.95);
	}

	// Thick, fast, and driven sideways. The drift is what sells it.
	static void Blizzard()
	{
		Zones(1.0, 1.0);
		Slab(320.0, 0.5, 96.0, 1.6, 0.1);
		Motion(6.0, 128.0, 2.4, 0.4, 0.026, 0.35, 22.0, 9.0);
		Tendrils(0.0, 160.0, 22.0, 96.0, 0.5, 0.4, 0.2, 0.7);
		RGB("rsf_col", 216, 224, 236);
		F("rsf_grad_mix", 0.0);
		F("rsf_pickup", 0.25);
	}

	// Low, dark, and hot underneath. Nearly all of its colour comes from
	// whatever is glowing nearby.
	static void Ember()
	{
		Zones(1.0, 1.0);
		Slab(72.0, 0.55, 30.0, 1.2, 0.4);
		Motion(10.0, 256.0, 0.8, 0.6, 0.013, 0.5, 3.0, 1.6);
		Tendrils(0.45, 152.0, 24.0, 104.0, 0.6, 0.4, 0.25, 0.7);
		RGB("rsf_col", 70, 58, 54);
		RGB("rsf_grad", 190, 90, 40);
		F("rsf_grad_mix", 0.6);
		F("rsf_pickup", 1.0);
	}

	// ---- the density ladder ------------------------------------------------
	//
	// Five settings of the same fog, differing in how much of it there is and
	// nothing else. The point is to be able to say "this, but less" without
	// changing the character of the room.

	// Barely there. You would not notice it until you looked down a corridor.
	static void FaintHaze()
	{
		Zones(1.0, 1.0);
		Slab(40.0, 0.14, 24.0, 0.8, 0.4);
		Motion(5.0, 320.0, 0.5, 0.5, 0.008, 0.30, 1.5, 0.8);
		Tendrils(0.0, 160.0, 22.0, 96.0, 0.5, 0.4, 0.2, 0.7);
		RGB("rsf_col", 180, 186, 196);
		F("rsf_grad_mix", 0.0);
		F("rsf_pickup", 0.45);
	}

	// Reads clearly, still shows you the room.
	static void LightMist()
	{
		Zones(1.0, 1.0);
		Slab(64.0, 0.32, 28.0, 1.0, 0.35);
		Motion(8.0, 288.0, 0.7, 0.6, 0.010, 0.38, 2.5, 1.2);
		Tendrils(0.0, 160.0, 22.0, 96.0, 0.5, 0.4, 0.2, 0.7);
		RGB("rsf_col", 172, 180, 192);
		F("rsf_grad_mix", 0.0);
		F("rsf_pickup", 0.5);
	}

	// Knee to waist, definitely weather. The reasonable middle.
	static void HeavyMist()
	{
		Zones(1.0, 1.0);
		Slab(104.0, 0.58, 36.0, 1.1, 0.3);
		Motion(14.0, 256.0, 0.8, 0.65, 0.013, 0.48, 3.5, 1.8);
		Tendrils(0.3, 150.0, 24.0, 110.0, 0.5, 0.45, 0.25, 0.65);
		RGB("rsf_col", 164, 172, 186);
		RGB("rsf_grad", 120, 130, 148);
		F("rsf_grad_mix", 0.35);
		F("rsf_pickup", 0.55);
	}

	// Over your head and hard to see through. Fights you.
	static void Murk()
	{
		Zones(1.0, 1.0);
		Slab(240.0, 0.95, 72.0, 1.3, 0.15);
		Motion(20.0, 288.0, 0.65, 0.7, 0.011, 0.55, 3.0, 1.5);
		Tendrils(0.35, 170.0, 28.0, 150.0, 0.55, 0.5, 0.3, 0.6);
		RGB("rsf_col", 140, 146, 158);
		RGB("rsf_grad", 82, 88, 102);
		F("rsf_grad_mix", 0.5);
		F("rsf_pickup", 0.6);
	}

	// Completely murky. You navigate by the glow and by sound.
	static void PeaSoup()
	{
		Zones(1.0, 1.0);
		Slab(640.0, 1.45, 160.0, 1.6, 0.05);
		Motion(26.0, 340.0, 0.5, 0.75, 0.009, 0.62, 2.0, 1.0);
		Tendrils(0.0, 160.0, 22.0, 96.0, 0.5, 0.4, 0.2, 0.7);
		RGB("rsf_col", 126, 132, 142);
		RGB("rsf_grad", 70, 74, 84);
		F("rsf_grad_mix", 0.55);
		F("rsf_pickup", 0.65);
	}

	// ---- rooms that know what they are --------------------------------------
	//
	// These three set the indoor/outdoor split as part of the look. A sky
	// ceiling is outdoors, so they work on any map without it being authored
	// for them, and a window shows you weather you are not standing in --
	// the far wall outside fogs as outdoor, the near wall does not.

	// Damp that pools inside and burns off in the open.
	static void Cellar()
	{
		Zones(1.35, 0.15);
		Slab(72.0, 0.55, 30.0, 1.1, 0.45);
		Motion(9.0, 224.0, 0.45, 0.6, 0.012, 0.45, 1.5, 0.8);
		Tendrils(0.4, 140.0, 22.0, 104.0, 0.4, 0.45, 0.25, 0.7);
		RGB("rsf_col", 150, 156, 160);
		RGB("rsf_grad", 96, 104, 110);
		F("rsf_grad_mix", 0.4);
		F("rsf_pickup", 0.5);
	}

	// Weather outside, dry indoors. Step through a door and it stops.
	static void Courtyard()
	{
		Zones(0.12, 1.25);
		Slab(128.0, 0.6, 44.0, 1.2, 0.3);
		Motion(15.0, 300.0, 1.0, 0.7, 0.012, 0.45, 7.0, 3.0);
		Tendrils(0.0, 160.0, 22.0, 96.0, 0.5, 0.4, 0.2, 0.7);
		RGB("rsf_col", 176, 184, 200);
		F("rsf_grad_mix", 0.0);
		F("rsf_pickup", 0.5);
	}

	// Heavy night air outside, a thin haze indoors -- not nothing, so a room
	// with a window does not read as two unrelated places.
	static void NightAir()
	{
		Zones(0.3, 1.5);
		Slab(320.0, 0.75, 88.0, 1.35, 0.2);
		Motion(18.0, 360.0, 0.6, 0.7, 0.010, 0.5, 5.0, 2.5);
		Tendrils(0.25, 190.0, 26.0, 140.0, 0.5, 0.5, 0.3, 0.6);
		RGB("rsf_col", 120, 132, 156);
		RGB("rsf_grad", 64, 74, 96);
		F("rsf_grad_mix", 0.5);
		F("rsf_pickup", 0.6);
	}

	// Over your head. You are inside it, not looking at it.
	static void Deep()
	{
		Zones(1.0, 1.0);
		Slab(512.0, 0.8, 128.0, 1.4, 0.05);
		Motion(28.0, 320.0, 0.6, 0.7, 0.009, 0.6, 2.0, 1.0);
		Tendrils(0.0, 160.0, 22.0, 96.0, 0.5, 0.4, 0.2, 0.7);
		RGB("rsf_col", 118, 126, 140);
		RGB("rsf_grad", 60, 68, 84);
		F("rsf_grad_mix", 0.5);
		F("rsf_pickup", 0.5);
	}
}
