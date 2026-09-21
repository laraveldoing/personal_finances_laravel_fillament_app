# MySQL database container (Docker Compose)

## Status
`complete`

## Verification evidence (2026-09-21)

Run against `docker compose` v5.5.1 with no `.env` present (development fallbacks in effect):

| Check | Command | Observed |
|---|---|---|
| Config valid | `docker compose config --quiet` | exit 0, no output |
| Only one service | `docker compose config --services` | `mysql` |
| Healthcheck keeps the password out of the config | `docker compose config \| grep -A3 healthcheck` | `CMD-SHELL`, `mysqladmin ping -h 127.0.0.1 -u root -p"$$MYSQL_ROOT_PASSWORD" --silent` |
| Container starts and becomes healthy | `docker compose up -d` + `docker compose ps` | `Up (healthy)` after ~42 s (first boot), `127.0.0.1:3306->3306/tcp` |
| App credentials work | `docker compose exec -T mysql mysql -ularavel -ppassword -e "SELECT VERSION(), DATABASE();" personal_finances` | `8.4.11` / `personal_finances` |
| Database exists | `... -e "SHOW DATABASES;"` | includes `personal_finances` |
| Database is writable | `... -e "CREATE TABLE persistence_check (...); INSERT ...; SELECT ...;"` | `CREATE`/`INSERT` exit 0, 1 row returned |
| Data survives a stop/start cycle | `docker compose down` → `docker compose up -d` → re-query | `healthy` again after ~9 s, rows `1` and `2` still returned |
| Volume is a named volume | `docker volume ls` | `personal_finances_laravel_fillament_app_mysql-data` |

Artifact left by the write/persistence check: a `persistence_check` table in `personal_finances`.
It was dropped on request on 2026-09-21 (`DROP TABLE persistence_check` → exit 0, `SHOW TABLES`
empty afterwards) with the database, the `laravel` user and the named volume left intact, so the
manual overrides the app will inherit once it exists are now clean.

## Context
The app (Laravel + Filament, "personal finances") needs a MySQL server to connect to, running as a
Docker container and managed with Docker Compose. As of this task the repository only contains the
AI-guidelines library (`base/`, `frameworks/`, `languages/`, `documentation/`): there is no
`artisan`, no `composer.json`, no `.env` and no application code yet. The container is therefore
wired to **Laravel's own standard environment variable names** (`DB_HOST`, `DB_PORT`, `DB_DATABASE`,
`DB_USERNAME`, `DB_PASSWORD`, plus Sail's `FORWARD_DB_PORT`), so no env file has to be created or
duplicated now and nothing conflicts with the Laravel skeleton when it is scaffolded.

Scope is deliberately limited to the database container: the application keeps running on the host
(`php artisan serve` / `composer run dev`) and connects over `127.0.0.1`.

## Subtasks

- [x] 1. Write this plan file and register the task in `/plans/_index.md`
- [x] 2. Create `docker-compose.yml` with a single MySQL service (named volume, healthcheck,
      configurable host port, named network, no credentials hardcoded in the file)
- [x] 3. Verify the compose file and the running container end to end
  - [x] 3.1 `docker compose config` parses without errors and declares only the `mysql` service
  - [x] 3.2 Container reaches `healthy` and accepts connections with the configured credentials
  - [x] 3.3 The application's database exists and is writable
- [x] 4. Verify data persistence across a `down` / `up` cycle (named volume)
- [x] 5. Document: `docs/CHANGELOG.md` entry, close this plan and update `_index.md`

## Success criteria

### Subtask 1: plan written before code
One-line check: `/plans/mysql-docker-container.md` and `/plans/_index.md` exist and the index lists
this task as `in-progress` before any code file is created.

### Subtask 2: compose file is valid and declares only what was asked
```gherkin
Feature: MySQL service definition

  Scenario: The compose file parses and declares a single service
    Given the repository root
    When `docker compose config --quiet` is executed
    Then it exits 0 with no error output
    And `docker compose config --services` prints only `mysql`

  Scenario: No credential is hardcoded in the compose file
    Given `docker-compose.yml` is inspected
    When looking for literal passwords or the root password value
    Then every credential is a `${VAR}` reference with a development-only fallback
```

