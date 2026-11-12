# Timer Deck for XTEINK X4 Pro

**0.3.0 — host-validated candidate. Device validation has not run.** Lua 5.5 with 32-bit integers and numbers, InkApp API 2.18, portrait 480×800. Functional baseline: Pebble Timer Deck 0.7.0 at `202dbc6`; the later 0.7.1 changes were not adopted.

Ten independent countdowns and stopwatches, five saved chains with up to ten steps and nine rounds, touch and side-key controls, four monochrome styles, an optional read-only lockscreen page, and transactional text-file import/export. State mutations save before success or alert effects. A private CRC-checked backup provides recovery.

This device has no sound or vibration. Timer Deck alerts you with a screen flash and a light pulse, so keep it where you can see it.

Alerts run while the app is open. Stay awake applies to countdowns or chains ending within four hours and uses more battery; it cannot prevent manual lock, power-off or low-battery shutdown. The optional lockscreen page is silent and updates periodically. Its actual wake timing, light visibility and battery cost remain unmeasured.

Time comes from saved whole-second anchors. Time away and forward clock changes count as elapsed; detected rollback preserves values at the last trusted sample. A crash can leave that sample up to five minutes old. Durations end at 999d 23:59:59, and deadlines beyond January 2038 are refused. No network or permissions are used.

Run `make test`, `make preview`, `make icons`, or `make package`. The local toolchain archive must be at `build/toolchain/lua-5.5.0.tar.gz`; setup verifies its pinned hash and builds with `LUA_32BITS`. Python with Pillow and cryptography, make and a C compiler must already be installed. Nothing downloads dependencies or imports code from sibling repositories.

- `dist/timerdeck-0.3.0.xtapp`: current package; adjacent JSON report and `SHA256SUMS` document decryption and source equality.
- `build/gate-results.json`: actual check outcomes, with `device_tests_run: false`.
- `build/validation-results.json`: HOST MOCK heap and instruction-count proxies.
- `build/previews/`: 480×800 HOST MOCK PNGs, draw-command JSON and contact sheets.
- [Installation](docs/INSTALL.md), [device checklist](docs/device-checklist.md), [test report](docs/test-report.md), [accepted decisions](docs/decisions.md), [storage format](docs/storage-format.md).

Import/export uses `/AppFiles/timerdeck/`. The format is described in `docs/INSTALL.md`; imports allow 16 KiB and 80 lines so a full export can be imported again. No running state is imported. Sources and third-party notices are retained: Lucide icons (ISC), vendored packager/lint (MIT), Lua (MIT).

All V01–V14 remain open and DV01–DV15 are queued. Mock fonts and rasterization are not device screenshots. No package has been installed, uploaded or pushed by this work.
