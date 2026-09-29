// RS_Darkness -- the Curve page, with the honest answer on it.
//
// The sliders on that page say what the curve is DOING; none of them says what
// it LEAVES. "Amount 150, compress" is not an answer to "will I be able to see
// in a room the mapper lit at 128", and under some settings -- Blackout, or any
// preset whose post-gain pins every level to the same faint value -- the answer
// is "nothing survives at any light level", which no slider shows.
//
// So this page reads it out: two ordinary rooms, dim and bright, and what the
// curve leaves of each, updated as the sliders move.
//
// THIS IS THE SERVICE'S CALLER, and it is the reason the service exists at all.
// It asks through ServiceIterator rather than calling the maths directly, so
// there is one implementation of the curve mirror and the service has a
// demonstrated, unambiguously LOCAL consumer -- a menu, on this machine, about
// this machine's settings. See rsd_service.zs.

class RSD_CurveMenu : OptionMenu
{
	// Doom's own light levels for a dim corridor and a well-lit room, so the
	// two numbers mean something to someone who has built a map.
	const SAMPLE_DIM = 96.0;
	const SAMPLE_LIT = 192.0;

	private OptionMenuItemStaticText readout;
	private OptionMenuItemStaticText readout2;

	// Exact class name, not the first substring match: ServiceIterator.Find
	// matches names that merely CONTAIN the request, so a service named
	// RSD_MenuDarknessServiceAnything could answer instead.
	private Service Find()
	{
		let it = ServiceIterator.Find("RSD_MenuDarknessService");
		for (Service cand = it.Next(); cand; cand = it.Next())
			if (cand.GetClassName() == 'RSD_MenuDarknessService') return cand;
		return null;
	}

	private String Line(Service s, String what, double light)
	{
		double surviving = s.GetDoubleUI("surviving", "", 0, light);
		// The service never returns exactly 0 for a real answer.
		if (surviving <= 0.0) return String.Format("%s room: no answer", what);

		double left = light * surviving;
		if (left < 1.0)
			return String.Format("%s room (light %d): nothing survives", what, int(light));
		return String.Format("%s room (light %d): about %d left, %d%% of it",
			what, int(light), int(left + 0.5), int(surviving * 100.0 + 0.5));
	}

	override void Ticker()
	{
		Super.Ticker();
		if (!mDesc) return;

		// Appended once, at the bottom, so nothing on the page moves.
		if (!readout)
		{
			readout = new("OptionMenuItemStaticText");
			readout.Init("", Font.CR_GOLD, false);
			mDesc.mItems.Push(readout);

			readout2 = new("OptionMenuItemStaticText");
			readout2.Init("", Font.CR_GOLD, false);
			mDesc.mItems.Push(readout2);
		}

		let s = Find();
		if (!s)
		{
			readout.mLabel = "";
			readout2.mLabel = "";
			return;
		}

		if (s.GetDoubleUI("active") <= 0.0)
		{
			readout.mLabel = "Curve off: every room keeps its own light.";
			readout2.mLabel = "";
			return;
		}

		readout.mLabel = Line(s, "Dim", SAMPLE_DIM);
		readout2.mLabel = Line(s, "Lit", SAMPLE_LIT);
	}
}
