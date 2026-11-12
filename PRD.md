# Timer Deck for XTEINK — Product Requirements Document

Implementation note (2026-11-12): the 0.3.2 cleanup delta is [docs/prd-0.3.2.md](docs/prd-0.3.2.md). Accepted owner overrides and DRAFT DEFAULT changes are recorded in [docs/decisions.md](docs/decisions.md), including removal of Appearance and Style, one-page Settings, Data, visible Device information and R5. This PRD remains the source of truth subject to those recorded changes and the API contract. VERIFY items still require device evidence.

| | |
| --- | --- |
| **Product** | Timer Deck (InkApp port of the Pebble watchapp) |
| **Version of this PRD** | 1.0-draft, prepared 2026-11-11 (Asia/Tokyo) |
| **Repository** | `/home/ubuntu/projects/xteink-timer-deck` (empty when this PRD was written; not yet a Git repository) |
| **Target device** | XTEINK X4 Pro, 480 × 800 portrait e-ink, touch + Up/Down/Back keys, front light |
| **Target platform** | InkApp API **2.18**, Lua 5.5 with 32-bit integers and single-precision floats |
| **Owner's unit** | XT Licorice **26110501** (recorded in the sibling `xteink-daily-mass` project) |
| **Functional baseline** | Pebble Timer Deck **0.7.0**, storage schema 10, commit `202dbc6` in `/home/ubuntu/projects/pebble-timer-deck` |
| **Distribution** | One `.xtapp`, installed by USB through **All Files**. No store submission in this scope |
| **Audience** | The implementing AI agent, the owner, and whoever tests on the device |
| **Status** | Implementation-ready draft. Nothing is built. No statement here is device evidence unless it is tagged **[D]** |

### Reading map

| Need | Sections |
| --- | --- |
| How to work from this document, product and scope | §1–§4 |
| What the platform gives and forbids | §5 |
| Architecture, time and data | §6–§8 |
| Timer behaviour, alerts, refresh, input | §9–§12 |
| Visual design and every screen | §13–§14 |
| Lock screen, Timer Chains, desktop file sync | §15–§17 |
| Copy, quality budgets, tooling, tests | §18–§21 |
| Milestones, risks, deferred work, done | §22–§25 |
| Owner questions, agent instruction, sources, appendices | §26–§28, A–E |

---

## 1. How the implementing agent must use this document

Read §1–§8 before writing code. Then build in the milestone order of §22. Implement the behavioural contract; the layouts in §13–§14 are starting geometry that you tune against host previews and, later, device photos.

### 1.1 Authority levels

| Tag | Meaning | What you may do |
| --- | --- | --- |
| **CONFIRMED** | The owner said it in the request for this PRD, or it is the product's established identity | Do not change without the owner |
| **BASELINE** | Behaviour of Pebble Timer Deck 0.7.0, carried over because the owner asked for "similar (identical) functionalities" | Keep. Change only where this PRD says the platform forces it |
| **DRAFT DEFAULT** | A concrete choice made in this PRD so that work can start. The owner has not approved it individually | Implement it, keep it easy to change, record material trade-offs in `docs/decisions.md` |
| **VERIFY** | A platform fact that must be measured on the device or the official simulator | Build the probe, record the result, do not claim it earlier |
| **DEFERRED** | Outside this scope | Do not build it |

**MUST** is required for the release it belongs to. **SHOULD** is preferred unless a recorded reason prevents it. **MAY** is optional.

### 1.2 Evidence tags for platform facts

| Tag | Source |
| --- | --- |
| **[O]** | Official InkApp contract, API 2.x, tag `api-2.18.2`, local copy in `../xteink-daily-mass/experiments/ext/kb/` (English sections `090`–`123`) |
| **[C]** | Community finding (`touch-licorice-apps`, `x4pro-emu`). Reverse-engineered and firmware-specific |
| **[D]** | Observed on the owner's X4 Pro in the `xteink-daily-mass` project |
| **[P]** | Pebble Timer Deck source or documents |
| **[V]** | Checked on this server on 2026-11-11 while writing this PRD |
| **[I]** | Inference by the author. Treat as VERIFY |

### 1.3 Standing rules

1. Host results (mock fonts, mock clock, PNG previews) are never device evidence. Label them `HOST MOCK` in file names, reports and images.
2. Do not push, publish, upload, open a Studio preview, or use the network without the owner's separate approval. `git init` and local commits are normal work. Follow the owner's global Git rules: conventional commit messages, no AI attribution lines.
3. Do not write to `../pebble-timer-deck` or `../xteink-daily-mass`. Copy what you need into this repository.
4. Use only API 2.x names. The 0.8 names (`ctx.data`, `ctx.display`, `ctx:set_tick_rate`, a global `g`, …) do not exist for a 2.x package [O §19]. The lint in §20.4 rejects them.
5. If a platform limit blocks a requirement, record the evidence, choose the smallest behaviour-preserving alternative, and continue with independent work. Do not silently drop a feature or replace the app with something else.
6. When this PRD and the official contract disagree, the contract wins. Record the correction in `docs/decisions.md`.
7. A step that needs the owner's hands (install, photo, measurement) never blocks host work. Queue it in `docs/device-checklist.md` and continue.

---

## 2. Product definition

### 2.1 Statement

Timer Deck is a board of up to ten independent countdowns and stopwatches for the XTEINK X4 Pro. The Pebble original lives on a wrist and vibrates. This device does neither: it is a pocket e-ink slab with a magnetic back that sits on a desk, a fridge door or the back of a phone. The port keeps the Pebble app's behaviour (the same items, states, limits, completion rules and chains) and replaces the parts the hardware cannot do.

### 2.2 What is different on this device, and what it forces

| Fact | Evidence | Consequence |
| --- | --- | --- |
| No sound and no vibration API | [O §21] lists every capability; [C] Timekeeper README: "The reader has no sound or vibration" | An alert is **visual only**: a screen flash, a front-light pulse, and a persistent "Time's up" page. The app must say so plainly (§10) |
| A lock, a power-off or leaving the app **ends the session** and destroys the Lua VM | [O §2, §15] | No background execution. All timing comes from saved end moments (§7). "Background alerts" become stay-awake and an optional lock-screen page (§10, §15) |
| A frame takes about 650 ms to present; a full refresh about 1.5 s | [O §2, §5] | No animation. Seconds are shown only when they matter (§11) |
| Black and white only (`gray_levels` 2) | [O §3] | Colour palettes become monochrome styles; warm/hot ring colours become shape changes (§13) |
| Touch, two side keys and Back. Keys have no long press and no repeat | [O §3, §4] | Touch-first controls; keys are a two-button remote (§12) |
| 480 × 800 px on a 4.3-inch panel, about 217 px per inch (80 px ≈ 9.3 mm) | [O §3]; computed from the diagonal | All ten items fit on one screen. A real keyboard and a keypad replace the Pebble character picker and field editors |
| Lua numbers are 32-bit | [O §1] | Time is kept in whole seconds, not milliseconds (§7) |
| E-ink keeps its last image with no power | Device property | A "Time's up" page stays readable after the alert stops, until the device locks |

### 2.3 Primary jobs

| Job | Required outcome |
| --- | --- |
| Time several activities | Create and run several countdowns that never affect each other |
| Check the time left | Read every item's state and value from across a kitchen, at a glance |
| Pause one activity | One touch (or one key) pauses or resumes one item |
| Walk away | Timing stays correct through exit, lock and power-off. The app says truthfully whether you will be alerted |
| Notice completion | Every finished countdown is shown and identified, including several at once |
| Reuse a timer | Configured duration survives finish, reset and dismissal |
| Measure elapsed time | Stopwatches run beside countdowns and across sessions |
| Run a sequence | A saved chain of steps advances by itself (Timer Chains) |

### 2.4 Principles (BASELINE, [P] PRD §2.3)

- Time and state outrank decoration.
- Every item is independent. Settings never change timing state.
- Values are computed from saved anchors and the wall clock, never from callback counts.
- A shown success reflects a checked result, especially for saves.
- State is readable without colour: words and shape carry it.
- A completion is an event with an identity. Dismissing one never discards another.
- No network, no account, no telemetry.
- The app never claims an alert it cannot deliver.

### 2.5 Success criteria

1. Ten mixed items run independently; an eleventh is refused without touching the others.
2. From the deck, starting or pausing an item takes one tap.
3. Timing arithmetic passes deterministic tests on Lua 5.5 with 32-bit numbers, including exit, relaunch, clock rollback and the 2038 limit.
4. Every user mutation is saved before the app reports success, or the failure is shown.
5. Every screen draws within the platform limits (§5.3) with at least 25% margin.
6. On the device, a countdown that finishes while the app is open is shown within 2 seconds of its deadline. [VERIFY, §21.5]
7. The owner can install the package over USB and complete the device checklist without help.

---

## 3. Functional baseline and parity map

Baseline: Pebble Timer Deck 0.7.0 [P]. "Ported" means the same rule. "Adapted" means the same outcome through different controls or drawing. "Replaced" means the platform cannot do it and an honest equivalent stands in. "Dropped" means it has no meaning here.

| # | Pebble 0.7.0 feature | Treatment | XTEINK behaviour | Section |
| --- | --- | --- | --- | --- |
| 1 | Ten combined countdowns and stopwatches | Ported | Same capacity and independence | §9 |
| 2 | Duration 1 s to 999d 23h 59m 59s (86,399,999 s) | Ported | Same bounds, whole seconds | §7, §9 |
| 3 | States Ready / Running / Paused / Finished; commands | Ported | Same state machines and ordering rules | §9 |
| 4 | Stable ID, run generation, display number 01–10 | Ported | Same | §9.1 |
| 5 | Optional 16-character names; `TIMER NN` / `WATCH NN` fallback | Adapted | System keyboard instead of a character picker | §9.2, §14.6 |
| 6 | 30 Lucide icons or None | Ported | Same list and indices, drawn as vectors | §13.6 |
| 7 | New timer → duration → Start timer; Save; More options; default 10 s | Adapted | Touch keypad; same three steps | §14.3 |
| 8 | Deck: one row per item, icon, value, progress bar, `+` for stopwatch | Adapted | Up to ten rows on one page, each with a start/pause button | §14.1 |
| 9 | Orbital detail: ring drains clockwise, warms at 25%, hot at 10% | Adapted | Monochrome ring; shape cues replace colour | §13.5, §14.4 |
| 10 | Detail buttons: Up gear, Select primary, Down reset | Adapted | On-screen buttons; keys Up = primary, Down = next item | §12 |
| 11 | Reset and Delete act at once, without confirmation | Ported | Same. Deleting from the deck needs two deliberate gestures | §9.5, §14.1 |
| 12 | Completion queue: browse, dismiss one, Back clears all; `FINISHED AWAY` when late | Ported | Same | §9.7, §14.8 |
| 13 | Delivered completions reset themselves after 10 minutes; missed ones wait | Ported | Same | §9.8 |
| 14 | Four vibration patterns, count 1–5, fair queue, durable attempt count | Replaced | Four **light-and-flash** patterns with the same names, counts and queue rules | §10 |
| 15 | OS wakeups, coverage states, `ALERT UNAVAILABLE` | Replaced | Stay awake while timers run; optional lock-screen page; honest coverage line | §10.6, §15 |
| 16 | App Glance launcher subtitle | Replaced | The lock-screen page shows the same priority order | §15 |
| 17 | Dark / Light appearance | Adapted | Auto (follow system) / Light / Dark | §13.2 |
| 18 | Palettes Ion, Cobalt, Plasma, Solar | Adapted | Four monochrome **styles** with the same names | §13.3 |
| 19 | Motion (slide and ring wind-up) setting | Dropped | E-ink cannot animate. A fixed refresh policy replaces it | §11 |
| 20 | Subtle clock on deck and detail | Ported | Same, honours 12/24-hour setting | §14.1 |
| 21 | Two-bank storage, schema version, recovery screen, no silent wipe | Adapted | `ctx.state` (atomic by contract) plus one checked backup file | §8 |
| 22 | Clock policy: forward counts as elapsed; detected rollback rebases | Ported | Same, plus "clock not set" and the 2038 limit | §7 |
| 23 | Clay phone settings: global settings, item edits, add up to three timers, chain editing | Replaced | Everything is editable on the device by touch. Bulk creation comes from a text file over USB | §17 |
| 24 | Timer Chains: 5 chains, 2–10 steps, rounds ×1–9, templates, copy from Deck | Ported | Same model and controls; alert coverage as for timers | §16 |
| 25 | Launcher icon | Ported | 88 × 88, 1-bit, stacked timer dial | §20.6 |
| 26 | Help / About, Reset saved data | Ported | Same, plus a device-information page | §14.10 |
| 27 | Round (Gabbro) layout | Dropped | One device profile; portrait only | — |
| 28 | App Store release tooling | Dropped | Local USB package only | §20 |

**Parity is behavioural.** The agent does not port C code line by line. It re-implements the rules of `src/core/model.c`, `chains.c`, `effects.c` and `glance.c` in Lua, using the Pebble host tests (`tests/test_core.c`, `test_chains.c`, `test_effects.c`, `test_glance.c`, `test_controller.c`) as the list of cases to cover. Where a rule in this PRD and the Pebble source differ without an explanation here, the Pebble source is right and the PRD needs a correction.

---

## 4. Decision register

| ID | Decision | Authority | Consequence |
| --- | --- | --- | --- |
| D01 | Name **Timer Deck**; `app_id` `timerdeck`; display name `Timer Deck` | CONFIRMED / BASELINE | `app_id` uses letters only, which satisfies the official character set and the community packager [C]. It never changes: a new id is a new app with empty data [O App. B] |
| D02 | Target XTEINK X4 Pro, InkApp API 2.18, portrait 480 × 800 | CONFIRMED | Manifest `"api": "2.18"`, `"requires": ["pointer"]`, `"permissions": []` |
| D03 | Functional baseline is Pebble Timer Deck 0.7.0 | CONFIRMED | §3 is the scope |
| D04 | Canonical time unit is the **whole second** (`epoch_sec`) | DRAFT DEFAULT, forced by 32-bit numbers | Epoch milliseconds do not fit. Each pause/resume can shift a value by less than one second, without bias (§7.4) |
| D05 | Alerts are a screen flash and a front-light pulse. Pattern names and counts keep their Pebble meaning | DRAFT DEFAULT | §10. The app states that it has no sound |
| D06 | **Stay awake while timers run** is On by default, for countdowns that end within 4 hours | DRAFT DEFAULT | Uses `ctx.device:keep_awake` (2.18). Costs battery; the setting says so |
| D07 | The lock-screen page is opt-in | DRAFT DEFAULT | It replaces the user's lock screen, so the user turns it on in Settings |
| D08 | Seconds are shown only when they matter (**Smart**); the user can choose Always or Never | DRAFT DEFAULT | §11 |
| D09 | Large numerals are drawn as vector digits, not TTF text | DRAFT DEFAULT | No dependence on TTF memory or font files; identical in the lock-screen session. M0 confirms (§22) |
| D10 | Labels use at most four TTF sizes per session: 22, 26, 32, 40 px | [D] | More sizes exhausted TTF memory on the owner's device in the Daily Mass project |
| D11 | Appearance is Auto / Light / Dark; default Auto | DRAFT DEFAULT | Auto draws light tokens and lets the system dark mode invert the frame |
| D12 | Palettes become four monochrome styles: Ion (default), Cobalt, Plasma, Solar | DRAFT DEFAULT | §13.3. Ion ships first; the others in M7 |
| D13 | Names: up to 16 printable ASCII characters (0x20–0x7E) except `\|` | DRAFT DEFAULT | Wider than Pebble's letters/digits/space, because a real keyboard exists. Width stays predictable; `\|` is the import separator |
| D14 | Keys: **Down moves to the next thing, Up acts on it** | DRAFT DEFAULT | A Bluetooth page turner becomes a two-button remote (§12.3) |
| D15 | Persistent state lives in `ctx.state`; a checked copy lives in the private file `deck.bak` | DRAFT DEFAULT | The contract makes each save atomic, but a damaged save loads as an empty table. The copy lets the app detect that instead of silently showing an empty deck |
| D16 | Icons are vector polylines generated at build time from the Pebble project's Lucide SVGs | DRAFT DEFAULT, forced | The community packager builds no image-asset section [V], so `ctx.package:image` is unavailable on the USB route |
| D17 | Phone editing is replaced by on-device editing and a text-file import/export | DRAFT DEFAULT | §17 |
| D18 | One active chain run; five saved chains; rounds ×1–9; three templates | BASELINE | §16 |
| D19 | Creation defaults: countdown 10 s; alert Short + short, count 3 | BASELINE | §9 |
| D20 | Auto-reset grace 10 minutes; late threshold 60 s | BASELINE | §9.8 |
| D21 | No `set_tick`. One planner arms `ctx:after` for the next moment something changes | DRAFT DEFAULT | Lowest wake count; deterministic host tests (§6.5) |
| D22 | Packaging uses a pinned, vendored copy of the community packager | DRAFT DEFAULT | The official packager is not public [C]. A firmware key rotation breaks installs until the package is rebuilt (§23) |
| D23 | No landscape, no other device profile, no localisation beyond English strings in one table | DRAFT DEFAULT | Keeps layout work bounded |

