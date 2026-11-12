# Timer Deck 0.3.2 — cleanup, fixes and polish

Status: proposed, 2026-11-12. Audited source: commit `6f6346c` (package `dist/timerdeck-0.3.1.xtapp`). Target device: XTEINK X4 Pro, InkApp API 2.18.

This document is a delta on `PRD.md`. `AGENTS.md` still applies in full: work offline, API 2.x with colon calls, pure core, draw only in `on_draw`, every callback under `pcall`, Lua 5.5/32 for every suite, no sound or vibration claims, HOST MOCK is never device evidence. Where this document changes a DRAFT DEFAULT, section 9 lists the decision to record in `docs/decisions.md`. Nothing here builds a DEFERRED item (`PRD.md` §24).

## 0. Evidence used

Every finding carries one of these tags. None of them is device evidence.

| Tag | Meaning |
| --- | --- |
| HOST REPRO | Reproduced on the Lua 5.5/32 host harness (`tools/shim/runtime.lua`) against `6f6346c` during this audit |
| CODE | Read in the source; file and line given |
| PREVIEW | Visible in the current `build/previews/HOST-MOCK-*.png` |
| CONTRACT | Stated by the API 2.18.2 contract (`../xteink-daily-mass/experiments/ext/kb/`, section number given) |
| BASELINE | Checked against Pebble source at `202dbc6` |

## 1. Goals

1. Remove settings and code that are redundant, non-functional or dead on the X4 Pro.
2. Fix every defect found in the audit. Four of them are serious: a crash reachable from the first-run screen, a chain alert that is silently lost, a preview that silences real alerts, and a dead-end screen after Back on Recovery.
3. Cut the work done per touch and per tick.
4. Apply ten polish items that make the app read as finished: real glyphs, weight hierarchy, one-page Settings, toasts, consistent paging and copy.
5. Ship as `0.3.2` with schema 1 unchanged. No migration, no reset.

Non-goals: new timer features, format changes to BASELINE values (§7.6), device claims, anything in `PRD.md` §24.

### 1.1 Silent device

The X4 Pro has no speaker, buzzer or vibration motor (CONTRACT §21 capability list; `PRD.md` §2.2). Every alert is visual: a screen flash, a front-light pulse, and the completion page. This shapes every change below:

- No copy, setting, help line, toast or preview may suggest sound or vibration. Do not call the product an alarm. Do not use the words beep, buzz, ring, vibrate, sound or alarm, except in the required sentence and in Help's "No sound" heading.
- The required sentence stays, byte for byte, in three places: the first Help topic, the empty deck, and `manifest.json` `description`. It reads: "This device has no sound or vibration. Timer Deck alerts you with a screen flash and a light pulse, so keep it where you can see it." POL-04 must not turn the empty-deck text into a toast, and POL-10 must not move it out of the first Help topic.
- The four patterns are Pebble vibration rhythms reused as front-light rhythms. On this device they describe the light only, and they are labelled that way (RM-03).
- With both channels off, an alert is the completion page alone. The app says so, and it never claims coverage it cannot give (§10.6).
- TU26 (`validation_test.lua`) checks all of this: the sentence is present in the three places, and the banned words appear nowhere else in COPY, `help_text` or the manifest.

## 2. Part A — removals

### 2.1 Settings verdicts

Current Settings has ten rows on two pages (PREVIEW `settings-light`, `settings-page2-light`).

| Row today | Verdict | Reason |
| --- | --- | --- |
| Appearance (Auto / Light / Dark) | **Remove** | See RM-01 |
| Style | Already removed in 0.3.1 | Remnants remain; see RM-02 |
| Default alert (pattern) | **Keep, show only when it does something** | The screen flash is identical for all four patterns: `signal.lua:18` adds one 700 ms flash whatever the pattern. Only the front light follows the pattern. With Light pulse Off the picker and its four Preview buttons change nothing. See RM-03 |
| Default count | **Keep, rename "Alert repeats", show only when it does something** | With flash and light both Off, `alerts.lua:8` allows one attempt only (`i.att==0`), so the count has no effect. See RM-03 |
| Screen flash | Keep | Functional; the only alert channel that needs no hardware capability |
| Light pulse | Keep | X4 Pro has a front light (CONTRACT §3 profile table). Already hidden without `ctx.frontlight` |
| Seconds (Smart / Always / Never) | Keep for now | Functional. It is the only user control over refresh rate until V04 and V07 are measured. Open question OQ1 |
| Stay awake | Keep; **hide when `ctx.device.keep_awake` is nil** | The row is drawn unconditionally (`menus.lua:13`) but the feature needs firmware 26110201 or later. On older firmware the toggle changes a saved bit and nothing else |
| Lock screen | Keep | Functional by contract (§15). Already hidden without `ctx.lockscreen` |
| Import and export | Keep, move to a **Data** page | Functional and the only export path. It does not belong among preferences |
| Reset saved data | Keep, move to the **Data** page | Destructive action should not sit one mis-tap below everyday toggles |

Result: Settings fits one page with no pager (layout in POL-03).

### 2.2 Removal requirements

**RM-01 Remove the Appearance setting.** Owner override of D11, same form as the D12 override.

