// RS_Radiance -- applies Looks, rolls random ones, and the React switch.
//
// Applying a Look is two steps, because each effect's handler applies its own
// preset a tic or two after its cvar changes (server cvars land after a round
// trip) and a preset starts with Base(), which would wipe any tuning written
// before it:
//
//   1. Start: switch effects on or off and hand each its preset.
//   2. Once every preset has landed (or after two seconds), Tune.
//
// Runs from UiTick, so a Look picked with the menu open shows at once.

class RSR_Handler : EventHandler
{
	const WAIT_MAX = 70;   // tics to wait for presets before tuning anyway

	private ui int stage;       // 0 idle, 1 waiting for presets
	private ui int target;
	private ui int waited;

	// ---- applying -----------------------------------------------------

	override void UiTick()
	{
		if (gamestate != GS_LEVEL) return;

		SyncReactive();
		LowPowerFlicker();

		int want = RSR_Looks.GetI("rsr_look", 0);
		if (stage == 0)
		{
			if (want == RSR_Looks.GetI("rsr_look_applied", 0)) return;
			RSR_Looks.I("rsr_look_applied", want);
			if (want <= 0 || want >= RSR_Looks.COUNT) return;   // None: touch nothing

			RSR_Looks.Start(want);
			target = want;
			waited = 0;
			stage = 1;
			return;
		}

		// A different Look was picked while this one was landing: start over.
		if (want != target)
		{
			stage = 0;
			return;
		}

		waited++;
		if (!RSR_Looks.Landed(target) && waited < WAIT_MAX) return;

		RSR_Looks.Tune(target);
		stage = 0;
	}

	// ---- React to the action -----------------------------------------
	//
	// One switch for the parts that change with combat: bloom that reacts, and
	// sweep bands fired by kills and explosions.

	ui void SyncReactive()
	{
		bool want = RSR_Looks.GetI("rsr_reactive", 0) != 0;
		int now = want ? 1 : 0;
		if (now == RSR_Looks.GetI("rsr_reactive_applied", -1)) return;
		RSR_Looks.I("rsr_reactive_applied", now);

		RSR_Looks.Flag("rsb_reactive", want);
		RSR_Looks.Flag("rss_ev_kill", want);
		RSR_Looks.Flag("rss_ev_explode", want);
	}

	// ---- per-Look extras that run every tic ------------------------------
	//
	// Thermal: hot outlines on living monsters. Signal Lost: the map's own
	// colour drained. Low Power: the tube buzz comes in bursts.

	const HOT_R = 255; const HOT_G = 150; const HOT_B = 40;

	private bool outlined;      // Thermal outlines are on monsters right now
	private bool drained;       // Signal Lost set the desaturation

	override void WorldTick()
	{
		int look = RSR_Looks.GetI("rsr_look_applied", 0);

		// Thermal. Refreshed twice a second so new spawns get it too.
		bool hot = (look == RSR_Looks.L_THERMAL);
		if (hot && (level.maptime % 17) == 0) Outline(true);
		else if (!hot && outlined) Outline(false);

		// Signal Lost.
		bool drain = (look == RSR_Looks.L_SIGNALLOST);
		if (drain != drained)
		{
			Level.SetDesatGlobal(drain ? 0.85 : 0.0);
			drained = drain;
		}
	}

	void Outline(bool on)
	{
		let it = ThinkerIterator.Create("Actor");
		Actor a;
		while (a = Actor(it.Next()))
		{
			if (!a.bIsMonster) continue;
			if (on && a.health > 0)
			{
				a.OutlineColorA = Color(255, HOT_R, HOT_G, HOT_B);
				a.OutlineColorB = Color(255, 255, 240, 200);
				a.OutlineStrength = 1.0;
				a.OutlineThickness = 1.4;
				a.OutlineThreshold = 0.2;
				a.OutlineGlow = 3.0;
				a.OutlinePulse = 0.0;
				a.OutlineMode = 1;
			}
			else if (a.OutlineMode != 0 && a.OutlineColorA == Color(255, HOT_R, HOT_G, HOT_B))
			{
				a.OutlineMode = 0;   // only take off what Thermal put on
			}
		}
		outlined = on;
	}

	// Low Power's buzz: steady, then a burst of 0.2-1.5 s every 3-10 s.
	private ui int burstLeft;
	private ui int calmLeft;

	ui void LowPowerFlicker()
	{
		bool lowPower = RSR_Looks.GetI("rsr_look_applied", 0) == RSR_Looks.L_LOWPOWER;
		double want = 1.0;
		if (lowPower)
		{
			if (burstLeft > 0) burstLeft--;
			else if (calmLeft > 0) calmLeft--;
			else
			{
				burstLeft = 7 + (MSTime() % 46);          // 0.2 - 1.5 s
				calmLeft  = 105 + ((MSTime() / 7) % 246); // 3 - 10 s
			}
			want = (burstLeft > 0) ? 1.0 : 0.0;
		}
		let c = CVar.FindCVar("gitd_pulse_mod");
		if (c && c.GetFloat() != want) c.SetFloat(want);
	}

	// ---- random Looks -------------------------------------------------

	override void WorldLoaded(WorldEvent e)
	{
		// THE BLOOM LOOK IS DROPPED ON A MAP CHANGE, with everything else presentational the
		// engine holds, so it is pushed again here -- on every load, including a savegame or
		// a reopen, because the layer is gone in all three cases while the chosen Look is
		// not. Cheap: it is seven numbers into a struct.
		RSR_Looks.BloomLook(RSR_Looks.GetI("rsr_look", 0));

		if (e.IsSaveGame || e.IsReopen) return;
		if (RSR_Looks.GetI("rsr_rand_map", 0) != 0) Roll();
	}

	override void WorldThingDied(WorldEvent e)
	{
		if (!e.Thing || !e.Thing.player) return;
		if (e.Thing.PlayerNumber() != consoleplayer) return;
		if (RSR_Looks.GetI("rsr_rand_death", 0) != 0) Roll();
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Name ~== "rsr_surprise") Roll();
	}

	// Any Look but the one showing.
	void Roll()
	{
		int cur = RSR_Looks.GetI("rsr_look", 0);
		int pick = cur;
		for (int tries = 0; tries < 16 && pick == cur; tries++)
			pick = random(1, RSR_Looks.COUNT - 1);
		RSR_Looks.I("rsr_look", pick);
	}
}
