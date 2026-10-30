---
status: accepted
date: 2026-10-30
---

# Spring Boot on Java 25, built with Maven

## Context and Problem Statement

Dibs is a small HTTP service in front of PostgreSQL whose risk is correctness under concurrency, not
scale. Which runtime, framework and build tool carry it, given that `CONTRIBUTING.md` asks for boring
technology and a gate that runs the same way locally and in CI?

## Considered Options

- Spring Boot on the JVM, built with Maven
- Spring Boot on the JVM, built with Gradle
- Quarkus or Micronaut on the JVM
- A non-JVM stack

## Decision Outcome

Chosen option: "Spring Boot on the JVM, built with Maven", because

- It is the most documented path for a JVM service. Every problem has a public answer, which is what
  boring means.
- Spring Boot 4.1 is in open-source support until 2027-07 and Java 25 is the current LTS, so neither
  needs a major bump before the service has users.
- The gate `CONTRIBUTING.md` asks for exists off the shelf: Testcontainers with `@ServiceConnection`,
  test slices, Flyway and Actuator probes are configuration, not code.
- Maven is declarative, and its wrapper is a committed script: a fresh clone needs only a JDK and
  Docker, and the build cannot drift with a developer's tooling.

### Consequences

- Good, because a developer new to Java can follow the reference documentation and land on this
  project's conventions.
- Bad, because a JVM process starts in seconds and holds hundreds of megabytes; the smallest instance
  class is not an option.
- Bad, because Maven's XML is verbose, and plugin configuration is the price of every gate step.
- Worth revisiting if startup time or memory becomes a cost, for example a scale-to-zero deployment,
  where Quarkus or a native image would pay off.
