# Decisions

2026-11-12: Owner update supersedes PRD header and Q8: repository and private origin already exist. Local commits only; no push.

Open owner question: Pebble 0.7.1 adds New stopwatch and wrap-around deck scrolling. Baseline remains 0.7.0 at 202dbc6. No adoption of those changes is implied (PRD §12.3 independently specifies key wrapping).

Contract corrections: API §28 drops unsupported state entries and entries deeper than six levels, rather than rejecting an entire save. The host double must emulate that loss; model validation must prevent it. API §6 returns nil/inactive on an expired canvas; a separate strict test assertion can detect misuse. Lock after has no effect and extend returns nil/inactive (API §15), rather than being absent. These are contract facts, not device measurements.

Baseline discrepancies reserved for M1: Pebble PRIMARY dismissal does not increment generation, and RESET of Ready is a no-op; PRD §9 explicitly requests generation increments. Resolve and document before implementing those commands.