- CONTRACT §13: system dark mode inverts the whole frame, app content included. The user already has three ways to switch it: system settings, a double-click of Home, and night mode. An app-level switch duplicates that.
- CODE: the setting is applied only by `A:draw` (`app.lua:243-244`). The lock page (`lock.lua:13`), both fatal frames (`index.lua:18`, `app.lua:276`), the system keyboard and system dialogs ignore it. With Appearance set to Light while the system is dark, the app is light and everything around it is dark.
- `PRD.md` §13.2 already warns that Dark means large black areas that may ghost (V07, unmeasured).
- Appearance is the last screen that uses the preview-picker path (`preview_setting`, `Use this`) that the removed Style page used. The cause of the 0.3.0 Style freeze is still unconfirmed; this removal deletes the shared path. It is not a diagnosis.

Changes:
- Delete the Settings row, the picker `preview` mode, `preview_setting`, the `use` action and the Back special case (`app.lua:158, 190, 196, 202, 243`; `pickers.lua:17`).
- `lib/ui/theme.lua` reduces to the flash flip: `colors(flash)` returns ink 15 / paper 0, swapped while a flash frame is shown. `A:draw` no longer reads `ctx.device:display()`.
- Remove copy: `appearance`, `appearances`, `use`.
- Schema: keep `set.app` exactly as `set.style` is kept. `M.new` still writes `app=0, style=0`; validation still accepts 0–2 and 0–3; drawing ignores both. A 0.3.1 save with `app=2` loads unchanged and renders in the system mode. A 0.3.2 save still loads in 0.3.1.
- Help gains one line: "Dark mode: double-press Home, or use the reader's display settings."

**RM-02 Finish removing Style.** Delete the unreachable guard `app.lua:199`. Keep the schema field (above). `importer.export` stops writing `# app = …` and `# style = …` comment lines.

**RM-03 Show alert options only when they act.**

| Row | Visible when |
| --- | --- |
| Light pattern (Settings, timer form, chain step) | `ctx.frontlight ~= nil and set.light == 1` |
| Alert repeats (Settings, timer form) | `set.flash == 1`, or the pattern condition holds |
| Preview buttons in the pattern picker | Same as Light pattern (they are inside that picker) |

Rename the row from `Default alert` / `Alert` to **Light pattern**. The picker title is `Light pattern`. Its Preview button pulses the light only and never flashes the screen, because the flash is the same for every pattern. The pattern names (`Short`, `Long`, `Short + short`, `Short + long`) and indices stay as they are: they are BASELINE, and import files use them.

Stored `pat`, `cnt` values are never changed by hiding a row. When both channels are Off, Settings shows one 22 px note under the two toggles: `Finished timers show on screen only.`

**RM-04 Remove the two always-true feature flags.** `features={lock=true,sync=true}` (`app.lua:9`) and both reads (`menus.lua:14-15`).

**RM-05 Replace the seven-tap gesture with a visible row.** `Menu` gets a fourth row, **Device information**. Remove the hidden hit area and `about_tap` (`info.lua:7`, `app.lua:204`). The owner needs this page for DV01 and V01–V14; hiding it helps nobody.

**RM-06 Merge the item actions page into the edit form.** The `...` button on Detail opens a page with two rows, Edit and Delete (PREVIEW `item-actions-light`). Replace it with an **Edit** top-bar button that opens the form; the form gets a last row **Delete** that uses the same inline Delete / Keep confirmation as the deck. Remove page kind `actions`. Delete still acts at once after the inline confirmation (parity row 11).

### 2.3 Dead code and unused data

All CODE.

| ID | Location | What |
| --- | --- | --- |
| DEAD-01 | `app.lua:223` | Unreachable: `chains` is intercepted at line 148. `S.no_chains` is therefore never shown (see POL-07 for the empty state that should use it) |
| DEAD-02 | `app.lua:224`, `app.lua:46` | `if self.preview_pattern` and `if self.backup` test methods, which are always truthy |
| DEAD-03 | `app.lua:109` | `run.st==4 and 3 or run.st` sits inside `if run.st==1 or run.st==2` |
| DEAD-04 | `deck.lua:27`, `nav.lua:25` | Branches for a chain row with `st==3` or `r.st>=3`. A chain row exists only for st 1 and 2 |
| DEAD-05 | `app.lua:263` | `kind=='blocked'` / `'recovery'` tests in a branch those kinds never reach |
| DEAD-06 | `signal.lua:21` | `signal.preview` is stored and never read (it becomes live in BUG-03) |
| DEAD-07 | `const.lua` COPY | Unused keys: `backspace`, `foundation`, `pending`, `open_only`, `preview_time`, `start_chain`, `discard_new`, and the aliases `patterns`, `icon_names`. `discard_new` becomes used in INC-05; delete the rest |
| DEAD-08 | `const.lua` COPY | Duplicates: `ACTIVE` = `chain_busy`, `CHAIN_FULL` = `chain_full`, `open_only` = `open_strip`. Keep the upper-case result codes; point the lower-case uses at them |
| DEAD-09 | `build/previews/` | 157 PNGs: 106 current frames, 11 contact sheets and 40 stale frames (`style-*`, `spike-*` and unsuffixed names from earlier milestones). `tools/preview.py` must delete `HOST-MOCK-*.png` before rendering, so that a stale frame can never be the one inspected |
| DEAD-10 | `build/remove_styles.py` | One-off script from 0.3.1. Delete |
| DEAD-11 | `tools/gate.py:5` | `'milestone':'M8'` is hard-coded. Write the manifest version instead |

## 3. Part B — defects

Severity: **S1** crash or lost alert, **S2** wrong behaviour the user will meet, **S3** cosmetic or rare.

### BUG-01 (S1) Fatal error from the empty deck with the side keys

HOST REPRO. Fresh install, deck empty: press Down four times, then Up. Result: `app/lib/app.lua:148: attempt to index a nil value (local 'action')`, caught as `E-INPUT`, and the first thing a new user sees is "Something went wrong".

