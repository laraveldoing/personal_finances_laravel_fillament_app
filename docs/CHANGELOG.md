# Changelog

## [2026-09-21]

### MySQL database container for local development
- **Modules affected:** none in the application yet — adds root-level local infrastructure.
- **Implementation:** new `docker-compose.yml` with a single `mysql` service (`mysql:8.4`, named
  `mysql-data` volume, `personal-finances` bridge network, `mysqladmin ping` healthcheck with a 30 s
  `start_period`, host port published as `127.0.0.1:${FORWARD_DB_PORT:-3306}`). Credentials and
  database name are read from the standard Laravel `DB_*` variables, with development-only
  fallbacks so the stack starts before the app is scaffolded. No `.env`/`.env.example` was created
  by this change: the Laravel scaffold owns those files.
- **Technical decisions:** MySQL 8.4 (supported LTS; 8.0 reached EOL on 2026-04-30, 9.7 rejected as
  unnecessary for this stack); database-only stack, the app keeps running on the host; the port is
  bound to loopback to avoid exposing the development database; the healthcheck reads the password
  from the container environment instead of interpolating it into the compose config. Full reasoning
  in `/plans/mysql-docker-container.md`.
- **Open items:** the repository still contains no Laravel application; scaffolding it (and deciding
  whether it should also run in Docker) is tracked in `/plans/_index.md`.
