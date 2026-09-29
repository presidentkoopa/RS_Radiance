// RS_Darkness -- the handler.
//
// Almost nothing happens here, and that is the point. DarkDoomZ needs ~110
// lines to walk every sector, rewrite Sector.LightLevel through a curve, keep
// a backup array so it can undo itself, and fire a network event every single
// UiTick to notice a slider moved. This pushes four calls.
//
// The reason it can be this small is that the four curves already live in the
// fragment shader (DarknessAt in main.fp), transcribed from the same ZScript
// with the same constants. Nothing is written to the map, so there is no state
// to restore, nothing to fight over, and turning it off is genuinely just
// stopping rather than undoing. The engine clears the level's darkness switches
// on a map change; WorldLoaded pushes them straight back.

class RSD_Handler : EventHandler
{
	// THE PRESET THE SAVE WAS PLAYING UNDER, kept with the save.
	//
	// Every look cvar is a server cvar, and the engine writes server cvars into
	// a savegame and puts them back on load. The latch is nosave, so it is NOT
	// put back: loading a save taken under a different preset left rsd_preset
	// and the latch disagreeing, SyncPreset read that as a fresh pick, and the
	// whole preset re-applied over the tuned sliders the save had just restored.
	//
	// A handler field is serialized with the save, so this comes back with it
	// and says which preset the restored cvars already belong to. Stored PLUS
	// ONE, so a save from before the field existed reads 0 and restores nothing.
	int savedLatch;

	// FALSE UNTIL THIS HANDLER HAS HAD A LIVE START. Transient, so a handler
	// restored from a save comes back with it false -- and a restored handler
	// never gets WorldLoaded (events.cpp skips non-static handlers on a save
	// restore), which is why the restore has to be noticed in WorldTick.
	transient bool loadedLive;

	// A PRESET APPLIES WHEN IT CHANGES, NOT ON EVERY MAP. Apply is a batch of
	// CVar writes; re-running it on each WorldLoaded wiped whatever had been
	// tuned on the sliders since the preset was picked, every level. The
	// last-applied index lives in a CVar (rsd_preset_applied) because this
	// handler is rebuilt per map and would otherwise forget.
	//
	// AND FROM THE MENU. The playsim is paused while the options menu is up,
	// so a preset picked there was not applied until the menu closed, while
	// the sliders (read live by Push) moved the picture at once -- which read
	// as "the menu half works". UiTick runs under the menu; CVar writes are
	// not scope-bound. Both sides fire only on a change they have not seen.
	override void WorldLoaded(WorldEvent e)
	{
		// RS_Sweeps' darkness effect writes this while a sweep is acting. It
		// is nosave, and nosave cvars persist in the ini, so a value left by
		// the previous map -- or by quitting mid-sweep -- would otherwise
		// darken the start of this one with no sweep anywhere.
		SetF("rsd_sweep_offset", 0.0);
		loadedLive = true;

		SyncPreset();
		savedLatch = GetI("rsd_preset_applied", -1) + 1;
		Push();
	}

	override void WorldTick()
	{
		if (!loadedLive) ResumeFromSave();

		SyncPreset();
		savedLatch = GetI("rsd_preset_applied", -1) + 1;
		Push();
	}

	// The playsim stops while the menu is up, so WorldTick alone would freeze
	// the picture exactly while you are dragging the slider meant to change
	// it. SetDarkness is clearscope for this reason -- see doombase.zs.
	override void UiTick()
	{
		// Not until WorldTick has matched the latch to a restored save: a sync
		// here first would see the mismatch and re-apply over the save. The
		// push does not wait -- it only reads what the save put back.
		if (loadedLive) SyncPreset();
		Push();
	}

	// A handler restored from a save. The look cvars are the save's own, so
	// match the latch to the preset they were set under instead of applying
	// anything. The sweep offset goes back to 0 for the same reason WorldLoaded
	// clears it; if a sweep in the save is still acting, RS_Sweeps writes it
	// again on its next tic.
	void ResumeFromSave()
	{
		loadedLive = true;
		if (savedLatch > 0) RSD_Presets.I("rsd_preset_applied", savedLatch - 1);
		SetF("rsd_sweep_offset", 0.0);
	}

	clearscope static void SyncPreset()
	{
		// ONLY A SETTINGS CONTROLLER WRITES. Every client runs this, and the
		// engine refuses a server cvar write from anyone else with one console
		// line per cvar -- 12 to 19 of them every time the host changed preset.
		// The host's own writes reach every client regardless. netgame is
		// ui-only and this is clearscope, so multiplayer stands in for it.
		bool mayWrite = !multiplayer || players[consoleplayer].settings_controller;

		int want = GetI("rsd_preset", RSD_Presets.DEFAULT);
		// CLAMPED BEFORE IT LATCHES, to the mod's own default. rsd_preset is
		// reachable from the console, and storing an out-of-range value as
		// "applied" left the latch pointing at a preset that does not exist.
		// Written back as well, or the Preset row stays blank.
		if (want < 0 || want >= RSD_Presets.COUNT)
		{
			want = RSD_Presets.DEFAULT;
			if (mayWrite) RSD_Presets.I("rsd_preset", want);
		}
		if (want == GetI("rsd_preset_applied", -1)) return;

		// A client that may not write still latches, locally and silently, so
		// it does not retry every tic -- and so becoming a controller later
		// does not re-apply the preset over the host's tuned sliders.
		if (mayWrite) RSD_Presets.Apply(want);
		RSD_Presets.I("rsd_preset_applied", want);
	}