Cause: with no rows, `nav.lua:20` cycles focus through four hit boxes, while `nav.lua:24` maps focus to `({'new_timer','chains','menu'})[focus]` and returns `{action=nil}` for focus 4.

Fix:
- The deck focus ring is always `rows + 3 bottom buttons`, including when there are no rows. Remove the `#a.deck_entries>0` condition at `nav.lua:13`. On the empty deck the large New timer button is not a separate stop.
- `A:action` returns `false` when `h.action` is nil.

Accept (TU17): on decks with 0, 1 and 10 rows, 2 × (rows + 3) Down presses followed by Up at every position never set `fatal`; the highlighted control is the one activated.

### BUG-02 (S1) A touch during any alert silences the running chain's result alert

HOST REPRO. Two-step chain, app open. At the step 2 cue the screen flashes; the user taps to acknowledge it. Afterwards `run.sil == 1` and `run.att == run.cnt` while the chain is still Running. When the chain finishes, no flash and no light happen (0 light calls, against 16 in the untouched control run). Because `sil == 1`, Stay awake is also released early and the lock page never shows `TIME'S UP` for it.

Cause: `app.lua:236` sends `CH_SILENCE` whenever a run exists (`r.st ~= 0`), and `core/chains.lua:88` applies it in any state. BASELINE: Pebble resets `attempts` at every boundary (`chains.c` `advance` and `finish`); the Lua `next_step` never resets `att` or `sil`.

Fix:
- `core/chains.lua` `next_step`: set `r.att = 0; r.sil = 0` on every boundary, including the final one.
- `CH_SILENCE`: when `r.st == 1`, clear `r.cue` only. When `r.st == 3`, set `r.att = r.cnt; r.sil = 1`. Otherwise return `INVALID`.
- Controller: send `CH_SILENCE` only when `r.st == 3`, or `r.st == 1 and r.cue == 1`.

Accept (TH11): tap during the step 2 cue, let the chain finish: `att` reaches `cnt` through `CH_ATTEMPT`, light calls occur, `sil == 0`. A tap during the result alert still silences it.

### BUG-03 (S1) Previewing a pattern silences real finished timers

HOST REPRO. A timer finished one attempt ago (`att = 1` of 5). In Settings the user presses Preview, then touches the screen. Result: the finished timer has `sil = 1`; its remaining attempts never happen. The same touch also triggers BUG-02 for a running chain.

Cause: `A:input` treats every active signal as a real alert (`app.lua:236`).

Fix: when `self.signal.preview` is true, a touch stops the signal and is consumed, and no `SILENCE` or `CH_SILENCE` is sent.

Accept (TA16): after a preview and a touch, every item's `sil` and `att` are unchanged and the next real attempt still fires.

### BUG-04 (S1) Back on Recovery or Blocked opens a fake empty deck

HOST REPRO. Start with unreadable saved state (mode `recovery`), press Back. The page becomes `deck`, drawn from an empty placeholder state. New timer opens the keypad; Start timer does nothing, because `A:event` refuses every command in these modes. The user sees an empty deck and may conclude that the data is gone.

Cause: `A:pop` falls back to `{kind='deck'}` when the stack is empty (`app.lua:28`).

Fix: in modes `recovery` and `blocked` the root page is `{kind=self.mode}`. Back at that root returns `false`, so the system exit confirmation appears (`PRD.md` §14.11).

Accept (TU18): in both modes, Back at the root leaves `page.kind` unchanged and the handler returns `false`; no deck frame can be drawn.

### BUG-05 (S2) Deck rows fall onto a second page that nothing indicates

HOST REPRO and PREVIEW (`chain-deck-ten-light`: header says `10/10`, nine timers are visible). Ten items plus the chain row gives 2 pages of 10. Ten items plus a warning strip gives 2 pages of 9. The second page is reachable only by a vertical swipe or by key focus, and no control says it exists. `PRD.md` §13.7 requires a `More · 1 of 2` strip.

Fix: one shared pager, used by the deck and by every paged list (it replaces the two-button pager at y 712 in `widgets.lua:37`).
- When rows do not fit, reserve a 40 px strip at the bottom of the list area with a 56 px hit area: `MORE · 1 OF 2`, 22 px, centred, with a chevron glyph at each side.
- Tap on the right half: next page. Tap on the left half: previous page. Both wrap. Swipe up / down and key focus keep working.
- Rows per page are computed after reserving the strip.
- The bottom bar (y 712–800) is then free for each page's own actions (INC-04).

Accept (TU19): for 11 entries, and for 10 entries with each warning strip, the pager is drawn, its hit box is at least 56 px tall and overlaps nothing, and every entry is reachable by taps alone.

### BUG-06 (S2) Stale chain pages: a dead Run screen and an ever-growing stack

HOST REPRO. Let a chain finish on its Run screen; the Result page is pushed on top. Press Back: the Run screen returns for a finished run, showing `00:00` and a **Resume** button that answers "Check the values and try again." Each **Run again** pushes another Run page; Back then walks through old Result pages that describe the current run as complete while it is running.

Fix:
- Add `A:prune()` and call it at the end of `A:event`: while the current page is `chain_run`, or `chain_more` / `chain_steps` opened from a run, and `run.st` is not 1 or 2, pop it. Remove such pages from the stack as well.
- **Run again** on Result replaces the Result page with the new Run page.
- The Result page is shown once per `(gen, st)` as now; Back from it goes to what was underneath after pruning.