The agent may start with these defaults. Changing D01–D03 needs the owner. Changing another product-visible default needs a recorded reason.

---

## 5. Platform contract

### 5.1 Device profile `x4_pro` [O §3]

| Item | Value |
| --- | --- |
| Screen | 480 × 800 portrait, occlusion 0 on every side, `gray_levels` 2 |
| Touch | One finger: `down`, `move`, `hold` (700 ms), `up` with gesture `tap`, `double_tap`, `long`, `swipe_*` (≥ 50 px), `cancel` |
| Keys | `up`, `down`, `back`. One `down`/`up` pair per press; no repeat, no long press visible to the app |
| Back | Short press: `down` then `up` on release. A 1 s hold force-quits the app. Unhandled Back opens the system exit confirmation (2.7) |
| Home pad | Tap delivers `back` if the user's setting is Back (default). Long press goes Home and ends the session. The user can change both; never depend on Back alone |
| System fonts | small / medium / large with line heights 20 / 24 / 30 px. TTF through `ctx.fonts:size(px)`, 8–96 px, in the user's chosen font |
| Front light | Yes, with warmth. `ctx.frontlight` exists in the main session only |
| Timer wake | Yes: `ctx.device.lock_timer` is true; the lock screen can wake every 30–3600 s |
| Docked keyboard | 340 px tall [O]; an older build reported 436 px [C]. Not used by this app |

### 5.2 API surface this app uses

| Need | Call | Notes |
| --- | --- | --- |
| Lifecycle | `on_load`, `on_draw(ctx, g)`, `on_input`, `on_pause`, `on_resume`, `on_leave` | Limits 2000 / 1500 / 1000 / 1000 / 1000 / 1000 ms [O §2]. An uncaught error or a timeout ends the session **without** `on_leave` and without the automatic save |
| Wake | `ctx:after(ms, fn)` → `timer:cancel()` | 1 to 2,147,483,647 ms; at most 32 pending. Fires late by up to a few hundred ms. Paused while a system screen covers the app |
| Present | `ctx:invalidate()`, `ctx:invalidate("full")`, `ctx:defer_full_refresh(ms)` | Whole-screen partial refresh ≈ 650 ms; full ≈ 1.5 s. The system forces a full refresh every N partials (user setting, default 30) unless deferred (1–60,000 ms) [O §5] |
| Draw | `g:clear`, `rect`, `circle`, `arc`, `line`, `polyline`, `polygon`, `text`, `text_box` | ≤ 1024 commands per frame. `arc`: 0° is due right, clockwise positive, drawn from `start_deg` clockwise to `end_deg`; a difference that is a multiple of 360 draws nothing. Strokes extend inward. `polyline` 2–128 points, `polygon` 3–128 [O §6] |
| Text | `ctx.fonts:size(px)`, `font:measure`, `font.line_height`, `font.ascent`, options `bold`, `tabular`, `align`, `valign` | `bold` and `tabular` need a 2.16+ manifest. A font that cannot be opened returns a system font with `font.px == nil` [O §7] |
| Clock | `ctx.clock:now()` → `valid`, `epoch_sec`, `hour`, `minute`, `second`, `hour12`, `date_order`, `date_sep`, `offset_minutes`, `revision`; `ctx.clock:millis()` | `epoch_sec` is nil when the clock is not set and after 2038-01-19. `millis` wraps after 24.8 days: compare with `(later - earlier) & 0x7FFFFFFF`. There is no time-change event [O §12] |
| State | `ctx.state`, `ctx:save_state()` | ≤ 16,384 bytes as JSON, ≤ 6 table levels, string and integer keys. Saved automatically after `on_leave`; a save is atomic. A missing **or damaged** save loads as an empty table. Shared with the lock-screen session [O §28] |
| Private file | `ctx.storage:read/write/remove/exists` | Name `[a-z0-9._-]`, ≤ 262,144 bytes, atomic write, about 120 ms per 4 KB write on the X4 Pro [O §9] |
| User files | `ctx.files:read/write/exists/list`, `ctx.files.path` | `/AppFiles/timerdeck/` on the card; survives uninstall [O §29] |
| Keep awake | `ctx.device:keep_awake(ms)` | 0–14,400,000 ms; replaces the previous value; postpones **idle** power-off only; ends with the session; `nil, "inactive"` on the lock screen [O §13]. Needs firmware 26110201 or later [C] |
| Device | `ctx.device:battery()`, `ctx.device:display().dark`, `ctx.device.model`, `.firmware`, `.lock_timer`, `ctx.api`, `ctx.capabilities` | Read `dark` in every `on_draw`; never cache it |
| Front light | `ctx.frontlight:get()`, `:set({on, brightness})`, `:reset()` | Optional capability `frontlight`. Session-only; reset automatically at session end [O §24] |
| Text entry | `ctx.input:text({title, text, max_bytes}, fn)` | Opens the system keyboard; `on_pause`/`on_resume` surround it; `fn(ctx, text)` gets nil on cancel. The initial text field is `text` [C] |
| Dialogs | `ctx.dialog:confirm`, `:choose`, `:toast` | Optional capability `dialog`. Toast ≤ 95 bytes, about 2 s [O §23] |
| Lock screen | Manifest `lockscreen`; `ctx.lockscreen:set_default()`, `:is_default()`, `:clear_default()`; in the lock session `ctx.lock.reason`, `.elapsed_sec`, `:set_interval(30..3600)` | A lock session runs `on_load` and `on_draw` only, 2000 ms total, no `after`, no `extend`, no front light, no automatic state save [O §15] |
| Utilities | `ctx.json`, `ctx.hash:crc32` (signed int32), `ctx.log`, `ctx.gc:count()`, `ctx.perf:info()`, `ctx.budget:extend()`, `ctx:quit()` | Every `ctx.*` function is a method: call it with a colon [C] |

Not used: `ctx:set_tick`, `ctx.net`, `ctx.reader`, `ctx.ui`, `ctx.layers`, `ctx.package:image`, `ctx.input:edit`, `ctx.nn`.

### 5.3 Limits that shape the design

| Limit | Value | Source |
| --- | --- | --- |
| Lua numbers | Integers are signed 32-bit and wrap; floats are single precision (exact integers only to 16,777,216) | [O §1] |
| Script heap | "At least 2 MB" [O]; 1 MB reported on an older build [C]. This project budgets **512 KiB** | — |
| Missing globals | `io`, `os`, `package`, `debug`, `load`, `loadfile`, `dofile`, `print`, `collectgarbage` | [O §1] |
| Lua 5.5 | A `for` loop variable cannot be assigned | [C] `lualint55.py` |
| `require` | Package scripts only; `a.b` loads `a/b.lua`; at most 128 scripts | [O §1, App. A] |
| Draw commands | 1024 per frame; older builds silently dropped the rest | [O §5], [C] |
| Callback budgets | See §5.2; `on_leave` and lock sessions cannot be extended | [O §2] |
| Key events | A side-key press can arrive more than once: ignore the same key within 250 ms | [C]; the Daily Mass app ships this rule |
| Layout calls | A negative height passed to `font:layout` is an error on the device | [D] |
| Large black areas | Can ghost on e-ink | [C] |
| Package | `.xtapp` ≤ 32 MB. This app should be under 200 KB | [O App. A] |

### 5.4 Verification gates (VERIFY)

Each gate is answered by the probe screen of M0 or by a later device check. Record results in `docs/platform-findings.md` with the firmware string and date.

| ID | Question | Why it matters | Fallback if the answer is bad |
| --- | --- | --- | --- |
| V01 | `ctx.api.minor`, `ctx.device.firmware`, `ctx.device.model`, every `ctx.capabilities` field | Confirms 2.18 and which optional features exist | Feature-detect everything optional; never lower `"api"` below 2.16 (bold, tabular) |
| V02 | Does the pinned packager's package install on 26110501? | The whole delivery route | Re-derive the key from the owner's own flash dump (community `--image` option), or use the official Studio route with owner approval |
| V03 | `ctx.frontlight:set` latency and visibility of 300 ms and 900 ms pulses, lit room and dark room | Light pulse design (§10.3) | Lengthen pulses; if useless, ship flash only |
| V04 | Does `keep_awake` hold the device awake for 30 minutes with no input? Battery percent lost per hour awake in each Seconds mode | D06, battery copy | Reduce the default horizon; default the setting to Off |
| V05 | Lock-screen page: appears on power-key lock and idle lock; `set_interval(30)` honoured; session time for our `lock.lua` | §15 | Fixed 60 s interval; smaller script |
| V06 | After the power key leaves the lock screen, does Timer Deck reopen by itself when it was in front? | Completion on return (§10.6) | Tell the user to open the app |
| V07 | Partial-refresh ghosting after 60 one-second frames; readability of an inverted (dark) frame | §11 refresh policy, Dark appearance | Full refresh more often; restrict Dark |
| V08 | Vector digits at 96 px: draw time, command count, legibility. `ctx.fonts:size(96, "0123456789:")` as the alternative | D09 | Switch to the other option |
| V09 | Heap after load, after opening every screen once, after 100 create/delete cycles (`ctx.gc:count()`) | 512 KiB budget | Lazy-load more; trim |
| V10 | `ctx:save_state()` and `ctx.storage:write` time for the full-size state | Input budget (§19) | Defer the backup write further |
| V11 | Key events: duplicates, order of `down`/`up`, page-turner behaviour | D14 | Adjust debounce |
| V12 | Tap accuracy on 63 px rows and 72 px buttons | Deck density (§14.1) | Raise the minimum row height and page the deck |
| V13 | `ctx.input:text` with `max_bytes = 16`: what the keyboard allows, what cancel returns | Name entry | Validate after entry (already required) |
| V14 | Behaviour when `ctx.clock:now().valid` is false, and after changing the device time while the app is open (`revision`) | §7.5 | — |

### 5.5 What this PRD adds to the minimum InkApp in the request

The request listed the bare minimum (a manifest, `index.lua`, a packager, USB install). That is correct. These points complete it for this app:

| Topic | Addition |
| --- | --- |
| Manifest | Also `requires: ["pointer"]`, `display.orientation: "portrait"`, `app_icon_s`, and a `lockscreen` block (Appendix A). `app_id` uses letters only so that the community packager accepts it |
| Entry script | `on_input` must return `false` for Back at the root so the system can confirm the exit. `on_pause`, `on_resume` and `on_leave` are needed for overlays and for giving the front light back |
| A second script | `lock.lua`, a separate one-frame session for the lock screen |
| State | `ctx.state` and `ctx:save_state()` are part of the minimum for a timer: without them every lock or exit would lose the deck |
| Firmware | `keep_awake` needs firmware 26110201 or later [C]; API 2.16 is the floor for bold and tabular digits |
| Memory | The 512 KiB budget is this project's choice. The contract promises at least 2 MB of script heap, not counting font memory |
| Images | `assets/` images are **not** available on the community packaging route; only the launcher icon is packed [V] |
| Studio preview | Optional, and it uploads the project to Xteink's relay. Not used without approval |
| Host testing | Not required by the platform, but required here: a Lua 5.5 interpreter built with 32-bit numbers, and a strict double of the API |

---

## 6. Architecture

### 6.1 Repository layout

```text
xteink-timer-deck/
├── PRD.md                      this document
├── AGENTS.md                   standing rules for agents (§1.3), written in M0
├── README.md                   build, test, package, install
├── Makefile                    test / preview / package targets
├── app/                        InkApp source: exactly what is packaged
│   ├── manifest.json           the only version source
│   ├── index.lua               lifecycle glue only
│   ├── lock.lua                lock-screen entry; reads state, never writes
│   ├── assets/app_icon_s.png   88 × 88, 1-bit
│   └── lib/
│       ├── core/               pure Lua: no ctx, no globals, no I/O
│       │   ├── const.lua       every limit and default (§9.9)
│       │   ├── model.lua       state, validation, commands, reconcile, completions
│       │   ├── chains.lua      chain definitions, run, commands
│       │   ├── format.lua      durations, labels, clock text
│       │   ├── alerts.lua      alert queue and attempt planner
│       │   ├── pulse.lua       next-wake planner
│       │   ├── glance.lua      lock-screen headline planner
│       │   └── importer.lua    text-file parser (loaded on demand)
│       ├── platform/
│       │   ├── clock.lua       one clock sample per event
│       │   ├── store.lua       ctx.state, deck.bak, migration, recovery
│       │   └── signal.lua      front-light pulses, keep-awake, lock-screen calls
│       ├── app.lua             controller: the only place that sequences work
│       ├── ui/
│       │   ├── theme.lua       tokens, appearance, styles
│       │   ├── strings.lua     every user-visible string (§18)
│       │   ├── digits.lua      Orbit digits; shared with lock.lua
│       │   ├── draw.lua        primitives: buttons, ring, icon, bars
│       │   ├── nav.lua         screen stack, hit map, input routing, guards
│       │   ├── deck.lua  detail.lua  keypad.lua  completion.lua     loaded at start
│       │   └── forms.lua  pickers.lua  menus.lua  chain_ui.lua  info.lua   loaded on first use
│       └── gen/                generated, committed
│           ├── icons.lua       30 icons as polylines
│           └── version.lua     written from manifest.json
├── assets/icons/lucide/        30 SVG sources + LICENSE (ISC), copied from the Pebble project
├── tools/
│   ├── setup_lua55.py          builds Lua 5.5.0 with LUA_32BITS from a verified archive
│   ├── shim/runtime.lua        deterministic API-2.18 host double (§20.3)
│   ├── tests/*.lua             suites run by the 5.5/32 interpreter
│   ├── lint.py                 device lint (§20.4) + vendored lualint55.py
│   ├── icons.py                SVG → polylines → app/lib/gen/icons.lua
│   ├── app_icon.py             draws the launcher icon
│   ├── preview.py              draw-command JSON → PNG (HOST MOCK)
│   ├── package_local.py        local .xtapp + decrypt round trip
│   ├── run_tests.sh            the host gate
│   └── vendor/                 pinned packager and lint, with licences
├── docs/                       platform-findings, decisions, storage-format, test-report,
│                               device-checklist, INSTALL
├── build/                      ignored: toolchain, logs, previews, gate results
└── dist/                       ignored: packages and reports
```

### 6.2 Boundary rules

- `lib/core/*` is pure. It never touches `ctx`, never reads a clock and never draws. Every function takes the state table and a time in seconds. It runs unchanged in host tests and in the lock-screen session.
- `lib/platform/*` are thin adapters. Each has a host double.
- `lib/app.lua` is the single controller. Screens send it intents; they never mutate state or call adapters.
- `on_draw` only draws. It performs no save, no file access, no font opening, no clock-dependent mutation. It reads the clock sample the controller took.
- Screens are tables with `draw(self, app, g)`, `input(self, app, ev)` and an optional `leave`. Each frame rebuilds the hit map.
- Modules loaded on first use: `forms`, `pickers`, `menus`, `chain_ui`, `info`, `core.importer`. Starting the app and running a timer must not load them (a host test checks this, as in Daily Mass).

### 6.3 Controller sequence (BASELINE, [P] PRD §10.4)

For every input, wake, resume and load:

1. Take **one** clock sample (§7.1).
2. If the clock went backwards, rebase (§7.3).
3. Reconcile: expired countdowns, stopwatch limit, chain boundaries, completion auto-reset.
4. Resolve the intent against its target `(id, generation)`. A stale target is rejected.
5. Build the candidate state on a copy.
6. Commit: assign `ctx.state`, call `ctx:save_state()`. On failure restore the previous table and report (§8.5).
7. Run effects: alert queue, keep-awake, pulse re-plan, backup write (deferred).
8. `ctx:invalidate()` with the wave chosen by §11.3.

### 6.4 Lifecycle mapping

| Callback | Work | Budget target |
| --- | --- | --- |
| top level + `on_load` | Load and validate state (§8.4); sample clock; reconcile; choose the first screen (completion queue or deck); plan the pulse; set keep-awake | ≤ 600 ms, so the system opening page (shown after about 0.8 s) does not appear |
| `on_draw` | Draw the current screen from state and the last sample | ≤ 300 ms, ≤ 400 commands |
| `on_input` | Debounce, guard, route, then §6.3 | ≤ 400 ms including the save |
| pulse timer | §6.3 with no intent | ≤ 200 ms |
| `on_pause` | Stop a running light pulse (`frontlight:reset`). Nothing else | — |
| `on_resume` | §6.3 with no intent. Timers that came due while paused fire after this [O §2] | — |
| `on_leave` | Reconcile once, update the trusted sample, write a pending backup. No explicit `save_state` (the host saves after `on_leave`). Cannot be extended | ≤ 300 ms |

Every callback body runs inside `pcall`. A caught error is logged once with a code (`E-…`), shown on a plain fatal screen with a **Try again** button, and never leaves the session to die silently (an uncaught error would skip the automatic save).

### 6.5 The pulse: one planner for every wake (D21)

`core/pulse.lua` computes, from the state, the visible screen and the current sample, the earliest moment something must happen. `app.lua` keeps exactly one pending `ctx:after` for it and re-plans after every event.

