// RS_Fog -- shared helpers.
//
// Deliberately the same shape as GITD_Util, RSD's, RSI_Util, RSDF and RSKC.
// These mods merge eventually and the identical copies collapse into one --
// which is only painless if they have not drifted. A fix in one is a fix in all.
//
// clearscope throughout, because the push runs from UiTick as well as
// WorldTick so the fog changes while its menu is open, and a play-scoped helper
// would put the whole chain out of reach.

class RSF
{
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
	clearscope static void SetI(String n, int v)
	{
		let c = CVar.FindCVar(n); if (c) c.SetInt(v);
	}

	// ALWAYS alpha 255. A colour that loses its alpha is the most expensive bug
	// in this family of mods -- several draw paths gate on `.a > 0` and simply
	// stop, with no error anywhere.
	clearscope static Color RGB(String pre)
	{
		return Color(255,
			clamp(GetI(pre .. "_r", 160), 0, 255),
			clamp(GetI(pre .. "_g", 170), 0, 255),
			clamp(GetI(pre .. "_b", 185), 0, 255));
	}
}