Accept (TH12): after three finish / Run again cycles the stack depth equals its depth after the first start; no Run page is ever drawn for a run with `st >= 3`.

### BUG-07 (S2) Fatal draw error on a Run page whose run was deleted

HOST REPRO. Deck chain row, `...`, All chains, swipe the running chain, Delete, Back, Back. Result: `app/lib/ui/chains.lua:72: attempt to index a nil value (field 'snap')`, `E-DRAW`.

Fix: BUG-06 pruning removes the page. In addition `U.draw` never indexes `r.snap` without checking `r.st ~= 0`; with no run it draws the Chains title and an empty list.

Accept (TH12): the sequence above ends on a valid page with `fatal == nil`.

### BUG-08 (S2) Page replacement skips the navigation bookkeeping

HOST REPRO (focus) and CODE. Nine places assign `self.page` directly (`app.lua:166, 173, 188, 213, 216, 219`; `ui/chains.lua:32, 59, 63`). They do not clear `focus` or `peek`, and most do not set `changed_at`. Effects: after creating a timer with the keys, the old keypad focus index (3) is kept on Detail and then selects an unrelated deck row; after Delete, Reset saved data, chain Save and chain Done the 400 ms settle window is not applied, so a second tap aimed at the old screen lands on the new one.

Fix: add `A:go(page)`: clears the stack, sets the page, clears `focus`, `peek`, the armed-delete state and `banner`, sets `changed_at`, requests a frame under rule R2. Use it at all nine sites. Simplify `app.lua:188` to an explicit three-way choice.

Accept (TU20): after each of the nine transitions `focus == nil` and a pointer `down` within 400 ms is ignored.

### BUG-09 (S3) The time editor asks "Discard changes?" when nothing changed

HOST REPRO. Edit, Time, Back: the confirmation opens, because the editor is prefilled and `app.lua:159` tests only for non-empty digits.

Fix: the keypad page carries `dirty`, set by the `digit` and `days` actions. Back asks only when `dirty`.

### BUG-10 (S3) The coverage page offers a button that does nothing, under the wrong text

HOST REPRO and CODE. A 6-hour timer with Stay awake already On shows the strip; the page behind it offers **Turn on Stay awake**, which changes nothing. Its text is the leave-dialog copy ("…until you open Timer Deck again") although the app is open (`app.lua:256`).

Fix:
- Show **Turn on Stay awake** only when `set.awake == 0` and `ctx.device.keep_awake` exists. Show **Use lock screen** only when `ctx.lockscreen` exists and Timer Deck is not the lock screen.
- New copy `coverage_text`: `Timer Deck can alert you only while it is on screen. Stay awake keeps the reader on for timers that end within 4 hours.` When Stay awake is On and the timer is beyond the horizon, add: `This timer ends later than that, so it is not covered yet.`

### BUG-11 (S3) Wrong titles

| Where | Shows | Should show | Evidence |
| --- | --- | --- | --- |
| Settings pickers (`app.lua:202`, `S[arg]` is always nil) | `Settings` | The row's label | HOST REPRO, PREVIEW `appearance-picker-light` |
| Time editor (`keypad.lua:4`) | `New timer` | `Time` | PREVIEW `days-keypad-light` |
| Keyboard for a chain name or step name (`app.lua:181`, drafts have no `type`) | `Stopwatch name` | `Chain name`, `Step name` | HOST REPRO |
| Chain editor (`ui/chains.lua:72`) | `Chains` | `New chain` or `Edit chain` | PREVIEW `chain-editor-light` |
| Step editor, Add step, From Deck timers | `Chains` | `Step`, `Add step`, `From Deck timers` | CODE |
| Days line in the time editor | `0 Days` | `0 days` | PREVIEW |

### BUG-12 (S3) Chain Run copy and unnamed steps

- PREVIEW `chain-run-light` shows `Steps 1 / 2` and `Rounds 1 / 4`. `PRD.md` §16.6 specifies `STEP 1 OF 2` and `ROUND 1 OF 4`. Hide the round line when the chain has one round.
- An unnamed step is `New timer` in the editor (`ui/chains.lua:84`), blank in the step list and on the Run screen, and yields `Starting now: ` and `Next:  5:00`. Add one helper, `step_label(step, n)`, returning the name or `Step n`, and use it in all five places and in `glance.lua`.
- `a.banner` is set at a cue and never cleared (`app.lua:94`). After a cue that was not delivered, the previous step's "Starting now" stays under the new step. Store the banner with the step token and draw it only while the token matches.

### BUG-13 (S3) Lock page

- PREVIEW `lock-running-light`: the order is digits, `ends 12:04`, `MIN LEFT`. The unit is separated from the number it qualifies. Order must be digits, `MIN LEFT` (22 px), `ends 12:04` (32 px).
- `lock.lua:17` prints `battery.percent .. '%'`. CONTRACT §13: `percent` is -1 when unreadable, which prints `-1%`. Draw nothing when `percent < 0`.
- `glance.lua:55` hard-codes `' · paused'` instead of using `S.paused_lower`.

Accept (TL07): layout order asserted from the draw-command list; a battery of -1 produces no percent text.

### BUG-14 (S3) Inline delete confirmation

- CODE: timer rows and chain rows keep separate armed flags but share one timeout handle (`a.settle`, `app.lua:174`, `ui/chains.lua:21`). Arming a second row cancels the first row's timeout and leaves it armed until Keep is tapped.
- `PRD.md` §14.1: the row reads `Delete "Tea"?` and any other input restores it. Today it shows two unlabelled buttons and only Keep or the timeout restores it.
- Swiping the running chain's deck row arms deletion of the **saved chain**, with no mention that the run stops.

