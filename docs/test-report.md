# Test report

2026-11-12 — M0 foundation, HOST MOCK. Device tests: Not run.

Passed: local archive SHA-256; Lua 5.5 / maxinteger 2147483647 / four-byte number assertions; vendored Lua 5.5 lint; API device lint; luac syntax compilation of seven app scripts; runtime self-tests (JSON and CRC, clock, timers, state, files, canvas/fonts, device/lock, sessions/overlays/errors, method receivers); shell/lock/fatal retry suite; 14 preview renders; manifest/version/icon validation; packager hash pins; decrypted script and manifest comparison; all 7,744 icon pixels compared. Package below 200 KB.

The first package attempt failed because the vendored xtapp module also imports mksd. Copied and pinned that MIT dependency. The second failed because an empty data section has no hmac_data; the wrapper now asserts that the section is absent. The final package round trip passed.

Inspected build/previews/HOST-MOCK-contact-sheet.png: shell, diagnostics, Ready, Running, 25%, 10%, Paused, Finished in light/dark. Digit/ring geometry readable; paused outline and finished circles distinct. Mock glyph metrics and Pillow rasterization do not reproduce device fonts or pixels. Runtime instruction counters are host proxies, not measured callback times.

Open: V01–V14; DV01 queued. TC01–TC22 and TR01–TR12 Not run until M1. TP04 vector icon generation belongs to M2; make icons currently regenerates the launcher only. No usable timer UI or alert effects yet.

Decisions: existing private remote acknowledged; Pebble 0.7.1 deltas remain an owner question; state filtering and inactive lock/canvas APIs follow the official contract. See decisions.md.

Next: M1 timing core and the 34 core/clock cases.


2026-11-12 — M1 timing core, HOST MOCK. Device tests: Not run.

Passed: TC01–TC22 and TR01–TR12, plus AUTO-RESET (35 named cases). Every command candidate and reconciled state is validated; refused commands preserve their input. TC12 runs 1,000 seeded trials of 100 pause/resume cycles, checks each sampled segment below one second error, total bounds and mean bias. TC22 runs 10,000 seeded commands/time steps. Fresh sandbox sessions prove reload isolation. Clock and checkpoint cases prove pure policy; no claim is made about a production save adapter or device refresh latency.

Passed: Lua 5.5/32 toolchain assertions; device lint including core global-write bytecode inspection; negative lint fixtures; syntax compilation of all ten app scripts; shell/lock/fatal retry suite; nine runtime self-test groups. The core suite took about 64 seconds on this host, not a device timing measurement.

Passed: 21 current preview frames generated; contact sheet and individual fatal, lock, dark shell, digit sizes, stopwatch ring and last-10% chip opened and inspected. Paths: build/previews/HOST-MOCK-contact-sheet.png and build/previews/HOST-MOCK-*.png. The shared ratio implementation moved into core/format.lua without changing ring geometry.

Passed: package manifest, version and 88×88 mode-1 icon validation; all three vendor hashes; decrypted equality of all ten scripts and manifest fields; all icon pixels; package under 200 KB. Final package details and SHA-256 are in dist/timerdeck-0.1.0.json and dist/SHA256SUMS. build/gate-results.json records step outcomes/durations and device_tests_run=false.

Open: V01–V14 remain Open; DV01 queued, all device checks Not run. M2–M8 test IDs are Not run. No host work is blocked on device evidence. The only generation deviations are the documented baseline corrections in decisions.md. No push, upload or network operation was performed.

Next: M2 foreground controls and vector icon generation. The current package remains a foundation preview, not candidate 0.1.0 (which requires M5).

M2 foreground interface — HOST MOCK. Foreground create/start/pause/resume/reset/edit/delete, ten-item geometry, draw purity, lazy modules, settle suppression, duplicate keys, Help/Device information and preview rollback passed in app_test.lua. 35 foreground preview frames generated; inspected ten-item deck, running detail, icon grid and days keypad. Vector regeneration checks all 30 baseline SVGs. Real touch feel and fonts remain V08/V12/V13. Alert/persistence failure extensions are covered by the following milestones, not these UI assertions.
