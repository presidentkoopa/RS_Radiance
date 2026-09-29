// RS_Bloom -- the menu that applies the presets.
//
// WHY A MENU AND NOT AN EVENT HANDLER.
//
// A preset is a batch of writes to the ENGINE's gl_bloom_* and gl_exposure_*
// cvars, and the engine refuses script writes to its own cvars unless menu code
// is running ("Attempt to change CVAR outside of menu code", vmnatives.cpp).
// This mod used to stamp presets from an EventHandler -- WorldLoaded, WorldTick
// and UiTick are not menu code -- so the very first write aborted the VM on
// every map load and no preset ever applied.
//
// A menu's tick IS menu code: DMenu::CallTicker raises InMenu around Ticker
// (menu.cpp). So the Bloom page applies the preset from its own Ticker, the
// moment one is picked, while the page is open. Nothing has to happen at map
// load: the engine archives gl_bloom_* itself, so whatever a preset set is still
// set next launch.

class RSB_BloomMenu : OptionMenu
{
	override void Ticker()
	{
		Super.Ticker();
		RSB_Presets.Sync();
	}
}
