# AGENTS.md

Dibs reserves inventory: no oversell, idempotent writes, safe state transitions.
Java 25, Spring Boot 4.1, Maven, PostgreSQL. The rules are `CONTRIBUTING.md`; the reasons are `docs/decisions/`.

## Commands

- `make dev` / `make down`: Postgres in Docker and the app on this JVM, up and down. Needs Docker and JDK 25, not Maven.
- `make test-unit`: seconds, no Docker. The loop.
- `make check`: the whole gate, identical to CI. Green before pushing.
- `make`: lists every target.

## Layout
- `src/main/java/io/github/mauricioazevedo/dibs/domain`: no framework imports. ArchUnit enforces it.
- `.../application`: use cases. `@Transactional` lives here and nowhere else.
- `.../adapter/web`: controllers and DTOs. `.../adapter/persistence`: JPA entities and repositories.
- `src/main/resources/db/migration/V<n>__snake_case.sql`: Flyway. Immutable once merged.
- `src/test/java`: same packages. `*Test` runs without Spring; `*IT` boots the context against Testcontainers.
- `docs/requirements.md` is where requirement IDs come from. `docs/openapi.yaml` is the API contract. `docs/glossary.md` is the only source of names.

## Done means

- The test came first and was seen failing, sad path included. `@DisplayName("R<id> <behavior>")` names the rule it verifies.
- `docs/glossary.md` has every new term. `docs/openapi.yaml` reflects every API change.
- A new dependency or a hard-to-reverse choice has an ADR in `docs/decisions/`, in the same PR.
- `make check` is green.

## Never

- Edit a merged migration. Add one.
- `@Autowired`, `@SuppressWarnings`, `double` for money, `Instant.now()`. Checkstyle rejects each; the fix is in CONTRIBUTING, not a suppression.
- `@SpringBootTest` unless the wiring is what is under test.
- Skip, retry or silence a failing check.
- Commit `.env`, or read config from anywhere but the environment.
