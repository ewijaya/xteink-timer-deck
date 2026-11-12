# Platform findings

Host suites are HOST MOCK only. On 2026-11-12 the owner reported successful use of 0.3.0 but a hang on Style. The cause is unconfirmed; no firmware or diagnostic measurements were supplied. All VERIFY items remain open. Version 0.3.1 removes Style at the owner’s request; device retest is pending.

| ID | Status | Probe / question |
| --- | --- | --- |
| V01 | Open | `ctx.api.minor`, `ctx.device.firmware`, `ctx.device.model`, every `ctx.capabilities` field |
| V02 | Open | Does the pinned packager's package install on 26110501? |
| V03 | Open | `ctx.frontlight:set` latency and visibility of 300 ms and 900 ms pulses, lit room and dark room |
| V04 | Open | Does `keep_awake` hold the device awake for 30 minutes with no input? Battery percent lost per hour awake in each Seconds mode |
| V05 | Open | Lock-screen page: appears on power-key lock and idle lock; `set_interval(30)` honoured; session time for our `lock.lua` |
| V06 | Open | After the power key leaves the lock screen, does Timer Deck reopen by itself when it was in front? |
| V07 | Open | Partial-refresh ghosting after 60 one-second frames; readability of an inverted (dark) frame |
| V08 | Open | Vector digits at 96 px: draw time, command count, legibility. `ctx.fonts:size(96, "0123456789:")` as the alternative |
| V09 | Open | Heap after load, after opening every screen once, after 100 create/delete cycles (`ctx.gc:count()`) |
| V10 | Open | `ctx:save_state()` and `ctx.storage:write` time for the full-size state |
| V11 | Open | Key events: duplicates, order of `down`/`up`, page-turner behaviour |
| V12 | Open | Tap accuracy on 63 px rows and 72 px buttons |
| V13 | Open | `ctx.input:text` with `max_bytes = 16`: what the keyboard allows, what cancel returns |
| V14 | Open | Behaviour when `ctx.clock:now().valid` is false, and after changing the device time while the app is open (`revision`) |
