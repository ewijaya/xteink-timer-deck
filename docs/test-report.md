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

M3 persistence — HOST MOCK. Passed make test: toolchain, lint, icon reproducibility, compilation, foreground/core/runtime/storage suites, negative lint fixtures and 39 previews. TS02–TS11 passed; TS01 currently covers ten items and reserved containers, with the fullest chain state deferred to M6. Recovery and blocked previews inspected. Device tests Not run; V01–V14 remain open. Files: store adapter, controller recovery/backup flow (included with M2), store_test.lua, gate and preview fixtures. No additional deviations. Next: M4 attention and cadence.

M4 attention — HOST MOCK. Passed full make test including TA01–TA15 and TD01–TD05 assertions, TU14 theme inversion, all prior suites and 45 previews. Light events, saved attempt counters, interruption, fairness, re-entry, keep-awake and exit dialog checked. Opened coverage deck and flash; corrected label/value spacing, regenerated and inspected. Device latency, light, battery, ghosting and other V01–V14 remain Open; no device tests run. Added alerts/signal modules, attention tests, controller scheduling and coverage UI. Next: M5 read-only lock page.

M5 lockscreen — HOST MOCK. Passed full make test and TL01–TL06: module whitelist, read-only state, priorities, elapsed deadlines, blink windows, adaptive intervals, invalid state/clock and injected failures. 57 previews generated; opened running, finished and paused lock frames in both visual polarities. Added glance.lua, lock.lua, settings toggle and lock tests. V01–V14 and all DV checks remain Open/Not run. Candidate 0.1.0 is host-validated only. No new deviations. Next: M6 chains.

M6 chains — HOST MOCK. Passed full make test, TH01–TH10 plus chain UI walk, full TS01 state (6,663 JSON bytes), rollback and lock projection. 79 previews rendered; inspected editor, overview, run and ten-item deck with chain row. Added chains core/UI; integrated model, pulse, alerts, lock and navigation. Fixed the fresh-session test fixture after its first failure; final gate Passed. V01–V14 and DV01–DV15 remain Open/Not run. Candidate 0.2.0 is host-validated only. Next: styles and file sync.

M7 styles and sync — HOST MOCK. Passed full make test, TI01–TI04 including all-or-nothing failures, at-most-once receipts, failed save and full-capacity export/import; prior suites Passed. 99 previews rendered; inspected all four styles, paused variants, style picker and sync screen. Fixed a header overlap found in the sync preview, then reran foreground checks, lint and previews. Files: importer, sync screen, style primitives and integration/tests. D17 line-limit correction recorded in decisions.md. V01–V14 remain Open, all device work Not run. Next: M8 full validation and handoff.

M8 final handoff — 2026-11-12, HOST MOCK; candidate 0.3.0.

Passed: final `make package` (which runs `make test`), all 46 recorded gate steps, Lua 5.5/32 assertions, lint and negative fixtures, icon regeneration check, compilation of 32 scripts, all nine Lua suites, preview rendering, manifest/version/launcher checks, vendor pins and decrypted round trip. TC01–TC22, TR01–TR12, TS01–TS11, TA01–TA15, TD01–TD05, TL01–TL06, TH01–TH10, TI01–TI04 and the interface/resource checks are mapped to executable evidence in test-matrix.md. The additional ATTEMPT-save and Start-fresh-save failure regressions Passed.

Passed: 118 current preview frames, audited hit maps and at most 122 counted drawing commands in a preview (target 400, hard test limit 768). Opened all ten paged contact sheets and individual detail, coverage, chain, style, sync, completion, fatal and recovery frames; inspected the final changed frames. Paths: build/previews/HOST-MOCK-contact-sheet.png, HOST-MOCK-contact-01.png through HOST-MOCK-contact-10.png, and per-screen HOST-MOCK-*.png. commands.jsonl identifies the current frame set; early spike PNGs are retained as historical host artifacts.

Passed: maximal-width state 9,123 bytes, depth five, platform save equality. App-attributable host heap peak 397,229 bytes (absolute host peak 501,954, pre-app harness baseline 104,725); retained delta after 100 mutation/screen cycles -13,718 bytes, so no measured growth. Fixed callback instruction proxies remain within the recorded regression baselines. build/validation-results.json retains the measurements. Device callback milliseconds, peak heap, completion latency, light visibility, wake behavior, battery and ghosting: **Not run**.

Passed: dist/timerdeck-0.3.0.xtapp, 118,072 bytes, 32 Lua scripts, no data section or TTF, all source bytes and manifest fields equal after decryption, all 7,744 launcher pixels equal. Independently compared every packaged source hash to committed source ab52e55. SHA-256: `1e5b125321c9be93065fd5fc4826902b24dbe7472196bf63b61cd7a6ddce3bf2`. The package report and SHA256SUMS are adjacent. Earlier host candidates are retained: 0.1.0 (79,912 bytes, 28 scripts) and 0.2.0 (102,792 bytes, 30 scripts), each with its own round-trip report.

Files finalized: lifecycle/controller and core/UI/platform modules; runtime, tests, previews and package tools; README, INSTALL, storage-format, decisions, test matrix and device checklist. Decisions cover baseline generation semantics, contract corrections, 80-line import limit, key access to bottom controls, lock-compatible shared copy, optional chain silence field and host measurement methodology. Found and fixed failed-attempt budget consumption and failed-fresh-state replacement during final failure-path review.

Open: V01–V14 all Open; DV01–DV15 all queued and Not run. No host gate is blocked. No device-validated label is claimed. Sibling repository status checks are clean; no network, Studio, upload, install or push occurred. All commits are local. Next step: owner installs candidate 0.3.0 over USB and starts DV01; record actual device results before changing any VERIFY status.

2026-11-12 / 0.3.1 Style removal — HOST MOCK. Owner reports successful use of 0.3.0 and a hang on Style; the cause remains unconfirmed. Removed the picker, its Settings row and alternate ring/bar/button renderers, keeping Ion and Auto/Light/Dark. Legacy set.style values remain readable without modifying saved timers. D12 owner override is recorded in decisions.md.

Passed: make package, including all 46 make test steps on Lua 5.5/32, nine Lua suites, lint/negative fixtures, icon checks, 32 script compilations and 106 preview frames with hit-map checks. Legacy style values 0–3 validate, render identical detail frames and expose no Style settings action. Passed: decrypted byte equality for 32 Lua files, manifest and 7,744 launcher pixels. Package: dist/timerdeck-0.3.1.xtapp, 116,632 bytes; SHA-256 654eed807632ab1e53219438aa91176e9651c851369e15fa8ac8b86698417b74.

Opened and inspected build/previews/HOST-MOCK-settings-light.png, HOST-MOCK-settings-page2-light.png, HOST-MOCK-ion-hot-dark.png and HOST-MOCK-appearance-picker-light.png. Contact sheet: build/previews/HOST-MOCK-contact-sheet.png. Device tests for 0.3.1: Not run (gate device_tests_run=false). DV01 is Partial based on the owner report; DV02–DV15 are still queued, V01–V14 Open. Next: install 0.3.1 and check Settings navigation and saved timers.
