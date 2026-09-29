RS_Radiance
===========

Darkness, Glow, Fog, Sweeps, Bloom and Flashlight in one mod, with one menu.

Options > Radiance.

LOAD THIS INSTEAD OF RS_Darkness, RS_GlowInTheDark, RS_Fog, RS_Sweeps,
RS_Bloom and RS_Flashlight. They share class names and will not load together.

Looks
  Golden Hour, Vaporwave, Frostbite, Toxic, Storm, Drowned, Signal Lost,
  Hellscape, Low Power, Cathedral, Neon, Red Alert, Lantern, Blackout, Thermal.

  A Look sets a preset for each effect, then tunes them to each other.
  Every effect's full settings are under Advanced.

  A Look applies immediately, bloom included. (It used to wait for the
  Radiance page to be opened, because the engine refuses cvar writes from
  play code; the engine now carries a bloom "look layer" under its reactive
  override, which needs no menu.)

Keys
  F                 flashlight
  Random Look       bind it in Customize Controls > Radiance
