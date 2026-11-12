# Timer Deck standing rules

PRD.md is the source of truth; the API 2.18.2 contract overrides it. Record corrections in docs/decisions.md. CONFIRMED and BASELINE stay; DRAFT DEFAULT changes need a decision; VERIFY stays open until device evidence; DEFERRED is not built.

- Work offline. No push, upload, publish, Studio preview, or network without explicit owner approval. Local conventional commits at each milestone; no attribution trailers.
- All writes stay in this repository. Sibling repositories are read-only. Read Pebble baseline via git show 202dbc6:path; never alter its worktree.
- API 2.x only; every ctx method uses a colon. Core is pure, with no ctx, globals or I/O. Draw only in on_draw(ctx, g); never save, open fonts, read files or mutate timing there.
- Every callback body is protected by pcall; caught errors log E- codes and offer Try again.
- Every Lua suite uses Lua 5.5/32. Whole seconds, integer stored values, checked time addition, overflow-safe ratio. Never count ticks.
- Controller order: sample, rebase, reconcile, resolve (id, gen), candidate, commit and save, effects, invalidate. One pulse planner; at most four pending timers.
- No sound or vibration claims. Use the required no-sound sentence; do not call the product an alarm.
- Host results and previews are HOST MOCK, never device evidence. Inspect regenerated PNGs after every UI change. Queue owner work without blocking host work.
- Record platform limits and the smallest behaviour-preserving alternative. Escalate only for an unmet CONFIRMED requirement, removal of core functionality, or an action leaving this machine.
- Gate reports include actual checks and statuses, preview paths, open IDs, decisions and next work. Do not claim completion from compilation alone.