Fix: one `a.armed = {kind, id, gen}` with one timer. Any input other than Delete disarms. The row shows `Delete "<label>"?`; for a chain with an active run it shows `Stop and delete "<name>"?`.

Accept (TU25): arm row A, arm row B: only B is armed; after 5 s none is. Any tap elsewhere disarms without acting.

### BUG-15 (S3) Peek

CODE `app.lua:207`, `detail.lua:9`. Tapping the digits of a Ready, Paused or Finished item replaces the `SEC` / `MIN` caption with `at 14:17:11` until the next pulse, which tells the user nothing. Restrict Peek to a Running item that currently shows minutes, and use the specified caption `at 14:17:11 · tap to refresh` (§11.1).

### BUG-16 (S3) Dialog and import details

- `A:confirm` and the leave prompt ignore the return value of `ctx.dialog:confirm` (CONTRACT §23: `nil, "busy"` or `nil, "limit_exceeded"`). On failure the tap does nothing. Log `E-DIALOG` and fall back to the in-app confirmation page.
- The import result view is one 360 px box of 22 px text, about 14 lines; a result can have 80. Page it with the Help paginator.
- A capacity failure is reported as a raw code (`Line 7: FULL`, `importer.lua:81`). Map the code through COPY.

## 4. Part C — inconsistencies

| ID | Finding | Change |
| --- | --- | --- |
| INC-01 | Display strings outside COPY: `Skip`, `SEC`, `MIN`, `at `, `x`, `#%02d`, `/10`, `File exceeds … lines`, the toggle labels `II`, `>`, `OK`, pager `<` `>`, `...` | Move text to COPY; the pseudo-glyphs disappear with POL-01 |
| INC-02 | Capacities as literals: `/10` (`deck.lua:4`), `for n=0,30` (`pickers.lua:6`), `{'1','2','3','4','5'}` twice | Derive from `C.CAPACITY`, `C.ICON_COUNT`, `C.COUNT_MIN..C.COUNT_MAX` |
| INC-03 | The same count is `Default count` in Settings and `Count` in the form; the pattern is `Default alert` in Settings and `Alert` in the form | `Alert repeats` and `Light pattern` in both |
| INC-04 | Primary actions sit at five different heights: keypad 580 and 688, form 712, chains 600 with a pager under it, picker 696, detail 676 | List pages (form, chain editor, step editor, From Deck, Data) put actions in the bottom bar y 712–800. Detail, Run, Completion and Keypad keep their large primary buttons |
| INC-05 | Leaving a new unsaved timer asks `Discard changes?`; `discard_new` exists and is unused | Use `Discard new timer?` when the form has no `id` |
| INC-06 | Two confirmation styles and full-page messages for one-line feedback | POL-04 |
| INC-07 | List rows are 96 px with the value under the label; `PRD.md` §13.7 specifies 88 px with the value at the right | POL-03 |
| INC-08 | Stopwatch Detail prints `COUNT UP` twice (state line and context line). An item with no icon gets an empty circle above `#01` | Drop the second `COUNT UP` (the context line at y 522) for stopwatches; `started 14:02` stays. With no icon, draw the number badge used on the deck instead of the circle and the `#01` text |
| INC-09 | Help omits long press, Peek, New stopwatch, import and export, and (after RM-01) dark mode | POL-10 |
| INC-10 | `a.settle` names the delete-arm timeout; `SETTLE_MS` names the touch settle window | Rename the handle `arm_timer` (BUG-14) |
| INC-11 | Docs describe features that no longer ship: `PRD.md` D11, D12, §13.2, §13.3, §14.9, §14.10; `README.md`; `docs/INSTALL.md` (seven taps); `docs/storage-format.md`; `docs/test-matrix.md` TU14; `docs/device-checklist.md` DV10 "Try Dark" | Record decisions (section 9); add a note at the top of `PRD.md` pointing to this file and `docs/decisions.md`; update the other five files in milestone N6 |

## 5. Part D — efficiency

**EFF-01 Stop running the whole controller on every pointer phase.** HOST REPRO: one tap delivered as down, five moves and up causes 9 deep copies of the state, 9 `plan()` calls (each cancels and re-arms the pulse timer and calls `keep_awake`) and 2 validations. `A:input` calls `A:event()` before it looks at the phase (`app.lua:237`), and `plan()` runs inside `event()`, again inside the command, and again at `app.lua:240`.

- `move`: return at once, no sample, no event.
- `down`: record the settle decision only.
- Run sample, reconcile and the command once, on `up`, `hold` or key `up`.
- `plan()` runs once per callback: `event()` marks the plan dirty and the callback wrapper flushes it.

Accept (TU24): the same tap costs at most 2 deep copies and exactly 1 `plan()`. Record a new `on_input` figure in `tools/tests/instruction-baseline.json` (today 31,700); it must go down.

**EFF-02 Reconcile without copying when nothing is due.** `A:event` deep-copies the state on every pulse (`app.lua:53`), about one hundred tables for a full deck, once per second while seconds are shown. Add a pure `M.due(s, now)`: true when `now < s.trusted`, or a running item or chain has reached its anchor, or an auto-reset is due. When it is false, set `trusted` on the live state and skip the copy. Keep the change only if the `timer` instruction proxy (today 1,600) and the heap churn in `validation_test.lua` both improve.

