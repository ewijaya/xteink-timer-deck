# Decisions

2026-11-12: Owner update supersedes PRD header and Q8: repository and private origin already exist. Local commits only; no push.

Open owner question: Pebble 0.7.1 adds New stopwatch and wrap-around deck scrolling. Baseline remains 0.7.0 at 202dbc6. No adoption of those changes is implied (PRD §12.3 independently specifies key wrapping).

Contract corrections: API §28 drops unsupported state entries and entries deeper than six levels, rather than rejecting an entire save. The host double must emulate that loss; model validation must prevent it. API §6 returns nil/inactive on an expired canvas; a separate strict test assertion can detect misuse. Lock after has no effect and extend returns nil/inactive (API §15), rather than being absent. These are contract facts, not device measurements.

Baseline discrepancies reserved for M1: Pebble PRIMARY dismissal does not increment generation, and RESET of Ready is a no-op; PRD §9 explicitly requests generation increments. Resolve and document before implementing those commands.

2026-11-12 M1 baseline corrections (PRD §3 source-precedence rule):
- `PRIMARY` on Finished clears to Ready without incrementing `gen`; the next Start increments it. Queue `DISMISS`, Reset of a non-Ready item and auto-reset increment it. Reset on Ready is a harmless no-op (§9.5). These follow baseline model.c and test_core.c exactly, correcting the broader generation wording in §8.1/TC13. TC17 rejects the prior run after restarting; explicit queue commands carry captured `(id, gen)` lists.
- A Running countdown retains its last positive frozen `val`, as baseline validation requires; only `anc` computes remaining time. This corrects the illustrative `val = 0` Running record in §8.1. Finished sets val to zero. No callback decrements val.
- Alert pattern/count freeze on both Start and Resume, as §10.2 and baseline tests require, resolving §9.3's shorter Resume row.
- M1's core validates only empty reserved chain data. Chain validation/commands arrive in M6; no chain behaviour is silently approximated. Checkpoint tests exercise the pure policy; production persistence scheduling remains M3/M4.
- The pinned packager also imports tools/vendor/mksd.py. Vendor and hash-pin this unmodified MIT dependency; an empty data section is absent, with no hmac_data field.

M2: Deck uses 32 px names and 40 px values when measured width fits; 26/22 px fallback keeps long labels/compact day values inside their columns. Geometry follows the PRD's tuning allowance; ten 63 px rows still fit. Host font measurement now brackets gsub's multiple return values before utf8.len, fixing a double-only error exposed by real labels. The lint tokenizes quoted/long strings before checking identifiers; ordinary module methods such as Store.load are permitted, while the unavailable global load remains banned.

M4: the 40 px coverage strip uses a 56 px hit area extending into reserved whitespace above it, satisfying the minimum touch target without overlapping rows. Deck text reserves extra width because the HOST MOCK font metrics differ from Pillow glyph widths; device font fit remains V12.