| Reason to wake | When |
| --- | --- |
| A visible value changes at second granularity | The next whole second |
| A visible value or the header clock changes at minute granularity | The next minute boundary of that value (not of the wall clock, except for the header clock) |
| A countdown or chain step ends | Its deadline, plus 150 ms so that `epoch_sec` has advanced |
| An alert attempt or its next frame is due | §10.4 |
| A delivered completion reaches its auto-reset moment | `done + 600` s |
| Keep-awake must be renewed | 120 s before the current keep-awake period ends |
| Running timing needs a checkpoint | 300 s after the last save, only while something runs |

Rules:

- The delay is `max(1, target − now)` in ms, capped at 3,600,000. When nothing runs and no clock is shown, there is **no** pending timer.
- After waking, read the clock again and decide from the sample, never from the reason the timer was set for.
- Pending timers in the whole app: the pulse, the alert sequencer, the deferred backup write and a settle timer. A host test asserts at most 4.

### 6.6 Memory

- Budget: 512 KiB peak script heap, measured on host Lua 5.5/32 with an allocation-sampling hook, and reported from the device by the diagnostics page (`ctx.gc:count()`).
- The whole persistent state is under 12 KiB encoded (§8.2). Copying it per command is acceptable.
- No per-frame table churn in `on_draw` beyond the hit map. Icon polylines are generated constants, shared, never copied.
- Call `ctx.gc:collect()` after leaving a lazily loaded screen group and after an import.

---

## 7. Time model

### 7.1 The clock sample

`platform/clock.lua` returns one read-only sample per event:

```lua
{ valid = true, sec = 1794400000,      -- epoch_sec, or nil
  rev = 1,                             -- clock revision
  hour = 14, minute = 5, second = 7,   -- local wall time, for display only
  hour12 = false, offset = 540,        -- minutes east of UTC
  millis = 123456 }                    -- since boot; for intervals inside one session only
```

All domain arithmetic uses `sec`. `hour`, `minute` and `offset` are for display. `millis` is used only for input debounce, settle windows and alert frame timing.

### 7.2 Anchors (BASELINE rule, new unit)

| Item state | Stored | Computed |
| --- | --- | --- |
| Countdown Ready | `val = dur` | remaining = `dur` |
| Countdown Running | `anc` = deadline (`epoch_sec`) | remaining = `max(0, anc − now)` |
| Countdown Paused | `val` = frozen remaining, > 0 | remaining = `val` |
| Countdown Finished | `done` = logical deadline | remaining = 0 |
| Stopwatch Ready | `val = 0` | elapsed = 0 |
| Stopwatch Running | `val` = earlier segments, `anc` = segment start | elapsed = `min(MAX, val + max(0, now − anc))` |
| Stopwatch Paused | `val` = total | elapsed = `val` |

A countdown is finished when `now ≥ anc`. Because the pulse wakes 150 ms after the deadline second begins, completion is shown within about one second of the true moment.

### 7.3 Clock policy (BASELINE, [P] PRD §12)

1. **Time away and forward clock changes count as elapsed.** They cannot be told apart.
2. **Detected rollback.** `trusted` is the last sample the app accepted. If `now < trusted`: evaluate every running item at `trusted`, keep those values, and re-anchor (`anc = now + remaining` for countdowns; fold the segment into `val` and set `anc = now` for stopwatches). Running chains rebase the same way. Then set `trusted = now`, save, and show once: `Clock changed. Timers restored from last saved time.`
3. `trusted` is updated in memory on every sample and written with every save, with the 300 s checkpoint, and by the automatic save at session end. After a crash it can be up to 300 s old; rollback recovery is bounded by that.
4. A change of time zone or of the 12/24-hour setting changes `revision` but not `epoch_sec`. Timing does not change; displayed clock times do.
5. A clock change that still leaves `now ≥ trusted` is treated as elapsed time. The app does not claim otherwise. Help says so in one sentence.

### 7.4 Whole seconds and their error (D04)

- `epoch_sec` is a floor. A duration measured between two samples is wrong by less than one second in either direction, with no bias. A pause/resume cycle therefore moves a countdown or stopwatch by less than ±1 s; many cycles do not drift one way.
- Displayed remaining seconds are exact in the same sense. The app never shows fractions.
- Host tests assert the bound (|error| < 1 s per sampled operation), not zero drift. This replaces Pebble test T13.
- Sub-second anchoring through `millis()` is DEFERRED.

### 7.5 Limits

| Case | Rule |
| --- | --- |
| Deadline beyond int32 | Before Start or Resume: if `remaining > 2147483647 − now`, refuse with result `OVERFLOW` and the message `This timer would end after the device clock's limit (January 2038).` No wrap is possible in any path: every addition of a time and a duration goes through one checked helper |
| `epoch_sec` nil (clock not set, or after 2038-01-19) | The app opens. Ready and Paused items show their values and can be edited and deleted. Running items show `--:--`. Start, Resume, chain Start and import are refused with `Set the device clock to use timers.` A top strip says `CLOCK NOT SET`. No reconcile, no change to `trusted` |
| Stopwatch at 86,399,999 s | It becomes Paused with `lim = 1` and the caption `LIMIT REACHED`. No alert |
| Duration of zero | Refused: `Set at least 1 second` |
| Float contamination | Domain values are integers. Use `//` for division. A host test checks `math.type(x) == "integer"` for every stored number |

### 7.6 Formats (BASELINE, [P] PRD §8, adapted by §11)

Countdowns round up to the shown unit; stopwatches round down. A finished countdown shows `00:00`, never a negative value.

| Granularity | Value | Detail screen | Deck row and lists |
| --- | --- | --- | --- |
| Seconds | under 1 hour | `MM:SS` | `MM:SS` |
| Seconds | 1 hour to under 1 day | `H:MM:SS` | `Hh MMm` |
| Seconds | 1 day or more | `DDDd` above `HH:MM:SS` | `DDDd HHh` |
| Minutes | under 1 hour | `MM` with the caption `MIN` | `MM min` (`<1 min` only in mode Never) |
| Minutes | 1 hour to under 1 day | `H:MM` with captions `H` and `MIN` | `Hh MMm` |
| Minutes | 1 day or more | `DDDd` above `HH:MM` | `DDDd HHh` |

- The detail screen always draws unit captions under the digits, so `12` minutes and `0:12` can never be confused.
- A stopwatch value on the deck has a leading `+`.
- Configured duration, in the context line and in forms: the shortest exact form, for example `10s`, `4:00`, `1:30:00`, `2d 03:00:00`.
- Clock times (`ends 14:32`, `Finished 2:32 PM`) follow `hour12`. A time on another day adds the date in the user's `date_order` and `date_sep`.
- Tests cover the boundaries 59:59, 1:00:00, 23:59:59, 1d 00:00:00 and 999d 23:59:59.

---

## 8. Data model and persistence

### 8.1 State (schema 1)

`ctx.state` is this table. Keys are short because the encoded size is limited; `docs/storage-format.md` documents each one.

```lua
ctx.state = {
  v = 1,                 -- schema version
  rev = 42,              -- increments with every committed mutation
  next_id = 17,          -- monotonic item id allocator; never reused
  sel = 12,              -- last selected item id, 0 for none
  trusted = 1794400000,  -- last accepted epoch_sec, 0 if never valid
  set = {                -- settings
    app = 0,             -- appearance: 0 Auto, 1 Light, 2 Dark
    style = 0,           -- 0 Ion, 1 Cobalt, 2 Plasma, 3 Solar
    pat = 2, cnt = 3,    -- default alert pattern 0..3 and count 1..5
    flash = 1, light = 1,-- alert channels
    secs = 0,            -- seconds: 0 Smart, 1 Always, 2 Never
    awake = 1,           -- stay awake while timers run
  },
  items = {              -- array, at most 10, in creation order
    { id = 12, gen = 3, num = 2, type = 0, st = 1, name = "Tea", icon = 1,
      pat = 2, cnt = 3,  -- configured alert
      rpat = 2, rcnt = 3,-- alert frozen for the current run
      att = 0, sil = 0, late = 0, lim = 0,
      dur = 240, val = 0, anc = 1794400240, done = 0 },
  },
  rc = {},               -- import receipts, newest first, at most 4: { dig, len, n }
  ch = {                 -- Timer Chains (§16)
    last = 0, saved = {}, run = { st = 0 },
  },
}
```

| Field | Values |
| --- | --- |
| `type` | 0 countdown, 1 stopwatch |
| `st` | 0 Ready, 1 Running, 2 Paused, 3 Finished (countdown only) |
| `num` | Display number 1–10; the smallest unused number at creation; never renumbered |
| `gen` | Run generation. Increases on Start from Ready, on Reset, and on auto-reset or queue dismissal. A pause/resume keeps it |
| `att` | Alert attempts consumed for the current completion |
| `sil` | 1 when the user silenced this completion |
| `late` | 1 when the completion was discovered more than 60 s after its deadline |
| `lim` | 1 when a stopwatch stopped at the maximum |
| `icon` | 0 None, 1–30 |

Fields that do not apply to a state hold their canonical value (0). A Ready record with a stale `anc` is invalid.

### 8.2 Limits of the container

- Encoded size: the fullest legal state (10 items with 16-character names, 5 chains of 10 steps, an active run with a 10-step snapshot, 4 receipts) MUST encode to at most **12,288 bytes**, leaving 25% of the 16,384-byte limit. A host test builds that state and measures it with the double's JSON encoder.
- Depth: `ch.saved[i].steps[j]` and `ch.run.snap.steps[j]` are five table levels under `ctx.state`. Do not add a level (the limit is six).
- Only integers, strings and tables are stored. No floats, no booleans (use 0/1), no string keys that look like integers.
- Arrays are dense (`1..#t`). Deleting an item uses `table.remove`.

### 8.3 Validation

`Model.valid(state)` returns true or `false, reason`. It checks, at least: `v`; types and ranges of every field; item count ≤ 10; unique ids below `next_id`; unique display numbers; state legal for the type; the anchor invariants of §7.2; `dur` within 1..86,399,999 for countdowns and 0 for stopwatches; names per §9.2; `att ≤ rcnt`; chain rules of §16.2; receipts shape. It never repairs. It runs on load, on every candidate before commit (in host tests always; on the device always for load and import, and behind a debug flag for ordinary commands if V10 shows a cost problem).

### 8.4 Loading

On session start the host has already filled `ctx.state` [O §28].

| What is found | Action |
| --- | --- |
| Empty table, no `deck.bak` | First run: initialise schema 1 with defaults, empty deck |
| Empty table, valid `deck.bak` | The save was lost or damaged. Restore the backup, reconcile, and show `Saved data was restored from a backup.` The time away counts as elapsed, as always |
| Empty table, invalid `deck.bak` | Show the recovery screen (§14.11). Do not initialise until the user chooses **Start fresh** |
| `v == 1`, valid | Use it |
| `v == 1`, invalid, valid `deck.bak` | Restore the backup with the same message |
| `v == 1`, invalid, no valid backup | Recovery screen. Do not overwrite |
| `v > 1` | Read-only block: `Saved data needs a newer Timer Deck version.` Never assign or change `ctx.state`, so the host writes nothing. Offer only Help / About |
| `v < 1` or other keys only (a foreign or legacy table) | Treat as invalid |

Migration rule for later schemas: convert in memory, validate, commit, and only then replace the backup.

### 8.5 Saving

- **When:** after every committed mutation: create, start, pause, resume, reset, delete, edit, rename, icon, settings, selection saved on opening an item or leaving the deck, silence, each alert attempt, dismissal, auto-reset, expiry, clock rebase, chain commands, import. Also the 300 s checkpoint while something runs. Never from `on_draw`, never per tick.
- **How:** `ctx.state = candidate; local ok, err = ctx:save_state()`.
- **User mutation fails to save:** restore the previous table, keep the previous screen, and show `Could not save. Try again.` Nothing claims success. Other running items keep their anchors, so their time is not rewound.
- **Time-driven change fails to save** (expiry, chain boundary, auto-reset): keep the truthful state in memory and in `ctx.state`, show the strip `NOT SAVED - RETRYING`, hold back new alert attempts that could not be recorded, and retry on each later pulse and at session end (the automatic save).
- `limit_exceeded` cannot occur for a valid state (§8.2). If it does, treat it as a failed save and log `E-STATE-SIZE`.

### 8.6 The backup file `deck.bak` (D15)

- Content: the text `TDB1`, a newline, the decimal CRC-32 of the JSON text, a newline, then the JSON encoding of the state (`ctx.json:encode`).
- Written with `ctx.storage:write` (atomic) by a deferred callback: 2 s after the last committed mutation, coalesced, and in `on_leave` if one is pending. Checkpoint-only saves do not rewrite it.
- Valid when the header matches, the CRC matches and `Model.valid` accepts the decoded table with `v == 1`.
- A failed backup write is logged (`E-BACKUP`) and retried with the next mutation. It never blocks the user.
- **Reset saved data** (§14.10) removes the file and clears the state in one user-confirmed action.

### 8.7 What is never stored

Derived values: coverage, the pulse plan, formatted text, screen stack, drafts, alert frame position. A session always opens on the deck or the completion queue.

---

## 9. Items: rules carried from Pebble

### 9.1 Identity and capacity

- At most ten items, countdowns and stopwatches combined. Ready, Paused and Finished items occupy slots.
- Each item has an internal `id` from a monotonic allocator and a display number 01–10 (smallest free number). Deleting never renumbers the others.
- Creation is transactional: no slot is used until the save succeeds. At capacity: `10 items saved. Delete one to add another.`
- Order is creation order. Nothing re-sorts while timers run.

### 9.2 Names and labels

- A name is optional: 0–16 characters, printable ASCII without `|`, trimmed, inner runs of spaces collapsed to one. Anything else is rejected with `Names use up to 16 basic Latin characters.`
- Label shown for an item: its name; else its icon's name; else `TIMER NN` or `WATCH NN`.
- Duplicate names are allowed. The detail screen always shows `#NN`.
- Long labels are ellipsised in lists. The edit form shows the full name.

### 9.3 Countdown state machine

| State | Event | Next | Effects |
| --- | --- | --- | --- |
| Ready | Start | Running | `gen + 1`; `anc = now + dur`; freeze `rpat`, `rcnt`; clear `att`, `sil`, `late` |
| Running | Pause | Paused | `val = anc − now` (> 0); `anc = 0` |
| Paused | Resume | Running | `anc = now + val`; same generation |
| Running | `now ≥ anc` | Finished | `done = anc`; `anc = 0`; `late = (now − done > 60)`; joins the completion queue |
| Finished | Dismiss (primary) | Ready | `val = dur`; completion cleared; no restart |
| Any | Reset | Ready | `gen + 1`; `val = dur`; completion and alert work cleared |
| Any | Delete | removed | Its alert work is cancelled |
| Ready | Edit duration | Ready | New `dur`, `val = dur` |

Expiry is reconciled **before** any command. A Pause that arrives at or after the deadline acts on a Finished item (so it dismisses); it never creates a paused timer with zero left.

### 9.4 Stopwatch state machine

| State | Event | Next | Effects |
| --- | --- | --- | --- |
| Ready | Start | Running | `gen + 1`; `val = 0`; `anc = now` |
| Running | Pause | Paused | `val = val + (now − anc)`; `anc = 0` |
| Paused | Resume | Running | `anc = now` |
| Running | limit reached | Paused | `val = 86399999`; `lim = 1` |
| Any | Reset | Ready | `gen + 1`; `val = 0`; `lim = 0` |

A stopwatch never finishes, never alerts and never keeps the device awake.

### 9.5 Commands

Every command names its target by `(id, gen)` captured when the control was drawn. A mismatch returns `STALE` and changes nothing.

| Command | Allowed when | Notes |
| --- | --- | --- |
| `CREATE` | fewer than 10 items | Ready item with name, icon, duration, alert. Stopwatch: name and icon only |
| `CREATE_START` | fewer than 10 items, valid clock | Create and start a countdown in one saved mutation |
| `PRIMARY` | any | Start / Pause / Resume / Dismiss by state |
| `RESET` | any | Immediate, no confirmation |
| `DELETE` | any | Immediate once requested (§14.1 for the deck gesture) |
| `EDIT` | Ready or Paused | Duration only while Ready; alert pattern and count while Ready or Paused; name and icon always. A changed alert applies from the next Start or Resume |
| `RENAME`, `ICON` | any state | Change nothing else: not the timing, not the generation |
| `SETTINGS` | any | Partial update by mask; never touches items |
| `SELECT` | any | Remember the selected item |
| `ATTEMPT` | Finished, eligible (§10.4) | `att + 1`, saved before the attempt is shown |
| `SILENCE` | completion queue | `sil = 1` on every item in the shown queue |
| `DISMISS` | completion queue | Every item in the shown queue → Ready with `gen + 1`, in one saved mutation |
| `ERASE` | after confirmation | Empty deck, default settings, no chains, no receipts |
| `IMPORT` | valid clock not required | Batch create with a receipt (§17) |
| `CHAIN_*` | §16 | — |

Results: `OK`, `INVALID`, `FULL`, `STALE`, `OVERFLOW`, `CLOCK`, `DUPLICATE`. An invalid command leaves the state untouched. A command that already reached its target state is a harmless no-op.

### 9.6 Invariants (host-tested after every command in the suites)

