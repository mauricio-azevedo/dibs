---
status: accepted
date: 2026-10-30
---

# PostgreSQL as the system of record

## Context and Problem Statement

Reservations must never oversell. The store has to make a conditional decrement atomic under concurrent
writers, hold an idempotency record in the same transaction as the write it protects, and move a
reservation between states without lost updates. Which store does that with the least machinery?

## Considered Options

- PostgreSQL
- MySQL
- DynamoDB, with conditional writes
- Redis, with Lua scripts for atomicity

## Decision Outcome

Chosen option: "PostgreSQL", because

- A conditional `UPDATE ... WHERE available >= :quantity RETURNING ...`, or `SELECT ... FOR UPDATE`, is
  the oversell guard in one statement, with no read-then-write in application code.
- One transaction covers the reservation row, its idempotency key and an outbox row, so durable state
  and its effects cannot diverge after a partial failure.
- Flyway, Testcontainers and the JDBC driver make the schema and the tests boring, and every developer
  runs the engine the service runs.
- It is the boring choice: well understood, offered managed on every cloud, with a long upstream
  support window.

### Consequences

- Good, because correctness rests on the database's transaction semantics, which are well understood
  and testable.
- Bad, because a single primary caps write throughput; horizontal scale needs partitioning this design
  does not do.
- Worth revisiting if write throughput exceeds what one primary serves, or if multi-region
  active-active becomes a requirement.