### Subtask 3: the database is reachable with the configured credentials
```gherkin
Feature: Database availability

  Scenario: Container becomes healthy
    Given `.env` sets DB_DATABASE=personal_finances, DB_USERNAME=laravel, DB_PASSWORD=password
    When `docker compose up -d` is executed and the healthcheck completes
    Then `docker compose ps` reports the `mysql` service as `healthy`

  Scenario: The application credentials work against the app database
    Given the container is healthy
    When `docker compose exec mysql mysql -ularavel -ppassword -e "SELECT VERSION(), DATABASE();" personal_finances` runs
    Then it exits 0 and prints a `8.4.x` version
    And `SHOW DATABASES` includes `personal_finances`

  Scenario: The database is writable from the application credentials
    Given the container is healthy
    When a table is created and a row inserted as the `laravel` user
    Then both statements exit 0
```

### Subtask 4: data survives a stop/start cycle
```gherkin
Feature: Persistence

  Scenario: Named volume keeps the data after the container is removed
    Given a table `persistence_check` exists in `personal_finances`
    When `docker compose down` then `docker compose up -d` are executed (no `-v`)
    Then `persistence_check` still exists after the container is healthy
```

### Subtask 5: documentation
One-line check: `docs/CHANGELOG.md` contains a dated entry for this change, and both this file and
`_index.md` are updated to `complete`.

## Decisions log

### D1: MySQL 8.4 instead of 9.7 or 8.0
- **Context:** the image tag decides the server version the app will develop against.
- **Options considered:** `mysql:8.4` (LTS, premier support to Apr 2029 / extended to 2032 —
  the tag Laravel Sail ships today); `mysql:9.7` (newest LTS, Apr 2026 → Apr 2034, far less
  represented in Laravel examples and tooling); `mysql:8.0` (**EOL since 30 Apr 2026** — rejected,
  no security backports).
- **Decision:** `mysql:8.4`, kept overridable with `MYSQL_IMAGE`-free simplicity: change the tag in
  the file when the project moves to 9.7.
- **Reason:** supported LTS, matches the Laravel ecosystem default, no EOL exposure. Reusing a tag
  a future production environment can also run matters more here than being on the newest LTS.
- **Reversibility:** costly (a version change later requires a dump/restore), easy if done before
  real data exists.

### D2: host port published on 127.0.0.1 only
- **Context:** the app runs on the host, so the port has to be reachable from outside the container.
- **Options considered:** `0.0.0.0:3306` (convenient, but exposes the dev database to anything that
  can reach the machine — meaningful in a Codespace, where forwarded ports can go public);
  `127.0.0.1:3306` (host only); no published port at all (breaks the "app on host" model).
- **Decision:** `127.0.0.1:${FORWARD_DB_PORT:-3306}:3306`.
- **Reason:** keeps the requested workflow working without widening exposure; the port is
  configurable per checkout through `FORWARD_DB_PORT`.
- **Reversibility:** easy.

### D3: `docker-compose.yml` as the file name
- **Context:** Compose v2 accepts both `compose.yaml` and `docker-compose.yml`.
- **Options considered:** `compose.yaml` (new CLI default); `docker-compose.yml` (Laravel
  documentation / Sail convention).
- **Decision:** `docker-compose.yml`.
- **Reason:** follows the framework convention this project is built on
  (`frameworks/laravel.md` rule: existing convention over a new default), and both Compose v2 and
  legacy `docker-compose` pick it up without flags.
- **Reversibility:** easy.

### D4: no `.env` / `.env.example` created by this task
- **Context:** the compose file needs credentials, but the repo has no `.env` and no Laravel
  skeleton yet; whichever file is created here is exactly the file the Laravel scaffold will also
  write.
- **Options considered:** create both files now (risk: clashes with the scaffold, and puts a
  placeholder root password in a tracked file); create only `.env` (gitignored, but the future
  `composer create-project` refuses the non-empty directory); create neither and rely on
  `${VAR:-default}` plus documentation.
- **Decision:** create none; the compose file consumes standard Laravel variable names with
  development-only fallbacks, and the required `.env` block is documented as a comment at the top
  of `docker-compose.yml`.
- **Reason:** no duplicated/conflicting config, no secret-looking values in tracked files, and
  `docker compose up -d` still works on a fresh clone.