Item count 0–10; unique ids and numbers; a Ready countdown has `val = dur`; a Paused countdown has `val > 0`; only Running items have `anc ≠ 0`; a Finished countdown has `done ≠ 0`; alert commands never change another item's timing; a renderer never changes state.

### 9.7 Completion queue

- A completion is `(id, gen)`. The queue lists Finished countdowns ordered by `done`, then `id`.
- A reconcile that finds several expired timers records all of them before anything is shown.
- The queue screen opens automatically for a Finished, unsilenced completion the session has not shown yet. It interrupts any screen. A draft form underneath is preserved and restored afterwards.
- Dismiss clears only the shown completion. **Back or Clear all** clears every completion in the shown queue (Pebble 0.7.0 F1). If more remain, the next is shown; otherwise the app returns to where it was.
- Header: `1 OF 3 DONE`; one late completion: `FINISHED AWAY`; several late: `AWAY 1 OF 2`.
- The screen shows the logical finish time, not the discovery time.

### 9.8 Finished timers clear themselves (BASELINE, [P] PRD §49)

- A Finished countdown returns to Ready by itself **600 s after `done`** if it was silenced, or if it is not late and at least one alert attempt was recorded.
- A late, unsilenced or never-alerted completion stays Finished until the user acts. Seeing it is not acknowledging it.
- Auto-reset increments the generation, like Reset. If the generation is at its maximum, auto-reset is skipped and Back only silences.
- It is applied by reconcile on load, on every pulse and before every command. The pulse arms one wake for the earliest such moment.

### 9.9 Constants (single source: `lib/core/const.lua`)

| Constant | Value |
| --- | --- |
| `CAPACITY` | 10 |
| `MAX_SEC` | 86,399,999 |
| `DEFAULT_COUNTDOWN` | 10 |
| `NAME_MAX` | 16 |
| `ICON_COUNT` | 30 |
| `PATTERNS` | Short, Long, Short + short, Short + long (0–3); default 2 |
| `COUNT` | 1–5; default 3 |
| `LATE_SEC` | 60 |
| `AUTO_RESET_SEC` | 600 |
| `CHECKPOINT_SEC` | 300 |
| `AWAKE_HORIZON_SEC` | 14,400 |
| `KEY_DEBOUNCE_MS` | 250 |
| `SETTLE_MS` | 400 |
| `ATTEMPT_INTERVAL_MS` | 2,000 |
| `CHAIN_CAPACITY`, `CHAIN_STEPS`, `CHAIN_ROUNDS`, `RECEIPTS` | 5, 10, 9, 4 |


---

## 10. Alerts on a silent device

### 10.1 What an alert is here

The device cannot buzz or beep. An alert is therefore something the user **sees**:

1. **Screen flash**: the current screen is drawn inverted for one frame, then normally. On e-ink this is a strong whole-screen change.
2. **Light pulse**: the front light blinks in the pattern's rhythm. This is the only cue that reaches peripheral vision, and the only one that works in a dark room.
3. **The completion page**: `FINISHED`, the item and its finish time stay on screen until dismissed. E-ink holds the image without power.

Help, the first-run empty deck and the Store-style description all carry this sentence: **"This device has no sound or vibration. Timer Deck alerts you with a screen flash and a light pulse, so keep it where you can see it."**

### 10.2 Channels and settings

| Setting | Values | Default | Notes |
| --- | --- | --- | --- |
| Screen flash | On / Off | On | Global |
| Light pulse | On / Off | On | Shown only when `ctx.frontlight` exists |
| Default alert | Short, Long, Short + short, Short + long | Short + short | Applies to new countdowns only |
| Default count | 1–5 | 3 | Total attempts, not extra repeats |
| Per item | Pattern and count | From the defaults at creation | Edited in the item's form. Frozen at Start and Resume for that run |

With both channels off, the completion page still appears and still counts as an attempt.

### 10.3 Patterns (DRAFT DEFAULT; V03 tunes the numbers)

The names and indices are Pebble's. The numbers are light-on / gap / light-on durations in milliseconds, longer than the Pebble vibration timings because a light blink needs more time to be noticed.

| Index | Name | Light sequence (ms) |
| --- | --- | --- |
| 0 | Short | `[300]` |
| 1 | Long | `[900]` |
| 2 | Short + short | `[300, 200, 300]` |
| 3 | Short + long | `[300, 200, 900]` |

- "Light on" means the opposite of the user's current light, so it is visible either way: read `ctx.frontlight:get()` once at session start, before the app sets anything. If the light is on at brightness 70 or more, a pulse turns it **off**; otherwise a pulse sets `{ on = true, brightness = 100 }`. Each gap and the end of the sequence call `ctx.frontlight:reset()`, which returns the user's own setting [O §24].
- The app never changes warmth and never leaves the light changed: `on_pause`, `on_leave`, any input during an alert, and every error path call `reset()`.
- One **attempt** = the light sequence, started together with one screen flash (inverted frame, then the normal frame 700 ms later [O §5: keep a state visible for at least one frame]).

### 10.4 The alert queue (BASELINE rules, [P] PRD §13)

- One dispatcher for the whole app. Two attempts never overlap.
- A completion is **eligible** while it is Finished, not silenced, not late, `att < rcnt`, and `now − done ≤ 60` s.
- Attempts start 2,000 ms apart, start to start (`ATTEMPT_INTERVAL_MS`). Count 5 therefore lasts about 10 seconds.
- Fairness: every eligible completion gets its first attempt before any gets a second. Order by `done`, then `id`. Then round-robin.
- **Record, then show**: the `ATTEMPT` command increments `att` and is saved before the flash and pulse start. A crash between the two can consume an unseen attempt; it can never replay a finished sequence. If the save fails, no attempt is shown and the `NOT SAVED - RETRYING` strip appears.
- The first attempt of a session starts no earlier than 1,000 ms after the first frame was requested, so the page is visible first.
- A completion older than 60 s when discovered is **late**: no attempts, header `FINISHED AWAY`, and it stays until the user acts (§9.8).
- A new run of the same item is a new generation and alerts again.
- Any touch or key during an attempt stops the light at once, restores the normal frame, and is otherwise **consumed**: it does not also press a button. The remaining attempts of the shown queue are cancelled by `SILENCE`.

### 10.5 Alerts for chains

A chain step that begins while the app is open gets **one** attempt with the destination step's pattern and a banner `Starting now: <step>`. The end of the chain uses the default pattern and count captured when the chain started. Boundaries older than 60 s get no attempt (§16.5). Chain cues and timer completions share the same queue and fairness rule.

### 10.6 Will I be alerted? Coverage (replaces Pebble wakeup coverage)

The app can alert only while its session is alive, or through the lock-screen page. It reports which applies. Coverage is **derived on every plan and never stored**.

| Coverage | Condition | Shown on the detail screen |
| --- | --- | --- |
| **Awake** | Stay awake is On, `ctx.device.keep_awake` exists, and the countdown ends within 4 hours | `Alert: screen stays on` |
| **Lock screen** | Timer Deck is the lock screen (`ctx.lockscreen:is_default()`) and `ctx.device.lock_timer` is true | `Alert: lock screen` |
| **Open only** | Neither | `Alert: only while open` |

Rules:

- **Keep awake.** While Stay awake is On and any of these holds, the controller calls `ctx.device:keep_awake(ms)` on every pulse with `ms = min(14400000, (seconds until the next planned wake + 120) × 1000)`: a Running countdown that ends within `AWAKE_HORIZON_SEC`; a Running chain whose remaining total is within it; pending alert attempts; a Finished, unsilenced completion younger than 600 s. When none holds any more, call `keep_awake(0)` once. Stopwatches and paused items never hold the device awake.
- **Deck strip.** While any Running countdown or chain has coverage Open only, the deck shows a 40 px strip above the bottom bar: `ALERTS ONLY WHILE TIMER DECK IS OPEN`. Tapping it opens a short explanation with two buttons: **Turn on Stay awake** and **Use lock screen** (each shown only when available).
- **Leaving.** Back on the deck normally returns `false`, and the system asks for confirmation [O §4]. When something is Running with no Lock screen coverage and `ctx.dialog` exists, the app asks instead: title `Leave Timer Deck?`, message `Timers keep counting. You will not be alerted until you open Timer Deck again.`, buttons `Leave` / `Stay`. `Leave` calls `ctx:quit()`.
- **Returning.** On every load the app reconciles first. Completions younger than 60 s alert normally; older ones are late. If V06 confirms that the device reopens the front app after a lock, a user who locks with Timer Deck open returns straight to the completion queue.
- The power key, a Home long press and a battery below 5% end the session regardless of keep-awake [O §13]. The app does not claim otherwise.
- Help states the battery cost: `Stay awake keeps the reader on while a timer runs. This uses more battery.`

---

## 11. Display cadence and refresh policy

### 11.1 When seconds are shown (D08)

Each visible running value has a granularity, **seconds** or **minutes**, chosen by the Seconds setting. The pulse wakes only as often as the finest visible granularity needs.

| Setting | Detail and chain-run screens | Deck and list rows |
| --- | --- | --- |
| **Smart** (default) | Seconds while a countdown has 10:00 or less left, or a stopwatch has run less than 10:00. Otherwise minutes | Seconds for a countdown with 60 s or less left. Otherwise minutes. Stopwatches: minutes |
| **Always** | Seconds | Seconds |
| **Never** | Minutes | Minutes |

- In minute granularity a countdown wakes when its rounded-up minute changes, a stopwatch when its minute changes. Formats are in §7.6.
- Whatever the setting, the pulse arms a wake for every deadline, so completion never waits for the next minute.
- **Peek:** tapping the large digits on a detail screen that shows minutes shows the exact `H:MM:SS` once, with the caption `at 14:17:11 · tap to refresh`, until the next cadence change. It costs one frame and no extra wakes.
- Ready, Paused and Finished values never cause wakes.
- The header clock (`14:05`) wakes once per wall-clock minute while a screen that shows it is open.

### 11.2 Why not tick every second by default

A frame costs about 650 ms of refresh [O §5], flickers the whole panel, adds ghosting and uses power. A four-minute tea timer deserves seconds; a three-hour roast does not. V04 measures the battery cost of each mode and the result goes into Help.

### 11.3 Refresh waves

The app counts its own partial frames since the last full refresh (`partials`).

| Rule | Wave |
| --- | --- |
| R1. First frame of a session; appearance or style change; opening or leaving the completion queue | `invalidate("full")` |
| R2. Any other screen change | Partial; but full when `partials ≥ 12` |
| R3. Value updates on the same screen (ticks) | Partial, and call `ctx:defer_full_refresh(5000)` so the system's automatic full refresh never interrupts a countdown |
| R4. While ticking seconds, every 120th consecutive tick frame | Full, to clear ghosting at a predictable moment |
| R5. The inverted frame of an alert flash and the frame after it | Partial then full |
| R6. Lock-screen page | Host default: full on `first`, partial on `timer`; the `TIME'S UP` page requests full |

V07 tunes the numbers 12 and 120 from the owner's judgement of ghosting.

### 11.4 Dark mode

`ctx.device:display().dark` is read in every `on_draw`. The theme computes one boolean, `flip` (§13.2), and every colour goes through two tokens, `ink` and `paper`. Nothing else in the app knows about dark mode.

---

## 12. Input

### 12.1 Touch

- Every interactive element registers a hit rectangle while it is drawn: `{ x, y, w, h, action, target_id, target_gen, arg }`. Input is resolved against the hit map of the last drawn frame. Hit rectangles never overlap and are never off screen (a host audit checks every frame).
- Sizes: primary actions at least 88 px tall; list rows at least 63 px; any other target at least 56 × 56 px. Text is at least 22 px.
- Gestures used: `tap`; `long` (acted on at the `hold` phase, for immediate feedback); `swipe_left` / `swipe_right`; `swipe_up` / `swipe_down` for paged lists. A `double_tap` is treated as a tap.
- **Settle window:** a new frame becomes visible about 650 ms after it is requested. A pointer `down` that arrives within `SETTLE_MS` (400 ms) of a screen change is ignored together with its `up`, because the user was aiming at the previous screen. V12 tunes this.
- **Stale target:** if the target's `(id, gen)` no longer matches, the command returns `STALE` and the screen simply redraws.
- A pointer `cancel` discards the press.

### 12.2 Back

Handled on the `up` phase only [O §4]. Every screen except the deck also draws a **Back** button at `(0, 0, 120, 80)`, because the user may have remapped the Home pad.

| Screen | Back does |
| --- | --- |
| Deck | Exit path of §10.6 |
| Completion queue | Clear all shown completions (§9.7) |
| A form with changes | `Discard changes?` (confirm → discard) |
| Preview pickers (appearance, style) | Restore the saved choice |
| Anything else | One screen back |

### 12.3 Keys (D14): Down moves, Up acts

A key press is handled on `up`; the same key within 250 ms is ignored (`KEY_DEBOUNCE_MS`). With a Bluetooth page turner, the two buttons are a remote control.

| Screen | Down | Up |
| --- | --- | --- |
| Deck | Move the highlight to the next row (wraps; the first press highlights the selected item) | Start / pause / resume the highlighted item; open the queue if it is Finished |
| Detail | Show the next item's detail (wraps) | Primary action |
| Completion queue | Show the next completion | Dismiss the shown completion |
| Chain run | Open View steps | Pause / resume |
| Lists, menus, pickers | Highlight the next row (wraps; paged lists turn the page) | Activate the highlighted row |
| Keypad, forms | Highlight the next control | Activate it |

Wrapping never activates anything by itself. The highlight is a 4 px outline; it appears only after a key is used and disappears on the next touch.

### 12.4 System overlays

`ctx.input:text` and `ctx.dialog:*` cover the app: `on_pause` runs, timers wait, and `on_resume` runs before their completion function [O §2]. The controller therefore reconciles in `on_resume`. A completion that became due under an overlay is shown right after it closes. Only one overlay can be open; a second request returns `busy` and is dropped with a log line.

---

## 13. Visual design

### 13.1 Direction

Orbital, as on Pebble: a thick ring around large, stable numerals; plain rows; one strong primary button. On this panel it is drawn in pure black and white with generous size. No decoration that does not carry state: no fake meters, no grids, no pattern fills behind text.

### 13.2 Tokens and appearance

Two tokens only: `paper` and `ink` (colours 0 and 15). `flip` swaps them.

| Appearance setting | System dark off | System dark on |
| --- | --- | --- |
| Auto (default) | `flip = false` → light | `flip = false` → the host inverts → dark |
| Light | `flip = false` | `flip = true` → the host inverts back → light |
| Dark | `flip = true` → dark | `flip = false` → the host inverts → dark |

The alert flash is one frame drawn with `flip` negated. Dark means large black areas; V07 checks ghosting and may restrict it.

### 13.3 Styles (the four palettes, in monochrome; DRAFT DEFAULT)

A style changes the ring, the progress bar and the primary button. Everything else is shared. Ion ships in the first release; the other three in M7. The agent has latitude in the exact drawing as long as the four are clearly different in the previews and every state stays readable.

| Style | Remaining arc | Track | Progress bar | Primary button |
| --- | --- | --- | --- | --- |
| **Ion** | Solid, 24 px | 2 px circle | Solid | Filled ink, paper label |
| **Cobalt** | 60 radial ticks, 4° each; elapsed ticks shrink to short marks | None | Blocks | 4 px outline, ink label |
| **Plasma** | Solid 12 px arc with a 4 px echo arc inside it | 2 px circle | Double line | Filled, pill-shaped |
| **Solar** | Solid 24 px arc with twelve 2° notches at the hour marks | Short ticks | Solid with an end marker | Filled ink, square corners |

### 13.4 Type and numerals

- Label fonts: `ctx.fonts:size(22 | 26 | 32 | 40)`, opened on first use and cached. **No fifth TTF size** (D10). When `font.px` is nil the system font came back; all layout uses `font.line_height` and `font:measure`, never the requested px.
- Roles: 22 captions and strips; 26 context lines, secondary values, small buttons; 32 row names, titles, buttons; 40 deck values and headings. Bold only at 22 px or more. Changing numbers use `tabular = true`.
- **Orbit digits** (D09): large numerals are seven-segment figures built from rounded `g:rect` calls. For height `h`: digit width `55h/100`, gap `14h/100`, colon cell `22h/100`, stroke `max(4, 11h/100)`, corner radius half the stroke. These proportions come from the community Timekeeper lock screen [C]. They need no font, are tabular by construction, cost at most 7 commands per digit, and look the same in the lock-screen session.
- Digit heights: 96 (`MM:SS`, `MM`), 64 (`H:MM:SS`), 56 (time under a days line; keypad display), 160 (lock-screen minutes).

### 13.5 The ring

- Centre `(240, 296)`, outer radius 200, thickness 24. `MM:SS` at height 96 is about 281 px wide and fits the inner chord (338 px at ±48 px from the centre).
- Remaining angle: `deg = ratio(remaining, dur, 360)`, at least 1 while any time remains. `ratio(n, d, scale)` MUST avoid 32-bit overflow: shift `n` and `d` right together until `d ≤ 1,048,576`, then compute `n * scale // d`. (86,399,999 × 360 does not fit in 32 bits.) The same helper sizes progress bars.
- The ring drains clockwise like a clock hand [P §41]: draw `g:arc(cx, cy, r, 630 − deg, 630, { line_width = 24 })`, with 270° being 12 o'clock. A full ring is a `g:circle` stroke, because an arc of exactly 360° draws nothing [O §6].

