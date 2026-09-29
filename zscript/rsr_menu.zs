// RS_Radiance -- the top page.
//
// Its ticker is menu code, which is the only place the engine lets script
// write gl_bloom_*: so this page applies the bloom preset and the Look's bloom
// tuning, the same way RS_Bloom's own page does.

class RSR_MainMenu : OptionMenu
{
	override void Ticker()
	{
		Super.Ticker();
		RSR_BloomSync();
	}

	static void RSR_BloomSync()
	{
		RSB_Presets.Sync();

		int look = RSR_Looks.GetI("rsr_bloom_pending", -1);
		if (look < 0) return;
		if (RSR_Looks.GetI("rsb_preset_applied", -1) != RSR_Looks.GetI("rsb_preset", -1)) return;

		RSR_Looks.BloomTune(look);
		RSR_Looks.I("rsr_bloom_pending", -1);
	}
}

// RS_Bloom's page gets the same, so a Look's bloom lands whichever page is open.
class RSR_BloomMenu : RSB_BloomMenu
{
	override void Ticker()
	{
		Super.Ticker();
		RSR_MainMenu.RSR_BloomSync();
	}
}
