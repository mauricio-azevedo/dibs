# Glossary

Terms used in dibs code and documentation. One word per concept: the word here is the word in the code, the API, the tests and the review.

How the quantities relate to one another is ADR-0003, not this file. This file only fixes the names.

## Available

Units that can be newly reserved.

## Committed

Units consumed by a confirmed reservation. Committed units are gone; releasing a reservation never returns them.

## Idempotency key

A client-provided identity for one logical command, stable across the client's retries. Two commands with the same key are the same command; the same key with a different payload is a conflict.

## Inventory

The units of a SKU the service accounts for, in all their states: on-hand, reserved, committed.

## Movement

One append-only record of an inventory change, carrying its cause. Movements are never updated or deleted; a correction is another movement.

## On-hand

Physical units recorded for a SKU.

## Reservation

A durable claim on a quantity of one SKU, with a deadline.

`ACTIVE` while it holds its units. Then exactly one terminal state: `CONFIRMED` when the units are committed to an order, `CANCELLED` when released explicitly, `EXPIRED` when released because the deadline passed.

## Reserved

Units held by active reservations.

## SKU

Identifies one stock-keeping unit. The unit of inventory and the unit of contention: reservations compete per SKU.

## Stock adjustment

An auditable correction or addition to on-hand units. An adjustment never invalidates an active reservation.