| State | Ring | State text |
| --- | --- | --- |
| Ready | Full, solid | `READY` |
| Running | Remaining arc, solid | `RUNNING` |
| Running, 25% or less left | Same, plus a filled bead (radius 16) on the moving end | `RUNNING · LAST 25%` |
| Running, 10% or less left | Same | `LAST 10%` as an inverted chip |
| Paused | Remaining arc as two thin outlines (hollow) | `PAUSED` |
| Finished | Two thin full circles | `FINISHED` or `FINISHED AWAY` |
| Stopwatch | Thin circle with twelve ticks; never a progress arc | `COUNT UP` plus the state |

### 13.6 Icons

- The 30 icons and their indices are Pebble's [P `scripts/icons.py`]. Index 0 is None.

| # | Name | Lucide file | # | Name | Lucide file | # | Name | Lucide file |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Coffee | coffee | 11 | Medicine | pill | 21 | Bus | bus |
| 2 | Cooking | cooking-pot | 12 | Reminder | bell | 22 | Parking | car |
| 3 | Eggs | egg | 13 | Prayer | flame | 23 | Meeting | users |
| 4 | Baking | croissant | 14 | Thanksgiving | hand-heart | 24 | Music | music |
| 5 | Laundry | washing-machine | 15 | Reading | book-open | 25 | Mass | church |
| 6 | Workout | dumbbell | 16 | Water | glass-water | 26 | Whistle | whistle |
| 7 | Run | footprints | 17 | Meal | utensils | 27 | Added time | clock-plus |
| 8 | Study | graduation-cap | 18 | Plants | sprout | 28 | Alarm plus | alarm-clock-plus |
| 9 | Focus | laptop | 19 | Cleaning | spray-can | 29 | Love | heart |
| 10 | Nap | bed | 20 | Bath | bath | 30 | Sex | venus-and-mars |

- Source: copy the 30 SVG files and `LICENSE` (ISC) from `../pebble-timer-deck/assets/icons/lucide/` into `assets/icons/lucide/`.
- `tools/icons.py` flattens each SVG (paths with lines, curves and arcs; `circle`, `rect`, `line`, `polyline`, `ellipse`) into polylines on a 0–94 integer grid and writes `app/lib/gen/icons.lua`. Each polyline is stored as a **string**, two printable characters per point (`char(32 + v)`), at most 128 points; a longer path is split. Target: at most 12 polylines and 160 points per icon. `icons.py --check` verifies that the generated file matches the sources and runs in the host gate.
- Drawing: decode a string to a point table scaled to the requested size, then `g:polyline(points, { line_width = w })`. Keep at most 12 decoded `(icon, size)` entries; the icon picker draws all 30 without caching. A host test measures the heap peak on the picker.
- Sizes and stroke widths: 44 px / 3 on the deck; 56 px / 4 inside the ring and in the picker; 96 px / 6 on the completion page.
- An item without an icon shows its two-digit number in a rounded 44 px outline.

### 13.7 Shared components

| Component | Geometry and rules |
| --- | --- |
| Top bar | `y 0–80`, 2 px rule at its bottom. Back at `(0, 0, 120, 80)`; title centred in `x 128–352`, 32 px bold, falling back to 26 px, then ellipsis; optional action at `(360, 0, 120, 80)` |
| Bottom bar | `y 712–800`. Equal-width buttons with a 2 px rounded outline |
| List row | Full width; label left at `x 20` (32 px), value right at `x 460` (26 px), chevron when it opens something. Standard height 88 px |
| Paged list | Rows per page = available height `// 63` at most; when rows do not fit, a 40 px strip `More · 1 of 2` and swipe up/down or the Down key turn pages |
| Primary button | 96–112 px tall, style-dependent fill (§13.3), 40 px bold label |
| Strip | 40 px, inverted, 22 px bold capitals, one line. Used only for live warnings |
| Toast | `ctx.dialog:toast` when available, else a strip for 2 s |
| Pressed feedback | None. A frame takes 650 ms; the result of the action is the feedback |

---

## 14. Screens

Coordinates are for 480 × 800. All of them are starting geometry: keep the hierarchy and the minimum sizes, and adjust from previews.

### 14.1 S01 Deck

**Layout.** Top bar: `TIMER DECK` at the left (32 px bold); at the right the count `3/10` and the clock `14:05` (26 px). List area `y 80–710`. Bottom bar: **New timer**, **Chains**, **Menu** (160 px each).

**Rows.** One per item, in creation order. Row height `clamp(area // max(n, 6), 63, 104)`, so six or fewer items get large rows and ten fit on one page (63 px). If the area cannot hold every row at 63 px (ten items plus a strip or the chain row), the list pages (§13.7).

| Part | Geometry in the row | Content |
| --- | --- | --- |
| Icon slot | `x 12–68` | Icon at 44 px, or the number badge |
| Name | from `x 80` to the value, 32 px bold; 26 px if that avoids an ellipsis | Label (§9.2) |
| Value | right-aligned to `x 392`, 40 px bold tabular | §7.6; `+` prefix for stopwatches; `00:00` when Finished; `--:--` without a clock |
| Toggle | `x 400–472`, full row height | Play (Ready, Paused), pause (Running), check (Finished). One tap = `PRIMARY` |
| Progress bar | `x 80–392`, 4 px high, 6 px above the row's bottom | Running and Paused countdowns only. 8 px high at 25% or less. At 10% or less the value is drawn as an inverted chip |
| State hint | Under the name when the row is 79 px or taller, 22 px | `PAUSED`, `DONE`, `LIMIT REACHED`. Running shows nothing |

**Chain row.** While a chain is Running or Paused, a first row shows the current step like a countdown row: step icon, `Practice 2/3`, remaining time, bar and toggle. A tap opens the run screen.

**Gestures.**

| Gesture | Result |
| --- | --- |
| Tap a row | Open its detail (selection is saved) |
| Tap the toggle | Start / pause / resume; a Finished item opens the queue |
| Long press a row | Same as the toggle |
| Swipe left on a row | The row turns into `Delete "Tea"?` with **Delete** and **Keep** for 5 s. **Delete** runs `DELETE` at once. Any other input restores the row |
| Tap **New timer** | S03 |
| Tap **Chains** | S18 |
| Tap **Menu** | S14 |

**Strips** (above the bottom bar, one at a time, in this priority): `NOT SAVED - RETRYING`; `CLOCK NOT SET`; `ALERTS ONLY WHILE TIMER DECK IS OPEN`.

### 14.2 S02 Empty deck

A small orbit drawing, `No timers yet`, the sentence of §10.1 in 26 px, and a large **New timer** button. The bottom bar is unchanged.

### 14.3 S03 New timer (keypad)

The Pebble flow is kept: **New timer → set the duration → Start timer**.

| Area | Geometry | Content |
| --- | --- | --- |
| Top bar | `0–80` | Back, `New timer` |
| Display | `80–200` | `00h 00m 10s` in Orbit digits (56 px) with unit letters |
| Keypad | `200–568`, 3 columns × 4 rows, cells 160 × 92 | `1`–`9`, `00`, `0`, backspace |
| Start timer | `(16, 580, 448, 96)` | Primary: `CREATE_START`, then the item's detail |
| Save / More options | `(16, 688, 216, 88)` and `(248, 688, 216, 88)` | Save: `CREATE` as Ready, back to the deck with the item selected. More options: S04 with the typed duration |

- The screen opens showing the default 10 s. The first digit replaces it. Digits enter from the right, at most six (`HHMMSS`).
- The total is `H × 3600 + M × 60 + S` even when minutes or seconds exceed 59 (typing `90` gives 1:30). Days are set in More options.
- Zero, a full deck, an unset clock (for Start) and a failed save are refused with the messages of §18 and the typed value is kept.
- Back with a changed value asks `Discard new timer?`.

### 14.4 S10 Countdown detail

| Area | Content |
| --- | --- |
| Top bar | Back; the label; gear (Item actions, S12) |
| Ring `y 96–496` | §13.5. Inside, from the top: icon (56 px) and `#NN`; the digits; unit captions (22 px); the state text (26 px bold) |
| Context `y 512–600`, 26 px, centred | Line 1: `of 4:00`. Line 2 while Running: `ends 14:32`. Line 3 while Running: the coverage line of §10.6 |
| Strip `y 620–660` | Live warnings only |
| Buttons | Primary `(16, 676, 292, 112)`: **Start**, **Pause**, **Resume** or **Dismiss**. **Reset** `(324, 676, 140, 112)`: immediate, no confirmation |

Tap on the digits: Peek (§11.1). Swipe left or right: the next or previous item's detail. A Finished item shows `00:00`, the double ring and **Dismiss**.

### 14.5 S11 Stopwatch detail

Same layout. The ring is the thin stopwatch circle; the state text is `COUNT UP · RUNNING` (or `READY`, `PAUSED`, `LIMIT REACHED`); the context line shows `started 14:02` while Running. No coverage line.

### 14.6 S04 / S05 Forms, S06 Time, S07 Name

**Countdown form** (More options, and Edit for a Ready or Paused countdown). Rows of 88 px: **Time**, **Name**, **Icon**, **Alert**, **Count**. Buttons at the bottom: for a new timer **Start timer** and **Save**; for an edit **Save**.

- **Time** opens S06: a **Days** stepper (0–999, −/+ buttons, hold does not repeat; a `+10` and `−10` pair speeds it up) above the same keypad. **Done** returns to the form.
- For a Paused countdown the Time row is disabled and reads `Reset to edit duration`.
- **Name** opens the system keyboard: `ctx.input:text({ title = "Timer name", text = current, max_bytes = 16 }, fn)`. On return: nil keeps the old name; otherwise normalise and validate (§9.2). An invalid name shows the message and keeps the old one.
- **Alert** opens the pattern list (four rows, each with its rhythm drawn as bars and a **Preview** that pulses the light once). **Count** is a row of five buttons, `1`–`5`.
- Back with changes asks `Discard changes?`. A completion that interrupts the form does not lose the draft.

**Stopwatch form.** Rows **Name** and **Icon**; button **Save**. No alert rows.

**Edit while Running or Finished.** Item actions → Edit opens a two-row list, **Name** and **Icon**. Each change is applied and saved at once and never touches the timing or the generation.

### 14.7 S08 Icon picker

A grid of 5 columns × 7 rows of 96 × 88 px cells under the top bar (`y 80–696`): None first, then icons 1–30. The current icon has a 4 px outline. The caption area (`y 696–800`) shows the highlighted icon's name. A tap selects and returns.

### 14.8 S13 Completion queue

| Area | Content |
| --- | --- |
| Header `0–80` | `1 OF 3 DONE`, `FINISHED AWAY`, or `AWAY 1 OF 2` (32 px bold, inverted band) |
| Body | Icon at 96 px; the label at 40 px bold; `00:00` in Orbit digits (96 px); `FINISHED`; `Finished 14:32` (with the date when it was another day) |
| Browse | `‹` at `(16, 560, 120, 88)` and `›` at `(344, 560, 120, 88)`, only with more than one completion. Swipes do the same |
| Buttons | One completion: **Dismiss** `(16, 676, 448, 112)`. Several: **Dismiss** `(16, 676, 292, 112)` and **Clear all** `(324, 676, 140, 112)` |

Dismiss clears the shown completion and shows the next, or returns. Clear all and Back clear the shown queue. Behaviour during attempts is in §10.4.

### 14.9 S12 Item actions