	// Every slider in the menu reaches the picture here, and UiTick runs this,
	// so they all move under the menu. Declared for menu_lint's live-page check:
	// LINT-UI-LIVE: rsd_adjust rsd_minlight rsd_pregain rsd_postgain rsd_dist rsd_dist_range
	// LINT-UI-LIVE: rsd_height rsd_height_range rsd_height_z rsd_height_offset rsd_actor_spare
	clearscope static void Push()
	{
		if (!Level) return;

		if (!GetB("rsd_enabled", true))
		{
			// Mode 0 is off in the shader, so this is a real stop rather than
			// a restore. Nothing was ever written to a sector to put back.
			Level.SetDarkness(0, 0, 0, 0, 0);
			Level.SetDarknessSpace(0, 0, 0, 0, 0);
			Level.SetDarknessActors(0);
			return;
		}

		int    mode      = GetI("rsd_mode", 1);
		// PLUS THE SWEEP. RS_Sweeps' darkness effect moves rsd_sweep_offset,
		// never rsd_adjust: rsd_adjust is a server cvar, so a sweep writing it
		// once per crossed sector queued a network write per sector per tic and
		// left its last value in the ini as the player's own Amount. The offset
		// is nosave and 0 when no sweep is acting. Clamped to the Amount
		// slider's range, which is also the range the curves are defined over --
		// deepen shadows divides by 33 - A/8, which reaches zero at 264.
		double adjust    = clamp(GetF("rsd_adjust", 128.0) + GetF("rsd_sweep_offset", 0.0), 0.0, 256.0);
		double minLight  = GetF("rsd_minlight", 0.0);
		double preGain   = GetF("rsd_pregain", 0.0);
		double postGain  = GetF("rsd_postgain", 0.0);
		double distDepth = GetF("rsd_dist", 0.0);
		double hDepth    = GetF("rsd_height", 0.0);

		// CURVE OFF IS NOT DARKNESS OFF. The shader returns before the distance
		// and height terms whenever the mode is 0, so Curve set to Off used to
		// silence the Distance and Height pages entirely. Subtract 0 with no
		// gains is an identity -- every fragment keeps exactly the light it had
		// -- so sending that instead leaves only range and height acting, which
		// is what Off plus a spatial depth means. Lantern does the same thing
		// on purpose.
		if (mode <= 0 && (distDepth > 0.0 || hDepth > 0.0))
		{
			mode = 1;
			adjust = 0.0;
			minLight = 0.0;
			preGain = 0.0;
			postGain = 0.0;
		}

		Level.SetDarkness(mode, adjust, minLight, preGain, postGain);

		// How much of the darkening actors are spared. The pass takes the
		// scene down as a whole, monsters included, so a room dark enough to
		// be worth lighting is a room you cannot see anything coming in.
		Level.SetDarknessActors(GetF("rsd_actor_spare", 0.4));

		// WHERE THE POOL STARTS.
		//
		// Fixed: rsd_height_z, handed over as written.
		//
		// Follows your feet: the RENDERER resolves the reference, every frame,
		// from the camera's interpolated Z plus the offset. It used to be worked
		// out here from players[consoleplayer].mo.pos.z, which is the raw 35 Hz
		// position while the view is drawn interpolated, so on lifts and stairs
		// the pool edge stepped against a smooth camera. The heightRef passed
		// to SetDarknessSpace is ignored in that mode; rsd_height_z is sent
		// anyway so the value stays sensible if the mode is ever dropped.
		//
		// OFFSET, or follow mode does almost nothing. The shader darkens only
		// below the reference, and your feet sit ON the floor -- so an unoffset
		// reference leaves flat ground alone entirely and only bites on geometry
		// you are standing above.
		//
		// Both modes are set on EVERY push, from UiTick too, so Reference and
		// Offset move the picture with the menu open, and a ClearDarkness from
		// anywhere (which resets follow to 0) is undone on the next tic.
		bool follow = GetI("rsd_height_mode", 0) == 1;
		Level.SetDarknessHeightFollow(follow ? 1 : 0, follow ? GetF("rsd_height_offset", 0.0) : 0.0);

		// WHICH SIDE THE DARK POOLS ON. 0 below the reference, which is what it has always
		// done and what a cellar wants; 1 above, which is what a ceiling wants -- dark
		// overhead with the floor still burning. Hellscape is built on the second.
		Level.SetDarknessSpace(
			distDepth,
			GetF("rsd_dist_range", 1024.0),
			hDepth,
			GetF("rsd_height_z", 0.0),
			GetF("rsd_height_range", 256.0),
			GetI("rsd_height_dir", 0));
	}

	// ---- cvar shorthand, clearscope so the push can reach it ---------------

	clearscope static double GetF(String n, double def = 0.0)
	{
		let c = CVar.FindCVar(n); return c ? c.GetFloat() : def;
	}

	clearscope static int GetI(String n, int def = 0)
	{
		let c = CVar.FindCVar(n); return c ? c.GetInt() : def;
	}

	clearscope static bool GetB(String n, bool def = false)
	{
		let c = CVar.FindCVar(n); return c ? c.GetBool() : def;
	}

	clearscope static void SetF(String n, double v)
	{
		let c = CVar.FindCVar(n); if (c) c.SetFloat(v);
	}
}
