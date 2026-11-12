# Owner device checklist

2026-11-12 owner report on 0.3.0: app works, but the Style page hangs. Installation/opening is reported successful; firmware, diagnostic photographs and a reproducible freeze sequence have not been supplied. DV01 is **Partial**; DV02–DV20 remain queued, **Not run** as structured checks. V01–V14 remain open. Candidate 0.3.2 removes Appearance as well as Style; check one-page Settings, system dark mode, timer detail and saved timers after upgrading. Open diagnostics through Menu → Device information. No 0.3.2 device checks have run. Host tests do not establish device results.

| ID | Step | Gate |
| --- | --- | --- |
| DV01 | Install, open, photograph Device information | V01, V02, V09 |
| DV02 | New timer, 10 s, Start. Watch the flash and the light; compare with a phone stopwatch | V03, §2.5 item 6 |
| DV03 | Try each alert pattern in a lit room and in the dark | V03 |
| DV04 | Fill the deck with ten items; read it at arm's length; tap rows and toggles | V12 |
| DV05 | Use the side buttons, and a page turner if available | V11 |
| DV06 | Start a 30-minute timer and do not touch the device. Note the battery before and after, once in each Seconds mode | V04 |
| DV07 | Turn the lock-screen page on. Lock during a 3-minute timer. Watch the page and the blink. Press the power key after the finish | V05, V06 |
| DV08 | Start a timer, leave the app for 37 s, return. Power off across a deadline, power on | TR02, TR08 |
| DV09 | Set the device clock back one hour while a timer runs; then restore it | V14 |
| DV10 | Run a timer showing seconds for two minutes; judge ghosting. Switch system dark mode with a double-press of Home or reader display settings | V07 |
| DV11 | Name a timer with the keyboard; cancel once | V13 |
| DV12 | Run a chain with two 10-second steps | §16 |
| DV13 | Put an import file on the card; import; export | §17 |
| DV14 | Reinstall the package over itself; data is kept. Report heap and last error | V09 |
| DV15 | Reset saved data | §14.10 |
| DV16 | Run a 10 s timer with three repeats. Judge the flash sequence and how soon a touch is accepted; compare with the previous candidate | POL-09 R5; revert R5 alone if worse |
| DV17 | Read deck toggle glyphs and bold titles at arm’s length, in light and system dark mode | POL-01, POL-02 |
| DV18 | Export to trigger a toast. Open Data → Reset saved data, then choose Keep | POL-04 |
| DV19 | With ten timers and a running chain, find the eleventh row using taps only | BUG-05 |
| DV20 | Run a two-step chain, tap during the step cue, wait for the final alert | BUG-02 |

DV16–DV20: **Not run**, queued for the owner. Record firmware, observations and photographs before changing any VERIFY status. The host’s simulated dark frames do not establish actual system inversion or ghosting behavior.
