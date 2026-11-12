# Test report

2026-11-12 — M0 foundation, HOST MOCK. Device tests: Not run.

Passed: local archive SHA-256; Lua 5.5 / maxinteger 2147483647 / four-byte number assertions; vendored Lua 5.5 lint; API device lint; luac syntax compilation of seven app scripts; runtime self-tests (JSON and CRC, clock, timers, state, files, canvas/fonts, device/lock, sessions/overlays/errors, method receivers); shell/lock/fatal retry suite; 14 preview renders; manifest/version/icon validation; packager hash pins; decrypted script and manifest comparison; all 7,744 icon pixels compared. Package below 200 KB.

The first package attempt failed because the vendored xtapp module also imports mksd. Copied and pinned that MIT dependency. The second failed because an empty data section has no hmac_data; the wrapper now asserts that the section is absent. The final package round trip passed.

Inspected build/previews/HOST-MOCK-contact-sheet.png: shell, diagnostics, Ready, Running, 25%, 10%, Paused, Finished in light/dark. Digit/ring geometry readable; paused outline and finished circles distinct. Mock glyph metrics and Pillow rasterization do not reproduce device fonts or pixels. Runtime instruction counters are host proxies, not measured callback times.

Open: V01–V14; DV01 queued. TC01–TC22 and TR01–TR12 Not run until M1. TP04 vector icon generation belongs to M2; make icons currently regenerates the launcher only. No usable timer UI or alert effects yet.

Decisions: existing private remote acknowledged; Pebble 0.7.1 deltas remain an owner question; state filtering and inactive lock/canvas APIs follow the official contract. See decisions.md.

Next: M1 timing core and the 34 core/clock cases.
