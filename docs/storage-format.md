# Storage format

Reserved schema 1 is specified by PRD §8.1. The M0 shell leaves saved state untouched and does not implement persistence or migrations. M1 adds the pure item model; M3 adds persistence adapters.

M1 implements item schema validation and transactional candidate construction in model.lua. `v=1`, `rev` is owned by the future commit adapter, `next_id` is monotonic, `sel` is an existing item id or zero, and `trusted` is the last accepted whole-second clock value. `set` contains integer settings; `items` is a dense creation-ordered array. `rc` reserves up to four import receipts; `ch` must currently be the empty reserved container.

Item keys: `id` stable identity; `gen` run generation; `num` smallest free display number; `type` 0 countdown/1 stopwatch; `st` 0 Ready/1 Running/2 Paused/3 Finished; `name` normalized ASCII; `icon` 0–30; `pat/cnt` configured alert; `rpat/rcnt` run alert; `att` consumed attempts; `sil/late/lim` integer flags; `dur` configured seconds; `val` frozen/accumulated seconds; `anc` running deadline or stopwatch segment start; `done` logical finish timestamp. Non-running anchors are zero. Running countdown val remains positive as in the Pebble baseline; it is never decremented by ticks.

All stored numeric values are integers. `Model.add_time` is the sole checked deadline addition. `Model.reconcile` mutates an owned working state and returns durable-change and rollback flags; `Model.command` copies that reconciled state, returning a candidate plus status. A refused command returns the unchanged input table. The production controller must perform save/rollback before effects; this pure model does not claim a save succeeded.