- **Reversibility:** easy.

### D5: healthcheck reads the password from the container environment
- **Context:** Sail's stub does `test: ["CMD", "mysqladmin", "ping", "-p${DB_PASSWORD}"]`, which
  interpolates the literal password into the compose configuration.
- **Options considered:** Sail's literal interpolation (password visible in `docker compose config`
  output and in `ps`); `CMD-SHELL` with `$$MYSQL_ROOT_PASSWORD` (resolved inside the container from
  its own environment).
- **Decision:** `['CMD-SHELL', 'mysqladmin ping -h 127.0.0.1 -u root -p"$$MYSQL_ROOT_PASSWORD" --silent']`
  with `interval`, `timeout`, `retries` and a `start_period` (MySQL needs ~20 s for first-time
  initialisation).
- **Reason:** equivalent behaviour without leaking the password into compose output, and a
  `start_period` avoids reporting the normal first-boot delay as an unhealthy container.
- **Reversibility:** easy.

### D6: database-only stack (no app container, no admin UI)
- **Context:** the request is one container for the database the app connects to.
- **Options considered:** MySQL only; MySQL + phpMyAdmin/Adminer; full stack with the Laravel app
  in Docker (Sail).
- **Decision:** MySQL only. phpMyAdmin and containerising the app are offered at the end of the
  task instead of being added unasked.
- **Reason:** `base/03-safety-and-scope.md` (implement exactly what was asked) and
  `documentation/changelog-and-docs.md` (offer extra docs/services, don't create them unprompted).
- **Reversibility:** easy.

## Blockers / open questions

- The repository holds no Laravel application yet. Scaffolding it (`laravel new` /
  `composer create-project laravel/laravel .`) plus Filament is **out of scope** for this task and
  needs explicit confirmation — and it must happen before `.env` can hold the `DB_*` values.
  Note: `composer create-project` refuses to run in a non-empty directory, so the scaffold has to
  happen first (or in a temporary directory) if this repository root is meant to hold the app.
- Whether the application itself should also be containerized (Sail or a hand-written app service
  on the `personal-finances` network with `DB_HOST=mysql`) is undecided.
- _(Resolved 2026-09-21)_ The verification table `persistence_check` was dropped on request, keeping
  the database, the `laravel` user and the volume. `docker compose down -v` (full volume reset) was
  offered as the alternative and explicitly **not** used.

## Documentation produced

- `docker-compose.yml` — commented with usage, the `.env` block it expects, and the
  `DB_HOST=mysql` note for a future containerized app.
- `docs/CHANGELOG.md` — entry for this change.

---

## Follow-up increment (2026-09-21): Adminer

The base task above stays `complete`; this section tracks an addition requested afterwards: a web UI
to manage the database, choosing **Adminer** over phpMyAdmin (43.7 MB compressed / ~156 MB on disk
vs 196.6 MB compressed / ~500 MB on disk), with the application still running on the host.

### Subtask 6: add the Adminer service

- [ ] 6.1 Add an `adminer` service to `docker-compose.yml`, on the existing network, with no
      database credentials in its environment and reachable from the host only
- [ ] 6.2 Verify it serves the login page and reaches the database over the compose network
- [ ] 6.3 Document (this section, `_index.md`, `docs/CHANGELOG.md`)

```gherkin
Feature: Adminer web UI

  Scenario: The service is declared alongside the database
    Given the repository root
    When `docker compose config --services` is executed
    Then it lists `mysql` and `adminer`

  Scenario: The UI is reachable from the host only
    Given `docker compose up -d` completed and the database is healthy
    When `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8081` runs
    Then it returns `200`
    And `docker compose ps` shows the published port bound to `127.0.0.1`, not `0.0.0.0`

  Scenario: Adminer reaches the database over the compose network
    Given both containers are running
    When a TCP connection to host `mysql`, port `3306`, is opened from inside the Adminer container
    Then the connection succeeds

  Scenario: No credentials are stored in the Adminer service
    Given `docker-compose.yml` is inspected
    When looking at the `adminer` environment block
    Then it holds no `MYSQL_*`/`DB_PASSWORD` value — only the default server name, since Adminer
      asks for credentials at login
```