**EFF-03 Redraw on a pulse only when the page can change.** The pulse callback invalidates every time (`app.lua:118`), including checkpoint and deadline-slack wakes on Settings, Help or a form. Invalidate only when the page is `deck`, `detail`, `chain_run` or `completion`, or when reconcile changed state, or a strip changed.

**EFF-04 Renew keep-awake only when needed.** `plan()` calls `ctx.device:keep_awake` on every run (`app.lua:113`). Remember the granted deadline in `millis` and call again only when the required deadline is later than the granted one minus 60 s, or when releasing.

**EFF-05 Per-frame allocations in drawing.** `digits.lua:16` builds seven tables and a closure for every glyph on every frame; `widgets.lua:52` builds a translated point table for every icon polyline on every frame; `clock.lua:3` rebuilds its field list on every sample; `widgets.lua:30-35` calls `require` inside the row loop. Hoist the constants to module level; cache translated icon polylines by `icon:size:x:y` in the existing 12-entry cache.

**EFF-06 Bound the `shown` table.** `A:completion` adds one key per finished run for the life of the session (`app.lua:68`). Drop keys whose item is no longer Finished at that generation.

**EFF-07 Validate once per command.** A user command validates the candidate in `M.command` and again in `Store.commit`. Let the controller pass an already-validated marker for candidates that came straight from `M.command`. Low value; do it only if it stays a three-line change.

## 6. Part E — polish: the ten changes

Each item names its previews. Inspect every regenerated PNG (`AGENTS.md`).

### POL-01 Real glyphs instead of ASCII stand-ins

PREVIEW: the deck toggle is the text `>` or `II`, the pager is `<` and `1 / 2 >`, the menu button is `...`, backspace is `<`. `PRD.md` §14.1 specifies play, pause and check.

Add `lib/ui/glyphs.lua`: small vector drawings from `g:polygon`, `g:rect`, `g:line` and `g:circle`, each at most four commands, drawn in a box of a given size and colour.

| Glyph | Used for |
| --- | --- |
| play, pause, check | Deck toggle; Run and Detail primary buttons keep their words |
| chevron-left, chevron-right | Pager strip, completion browse, rows that open a page |
| more (three dots) | Run screen top bar |
| backspace | Keypad |
| plus | New timer and New chain buttons |

Previews: `deck-ten`, `keypad`, `completion` with two items, and a new `glyphs` sheet showing every glyph at 24, 32 and 44 px.

### POL-02 Weight hierarchy

CODE: no text in the app uses `bold`; titles, labels, values and captions differ only by size. CONTRACT §7: `bold` is available from 2.16 for text of 21 px and above, and adds 1 px to the measured width.

`W.text` and `W.button` accept `bold`. Bold: page titles, deck names and values, list row labels, primary button labels, state words. Regular: captions, values in lists, secondary buttons, help body. Every `measure` call passes the same options as its `text` call. No new font size (D10).

### POL-03 Settings on one page, with a proper list row

One list component for Settings, Menu, forms and chain pages.
- Row height `clamp(area // rows, 72, 96)`. If the rows do not fit at 72 px, page with the BUG-05 strip.
- One line: label at x 20 (32 px bold, 26 px if needed), value right-aligned at x 444 (26 px), chevron when the row opens a page. An optional 22 px note goes on a second line.
- On / Off rows toggle on tap and show `On` or `Off` as the value.

Settings rows, in order:

| Row | Value | Shown when |
| --- | --- | --- |
| Screen flash | On / Off | Always |
| Light pulse | On / Off | `ctx.frontlight` |
| Light pattern | Pattern name | RM-03 |
| Alert repeats | 1–5 | RM-03 |
| Seconds | Smart / Always / Never | Always |
| Stay awake | On / Off, note `Uses more battery` | `ctx.device.keep_awake` |
| Lock screen | On / Off | `ctx.lockscreen` |
| Data | chevron | Always |

Eight rows give 78 px each and no pager. **Data** is the present Import and export page with **Reset saved data** added as a separate last row.

Previews: `settings` (replaces `settings` and `settings-page2`), `settings-alerts-off`, `data`.

### POL-04 Toasts for feedback, native dialogs for decisions

CODE: there is no `toast` call in the app. Every one-line result is a full page that costs two screen refreshes and a tap (about 1.3 s of panel time; CONTRACT §5).

- `A:toast(text)` uses `ctx.dialog:toast` (≤ 95 bytes, about 2 s) and falls back to the message page when `ctx.dialog` is missing or the call returns an error.
- Toast: exported, imported, `Set at least 1 second`, the name rule, deck full, chain limits, stale item, save retry result.
- Keep as pages: recovery, blocked, restored from backup, import failure with details.
- Confirmations use title, message and button text instead of one long title:

| Action | title | message | ok_text / cancel_text |
| --- | --- | --- | --- |
| Reset saved data | `Reset saved data?` | `All Timer Deck items and settings will be removed.` | `Reset` / `Keep` |
| Stop chain | `Stop this chain?` | — | `Stop` / `Keep running` |
| Delete chain with a run | `Stop and delete this chain?` | — | `Delete` / `Keep` |
| Discard | `Discard changes?` or `Discard new timer?` | — | `Discard` / `Keep editing` |
| Start fresh | `Start fresh?` | `Old timers and settings will be removed.` | `Start fresh` / `Cancel` |

Accept (TU23): a host test walks COPY and fails on any toast string over 95 bytes, any title over 95, any message over 191, any button text over 63.

### POL-05 Deck rows that show state at every density

