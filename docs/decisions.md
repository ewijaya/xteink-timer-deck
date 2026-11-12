# Decisions

2026-11-12: Owner update supersedes PRD header and Q8: repository and private origin already exist. Local commits only; no push.

Open owner question: Pebble 0.7.1 adds New stopwatch and wrap-around deck scrolling. Baseline remains 0.7.0 at 202dbc6. No adoption of those changes is implied (PRD §12.3 independently specifies key wrapping).

Contract corrections: API §28 drops unsupported state entries and entries deeper than six levels, rather than rejecting an entire save. The host double must emulate that loss; model validation must prevent it. API §6 returns nil/inactive on an expired canvas; a separate strict test assertion can detect misuse. Lock after has no effect and extend returns nil/inactive (API §15), rather than being absent. These are contract facts, not device measurements.

The M1 baseline discrepancies listed below were resolved against the pinned Pebble source.

2026-11-12 M1 baseline corrections (PRD §3 source-precedence rule):
- `PRIMARY` on Finished clears to Ready without incrementing `gen`; the next Start increments it. Queue `DISMISS`, Reset of a non-Ready item and auto-reset increment it. Reset on Ready is a harmless no-op (§9.5). These follow baseline model.c and test_core.c exactly, correcting the broader generation wording in §8.1/TC13. TC17 rejects the prior run after restarting; explicit queue commands carry captured `(id, gen)` lists.
- A Running countdown retains its last positive frozen `val`, as baseline validation requires; only `anc` computes remaining time. This corrects the illustrative `val = 0` Running record in §8.1. Finished sets val to zero. No callback decrements val.
- Alert pattern/count freeze on both Start and Resume, as §10.2 and baseline tests require, resolving §9.3's shorter Resume row.
- M1 initially validated empty reserved chain data; M6 now validates full definitions and snapshots. Production checkpoint/save scheduling was added in M3/M4.
- The pinned packager also imports tools/vendor/mksd.py. Vendor and hash-pin this unmodified MIT dependency; an empty data section is absent, with no hmac_data field.

M2: Deck uses 32 px names and 40 px values when measured width fits; 26/22 px fallback keeps long labels/compact day values inside their columns. Geometry follows the PRD's tuning allowance; ten 63 px rows still fit. Host font measurement now brackets gsub's multiple return values before utf8.len, fixing a double-only error exposed by real labels. The lint tokenizes quoted/long strings before checking identifiers; ordinary module methods such as Store.load are permitted, while the unavailable global load remains banned.

M4: the 40 px coverage strip uses a 56 px hit area extending into reserved whitespace above it, satisfying the minimum touch target without overlapping rows. Deck text reserves extra width because the HOST MOCK font metrics differ from Pillow glyph widths; device font fit remains V12.

M6: the single checked time-add implementation lives in core/const.lua and model.add_time aliases it. This lets the lock projection follow chain deadlines while respecting its module whitelist. Run generations remain in the idle run after Done so stale commands cannot target a later run. The first M6 gate found a hard-coded fresh-session test module list missing chains.lua; extended that fixture. No device claims are made.

M7 / D17: raise the import line limit from 64 to 80 (still 16,384 bytes). The fullest legal export has 65 definition lines (10 items + 5 headers + 50 steps), plus settings comments, so 64 cannot satisfy TI04. This is the smallest simple limit that accommodates the complete export. Import while the clock is unset follows the explicit §17.4 rule, overriding the contradictory import mention in §7.5; imported definitions never start. Receipts are newest first, as in §8.

M8 / D14: include the deck bottom controls after its item rows in the key focus cycle. Restricting the cycle to rows makes New timer, Chains and Menu unreachable by keys once an item exists, conflicting with the M2 key-only workflow gate. This adds no deck item row and does not adopt the Pebble 0.7.1 New stopwatch row. Lists initially focus their first content control rather than Back.

M8 validation reports application-attributable host heap: subtract the runtime/test-harness baseline measured before loading app modules. The report also retains the absolute host peak and baseline; simulated canvas command records remain included in the app delta. Device heap and wall-time limits remain V08/V09, not inferred from instruction counts. Callback proxy thresholds are regression limits, not conversions to milliseconds. Both sibling repositories were clean in the final read-only status check.

M8: add optional integer ch.run.sil (missing = 0) to distinguish a delivered chain result from a silenced one. Without that distinction, using att == cnt would wrongly hide delivered results on the lock page and release keep-awake before the 600-second viewing window. The extra field preserves schema-1 compatibility and the same alert budget.

M8 copy placement: shared interface/lock/import copy lives in core/const.COPY, with lib/ui/strings.lua as its alias. The lock whitelist cannot load a UI strings module, and pure core code cannot import a UI module, so this keeps shared copy available without weakening either boundary. The two emergency entry-script fallback frames retain literal text so a failed module load still produces a readable screen.

M8 alert retry: an ATTEMPT save failure retains the prior attempt count while showing NOT SAVED and retrying. A targeted injected failure verifies that no physical attempt is lost merely because its record failed to save. A crash after a successful save may still consume an unseen attempt, as specified.

2026-11-12 / D12 owner override: remove the Style page after the owner reported a device hang and requested its removal. Monochrome supports geometric styles, but the owner prefers a simpler interface. Version 0.3.1 uses Ion for rings, progress bars and buttons and removes the alternate renderers/picker. Keep schema-1 set.style values 0–3 readable and unchanged for existing saves; the field is now ignored by drawing. Appearance (Auto/Light/Dark) remains available. No state migration or reset is required. The reported hang’s cause is not established; removing the page is not proof of a diagnosed runtime fix.

2026-11-12 / 0.3.2 N1, §16: reset chain `att` and `sil` at every step/final boundary; scope CH_SILENCE to the current cue or Finished result. Pinned Pebble `202dbc6:src/core/chains.c` resets attempts in advance/finish. TH11 initially checked the second result at exactly five seconds while the Result page used the existing 150 ms deadline slack; its fixture now waits 5.3 seconds and asserts Finished before touching. This corrects the fixture, not the timing contract. TU17, TU18, TA16 and TH11 reproduced their respective defects before production changes. No VERIFY item is closed.
