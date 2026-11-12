# Host validation map

All results below are **HOST MOCK**. The authoritative last-run statuses, durations and output are in `build/gate-results.json`. Device statuses are independently recorded in `device-checklist.md` and remain Not run.

| Requirement IDs | Executable evidence |
| --- | --- |
| TC01–TC22, TR01–TR12 | `core_test.lua`: named cases, 1,000 sampled timing trials, 10,000 random commands, invariants and fresh sessions |
| TS01 | `chains_test.lua`: capacity fixture plus maximal encoded field widths, five-level snapshot and platform save equality |
| TS02–TS11 | `store_test.lua`: persistence, failures, retry, backup/recovery, blocked schema, cancel/confirm reset, draw purity and crash retention |
| TA01–TA15 | `attention_test.lua`: patterns with exact timestamps, save-before-light, budgets/fairness, interruption, relaunch, coverage, keep-awake, exit and timer limits |
| TD01–TD05 | `attention_test.lua`: mode boundaries, simulated hour wake counts, peek, refresh calls and deadline latency |
| TU01–TU08 | `app_test.lua`, `chains_test.lua`, `validation_test.lua`, preview hit-map audit: geometry, touch/key routes, stale targets, draft and control flows |
| TU09–TU11 | `validation_test.lua`: native overlay crossing a deadline, draft restoration, normalized name, lock selection/resume; `app_test.lua` and storage suites cover related flows |
| TU12–TU13 | `app_test.lua`: Help pagination/about taps and lazy module isolation |
| TU14 | `attention_test.lua`: appearance inversion table and flash negation; Ion and appearance previews; legacy style compatibility in `validation_test.lua` |
| TU15 | `validation_test.lua`: injected draw error, one logged fatal, Retry and retained mutation |
| TU16 | `preview.lua` → `preview.py`: per-screen light/dark PNGs, command JSON and contact sheets, inspected by the implementing agent |
| TM01 | `validation_test.lua`: full module/screen walk, icon picker, heap proxy and 100 mutation/screen cycles |
| TL01–TL06 | `lock_test.lua`: isolated module whitelist, priorities, read-only state, blink, intervals and fallbacks |
| TH01–TH10 | `chains_test.lua`: definitions/templates, copies, logical boundaries, rounds, stale commands, skips/stop, away handling, fairness and limits |
| TI01–TI04 | `import_test.lua`: grammar, atomic rejection/save, receipts, full export round trip, actual controller file effects |
| TP01 | `lint.py`, negative fixtures and Lua 5.5/32 `luac -p` |
| TP02–TP03 | `package_local.py`: exact manifest/version/icon checks, pinned vendor hashes, decryption and source/pixel equality |
| TP04 | `icons.py --check`: all 30 generated vector icons |

The runtime double has its own nine grouped tests for clock/timers/state/files/canvas/fonts/device/light/lock/overlays/sessions/receivers. It records instruction counts rather than inferring device milliseconds. Each fixed callback fixture is checked against twice its recorded instruction baseline plus 1,000 instructions (`tools/tests/instruction-baseline.json`); the combined lock fixture also has a 100,000-instruction ceiling. The host heap report includes the runtime baseline, absolute peak and app-attributable delta; these are not device heap measurements.

No host case substitutes for DV01–DV15. Real font layout, touch settling, light visibility, keep-awake, lock wake intervals, refresh latency, ghosting and battery use remain open. Tests target behavior and failure boundaries; they do not claim exhaustive enumeration of every possible input sequence.