PREVIEW `deck-ten-light`: at eight or more rows the state hint is dropped, and Ready and Paused rows both show `>`. State must be readable from shape alone (`PRD.md` §2.4).

| State | Toggle glyph | Progress bar | Value |
| --- | --- | --- | --- |
| Ready | play | none | normal |
| Running | pause | solid | normal; inverted chip at 10% or less (unchanged) |
| Paused | play | hollow outline, matching the hollow paused ring | normal |
| Finished | check | none | `00:00` in an inverted chip |

Also: the pager strip (BUG-05), the labelled delete confirmation (BUG-14), and the 22 px state hint stays for rows of 79 px or more.

Previews: `deck-states-dense` (ten rows covering all four states and a stopwatch), `deck-pager`, `deck-delete-armed`.

### POL-06 Fewer screens for common actions

- **New stopwatch form** gets **Start** beside **Save**. Start issues `CREATE` then `PRIMARY` and opens Detail. Today a stopwatch can only be saved, found on the deck, and then started. No model change.
- Detail **Edit** replaces the two-row actions page (RM-06).
- Key focus on list pages starts on the first control below the top bar, never on Back. Up with no focus does nothing there (today it activates the first hit box, which is Back: `nav.lua:29`). Detail, Run and Completion keep Up as their primary action.

### POL-07 Chain screens

- Run screen copy and labels per BUG-12; titles per BUG-11.
- Step pips: one row of segments under the top bar, one per step, filled when done, outlined when pending, the current one half-filled. At most ten rectangles; it carries state and replaces reading `STEP 2 OF 5` at a distance.
- Rounds in the editor: a `−` / `+` stepper as `PRD.md` §16.6 says, instead of a tap that cycles 1 to 9.
- Chains list with no saved chains: show `No chains yet` (the unused `no_chains`) and the New chain button.
- Navigation hygiene from BUG-06 and BUG-07.

Previews: `chain-run`, `chain-run-single-round`, `chain-editor`, `chains-empty`.

### POL-08 Lock page

- Caption order and battery guard (BUG-13).
- A progress bar under `MIN LEFT` for the headline countdown: `glance.lua` adds `v.ratio` from `F.ratio(left, dur, 440)`; `lock.lua` draws one 8 px rectangle. No new module; the lock whitelist is unchanged.
- Secondary lines use the same separators and step labels as the app.

Previews: all `lock-*` frames. TL01–TL06 must still pass with the 2,000 ms budget proxy unchanged or lower.

### POL-09 The alert moment

- CODE `signal.lua:25`: every attempt ends with `invalidate('full')`. CONTRACT §5: a partial frame takes about 0.65 s and a full refresh about 1.5 s on this device, and attempts start 2 s apart. With three repeats the panel is refreshing for most of six seconds, and the first touch in that time is consumed by design. Change rule R5: the frame after each flash is a partial refresh; one full refresh follows the last attempt of the series, or the touch that silences it.
- **Test alert** button on the Settings page bottom bar: plays one attempt with the current default pattern and channels, through the preview path fixed in BUG-03. It replaces guessing what the toggles do. With both channels off it is disabled, and its note reads `Flash and light are off`. It never implies that anything will be heard.
- The completion page is unchanged.

Accept (TA17): over a three-attempt alert the host records three inverted frames, three partial restores and exactly one full refresh.

Device check DV16 decides whether this reads better than the current behaviour; if not, revert R5 only.

### POL-10 Help, diagnostics and focus

- Help is laid out by topic: each heading is bold 26 px and never the last line of a page; a topic that fits on a page is not split. The first topic stays **No sound**, with the required sentence (§1.1), on page 1.
- Add the missing lines: long press a row to start or pause; tap the digits for exact time; Menu has New stopwatch and Device information; Settings, Data imports and exports; dark mode (RM-01).
- **Device information** from the Menu (RM-05), with the app version as its first line.
- The 4 px focus outline is drawn the same way on every page, deck included, and is cleared on every page change (BUG-08).

## 7. Data and compatibility

- Schema stays `v = 1`. No field is added or removed. `set.app` and `set.style` are legacy fields: written as 0 by `M.new`, validated, never read by drawing.
- BUG-02 changes when `ch.run.att` and `ch.run.sil` are reset, not their type or range.
- A 0.3.1 save loads in 0.3.2 and the reverse. Add both directions to `store_test.lua` with fixtures holding `app = 2`, `style = 3` and a running chain with `sil = 1`.
- `deck.bak` format `TDB1` is unchanged.
- Package budget unchanged: under 200 KB, at most 40 scripts (33 after adding `glyphs.lua`), heap peak at most 512 KiB on the host walk.

## 8. Tests and previews

New host cases, added to the existing suites and to `docs/test-matrix.md`:

| ID | Suite | Covers |
| --- | --- | --- |
| TU17 | `app_test.lua` | BUG-01 key cycle on 0, 1 and 10 rows |
| TU18 | `store_test.lua` | BUG-04 Back in recovery and blocked |
| TU19 | `app_test.lua` | BUG-05 pager geometry and reachability |
| TU20 | `app_test.lua` | BUG-08 `A:go` at nine sites; BUG-09 dirty flag |
| TU21 | `app_test.lua` | BUG-11 title table; INC-03, INC-05 copy |
| TU22 | `validation_test.lua` | Settings rows per capability and per RM-03; legacy `app` and `style` values load and are ignored; no hit carries `arg` `app` or `style` |
| TU23 | `validation_test.lua` | POL-04 byte limits and fallback page |
| TU24 | `validation_test.lua` | EFF-01 copies and plans per tap; EFF-03 no frame on a Settings pulse |
| TU25 | `app_test.lua` | BUG-14 single armed row |
| TU26 | `validation_test.lua` | §1.1 required sentence in Help page 1, the empty deck and the manifest; no banned sound/vibration/alarm words elsewhere |
| TA16 | `attention_test.lua` | BUG-03 preview does not silence |
| TA17 | `attention_test.lua` | POL-09 refresh sequence |
| TH11 | `chains_test.lua` | BUG-02 cue touch, result alert delivered |
| TH12 | `chains_test.lua` | BUG-06, BUG-07 pruning, stack depth, no draw error |
| TH13 | `chains_test.lua` | BUG-12 labels, banner token |
| TL07 | `lock_test.lua` | BUG-13 order, battery -1, bar ratio |

