// RS_Bloom -- the one place that calls the engine's bloom override.
//
// Kept to one file so the reactive code never names an engine native directly:
// when the main lane sends the final names, only this file changes.
//
// ONE SLOT. The engine keeps a single bloom override, not a stack; a second
// mod calling it shares the slot. RSB_ReactiveHandler folds all its signals into
// one call per tic for that reason.
//
// pulse / pulseRate are a RENDERER-SIDE throb on the override's intensity,
// driven by the same timer as the glow shader: in phase with GitD's alarm
// pulse, smooth at frame rate, and still beating while a menu pauses the game.
// pulseRate 0 means "the glow alarm's own rate".

class RSB_Override
{
	clearscope static void Set(double spread, double threshold, double knee,
		double tintR, double tintG, double tintB, double mixAmount,
		double intensity, double fade, double pulse, double pulseRate)
	{
		Level.SetBloomOverride(spread, threshold, knee, tintR, tintG, tintB, mixAmount,
			intensity, fade, pulse, pulseRate);
	}

	// Quiet when nothing is set (the engine makes it a no-op), so calling it
	// every menu tic costs nothing and logs nothing.
	clearscope static void Clear()
	{
		Level.ClearBloomOverride();
	}
}