A list under the top bar: **Edit**, **Delete**. Delete acts at once and returns to the deck. (Pebble's **Retry alert** row has no equivalent: nothing is scheduled with the system.)

### 14.10 S14 Menu, S15 Settings, S16 Help / About

**Menu.** **New stopwatch** (S05), **Settings**, **Help / About**.

**Settings** (paged list of 88 px rows; the value is shown at the right):

| Row | Values | Acts |
| --- | --- | --- |
| Appearance | Auto, Light, Dark | Picker with preview: a tap shows the choice; **Use this** saves; Back restores |
| Style | Ion, Cobalt, Plasma, Solar | Same, with a sample ring |
| Default alert | Four patterns | New countdowns only |
| Default count | 1–5 | New countdowns only |
| Screen flash | On, Off | Toggles on tap |
| Light pulse | On, Off | Hidden without `ctx.frontlight` |
| Seconds | Smart, Always, Never | §11.1 |
| Stay awake | On, Off | §10.6. Subtitle: `Uses more battery` |
| Lock screen | On, Off | Hidden without `ctx.lockscreen`. On calls `set_default()` (system dialog); Off calls `clear_default()`. The shown value is always `is_default()`, read again in `on_resume` |
| Import and export | — | S24 |
| Reset saved data | — | Confirm `Reset saved data? All Timer Deck items and settings will be removed.` then `ERASE`, remove `deck.bak`, cancel keep-awake |

A setting change never starts, pauses, resets or dismisses anything.

**Help / About.** `Timer Deck <version>`, then the text of §18.2 as paged text (`font:layout` gives the page breaks; never pass a negative height). Seven taps on the title open **Device information**: model, firmware, API major.minor, each capability, `lock_timer`, keep-awake available, front light present, heap bytes, encoded state bytes, pending timers, partial-frame counter, last error code. This page is how the owner reports V01–V14.

### 14.11 S17 Messages, recovery, blocked, fatal

| Screen | Content | Controls |
| --- | --- | --- |
| Message | Title, wrapped text | **OK**, Back |
| Recovery | `Saved data could not be read.` and what each button does | **Try again** (reload), **Start fresh** (confirm, then initialise). Nothing is overwritten before the user chooses |
| Blocked | `Saved data needs a newer Timer Deck version.` | **Help / About** only |
| Fatal | `Something went wrong` and the code `E-…` | **Try again** (rebuild the deck screen). Back still exits |

### 14.12 Timer Chains screens (S18–S23) and S24

Specified with their behaviour in §16.6 and §17.4.

---

## 15. Lock-screen page (replaces App Glance)

### 15.1 Role

When the user makes Timer Deck the lock screen, the device wakes on a timer while locked, runs `lock.lua` for one frame, and sleeps again [O §15]. This is the only way the app shows anything after its session ended. It is opt-in (D07), read-only and silent.

### 15.2 Constraints

- `lock.lua` defines `on_load` and `on_draw` only. Both together have 2,000 ms, with no extension [O §15]. Target: 800 ms.
- It may `require` only `lib.core.const`, `lib.core.format`, `lib.core.glance` and the digit drawing module. It MUST NOT load `model.lua`, the icon data or any UI screen. A host test checks the loaded module list.
- It never writes: no `save_state`, no file write. It does not reconcile the saved state; it computes a **view**: a Running countdown whose deadline has passed is shown as finished.
- `ctx.frontlight`, `ctx:after`, `ctx.lockscreen` and `ctx.budget:extend` are unavailable there. Missing or invalid state draws `Timer Deck` and the time, nothing else.
- An error in a lock session makes the device draw its default picture and stops the wakes until the next lock [O §15]. Every line of `lock.lua` runs inside `pcall` with a plain fallback frame.
- [C] On current firmware the page appears only when Settings → Display → Off wallpaper is **Default**. `docs/INSTALL.md` says so.

### 15.3 Content, in priority order (BASELINE order, [P] glance planner)

`core/glance.lua` returns a headline and up to four secondary lines.

| Priority | Condition | Headline |
| --- | --- | --- |
| 1 | State blocked (newer schema) or invalid | `Open Timer Deck` |
| 2 | A countdown finished 600 s ago or less (by view), not silenced | `TIME'S UP`, the label, `finished 14:32`, `+2 more` when several |
| 3 | A countdown or chain step is Running | The soonest: label, minutes left in 160 px Orbit digits (`H:MM` from one hour), `MIN LEFT`, `ends 14:32`. A chain adds `Practice 2/3` |
| 4 | A stopwatch is Running | Label, `+12 min`, `since 14:02` |
| 5 | Something is Paused | Label, `paused · 3 min left` |
| 6 | Nothing | `No timers running` |

Secondary lines list the other Running countdowns (`Eggs · 6 min · 14:38`), then stopwatches, then paused items. A finished line older than 600 s disappears and the next priority shows (Pebble 0.7.0 F3). The top line shows the date and time in the user's formats; the battery percentage is at the right. Seconds are never shown.

**Blink.** For 180 s after a finish, the `TIME'S UP` page is drawn inverted when `((now − done) // 30) % 2 == 0`, and requests a full refresh. This is the slow blink the community Timekeeper uses [C].

### 15.4 Adaptive wake interval

Each lock session ends by calling `ctx.lock:set_interval(s)`:

| Situation | Interval |
| --- | --- |
| A deadline within 150 s, or a finish within the last 180 s | 30 s |
| A deadline within 60 minutes, or a finish within the last 600 s | 60 s |
| A deadline within 6 hours, or a stopwatch running | 300 s |
| A later deadline, or only paused items | 900 s |
| Nothing to show | 3600 s |

The manifest's `interval_sec` is 60, which is also the value after every new lock.

---

## 16. Timer Chains

Ported from the Pebble feature as it stands in 0.7.0 ([P] `docs/timer-chains-prd.md` §24–§27 supersede its earlier sections). A chain is a saved, ordered series of countdown steps that runs by itself.

### 16.1 Scope

| Capability | Value |
| --- | --- |
| Saved chains | Up to 5, separate from the 10 Deck items |
| Steps per chain | 2 to 10, each 1 s to `MAX_SEC`; the whole chain (steps × rounds) also at most `MAX_SEC` |
| Rounds | ×1 to ×9 |
| Active runs | One (Running or Paused) |
| Step fields | Name (§9.2), icon, duration, alert pattern |
| Templates | **Pomodoro** (chain icon Focus): Focus 25:00 (icon Focus), Break 5:00 (icon Coffee), ×4. **Plank** (Workout): Plank 0:30 (icon Workout), Rest 0:30 (no icon), ×3. **Tea** (Coffee): Boil 4:00 (icon Water), Steep 3:00 (icon Coffee), ×1. Steps take the default alert pattern |
| Access | The **Chains** button on the deck, always present |

Steps own copies of their values. **From Deck timers** copies a countdown's name, icon, configured duration and pattern; it never links, and it never copies the remaining time or the running state.

### 16.2 Data

```lua
ch = {
  last = 3,                       -- last chain id issued
  saved = {                       -- array, at most 5, in list order
    { id = 2, rev = 5, next_step = 4, name = "Practice", icon = 24, rounds = 1,
      steps = { { id = 1, name = "Scales", icon = 24, sec = 300, pat = 0 }, ... } },
  },
  run = {
    st = 1,                       -- 0 idle, 1 Running, 2 Paused, 3 Finished, 4 Stopped
    id = 2, gen = 7,              -- source chain id; run generation
    snap = { ... },               -- a full copy of the chain taken at Start
    idx = 2, round = 1,           -- current step and round, 1-based
    anc = 1794400600,             -- Running: the step's deadline; Paused: seconds left
    ev = 1794400300,              -- last logical boundary, or the result time
    skipped = 0, away = 0,        -- steps skipped by hand; steps that elapsed unseen
    pat = 2, cnt = 3,             -- final alert, captured at Start
    att = 0, cue = 0,             -- final-alert attempts; 1 while a step cue is pending
  },
}
```

Validation: ids unique; 2–10 steps in a saved chain; names valid; durations and totals in range (checked without overflow); `idx` and `round` inside the snapshot; `anc` consistent with `st`.

### 16.3 Timing contract (BASELINE)

- **A logical timeline.** A step starts at the previous step's logical deadline, not when the app noticed it. A late wake never lengthens the chain: 60 s then 120 s ends at 180 s.
- Reconcile advances through every boundary that has passed (bounded by 10 steps × 9 rounds), saves, and only then shows a cue.
- After the last step of the last round the run becomes Finished with one result.
- Clock policy and rollback as in §7.3.

### 16.4 Run commands

| Command | Effect |
| --- | --- |
| Start | Snapshot the definition; `gen + 1`; step 1 of round 1 from now. No confirmation. Replaces an old result. Refused while another run is Running or Paused: offer **View active chain** |
| Pause / Resume | Freeze the current step's remainder / re-anchor it from now; later boundaries shift |
| Skip step | Reconcile, end the current step now, start the next in full (or keep it frozen if Paused). Skipping the last step finishes the chain and records the skip. Acts at once |
| Restart step | The current step returns to its full duration, keeping Running or Paused. Acts at once |
| Stop | Confirm `Stop this chain?`. Result Stopped |
| Delete chain | Deleting the running chain ends its run and removes the definition in one saved mutation, with no result |
| Run again | A fresh run from step 1 |
| Done | Acknowledge the result |

Every run command carries the run generation, the step id and the round. A command for a step that has already advanced is `STALE`.

### 16.5 Cues and results

- A step that starts while the app is open: one attempt with that step's pattern (§10.5). No cue for step 1 at Start. Skipping while Paused gives no cue until Resume.
- If boundaries passed while the app was closed: no burst. One summary on return, `2 steps elapsed while away`. A single boundary younger than 60 s still gets its one attempt.
- The end of the chain is a completion with the captured default pattern and count, shown as `Chain complete` with the name, the number of steps and any skips. The late rule (60 s) applies.
- Coverage for a running chain follows §10.6. The lock-screen page shows the current step (§15.3).

### 16.6 Screens

| Screen | Content and controls |
| --- | --- |
| **S18 Chains** | The active run first (`Practice 2/3 · 02:10`, tap to open). Saved chains: name, `3 steps · 30:00 · ×4`, and a play button that starts the chain at once. Swipe left on a row: inline **Delete** as on the deck. Bottom bar: **New chain** |
| **New chain** | **Empty chain**, **From Deck timers**, **Pomodoro**, **Plank**, **Tea**. Templates open as unsaved drafts. At five chains: `You have 5 saved chains` |
| **S19 Overview** | Name, icon, ordered steps, total duration, rounds. Buttons **Start**, **Steps**, **Edit**, **More** (Duplicate, Move up, Move down, Delete with confirmation; `Stop and delete this chain?` when it is running) |
| **S20 Editor** | Rows **Name**, **Icon**, **Rounds** (stepper), then one row per step, then **Add step**. A step row opens **Edit**, **Move up**, **Move down**, **Remove**. **Save** needs 2–10 steps (`Add at least 2 steps`; at ten: `This chain has 10 steps`). A chain with an active run cannot be edited. Back with changes: `Discard changes?` |
| **Add step** | **New countdown**: the keypad, defaulting to the previous step's time; **Done** adds the step and returns here. **From Deck timers**: tick countdowns in the order wanted, then **Add steps** |
| **Step editor** | Name, Icon, Time, Alert |
| **S21 Run** | The detail layout: top bar with the chain name and a gear; the ring for the current step; `STEP 2 OF 3` and, with rounds, `ROUND 1 OF 4`; the step's label; `Next: Break 5:00`. Buttons: **Pause** / **Resume** (primary), **Restart step**, **Skip**. Gear: Skip step, Stop chain, Delete chain, View steps, All chains |
| **S22 Steps** | The steps of the run with the current one marked; read-only |
| **S23 Result** | `Chain complete` or `Chain stopped`, name, steps, skips. **Run again**, **Done** |

Independent Deck items are never changed by a chain, and Deck order is never read as sequence order.

---

## 17. Desktop file sync (replaces Clay phone settings)

### 17.1 Why

Pebble has no keyboard, so Timer Deck used a phone page to name timers and add several at once. Here the device has a keyboard and a keypad, so **every edit is made on the device**. What remains useful is bulk creation and a readable copy of the deck: both go through a text file in the app's folder on the card, `/AppFiles/timerdeck/`, which the user reaches over USB [O §29]. No network, no permission.

### 17.2 Files

| File | Written by | Purpose |
| --- | --- | --- |
| `timerdeck-import.txt` | The user | Timers and chains to add |
| `timerdeck-import-result.txt` | The app | The outcome of the last import, line by line |
| `timerdeck-export.txt` | The app | The current deck and chains in import format, with settings as comments. Renamed by the user, it can be imported on a fresh install |

The folder is created by the first `ctx.files` call, which happens only when the user opens S24. Uninstalling does not delete it.

### 17.3 Import format

UTF-8 text, at most 16,384 bytes and 64 lines. Fields are separated by `|` and trimmed. Blank lines and lines starting with `#` are ignored. Keywords, icon names and pattern names are case-insensitive.

```text
# kind | name | duration | icon | alert | count
timer | Tea | 4:00 | Coffee | Short + short | 3
timer | Eggs | 6:30
timer | | 90
stopwatch | Run | Run
# kind | name | rounds | icon        then 2 to 10 step lines
chain | Practice | 1 | Music
step | Scales | 5:00 | Music | Short
step | Piece | 20:00
```

| Field | Rule |
| --- | --- |
| name | §9.2; may be empty |
| duration | Digits only = seconds; `MM:SS`; `H:MM:SS`; or units in order, `1d 2h 3m 4s`. Range 1 to `MAX_SEC` |
| icon | A name from §13.6, a number 0–30, or empty for None |
| alert | A pattern name or 0–3; empty = the default |
| count | 1–5; empty = the default |
| rounds | 1–9; empty = 1 |

### 17.4 Behaviour (S24 Import and export)

The screen shows the folder path, **Export deck**, **Import file** and the last result.

- **All or nothing.** The whole file is parsed and checked against the free capacity first. If any line is wrong or anything does not fit, nothing is created and the result file names each line and reason. (Pebble kept rejected timers as drafts; a file can simply be corrected and imported again.)
- Created timers are Ready, in file order, appended to the deck. Chains are appended to the list. Nothing is started, edited or deleted by an import.
- **At most once** ([P] receipts): the import records a receipt `{ dig = CRC-32 of the file bytes, len = byte count, n = things created }` in the same saved mutation as the created items. A file whose digest and length match one of the last four receipts returns `DUPLICATE`: `This file was already imported.` Changing the file (even a comment) makes it a new import.
- The app never deletes or edits the user's file.
- Parsing happens in an input callback after `ctx.budget:extend()`. Reading uses one `ctx.files:read` call.
- Export writes the file and shows `Saved to /AppFiles/timerdeck/timerdeck-export.txt`.
- An unset clock does not prevent import (nothing starts).


---

## 18. Copy

### 18.1 Required strings

All user-visible text lives in one table (`lib/ui/strings.lua` or inside `theme.lua`) so that it can be reviewed and later translated. Developer terms (schema, generation, error codes) never appear outside Device information and the fatal screen.

| Situation | Text |
| --- | --- |
| Empty deck | `No timers yet` |
| No-sound notice | `This device has no sound or vibration. Timer Deck alerts you with a screen flash and a light pulse, so keep it where you can see it.` |
| Capacity | `10 items saved. Delete one to add another.` |
| Zero duration | `Set at least 1 second` |
| States | `READY`, `RUNNING`, `PAUSED`, `FINISHED`, `COUNT UP`, `LIMIT REACHED` |
| Ring hints | `RUNNING · LAST 25%`, `LAST 10%` |
| Buttons | `Start`, `Pause`, `Resume`, `Dismiss`, `Reset`, `Clear all`, `Start timer`, `Save`, `More options`, `Done` |
| Queue headers | `%d OF %d DONE`, `FINISHED AWAY`, `AWAY %d OF %d` |
| Coverage | `Alert: screen stays on`, `Alert: lock screen`, `Alert: only while open` |
| Deck strip | `ALERTS ONLY WHILE TIMER DECK IS OPEN` |
| Leaving | `Leave Timer Deck?` / `Timers keep counting. You will not be alerted until you open Timer Deck again.` / `Leave`, `Stay` |
| Save failure (user action) | `Could not save. Try again.` |
| Save failure (time-driven) | `NOT SAVED - RETRYING` |
| Clock rollback | `Clock changed. Timers restored from last saved time.` |
| Clock not set | `CLOCK NOT SET` / `Set the device clock to use timers.` |
| 2038 limit | `This timer would end after the device clock's limit (January 2038).` |
| Backup restored | `Saved data was restored from a backup.` |
| Recovery | `Saved data could not be read.` |
| Newer data | `Saved data needs a newer Timer Deck version.` |
| Reset data | `Reset saved data? All Timer Deck items and settings will be removed.` |
| Discard | `Discard new timer?`, `Discard changes?` |
| Edit while paused | `Reset to edit duration` |
| Name rule | `Names use up to 16 basic Latin characters.` |
| Delete on the deck | `Delete "%s"?` / `Delete`, `Keep` |
| Chains | `Add at least 2 steps`, `This chain has 10 steps`, `You have 5 saved chains`, `A chain is already active`, `Stop this chain?`, `Stop and delete this chain?`, `%d steps elapsed while away`, `Starting now: %s`, `Chain complete`, `Chain stopped` |
| Import | `This file was already imported.`, `Nothing was imported. See timerdeck-import-result.txt.`, `Imported %d timers and %d chains.`, `No import file found. Put timerdeck-import.txt in %s.` |
| Stay awake | `Uses more battery` |
| Fatal | `Something went wrong` |

### 18.2 Help text

A host test compares the Help screen with this section.

> **No sound**
> This device has no sound or vibration. Timer Deck alerts you with a screen flash and a light pulse, so keep it where you can see it.
>
> **Timers**
> Tap New timer, type the time, then tap Start timer. Save keeps it for later. The deck holds ten timers and stopwatches.
>
> **On the deck**
> Tap the button at the right of a row to start or pause it. Tap the row to open it. Swipe a row left to delete it.
>
> **Side buttons**
> The lower button moves to the next item. The upper button starts, pauses or dismisses it.
>
> **When a timer ends**
> Tap Dismiss, or Back to clear all finished timers. A finished timer you were shown clears itself after ten minutes. One you missed waits for you.
>
> **Leaving the app**
> Timers keep counting when you leave, lock or switch off. Alerts need Timer Deck on screen, or Timer Deck as your lock screen (Settings).
>
> **Stay awake**
> Stay awake keeps the reader on while a timer runs. This uses more battery.
>
> **Chains**
> A chain runs several steps one after another. Tap Chains, then New chain.
>
> **Clock changes**
> Timer Deck uses the device clock. If the clock moves forward, timers move forward with it.
>
> **Typeface**
> To change the typeface, open Ink App settings, then Font.

---

## 19. Quality budgets

| Area | Requirement | How it is checked |
| --- | --- | --- |
| Callback time | `on_load` ≤ 600 ms, `on_draw` ≤ 300 ms, input ≤ 400 ms, pulse ≤ 200 ms, `on_leave` ≤ 300 ms, lock session ≤ 800 ms | Host: instruction-count proxy per callback against a recorded baseline. Device: Device information shows the last `draw_us` and the longest input callback |
| Draw commands | ≤ 400 per frame as a target; a host assert fails at 768 (the limit is 1024) | Canvas double counts, with `text_box` lines counted individually |
| Frame text | ≤ 8,192 bytes per call; ≤ 65,536 per frame | Canvas double |
| Heap | Peak ≤ 512 KiB (524,288 bytes) through a full walk of every screen | Host sampling on Lua 5.5/32; device `ctx.gc:count()` |
| No growth | 100 create/delete cycles and 100 screen open/close cycles end within 4 KiB of the starting heap after a collection | Host |
| State size | ≤ 12,288 bytes for the fullest legal state | Host |
| Pending timers | ≤ 4; zero when nothing runs and no clock is shown | Host |
| Wakes | In minute granularity: at most one wake per minute for each running item on screen, plus one for the header clock. Nothing else wakes the app except deadlines, alerts and auto-reset | Host simulation of a 2-hour countdown on the deck in each Seconds mode |
| Saves | Only on mutations plus one checkpoint per 300 s while something runs; never from `on_draw` | Host counts `save_state` calls over simulated runs |
| Completion latency | Shown within 2 s of the deadline while open | Device |
| Timing | A value shown after exit and relaunch is within 1 s of a reference clock | Host exact; device spot check |
| Package | Under 200 KB; at most 40 scripts; no TTF; no data files | Packaging script |
| Privacy | `permissions` is empty. No network, no identifiers, no telemetry. Logs contain codes and counts, never names of timers | Review + lint (`ctx.net` is banned) |

A budget that cannot be met is reported with evidence and a proposed change. It is never silently marked as passed.

---

## 20. Tooling and repository

### 20.1 What exists on this server [V, 2026-11-11]

| Item | State |
| --- | --- |
| Python | 3.10.12, with Pillow 12.1.0 and `cryptography` 46.0.3 importable |
| Lua | **Not installed.** A verified Lua 5.5.0 source archive is at `../xteink-daily-mass/build/toolchain/lua-5.5.0.tar.gz`, SHA-256 `57ccc32bbbd005cab75bcc52444052535af691789dba2b9016d5c50640d68b3d` |
| Official contract | `../xteink-daily-mass/experiments/ext/kb/` (tag `api-2.18.2`); English sections are files `090`–`123`; the countdown guide is `039_2.x_graphics.md` |
| Community packager | `../xteink-daily-mass/experiments/ext/touch-licorice-apps`, commit `4290dcab76ad0317803421f442cbc7e01a90a8ad` (MIT). It also contains `apps/timekeeper/`, a working timer app for this device: read its `README.md`, `src/main.lua` and `lockscreen.lua` before M4 and M5 |
| Reference InkApp | `../xteink-daily-mass/app/` and `tools/` (API 2.18, installed on the owner's unit): lifecycle glue, hit map, key debounce, host double, packaging wrapper |
| Pebble source | `../pebble-timer-deck/` at `202dbc6` |

Copy what is needed. Do not depend on those paths at build time, and never write to them.

### 20.2 Host toolchain

- `tools/setup_lua55.py`: expects `build/toolchain/lua-5.5.0.tar.gz` (copy it from the sibling project; never download silently), checks the SHA-256, builds with `make linux MYCFLAGS=-DLUA_32BITS`, and asserts `_VERSION == "Lua 5.5"`, `math.maxinteger == 2147483647` and `string.packsize("n") == 4`.
- **Every Lua suite runs on that interpreter.** A 64-bit Lua would hide the overflow and precision bugs this app is most exposed to. No Lua-in-Python binding is needed: suites print results and, for previews, draw-command JSON.
- `luac -p` (same build) compiles every file under `app/`.

### 20.3 The runtime double (`tools/shim/runtime.lua`)

A deterministic stand-in for `ctx` and `g`, strict enough that code which passes on it does not fail on the device for a contract reason. It MUST model:

| Area | Behaviour |
| --- | --- |
| Clock | `now()` returns a read-only snapshot, the same table within one callback; `valid`, `epoch_sec` nil when invalid; `revision`; `millis()` with a settable start near the wrap |
| Timers | `after` with the 1..2,147,483,647 range, at most 32 pending, `cancel`; `advance(ms)` fires due timers in order; timers do not fire while paused and fire after `on_resume` |
| State | `ctx.state` restored before load; `save_state` with the 16,384-byte and 6-level rules, the key and value rules of [O §28], failure injection (`io_error`, `limit_exceeded`), a call counter, and "unchanged content writes nothing" |
| Sessions | `Runtime.session(files, state, kind)` builds a fresh VM-like environment (`main` or `lock`) so relaunch tests cannot leak module state; an uncaught error ends the session without `on_leave` and without saving |
| Storage and files | Atomic `write`, name rules, size limits, failure injection |
| Canvas | Records commands; enforces 1024 commands, text limits, valid UTF-8, integer arguments (a float equal to an integer is accepted), colour 0–15, `polyline` 2–128 and `polygon` 3–128 points, `arc` with a 360° multiple drawing nothing; any unknown method is an error; use after `on_draw` returns is an error |
| Fonts | Mock metrics (`line_height = px`, glyph width `px // 2`); a configurable limit on TTF sizes after which the system font returns with `px == nil`; `layout` rejects a negative height |
| Device | `keep_awake` range and call log; `display().dark` settable; `battery`; `lock_timer`; `model`, `firmware`, `api`, `capabilities` configurable, including absent `frontlight`, `dialog` and `keep_awake` |
| Front light | `get`, `set`, `reset` with a call log and range checks |
| Overlays | `input:text` and `dialog:*` scripted answers, with `on_pause` / `on_resume` in the contract's order; `busy` for a second overlay |
| Lock | `ctx.lock` with `reason`, `elapsed_sec`, `set_interval` range; `after`, `extend`, `frontlight` behave as in a lock session |
| Lifecycle | Budget counters per callback; `invalidate` wave recording; `defer_full_refresh` log |
| JSON, CRC-32 | Pure-Lua implementations; CRC-32 returned as a signed 32-bit integer |

Mock fonts prove geometry and behaviour. They prove nothing about real line breaks, glyphs or timing.

### 20.4 Lint (`tools/lint.py`)

- Vendored `lualint55.py` (assignment to a `for` variable) from the community repository, with its licence.
- Banned in `app/`, because they do not exist in 2.x or this app does not use them: `io`, `os`, `debug`, `load`, `loadfile`, `dofile`, `print`, `collectgarbage`; `ctx.data`, `ctx.assets`, `ctx.display`, `ctx.layers`, `ctx.net`, `ctx.sys`, `ctx.system`, `ctx:set_tick`, `ctx:set_tick_rate`, `ctx:request_refresh`, `ctx:save`; `require` with a slash; a dot call on a `ctx.*` function.
- `on_draw` must be declared as `on_draw(ctx, g)`.
- `lib/core/*` must not contain the identifier `ctx`.
- `lock.lua` may require only the modules listed in §15.2.

### 20.5 Previews (`tools/preview.py`)

A Lua suite walks fixture states through every screen and prints each frame's commands as JSON. Python with Pillow renders 480 × 800 PNGs into `build/previews/`, one per screen and appearance (and per style from M7), with a footer `HOST MOCK · NOT DEVICE EVIDENCE`, plus a contact sheet. The agent MUST look at the images after every UI change; a passing geometry audit does not show that a screen reads well.

### 20.6 Launcher icon

`tools/app_icon.py` draws the Pebble launcher motif (a timer dial on a card with two cards behind it) directly with Pillow at 88 × 88, pure black and white, corners left empty, and saves `app/assets/app_icon_s.png` in mode `1`. No network and no SVG rasteriser.

### 20.7 Packaging (`tools/package_local.py`)

- Vendor `xtpack.py` (SHA-256 `76580e3feedf5a19aac75b217246c5a69f5bbfb964907dcd68f837276227baa6`) and `tools/vendor/xtapp.py` (SHA-256 `2e87c7630fcb46aea0b4d9c0ba17d84bf3d3d5b62cb05ba0c0d2bb830736a06a`) from the pinned commit into `tools/vendor/xtpack/`, with `LICENSE` and `NOTICE.md`. The wrapper refuses to run if a hash differs.
- Steps, following the Daily Mass wrapper: validate the manifest (Appendix A); collect every `.lua` under `app/` with `index.lua` first; no data section; convert the icon to a 1-bit XIC and build the icons table with the single entry `app_icon_s`; `build_container`; then **decrypt the result** and compare every script byte for byte, the manifest fields and all 7,744 icon pixels.
- Output: `dist/timerdeck-<version>.xtapp`, a JSON report (sizes, source hashes, packager commit, `device_verified: false`) and `dist/SHA256SUMS`. The encrypted bytes differ between builds; the decrypted content must not.
- The official packager is not public. The official route (Studio, Developer Center) needs the owner's account and uploads the source; it is used only if the owner asks.

### 20.8 Commands

```bash
make test       # ./tools/run_tests.sh: setup, lint, luac, every suite, previews, checks
make preview    # previews only
make icons      # regenerate app/lib/gen/icons.lua
make package    # after a passing gate: dist/timerdeck-<version>.xtapp
```

`build/gate-results.json` records every step, its duration and `device_tests_run: false`.

### 20.9 Versioning and Git

- `app/manifest.json` holds the only version. A build step writes `app/lib/gen/version.lua`; the gate checks that they agree.
- The save format has its own number (`v`, §8.1).
- Initialise Git in M0 on `main`. Ignore `build/` and `dist/`. Commit generated `app/lib/gen/*` and the icon PNG. No remote, push or tag without the owner.

### 20.10 Installation (`docs/INSTALL.md`, written in M0)

1. Copy the `.xtapp` to the root of the SD card over USB and eject safely.
2. On the reader: **All Files** → tap the file → install.
3. If **Ink App** is not in the side drawer: Settings → About → tap **Model** ten times [C].
4. Open **Ink App** → **Timer Deck**.
5. For the lock-screen page: Timer Deck → Menu → Settings → Lock screen → On, and keep Settings → Display → Off wallpaper on **Default** [C].

Installing the same `app_id` again is an upgrade and keeps the data [O App. B]. Uninstalling deletes the data but not `/AppFiles/timerdeck/`.

---

## 21. Test plan

### 21.1 Layers

| Layer | Proves | Does not prove |
| --- | --- | --- |
| Host suites (Lua 5.5/32 + the double) | Rules, arithmetic, sequencing, geometry, limits, save discipline | Real fonts, real timing, touch feel, light, battery |
| Host previews | Layout and hierarchy by eye | Device rendering |
| Device checklist (owner) | Everything tagged VERIFY | — |

Every report states its layer. `Not run`, `Blocked` and `Failed` are different from `Passed`.

### 21.2 Core and clock

| ID | Case | Expected |
| --- | --- | --- |
| TC01 | Fresh state | Valid, empty deck, defaults of §8.1 |
| TC02 | Create with defaults | Ready at 10 s; one slot used; not running |
| TC03 | Zero duration | Refused; draft kept |
| TC04 | One-second countdown | Not finished before `now ≥ anc`; finished at it |
| TC05 | 999d 23:59:59 | Exactly 86,399,999 s; every derived value correct; no overflow |
| TC06 | Keypad entry | `90` → 1:30; six-digit cap; first digit replaces the default |
| TC07 | Eleventh item | `FULL`; nothing changes |
| TC08 | Delete then create | Numbers of survivors unchanged; smallest free number reused; id never reused |
| TC09 | Five countdowns and five stopwatches | All independent |
| TC10 | Pause one | Its value freezes; the others advance |
| TC11 | Resume after 90 s | The pause is excluded; same generation |
| TC12 | 100 pause/resume cycles at random sub-second phases | Each step's error under 1 s; total error within ±100 s and its mean near zero over 1,000 seeded runs |
| TC13 | Reset in every state | Ready, full duration, generation + 1, alert work cleared |
| TC14 | Edit by state | §9.5 rules; a paused edit never resets |
| TC15 | Rename and icon while Running | Timing and generation unchanged |
| TC16 | Pause at the deadline sample | Expiry first; no paused-zero item; one completion |
| TC17 | Dismiss, then Start | Ready with full time; new generation; a command with the old generation is `STALE` |
| TC18 | Stopwatch lifecycle and limit | §9.4; `LIMIT REACHED`; no alert |
| TC19 | Names | Trim, collapse, 16 limit, `\|` and non-ASCII refused; label fallbacks |
| TC20 | Formats | Every boundary of §7.6 in both granularities; 12/24-hour clock text; date added for another day |
| TC21 | `ratio` helper | Correct at maximum values without overflow |
| TC22 | Property test: 10,000 seeded random commands and time steps | Invariants of §9.6 hold; every stored number is an integer; state always valid |
| TR01 | Seven missed wakes | Same value as seven timely ones |
| TR02 | Exit with a Running countdown, relaunch 37 s later (new session) | 37 s less |
| TR03 | Paused items across sessions | Unchanged; a Running stopwatch includes the time away |
| TR04 | Relaunch after three deadlines | Three completions ordered by deadline, then id |
| TR05 | Clock jumps forward past a deadline | Finishes once |
| TR06 | Clock moves back below `trusted` | Values kept, anchors rebased, message once, saved |
| TR07 | Time zone or 12/24 change (`revision` only) | No timing change; clock text changes |
| TR08 | Completion found 61 s late | Late; no attempts; stays |
| TR09 | Clock not valid | §7.5 table: no reconcile, Start refused, strip shown, edits allowed |
| TR10 | Deadline beyond int32; `epoch_sec` nil | `OVERFLOW` and the message; no wrap anywhere |
| TR11 | `millis` wraps during a debounce and a settle window | Intervals still correct |
| TR12 | Checkpoints | One save per 300 s while Running; none when idle |

### 21.3 Storage

| ID | Case | Expected |
| --- | --- | --- |
| TS01 | Fullest legal state | ≤ 12,288 bytes; ≤ 5 levels; only integers, strings, tables |
| TS02 | Save, new session, load | Equal state, integer types preserved |
| TS03 | Save fails on a user action | Previous state and screen; `Could not save. Try again.`; no success shown |
| TS04 | Save fails at an expiry | Finished in memory; strip; attempts held back; retried; saved at session end |
| TS05 | Backup | Written once within 2 s after a burst of mutations; header and CRC correct; flushed in `on_leave` |
| TS06 | Empty state with a valid backup | Restored, reconciled, message |
| TS07 | Invalid state without a valid backup | Recovery screen; nothing written until the user chooses |
| TS08 | Schema 2 state | Blocked screen; `save_state` never called; `ctx.state` identical afterwards |
| TS09 | Reset saved data: cancel, then confirm | Cancel keeps everything; confirm empties state, removes the backup, releases keep-awake |
| TS10 | `on_draw` | Never saves, writes or opens a font |
| TS11 | Error injected after a committed mutation | The mutation survives in the next session |

### 21.4 Alerts, attention, cadence

| ID | Case | Expected |
| --- | --- | --- |
| TA01 | Each pattern | Light calls match §10.3 in order and timing; `reset` at every gap and at the end |
| TA02 | Counts 1–5 | Exactly that many attempts, 2,000 ms apart |
| TA03 | Three simultaneous completions, count 3 | All recorded first; first attempts before repeats; order by deadline, then id |
| TA04 | Dismiss one of them mid-sequence | Only it is cleared; the others continue correctly |
| TA05 | Touch during an attempt | Light reset, normal frame, input consumed, queue silenced |
| TA06 | The item finishes again later | New generation; alerts again |
| TA07 | Duplicate wakes, resumes and relaunches | `att` never exceeds `rcnt` |
| TA08 | Session ends after `ATTEMPT` was saved but before the flash | Next session does not exceed the budget |
| TA09 | Auto-reset | Delivered: Ready at 600 s. Late or never alerted: stays. Silenced: resets. Generation at maximum: skipped |
| TA10 | Front light safety | `reset` on pause, leave, error and input; a bright light pulses by dimming; no call when the capability is absent |
| TA11 | Both channels off | One attempt recorded when the page is shown; auto-reset still works |
| TA12 | Keep-awake | Values per §10.6; renewed each pulse; released once; not for stopwatches, paused items or countdowns beyond 4 hours; no call when unavailable |
| TA13 | Coverage and strip | Each combination of Stay awake, lock default, horizon and capability gives the right line and strip |
| TA14 | Back on the deck | System path, own dialog, or `quit` as §10.6 says |
| TA15 | Pulse | The right delay for every reason in §6.5; at most 4 pending timers; none when idle |
| TD01 | Granularity | §11.1 table for each setting, screen and value |
| TD02 | Wake counts over a simulated hour | Within the budget of §19 for each mode |
| TD03 | Peek | One frame; exact value; no extra wakes |
| TD04 | Waves | R1–R5 produce the stated `invalidate` arguments and `defer_full_refresh` calls |
| TD05 | Deadline in mode Never | Completion shown within one simulated second |

### 21.5 Interface

| ID | Case | Expected |
| --- | --- | --- |
| TU01 | Geometry audit of every frame the suites draw | Target sizes of §12.1; no overlap; on screen; text ≥ 22 px; nothing under an inverted strip |
| TU02 | Command and text counts | Within §19 on every screen, including the icon picker and a ten-row deck |
| TU03 | Deck rows for 0–10 items, with the chain row and a strip | Heights per §14.1; paging only when needed |
| TU04 | Deck gestures | Tap, toggle, long press, swipe-to-delete arm, expiry after 5 s, Delete, Keep |
| TU05 | Settle window and stale target | An early tap is ignored; a tap on a changed item does nothing harmful |
| TU06 | Keys | The grammar of §12.3 on every screen; 250 ms debounce; wrap activates nothing |
| TU07 | New timer | Start timer, Save, More options, discard; all refusals keep the draft |
| TU08 | Forms by state | Rows, disabled Time when Paused, live Name/Icon when Running |
| TU09 | Name entry | Confirm, cancel, invalid text, trimming, through the overlay double |
| TU10 | Completion queue | Browse, Dismiss, Clear all, Back; interrupting a form keeps its draft |
| TU11 | Settings | Every row; preview pickers commit and restore; lock-screen toggle across pause/resume; hidden rows without the capability |
| TU12 | Help | Equals §18.2; paginates; seven taps open Device information |
| TU13 | Lazy modules | Not loaded by start-up or by running a timer |
| TU14 | Appearance | `flip` table of §13.2 with system dark on and off; the flash frame is its negation |
| TU15 | Injected draw error | Fatal screen; logged once; Try again works; Back exits |
| TU16 | Previews | One PNG per screen and appearance; contact sheet written |
| TM01 | Heap through a full walk; 100 cycles; icon picker | Within §19 |

### 21.6 Lock screen, chains, import, package

| ID | Case | Expected |
| --- | --- | --- |
| TL01 | Modules loaded by `lock.lua` | Only those of §15.2 |
| TL02 | Each priority of §15.3 | Right headline and secondary lines |
| TL03 | A deadline passed before the lock session | Shown as finished; nothing written; state identical |
| TL04 | Blink and expiry | Inverted on even 30 s slots for 180 s; gone after 600 s |
| TL05 | Interval | §15.4 table |
| TL06 | Empty, invalid or blocked state; clock invalid; an injected error | A plain fallback frame; no error escapes |
| TH01 | Chain definitions | Create, edit, reorder, duplicate, delete; limits and messages |
| TH02 | Templates | Exactly the values of §16.1 |
| TH03 | From Deck timers with a running source | Configured values copied; the source is untouched |
| TH04 | 60 s + 120 s with a 2 s late wake | Ends at 180 s |
| TH05 | Rounds ×4 | Four passes; one final result |
| TH06 | Pause, resume, skip, restart at and around a boundary | §16.4; stale commands rejected |
| TH07 | Stop; delete while running | Confirmed stop gives Stopped; delete leaves no result |
| TH08 | Return after two boundaries; after one within 60 s | One summary and no burst; one cue |
| TH09 | Final completion with ten Deck items alerting | Fair order; nothing starved |
| TH10 | Totals at the limit | Overflow refused without partial change |
| TI01 | Grammar and durations | Every form of §17.3; errors name the line |
| TI02 | One bad line; not enough room | Nothing imported; result file written |
| TI03 | Same file twice; a fifth different file | `DUPLICATE`; oldest receipt dropped |
| TI04 | Export, erase, import the export | Same definitions |
| TP01 | Lint and `luac -p` | Clean |
| TP02 | Manifest, version agreement, icon | Appendix A; 88 × 88 1-bit |
| TP03 | Package round trip | Decrypted content equals the sources; size under 200 KB |
| TP04 | `icons.py --check` | Generated file matches the SVG sources |

### 21.7 Device checklist (`docs/device-checklist.md`, for the owner)

Each step names the gate it answers. The owner reports the Device information page and short notes or photos.

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
| DV10 | Run a timer showing seconds for two minutes; judge ghosting. Try Dark | V07 |
| DV11 | Name a timer with the keyboard; cancel once | V13 |
| DV12 | Run a chain with two 10-second steps | §16 |
| DV13 | Put an import file on the card; import; export | §17 |
| DV14 | Reinstall the package over itself; data is kept. Report heap and last error | V09 |
| DV15 | Reset saved data | §14.10 |

---

## 22. Milestones

Each milestone ends with a report: what works, files changed, checks run and their results, previews or logs, open test IDs, next step. A successful compile is not completion. Work that needs the owner is queued, never waited for.

| Milestone | Deliverables | Exit gate |
| --- | --- | --- |
| **M0 Foundations** | Git repository, `AGENTS.md`, `README.md`, layout of §6.1; Lua 5.5/32 toolchain; runtime double with its own self-tests; lint; preview pipeline; pinned packager and a round-trip package; manifest; minimal `index.lua` (deck shell + Device information) and a minimal `lock.lua` (name and time), so the manifest never changes shape later; digit and ring drawing spike with previews; `docs/platform-findings.md` listing V01–V14 as open; `docs/INSTALL.md`; `docs/device-checklist.md` | `make test` passes; `make package` produces a package whose decrypted content equals the sources; previews of the spike exist. DV01 is queued for the owner |
| **M1 Timing core** | `core/const`, `model`, `format`; commands; reconcile; completion queue; auto-reset; clock policy | TC01–TC22 and TR01–TR12 pass with no UI |
| **M2 Foreground interface** | Theme (Ion, Auto/Light/Dark), draw primitives, icons generator and data, nav and input, deck, empty deck, keypad, forms, pickers, detail screens, item actions, menu, settings (without lock screen and sync), help | TU01–TU13 pass; a previewed walk shows create, start, pause, resume, reset, edit, delete entirely by touch and by keys |
| **M3 Persistence** | Store, validation, backup, recovery and blocked screens, save discipline, fatal screen | TS01–TS11, TU15 pass |
| **M4 Alerts and attention** | Completion screen, alert queue, flash and light, attempts, pulse planner, cadence, refresh waves, keep-awake, coverage, exit prompt | TA01–TA15, TD01–TD05, TU10, TU14 pass |
| **M5 Lock screen** | `core/glance`, full `lock.lua`, settings row | TL01–TL06 pass. **Candidate 0.1.0** |
| **M6 Timer Chains** | `core/chains`, chain screens, deck chain row, lock-screen line | TH01–TH10 pass. **Candidate 0.2.0** |
| **M7 Styles and file sync** | Cobalt, Plasma, Solar; import and export | TI01–TI04 pass; previews for every style. **Candidate 0.3.0** |
| **M8 Validation** | For each candidate: full gate, package, checklist results recorded, findings fixed or accepted in `docs/decisions.md`, `docs/test-report.md`, README limits | The candidate is labelled **device-validated** only when DV01–DV15 that apply to it have recorded results. Otherwise it is a **host-validated candidate** |

Order within a milestone is the agent's choice. M1 does not wait for the device.

---

## 23. Risks

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| A silent device cannot alert someone who is not looking | It is the product's main weakness | Say it in the app. Stay awake, light pulse, persistent page, lock-screen blink. Never use the word alarm |
| Firmware rotates the package key | Installs stop [C] | Pinned packager with the `--image` path documented; keep the previous package; record the firmware in every report |
| `keep_awake` or `lock_timer` behaves differently on 26110501 | Coverage claims would be wrong | V04, V05 before the claims ship; coverage falls back to Open only |
| 32-bit integer overflow or float creep | Wrong times with no error | One checked helper for time sums; `ratio`; integer property test; all suites on 5.5/32 |
| Battery drain while awake | 1,100 mAh | Smart cadence; the 4-hour horizon; measure in DV06 and publish the numbers in Help |
| Ghosting from one-second partial frames | Unreadable digits | Refresh rules R3–R4, tuned in DV10 |
| TTF memory runs out | Text falls back to a small system font [D] | Four sizes; vector numerals; layout from measured metrics |
| Lost or damaged `ctx.state` looks like a first run | Silent data loss | Backup file and recovery screen |
| Accidental deletes and resets on a touch screen | Lost timers | Two gestures to delete on the deck; settle window; stale-target rejection. Reset stays immediate (owner's Pebble decision) and can be revisited |
| Lock-screen script error | The device disables the page until the next lock | `pcall` everywhere; tiny script; TL06 |
| Scope: chains, styles and sync delay the core | No usable app | Candidates at M5, M6, M7 |
| Host mocks give false confidence | Device surprises | Evidence labels; the checklist; no device claim without a DV result |

Escalate to the owner when a CONFIRMED requirement cannot be met, when a workaround would remove a core function, or when anything must leave this machine.

---

## 24. Deferred

Not in this scope. Each needs a decision and tests before any code.

- Sub-second anchoring with `millis()`.
- Snooze, +1 / +5 minutes, presets library, laps, history, per-timer "when done" rules, a configurable auto-reset time.
- Sound or vibration, if a later API or a Bluetooth accessory offers it.
- Network features: phone page, sync, calendar.
- Landscape, the X4 Classic (no touch), other device profiles.
- Translations.
- Icons on the lock-screen page; a reading "cover" (`set_wallpaper`).
- Chain extras: scheduled starts, manual-confirm steps, several simultaneous chains.
- Store submission and public distribution.
- Editing existing items through the import file.

---

## 25. Definition of done and handoff

A candidate is done when:

1. Its milestone gates pass on Lua 5.5/32, and `build/gate-results.json` shows it.
2. Every screen in its scope has current previews that the agent has inspected.
3. Every user mutation is saved before success is shown, and every failure path shows the truth.
4. No stale input can act on a deleted, reset or dismissed generation.
5. The package is rebuilt from committed sources and its decrypted content matches them.
6. `README.md`, `docs/INSTALL.md`, `docs/storage-format.md`, `docs/decisions.md`, `docs/platform-findings.md`, `docs/test-report.md` and `docs/device-checklist.md` are current.
7. Limits are stated: no sound, clock policy, what Stay awake and the lock screen can and cannot do, the 2038 limit.
8. Device results are recorded, or the candidate is explicitly labelled host-validated with the open DV items listed.
9. Sibling repositories are unchanged.

Handoff: the repository; this PRD with a list of accepted deviations; the `.xtapp`, its report and checksums; the previews; the documents above; licences and provenance for the icons (Lucide, ISC) and the vendored tools (MIT).

---

## 26. Questions for the owner (none blocks the start)

| # | Question | Default used until answered |
| --- | --- | --- |
| Q1 | Is a front-light pulse acceptable as an alert? | Yes, On by default (D05) |
| Q2 | Side buttons: lower = next, upper = act. Or the other way round? | As stated (D14) |
| Q3 | Stay awake On by default, with its battery cost? | On, for timers ending within 4 hours (D06) |
| Q4 | Should the app offer the lock-screen page once on first run? | No; Settings only (D07) |
| Q5 | Keep all 30 Pebble icons, including Love and Sex? | Yes (parity) |
| Q6 | Is Reset without confirmation still wanted on a touch screen? | Yes (Pebble decision) |
| Q7 | May the agent use the official Studio simulator? It uploads the source to Xteink's relay and needs your sign-in | No |
| Q8 | Should the repository get a private GitHub remote? | No; local only |
| Q9 | Is the reader still on firmware 26110501? | Assumed; DV01 records it |
| Q10 | First release scope: is candidate 0.1.0 (no chains, Ion only) worth installing, or wait for 0.3.0? | Install each candidate |

---

## 27. Instruction for the implementing agent

> Build Timer Deck for the XTEINK X4 Pro from `PRD.md`. Read §1–§8 first. The app is a Lua 5.5 InkApp for API 2.18 that reproduces the behaviour of Pebble Timer Deck 0.7.0 (`../pebble-timer-deck`, read-only) on a silent e-ink device. Work through M0–M8 in order and report at each gate. Keep `lib/core` pure and test everything on Lua 5.5 built with `LUA_32BITS`; time is in whole seconds and every addition of a time and a duration is overflow-checked. Never count ticks, never save from `on_draw`, never claim an alert the device cannot deliver. Use only API 2.x names and check each against the local contract in `../xteink-daily-mass/experiments/ext/kb/`. Treat DRAFT DEFAULT choices as working decisions and record changes in `docs/decisions.md`. Host results are labelled HOST MOCK and are never presented as device evidence; anything tagged VERIFY goes on the owner's checklist and does not block host work. Do not push, publish, upload, or write outside this repository. Inspect the previews after every UI change. If the owner is unavailable, deliver the host-validated candidate with the open device checklist.

---

## 28. Sources and provenance

| Source | Location | Used for |
| --- | --- | --- |
| Owner's request, 2026-11-11 | The conversation that produced this PRD | Device, API target, scope "similar (identical) functionalities", minimum InkApp structure |
| Pebble Timer Deck 0.7.0 | `/home/ubuntu/projects/pebble-timer-deck` at `202dbc6655421baf45439f063d208ce9b140a29a`: `README.md`, `docs/timer-deck-prd.md` (§1–§49), `docs/timer-chains-prd.md` (§24–§27 current), `docs/decisions.md`, `docs/prd-finished-reset-0.7.0.md`, `src/core/*.h`, `scripts/icons.py`, `assets/icons/lucide/` | Functional baseline, constants, copy, icons |
| InkApp API 2.x contract, tag `api-2.18.2` | `../xteink-daily-mass/experiments/ext/kb/` (from `xtapp-studio-mcp-intl` at `f953feb`) | Every [O] statement. Sections 0–4, 5–7, 9, 12, 13, 15, 17, 18, 21, 23, 24, 28, 29, appendices A and B; guide "Clock faces and countdowns" |
| Community repository `touch-licorice-apps` | `../xteink-daily-mass/experiments/ext/touch-licorice-apps` at `4290dca` | Packager, `docs/firmware-notes.md`, the Timekeeper app. Every [C] statement |
| Roman Missal for XTEINK 0.5.3 | `/home/ubuntu/projects/xteink-daily-mass` | Working API 2.18 patterns, host double, packaging wrapper, and the [D] findings (TTF size limit, negative layout height) |
| XTEINK product page and ExplorInk hardware notes | Links in the owner's request | Hardware summary only |

Not verified by this PRD: anything on the device. No package was built, nothing was installed, and no statement here about light pulses, keep-awake, the lock screen, battery or ghosting is a measurement.

---

## Appendix A. `app/manifest.json`

```json
{
  "api": "2.18",
  "app_id": "timerdeck",
  "display_name": "Timer Deck",
  "version": "0.1.0",
  "description": "This device has no sound or vibration. Timer Deck alerts you with a screen flash and a light pulse, so keep it where you can see it.",
  "entry": "index.lua",
  "requires": ["pointer"],
  "permissions": [],
  "display": { "orientation": "portrait" },
  "app_icon_s": "app_icon_s",
  "lockscreen": { "enabled": true, "entry": "lock.lua", "interval_sec": 60 }
}
```

- `frontlight`, `dialog` and `lockscreen_timer` are **not** in `requires`: the app detects them and works without them.
- `"enabled": true` inside `lockscreen` is what the community apps ship [C]; the official field list has `entry` and `interval_sec` only [O §0]. If the installer rejects the package in DV01, remove `enabled` first.
- The gate asserts these fields exactly, with only `version` allowed to change.

## Appendix B. Entry-script shape

```lua
-- index.lua: lifecycle glue only.
local App = require('lib.app')
local app, fatal

local function guard(ctx, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    fatal = tostring(err)
    ctx.log:error(fatal)
    ctx:invalidate('full')
  end
  return ok, err
end

function on_load(ctx)
  guard(ctx, function() app = App.new(ctx) end)
end

function on_draw(ctx, g)
  if app and not fatal then
    local ok = pcall(app.draw, app, ctx, g)
    if ok then return end
    fatal = fatal or 'E-DRAW'
  end
  App.draw_fatal(ctx, g, fatal)        -- plain text and a Try again button
end

function on_input(ctx, ev)
  if fatal then return App.fatal_input(ctx, ev, function() fatal = nil; app = nil; on_load(ctx) end) end
  if not app then return false end
  local ok, handled = guard(ctx, app.input, app, ctx, ev)
  return ok and handled or false
end

function on_pause(ctx)  if app then guard(ctx, app.pause, app, ctx) end end
function on_resume(ctx) if app then guard(ctx, app.resume, app, ctx) end end
function on_leave(ctx)  if app then pcall(app.leave, app, ctx) end end
```

```lua
-- lock.lua: one frame, read-only, never raises.
local ok_mods, Glance, Format, Digits = pcall(function()
  return require('lib.core.glance'), require('lib.core.format'), require('lib.ui.digits')
end)

function on_draw(ctx, g)
  local ok = ok_mods and pcall(function()
    local now = ctx.clock:now()
    local view = Glance.plan(ctx.state, now.epoch_sec)     -- pure; computes a view, writes nothing
    -- draw the date line, headline, digits and secondary lines from `view`
    if ctx.lock then ctx.lock:set_interval(view.interval) end
  end)
  if not ok then
    g:clear(0)
    g:text(ctx.screen.width // 2, ctx.screen.height // 2, 'Timer Deck',
           { font = ctx.fonts.large, align = 'center', valign = 'middle' })
  end
end
```

`lib/ui/digits.lua` holds the Orbit digit drawing and is shared by the main app and the lock screen.

## Appendix C. Pitfalls checklist for this platform

| Pitfall | Rule |
| --- | --- |
| `now + duration` can exceed 2,147,483,647 and wrap negative | Only through the checked helper (§7.5) |
| `remaining * 360` overflows for long timers | `ratio` (§13.5) |
| `/` and `^` produce single-precision floats | Use `//`; keep every stored value an integer |
| CRC-32 is a signed integer | Store and compare it as a signed decimal |
| `ctx.clock:millis()` wraps after 24.8 days | `(later - earlier) & 0x7FFFFFFF` |
| `ctx.clock:now()` is a read-only snapshot | Copy fields; never assign into it |
| `epoch_sec` is nil without a clock | Check before every use |
| A `for` variable cannot be assigned in Lua 5.5 | Use a `while` loop or a second local |
| `print`, `os`, `io`, `collectgarbage` do not exist | `ctx.log`, `ctx.clock`, `ctx.storage`, `ctx.gc` |
| Dot calls on `ctx.*` shift the arguments | Always a colon |
| `g` is valid only inside `on_draw` | Never keep it |
| `invalidate` called inside `on_draw` applies to the next frame | Request frames from other callbacks |
| A frame requested during a refresh is merged, not queued | Draw from state, never from an event |
| Timers and completion functions wait while a system screen is open | Reconcile in `on_resume` |
| An uncaught error ends the session with no save | `pcall` in every callback; save at each mutation |
| `on_leave` and lock sessions cannot be extended | Keep them tiny |
| `arc` with a multiple of 360° draws nothing | Full ring = `circle` stroke |
| Strokes grow inward; `radius` clamps to half the short side | Size outlines from the outer box |
| `polyline` takes at most 128 points | Split |
| A negative height in `font:layout` is an error | Guard before calling |
| `font.px` is nil when a system font was returned | Lay out from `line_height` and `measure` |
| More than four TTF sizes can exhaust font memory | The ladder of §13.4 |
| `ctx.state` rules: 16,384 bytes, 6 levels, no float keys, `"12"` reads back as `12` | §8.2 |
| A damaged save loads as `{}` | §8.4 |
| Side keys can arrive twice | 250 ms debounce |
| Back acts on `up`; a 1 s hold kills the app | Never put work on Back `down` |
| The Home pad may be remapped or off | An on-screen Back on every screen |
| The front light must be given back | `reset()` on every exit path |
| Large black areas can ghost | Prefer outlines in Light; check Dark on the device |

## Appendix D. Traceability to the Pebble acceptance cases

| Pebble cases ([P] PRD §21) | Subject | Here |
| --- | --- | --- |
| T01–T25 | Creation, limits, independence, state machines, stopwatch | TC01–TC22 |
| T13 | No rounding drift over 100 pause/resume cycles | TC12, with the bound of §7.4 |
| T26–T38 | Callbacks, reopen, clock changes, late completion | TR01–TR12 |
| T39–T46 | Patterns, counts, fairness, silence, duplicates, crash window | TA01–TA08 |
| T47–T59 | OS wakeups, conflicts, slots, prewake | Replaced by coverage and keep-awake: TA12–TA14, TL01–TL06, DV06–DV07 |
| T60–T70 | Serialisation, torn writes, banks, newer schema, reset | TS01–TS11 |
| T71–T84 | Screens, themes, formats, navigation, held presses, heap | TU01–TU16, TM01, TD01–TD05 |
| N01–N08 | Names | TC19, TU09 |
| 0.7.0 F1–F3 | Back clears, auto-reset, glance expiry | TU10, TA09, TL04 |
| Chains TC01–TC35 | Timer Chains | TH01–TH10 |
| Clay tests | Phone settings | Replaced by TI01–TI04 |

## Appendix E. Document history

| Date | Change |
| --- | --- |
| 2026-11-11 | First draft, written from the Pebble 0.7.0 sources, the local API 2.18.2 contract and the community notes. Nothing implemented |
