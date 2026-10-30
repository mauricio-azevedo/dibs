# Contributing

## Branches and merges

- Trunk-based. Every change to `main` comes through a PR; the ruleset enforces it.
- `main` is always deployable. Every merge could go to production; the gate, squash and short branches exist to keep that true.
- Unfinished work merges behind a feature flag, off by default. A change that takes days still merges on day one. The PR that turns the flag on removes it, or opens the issue that will; a flag nobody remembers is dead code with a switch.
- Small PRs, readable in fifteen minutes. One self-contained change.
- Every branch starts from an issue: `gh issue develop <number> --checkout`. The branch is linked, so the PR closes the issue on merge; no `Closes #123`.
- Issues use the forms in `.github/ISSUE_TEMPLATE/`. Blank issues are off, so every issue has what's needed to act on it.
- Squash only. Merge commits and rebase merges are disabled in repo settings.
- PR title is a [Conventional Commit](https://www.conventionalcommits.org/): `type(scope): summary`. It becomes the squash commit message, so it is the only line that survives. `!` marks a breaking change: a correct caller would fail.
- CI checks the title with [action-semantic-pull-request](https://github.com/amannn/action-semantic-pull-request). PR body comes from `.github/pull_request_template.md`.
- The body names the requirement the change serves, by ID. Behavior no requirement covers is an open question there first, settled in an issue.

## Review

- Approve when the change improves the overall health of the codebase, even if it isn't perfect. Block only on what the sections below require. Reference: [Google's code review guide](https://google.github.io/eng-practices/review/).
- Look in this order: design, behavior, complexity, tests, naming, comments, style, documentation. A review that starts at style never reaches design.
- Every comment says why. Optional ones start with `Nit:` so the author knows they don't block. Within a business day, or say when.
- With one person on the project, review is self-review plus an agent review, and the ruleset requires CI only. With a team, one approval.

## Running locally

- `make dev` brings everything up from a fresh clone. `make down` stops and removes it.
- Prerequisites: Docker, and the JDK in `.java-version`. Not Maven: `./mvnw` downloads the pinned version itself.
- Config comes from `.env`, not committed. `make dev` creates it from `.env.example` when missing. The example lists every variable with a safe local default; add a line there when the code reads a new one.

## Code

Review checks these. Where a tool does too, the bullet says so.

- Strictest mode the language has. An escape hatch (`@SuppressWarnings`, a raw type, a cast to `Object`) means the type isn't understood yet. The linter rejects them.
- Explicit names. The name says what the thing does, not how it was built. Names come from `docs/glossary.md`; a change that introduces a concept adds its term in the same PR, so the word in the code, the documents and the review is one word.
- Focused files. A big file is usually a file doing more than one thing.
- Comments explain why. What is already in the code; if it isn't, fix the code.
- Errors are handled where there is something to do about them, otherwise they propagate. Queues fail, databases go down, networks flap; the sad path is part of the feature.
- Adding a dependency is a decision: license, maintenance, size. A large one gets an ADR.
- Durable state and its externally visible effects don't diverge after a partial failure. A row committed with its event never sent, or the reverse, is a design bug, not a network one.
- Anything that can be retried is safe to run twice, or detects that it already ran.
- Delivery is at-least-once and unordered until something proves otherwise. Consumers tolerate duplicates; an ordering requirement is written down.
- Old and new versions run at once during every deploy. Schema migrations live in the PR, run forward only, and work with both: add, deploy, backfill, drop in a later PR. Events and APIs the same: a breaking change keeps the old behavior beside the new until every consumer has moved. The `!` goes on the PR that removes the old behavior, since that is when a correct caller fails.
- Migrations are immutable once merged. To correct one, add another.
- Logic that decides is separate from code that does I/O, and gets its collaborators passed in rather than reaching for a global, so the decision is testable without a database. The clock is one of them: Checkstyle rejects `Instant.now()` and its siblings; take the time from an injected `Clock`.
- External systems sit behind an interface this code owns. The database, the broker and the vendor API are details at the edge.
- Boring technology, unless a concrete benefit is written down; in an ADR if the choice is hard to reverse.
- The runtime and the base image are inside upstream support. [endoflife.date](https://endoflife.date/) is the reference; Dependabot bumps versions but does not notice an end of life.
- Config is parsed and validated before the listener opens. A missing or malformed value fails the start, so a rolling deploy keeps the previous version running instead of a misconfigured new one.
- The HTTP API is `docs/openapi.yaml`, the contract. Written first or generated from code, it is committed. `make api-lint` under `check` fails on a document that is not valid OpenAPI, by the rules in `config/redocly.yaml`. A change that breaks a correct client is a breaking change: `!` in the title, and `make api-diff` under `check` fails without it.
- Anything that takes input from the internet meets [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/) Level 1; anything holding personal data, Level 2.
- A change to auth, sessions, input handling, crypto or secrets names the ASVS chapter and the [cheat sheet](https://cheatsheetseries.owasp.org/) it was checked against, in the PR body.

## Stack

Spring Boot on the JVM, PostgreSQL.

- `make` targets wrap Maven, and CI calls the targets: `fmt-check` is Spotless with google-java-format, `lint` is Checkstyle with `config/checkstyle.xml`, `typecheck` is `test-compile` with `-Werror -Xlint:all`, `test` is the suites below, `build` is the Dockerfile plus a check that the image's JRE is the one in `.java-version`, `audit` is Trivy over the Java dependencies inside that image. A Maven goal reachable only by typing `./mvnw` is a step outside the gate.
- `.mvn/maven.config` applies `.mvn/settings.xml` to every `./mvnw` run: each repository id resolves to Maven Central. Dependency POMs leak private repositories into the build, and a repository the build does not need is a request it should not make.
- The JDK major lives in `.java-version`, read by CI's `setup-java`, the IDE and version managers. `pom.xml` and the Dockerfile name the same major, and `check` proves it: Enforcer fails a build whose JDK differs from `pom.xml`, `make build` fails an image whose JRE differs from `.java-version`. A bump touches all three in one PR.
- Packages: `domain`, `application`, `adapter.web`, `adapter.persistence`. Adapters depend on the core, never the reverse and never on each other; ArchUnit enforces it in `make test-unit`.
- The domain imports no framework. No Spring, no Jakarta, no Hibernate annotation under `domain`; ArchUnit enforces it in `make test-unit`. A domain type that imports a framework can only be exercised with that framework booted, which is how a unit suite becomes a slow one.
- Dependencies arrive through constructors. No field `@Autowired`, no setter injection; Checkstyle rejects the token, and a single constructor needs none. A type whose collaborators are not in its signature cannot be built in a test without a container.
- JPA entities stay inside the persistence adapter, behind repository interfaces the domain owns. An entity in a controller signature is a lazy-loading failure waiting for its first request outside a transaction.
- Transactions are declared on the application service, never on a controller or a repository, and never span a call to another system; ArchUnit enforces the placement. A transaction waiting on an HTTP response holds a pooled connection while the network decides.
- A write that races another write on the same row uses a conditional update or an explicit lock. Read-then-write in application code is a lost update, and for this service a lost update is an oversell.
- Flyway owns the schema: `src/main/resources/db/migration/V<n>__snake_case.sql`, forward only, immutable once merged. `ddl-auto` is `validate` and nothing else, so the running schema and the migrations cannot disagree silently.
- Money and quantities are `BigDecimal` or integers with an explicit scale, never `double`, and the column carries the same scale; Checkstyle rejects `double` and `float`. Binary floating point cannot represent a tenth.
- Inbound DTOs carry Bean Validation at the edge; the domain constructor still rejects its own invalid states. An annotation protects one entry point, a constructor protects every caller.
- `@SpringBootTest` is for cases where the wiring is what is under test. Slices (`@DataJpaTest`, `@WebMvcTest`) otherwise, plain JUnit for the domain. Context startup is the largest fixed cost in a Spring suite, and every distinct context configuration pays it again.
- PostgreSQL in tests comes from Testcontainers with `@ServiceConnection`, so no suite reads a URL from the developer's environment.
- Actuator serves `/healthz` and `/readyz` from the liveness and readiness groups, on the management port, not the public one. Probes are operational surface, not API.

## Decisions

- A decision that is hard to reverse, or that a newcomer would ask "why?" about, gets an ADR in `docs/decisions/`, in the PR that makes it. Database, sync or async, how services talk. Not naming, not formatting.
- One file per decision, `NNNN-title-with-dashes.md`, consecutive, in [MADR](https://adr.github.io/madr/) from the template. `status` carries the lifecycle: `proposed`, `accepted`, `rejected`, `deprecated`, `superseded by ADR-NNNN`.
- An accepted ADR's decision is not edited. A change of mind is a new ADR that supersedes the old one, and only the old one's status changes, to point forward.
- MADR's sections, under a page, plus "Revisit when", which MADR lacks and is required here: a decision that no evidence could overturn is a preference.
- Diagrams are [C4](https://c4model.com/) in Mermaid so GitHub renders them. A diagram in an ADR or a PR is at the C4 level its change needs.
- CONTRIBUTING holds how we work. ADRs hold why the system is shaped the way it is.

## Testing

Review checks these too.

- Tests are part of the change. A PR that changes behavior changes tests in the same PR, sad path included.
- TDD when you can: the test first, seen failing, then the code. A test that never failed proves nothing. A bug fix starts with the test that reproduces it. `make test-unit` is the loop; it runs in seconds.
- Test behavior, not implementation. A test that fails on a refactor that changed no behavior is testing the wrong thing.
- The name states the behavior, prefixed by the requirement ID it verifies: `@DisplayName("R4.1 rejects an expired token")`, not `testValidate`. IDs come from `docs/requirements.md`. A failure should say what broke without opening the file. One ID per test; a test that needs three is testing three things.
- Real dependencies, not mocks of them. A database test runs against a database the test starts itself with Testcontainers, so `make test` needs no service running first, only Docker, and each run starts clean. Mocks belong at boundaries we don't own.
- Fast and deterministic. No sleeps, no real network, no order dependence. A flaky test is fixed or deleted the day it flakes, never retried.
- Each kind is owed when its risk exists. Unit: always. Integration: the code touches a database, filesystem, broker or service. Contract: two independently deployed services call each other. E2E: critical paths, few. Load: throughput or latency is a requirement, and once to the breaking point for anything internet-facing, with the number and the failure mode in the runbook. Chaos: availability is; at minimum, a test that kills a dependency and checks the sad path.
- Unit, integration and contract run in `make check`. E2E runs there while it stays fast, otherwise on `main`. Load, chaos, a backup restore and a rollback rehearsal run on a schedule, quarterly at least, never in the PR gate.

## Observability

- Structured logs to stdout, one JSON object per line. The runtime environment collects; the code never opens a log file.
- One line per unit of work, at the end: who, what, how long, outcome, every field known by then. Not a narrative of steps. The test is that a failed request is explainable from its telemetry alone, without reproducing it.
- A trace id on everything. It arrives on the request or is minted there, goes out on every call, and sits on every log line, span and metric. OpenTelemetry, so the backend is config. Every line also carries the build's commit, so "which version served this" needs no timestamp arithmetic.
- Never a trace id as a metric label: one value per request is one time series per request, memory and query time that grow with traffic, and nothing left to aggregate over. Metric labels have a small fixed range of values.
- Levels mean something. `error`: someone acts. `warn`: degraded, self-healed. `info`: a business event happened. `debug`: off by default in production, on by config when a bug needs it.
- Errors are logged once, where they stop. A layer that can't handle an error passes it up without logging it.
- No secrets, no personal data in logs. Redact at the logger, not at each call site.
- Authentication failures, access denials and privilege changes are always logged, with who and what. That is the OWASP logging baseline, and the incident timeline.
- `/healthz` says the process is up. It does no I/O and takes no lock, so a starved process is not killed for being slow.
- `/readyz` says the dependencies the service cannot serve without are reachable. Soft dependencies stay out, so their outage degrades the service instead of removing it from rotation.
- An alert fires on a symptom, or on a definite and imminent cause such as a disk filling or a certificate expiring. A page or a ticket, never an email, and it holds for a few minutes so one incident is one alert.

## Production

- Nothing is deployed yet. Hosting is a hard-to-reverse decision, so it gets an ADR before the first deploy, and `make deploy` arrives in that PR. The intent today: AWS, an ECS Fargate service in `us-east-1`, Terraform in `infra/`, the image pushed to Amazon ECR.
- The [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/) is the reference for how; its review is part of the checklist.

## Incidents

- User-visible outage, data loss, or a rollback: each gets a postmortem in `docs/postmortems/`, from the template, within a week. Blameless: it names causes and fixes, never people.
- Every action item is an issue. A postmortem whose items are not issues is a story.
- During the incident, the runbook's first three lines apply: roll back before diagnosing, write down what you did with times, call the second person after an hour or when users can see it.

## Quality gate

- `make check` runs the whole gate. CI runs the same target, so green locally means green in CI.
- Each step is its own target: `make fmt-check`, `make lint`, `make typecheck`, `make test`, `make build`, `make audit`, `make api-lint`, `make api-diff`. Run one while iterating, `check` before pushing.
- `make fmt` rewrites files; `check` runs `fmt-check` instead. Everything under `check` only verifies and fails if it would change something; CI never rewrites.
- A failing check is fixed, not silenced. No skipped test, no lint-disable comment, no deleted assertion, no `--no-verify`. Green earned that way is red with a lie on top.
- `make audit` fails on a known vulnerability in the dependency tree. A transitive advisory with no fix available gets a severity floor on the target, not a skip: `AUDIT_SEVERITY` in the Makefile, every severity by default.
- No stubs under `check`. A target that prints "nothing configured" verifies nothing; it is filled or removed in the PR that notices.
- The runtime version is pinned in `.java-version`. CI installs exactly that one, so a version difference is a change to that file and not a surprise in a job log. `pom.xml` and the Dockerfile carry the same major; Stack says how `check` proves it.
- `make` alone lists the targets.
- Add a step by adding a target and putting it under `check`. A CI job outside `check` says why it is outside: the title check reads the PR, not the code; a scheduled job runs on time, not on a PR.

## CI

- `ci` runs `make check` on every PR and on push to `main`. It is a required check on `main`.
- `pr-title` validates the PR title. Outside `make check` because it reads the PR, not the code.
- Actions pinned to a full commit SHA, version in a comment: `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`. Tags can be moved ([tj-actions](https://github.com/advisories/GHSA-mrrh-fwg8-r2c3)); SHAs can't.
- Dependabot bumps the SHAs, the Maven dependencies and the image digests weekly, from `.github/dependabot.yml`. Its PR titles carry a Conventional Commit prefix so `pr-title` passes; `ci` gates them like any other PR.

## Board

- Work is tracked on the [Dibs project board](https://github.com/users/mauricio-azevedo/projects/14). Every open issue has a card. A PR gets no card of its own: it moves the card of the issue it was branched from.
- Columns: Backlog → Ready → In progress → In review → Done. Backlog: new. Ready: scoped, next in line. In progress: branch created. In review: PR open. Done: merged or closed.
- Automatic, by the board's own workflows: a new issue lands in Backlog; a closed issue moves to Done. Manual: Ready, In progress, In review — Projects v2 has no automation that moves a linked issue when its PR opens.
- From the CLI: `gh project item-edit` moves a card; `gh project item-list 14 --owner mauricio-azevedo` shows the board.

## Repository settings

What the buttons do, so none of it is a surprise mid-merge.

- Squash is the only merge button. Merge commits and rebase merging are disabled, so history on `main` is one commit per PR and `git log` reads as a list of changes.
- The squash message is the PR title with an empty body. The title is the only line that survives, which is why CI validates it.
- Merged branches are deleted automatically. A branch outliving its PR is a branch someone will push to.
- Linked issues close on merge, so a branch created from an issue needs no `Closes #123`.
- Auto-merge is on. Arm it and the PR lands when the checks go green, without you watching them.
- "Update branch" is allowed, which is how a stale branch gets current without a merge commit.
- Secret scanning and push protection are on: a pushed credential is rejected at the push, not found later in history.
- Actions must be pinned to a full commit SHA. A tag reference (`@v4`) is rejected, because a tag can be moved under you.

## Rulesets

The ruleset on `main` is what actually stops a mistake. It has no bypass actors: it applies to the owner too.

- No direct pushes. Every change lands through a squash-merged PR.
- No deletion, no force push, linear history required. `main` only moves forward.
- A PR branch must be up to date with `main` before it can merge. Rebase; do not merge `main` in.
- Required checks: `ci` and `pr-title`. Both must pass.

Two ways this bites:

- The required checks are job ids. Rename a job and every PR waits forever, with nothing saying why.
- Auto-merge lands a few minutes after green. A PR sitting on a clean status means it was armed too late; merge it directly.