Existing cases to update, not delete: `app_test.lua:21` (appearance preview) becomes a check that the action no longer exists; `attention_test.lua:36` (appearance inversion table) reduces to the flash flip; `validation_test.lua:21-35` keeps the legacy-value checks; `preview.lua:38` drops `appearance-picker`.

`tools/preview.py` clears old frames first (DEAD-09). The previews named in section 6 are added to `tools/tests/preview.lua`. The hit-map audit (no overlap, at least 56 × 56, on screen) applies to every new frame.

## 9. Decisions to record in `docs/decisions.md`

| Topic | Decision |
| --- | --- |
| D11, parity row 17 | Owner override: Appearance is removed; the app follows system dark mode. `set.app` is kept and ignored |
| §14.10 Settings | One page; Import, Export and Reset move to Data; alert rows shown only when they act; Stay awake hidden without the capability |
| §14.9 S12 | Item actions page merged into the edit form |
| §14.10 Device information | Reached from the Menu; the seven-tap gesture is removed |
| §11.3 R5 | Partial restore after each flash; one full refresh per alert series. Pending DV16 |
| §13.7 | One pager strip for deck and lists; adaptive list row height 72–96 px |
| §16 chains | `att` and `sil` reset at every boundary (baseline `chains.c`); `CH_SILENCE` scoped to the current event |
| §10.6 | Coverage page copy and button conditions |

Open questions for the owner. None blocks the work; the stated default applies until answered.

| ID | Question | Default |
| --- | --- | --- |
| OQ1 | Reduce Seconds to Smart only? "Always" refreshes the whole panel every second for the full run | Keep three modes until DV06 and DV10 are measured |
| OQ2 | Reduce four patterns to two if DV03 shows they cannot be told apart? | Keep four |
| OQ3 | Minute values read `08 min` and a Ready stopwatch reads `+00 min` (BASELINE §7.6). Change to `8 min` and `+0 min`? | No change |
| OQ4 | Importing the same file twice is refused (`This file was already imported.`), also after the imported items were deleted. Offer "Import again?" instead? | No change |

## 10. Milestones

Each milestone ends with `make test` green on Lua 5.5/32, regenerated previews inspected, and one local conventional commit with no attribution trailer. No push, no upload.

| # | Scope | Commit |
| --- | --- | --- |
| N1 | BUG-01 to BUG-04 with TU17, TU18, TA16, TH11 | `fix: close crash, lost chain alert, preview silence and recovery dead end` |
| N2 | BUG-05 to BUG-16 with their tests; `A:go`, `A:prune`, shared pager | `fix: repair navigation, paging, titles and lock layout` |
| N3 | RM-01 to RM-06, DEAD-01 to DEAD-11, INC-01 to INC-10 | `refactor: remove appearance, dead code and duplicate copy` |
| N4 | EFF-01 to EFF-07 with TU24; new instruction baseline | `perf: run the controller once per input and skip idle copies` |
| N5 | POL-01 to POL-10 with TU22, TU23, TU26, TA17, TH13, TL07 and all previews | `feat: glyphs, weight hierarchy, one-page settings and toasts` |
| N6 | Version `0.3.2` in `app/manifest.json` and `app/lib/gen/version.lua`; README, INSTALL, storage-format, test-matrix, test-report, device-checklist, decisions; `make package` | `chore: release 0.3.2 host candidate` |

Order matters: N1 is shippable alone if the owner wants the four serious fixes first.

Gate report per milestone (`AGENTS.md`): actual checks and statuses, preview paths, open IDs, decisions, next work. `device_tests_run` stays `false`.

## 11. Device checks to queue

Add to `docs/device-checklist.md`; V01–V14 and DV01–DV15 stay as they are, with DV10 reworded to use the system dark mode.

| ID | Step | Decides |
| --- | --- | --- |
| DV16 | Run a 10 s timer with three repeats. Judge the flash sequence and how soon a touch is accepted | POL-09 R5 |
| DV17 | Read the deck toggle glyphs and bold titles at arm's length, in light and system dark mode | POL-01, POL-02 |
| DV18 | Trigger a toast (export) and a native confirmation (Reset saved data, then Keep) | POL-04 |
| DV19 | With ten timers and a running chain, find the eleventh row using taps only | BUG-05 |
| DV20 | Run a two-step chain, tap during the step cue, wait for the end | BUG-02 |

## 12. Definition of done

- All S1 and S2 defects fixed with a failing-then-passing host case each.
- Settings is one page; no Appearance; no screen offers a control that does nothing.
- `make package` passes; the decrypted package equals the sources; the report says `device_verified: false`.
- Every preview named here exists, was opened and inspected, and no stale frame remains in `build/previews/`.
- `docs/decisions.md` holds every row of section 9; open VERIFY items are still open.
