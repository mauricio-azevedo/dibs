# Requirements

What dibs must do, each with an ID. Tests cite it: `@DisplayName("R2.4 confirm consumes an active reservation exactly once")`. PR bodies name the requirement they serve, by ID.

IDs are append-only. A requirement that turns out wrong is superseded by a new one and marked here; it is never renumbered or reused, because the ID is already in test names and in merged history. Behavior no requirement covers is an open question at the bottom of this file first, then an issue.

"Proven by" says where the evidence has to live: `unit` is plain JUnit over the domain, `integration` boots against Postgres from Testcontainers, `concurrency` runs many callers or processes at once, `recovery` kills something.

## R1 Inventory accounting

| ID | Requirement | Proven by |
|---|---|---|
| R1.1 | The accounting equation in ADR-0003 holds after every committed operation. Every state-changing test asserts it, not just the response. | unit, integration |
| R1.2 | Units held by active reservations plus committed units never exceed the inventory accounted for. | concurrency |
| R1.3 | Available inventory is never negative. | integration |
| R1.4 | A reservation succeeds only when its full quantity is available at the point it commits. Partial holds do not exist. | unit, integration |
| R1.5 | A stock adjustment records its cause and does not invalidate an active reservation. | integration |
| R1.6 | A command naming an unknown SKU is rejected and changes no inventory. | unit |

## R2 Reservation lifecycle

| ID | Requirement | Proven by |
|---|---|---|
| R2.1 | A reservation is `ACTIVE`, `CONFIRMED`, `CANCELLED` or `EXPIRED`. The last three are terminal. | unit |
| R2.2 | A reservation reaches exactly one terminal state. It is never both confirmed and released. | unit, concurrency |
| R2.3 | A command against a terminal reservation is rejected and changes no inventory. | unit |
| R2.4 | Confirm consumes a still-active reservation exactly once. | unit, concurrency |
| R2.5 | Cancel releases an active reservation exactly once. | unit, concurrency |
| R2.6 | Expire releases an overdue active reservation exactly once. | integration |
| R2.7 | Releasing never returns units already committed by a confirmation. | unit, concurrency |
| R2.8 | Confirm and expire running concurrently at the deadline resolve to one terminal state, by the rule in ADR-0005. | concurrency |
| R2.9 | A deadline is the creation time from the injected `Clock` plus the configured TTL, compared by the rule in ADR-0005. | unit |
| R2.10 | A query returns the durable state, SKU, quantity and the timestamp of each transition. | integration |
| R2.11 | A quantity that is zero, negative, fractional or above the configured maximum is rejected before any inventory effect. | unit |

## R3 Idempotency

| ID | Requirement | Proven by |
|---|---|---|
| R3.1 | Retrying a command under the same idempotency key produces no additional reservation and no additional inventory effect. | concurrency |
| R3.2 | A replay returns the outcome defined by ADR-0006. | integration |
| R3.3 | The same key with a different payload returns a conflict and creates no hold. | integration |
| R3.4 | Deduplication records survive a restart. | recovery |
| R3.5 | A key is scoped and retained as ADR-0006 defines; a key outside its scope is a different command. | integration |
| R3.6 | Confirm and cancel are idempotent by the identity ADR-0006 names. | unit, integration |

## R4 Concurrency and durability

| ID | Requirement | Proven by |
|---|---|---|
| R4.1 | Concurrent commands on one SKU cannot overwrite each other's inventory effect. | concurrency |
| R4.2 | With 10 units available and 1,000 concurrent requests for 1 unit, exactly 10 succeed and 990 are rejected for insufficient stock. | concurrency |
| R4.3 | Two or more service processes competing for the same SKU do not oversell. | concurrency |
| R4.4 | Commands for different SKUs make progress without serializing on each other. | concurrency |
| R4.5 | A reservation decision and its inventory effect commit together or not at all. | integration |
| R4.6 | An acknowledged outcome is discoverable after a restart. | recovery |
| R4.7 | A crash before commit leaves no effect; a crash after commit leaves exactly one. | recovery |
| R4.8 | Overdue reservations are released after downtime without operator action. | recovery |
| R4.9 | Two expiration workers cannot release the same reservation twice. | concurrency |
| R4.10 | Re-running recovery leaves every total unchanged. | integration |
| R4.11 | An expiration job delivered late cannot release inventory a later confirmation committed. | concurrency |
| R4.12 | A transaction retried after a serialization failure or deadlock leaves exactly one effect. | concurrency |

