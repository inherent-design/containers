#!/bin/sh
set -eu
# Only disposable fixture data is mounted; no production data is accessed.
old=${1:?usage: upgrade-test.sh OLD_IMAGE NEW_IMAGE}
new=${2:?usage: upgrade-test.sh OLD_IMAGE NEW_IMAGE}
platform=${PLATFORM:-linux/amd64}
volume="containers-refresh-upgrade-$$"
docker volume create "$volume" >/dev/null
trap 'docker volume rm "$volume" >/dev/null' EXIT
docker run --rm --platform "$platform" --user 0 --entrypoint sh -v "$volume:/test" "$new" -c 'chown 26:26 /test'
docker run --rm -i --platform "$platform" --entrypoint sh -v "$volume:/test" "$old" -s <<'OLD'
set -eu
export PATH="/usr/lib/postgresql/18/bin:$PATH"
initdb -D /test/data --auth-local=trust --auth-host=reject --encoding=UTF8 --locale=en_US.utf8 >/dev/null
trap 'pg_ctl -D /test/data -m fast -w stop' EXIT
pg_ctl -D /test/data -l /test/old.log -o "-k /test -c listen_addresses='' -c shared_preload_libraries=timescaledb,pgaudit" -w start
psql -X -v ON_ERROR_STOP=1 -h /test -d postgres <<'SQL'
-- The published May 2026 image has a mismatched loader; select its installed version.
CREATE EXTENSION timescaledb VERSION '2.26.2';
CREATE EXTENSION vector;
CREATE EXTENSION pgaudit;
CREATE TABLE measurements (time timestamptz NOT NULL, device text, value integer);
SELECT create_hypertable('measurements', by_range('time'));
INSERT INTO measurements SELECT '2026-01-01'::timestamptz + n * interval '1 hour', 'test', n FROM generate_series(1,100) n;
ALTER TABLE measurements SET (timescaledb.compress, timescaledb.compress_segmentby='device');
SELECT compress_chunk(i) FROM show_chunks('measurements') i;
CREATE MATERIALIZED VIEW hourly WITH (timescaledb.continuous) AS SELECT time_bucket('1 day', time) AS bucket, sum(value) AS total FROM measurements GROUP BY 1 WITH NO DATA;
CALL refresh_continuous_aggregate('hourly', NULL, NULL);
CREATE TABLE words (word text PRIMARY KEY);
INSERT INTO words VALUES ('alpha'), ('Zulu'), ('éclair'), ('ångström');
SELECT datcollversion FROM pg_database WHERE datname = current_database();
SELECT extname,extversion FROM pg_extension;
SQL
OLD
docker run --rm -i --platform "$platform" --entrypoint sh -v "$volume:/test" "$new" -s <<'NEW'
set -eu
export PATH="/usr/lib/postgresql/18/bin:$PATH"
trap 'pg_ctl -D /test/data -m fast -w stop' EXIT
pg_ctl -D /test/data -l /test/new.log -o "-k /test -c listen_addresses='' -c shared_preload_libraries=timescaledb,pgaudit" -w start || { cat /test/new.log; exit 1; }
psql -X -v ON_ERROR_STOP=1 -h /test -d postgres <<'SQL'
-- TimescaleDB must be updated before any command can load its old version.
ALTER EXTENSION timescaledb UPDATE;
ALTER EXTENSION vector UPDATE;
ALTER EXTENSION pgaudit UPDATE;
-- OS upgrades can change libc sort rules. Rebuild before refreshing the version.
REINDEX DATABASE postgres;
ALTER DATABASE postgres REFRESH COLLATION VERSION;
DO $$ BEGIN
  IF (SELECT count(*) FROM words) <> 4 THEN RAISE EXCEPTION 'collated data mismatch'; END IF;
  IF (SELECT datcollversion IS DISTINCT FROM pg_database_collation_actual_version(oid) FROM pg_database WHERE datname=current_database()) THEN RAISE EXCEPTION 'collation version mismatch'; END IF;
  IF (SELECT sum(value) FROM measurements) <> 5050 THEN RAISE EXCEPTION 'hypertable data mismatch'; END IF;
  IF (SELECT sum(total) FROM hourly) <> 5050 THEN RAISE EXCEPTION 'aggregate mismatch'; END IF;
  IF (SELECT installed_version <> default_version FROM pg_available_extensions WHERE name='timescaledb') THEN RAISE EXCEPTION 'version mismatch'; END IF;
END $$;
CALL refresh_continuous_aggregate('hourly', NULL, NULL);
INSERT INTO measurements VALUES ('2026-01-10', 'test', 101);
SELECT extname, extversion FROM pg_extension;
SQL
NEW