## R5 HTTP contract

| ID | Requirement | Proven by |
|---|---|---|
| R5.1 | Every response matches `docs/openapi.yaml`. The file is the contract; a divergence is a defect in the code. | integration |
| R5.2 | Malformed input, insufficient stock, idempotency conflict, invalid transition, unknown reservation, unknown SKU and transient infrastructure failure are distinguishable by a machine-readable error code. | integration |
| R5.3 | An error code is stable. Removing one or changing what it means is a breaking change. | integration |
| R5.4 | Liveness and readiness answer separately, on the management port. `/healthz` does no I/O and takes no lock; `/readyz` reports the dependencies the service cannot serve without. | integration |

## R6 Audit

| ID | Requirement | Proven by |
|---|---|---|
| R6.1 | Every inventory-changing operation writes a durable movement carrying its cause. | integration |
| R6.2 | Movement history is append-only. No movement is updated or deleted. | integration |
| R6.3 | Replaying movements reproduces the stored stock state. | integration |
| R6.4 | A reconciliation mismatch is reported for an operator to act on, never silently repaired. | integration |

## R7 Events

Deferred until synchronous correctness is proven. Transport is undecided; see the open questions.

| ID | Requirement | Proven by |
|---|---|---|
| R7.1 | An event is emitted only for a state change that committed. | integration |
| R7.2 | A crash between commit and publication does not lose the event. | recovery |
| R7.3 | Duplicate delivery of one event produces one downstream effect. | integration |
| R7.4 | Delivery is at-least-once and unordered. An ordering guarantee exists only where an ADR states it. | integration |
| R7.5 | A permanently invalid message is isolated and diagnosable without stopping the stream. | integration |
| R7.6 | Concurrent publishers do not starve one another. | concurrency |

## R8 Operability

Deferred until there is something to operate.

| ID | Requirement | Proven by |
|---|---|---|
| R8.1 | A command emits one log line at its end carrying trace id, command id, reservation id, SKU and outcome, and no secrets or personal data. | integration |
| R8.2 | Metrics expose reservation outcomes, idempotent replays, transition conflicts, expiration lag, worker retries, event backlog and processing latency. Never a trace id as a label. | integration |
| R8.3 | Shutdown finishes or abandons in-flight work without losing or duplicating an inventory effect. | recovery |
| R8.4 | A missing or malformed configuration value fails the start, before the listener opens. | integration |

## Open questions

Each blocks the requirements beside it and lands as an ADR in `docs/decisions/`, in the PR that first needs it.

| Decision | Blocks | ADR |
|---|---|---|
| The inventory accounting model, as one equation. Everything else is built on it. | R1.1 | 0003 |
| The serialization point for competing reservations of one SKU, and whether different SKUs serialize. | R4.1–R4.4, R4.12 | 0004 |
| Which of confirm and expire wins at the deadline, the authoritative clock, and how deadline equality is compared. | R2.8, R2.9 | 0005 |
| Idempotency key scope, retention, payload comparison, and whether a replay returns the original snapshot or current state. | R3.2, R3.5, R3.6 | 0006 |
| Event transport, durable publication, and any ordering guarantee offered. | R7.1–R7.6 | later |
| How a caller is authenticated, and the ASVS chapter it is checked against. Until it is answered, `security-defined` is off in `config/redocly.yaml` and the contract declares no scheme. | R5.1 | later |
