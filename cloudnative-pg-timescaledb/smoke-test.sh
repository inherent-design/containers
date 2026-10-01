#!/bin/sh
# Validate the image inside a disposable container as its default postgres user.
# PG_MAJOR selects the binaries; TIMESCALEDB_VERSION optionally asserts a version.
set -eu

PG_MAJOR=${PG_MAJOR:-18}
export PATH="/usr/lib/postgresql/$PG_MAJOR/bin:$PATH"
if [ "$(id -u)" -ne 26 ]; then
  echo "Run the smoke test as the image's default postgres user (UID 26)" >&2
  exit 1
fi

# Check that the server and supported backup commands can start.
postgres --version
for command in \
  barman-cloud-backup \
  barman-cloud-wal-archive \
  barman-cloud-check-wal-archive \
  barman-cloud-wal-restore \
  barman-cloud-restore
do
  "$command" --version
done

# Keep test data and the Unix socket in a temporary directory; disable TCP.
work_dir=$(mktemp -d)
cleanup() {
  pg_ctl -D "$work_dir/data" -m immediate stop >/dev/null 2>&1 || true
  rm -rf "$work_dir"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

initdb -D "$work_dir/data" --auth-local=trust --auth-host=reject --no-locale >/dev/null
if ! pg_ctl -D "$work_dir/data" -l "$work_dir/postgres.log" \
  -o "-k $work_dir -c listen_addresses='' -c shared_preload_libraries=timescaledb,pgaudit" -w start; then
  cat "$work_dir/postgres.log" >&2
  exit 1
fi

# Exercise extension creation and basic SQL queries.
psql -X -v ON_ERROR_STOP=1 -h "$work_dir" -d postgres <<'SQL'
CREATE EXTENSION timescaledb;
CREATE EXTENSION vector;
CREATE EXTENSION pgaudit;
CREATE TABLE measurements (time timestamptz NOT NULL, value integer);
SELECT create_hypertable('measurements', by_range('time'));
INSERT INTO measurements VALUES ('2026-01-01', 42);
DO $$
BEGIN
  IF (SELECT sum(value) FROM measurements) IS DISTINCT FROM 42 THEN
    RAISE EXCEPTION 'hypertable data mismatch';
  END IF;
  IF ('[1,2,3]'::vector <-> '[1,2,3]'::vector) <> 0 THEN
    RAISE EXCEPTION 'vector distance mismatch';
  END IF;
END $$;
SELECT extname, extversion FROM pg_extension ORDER BY extname;
SQL

if [ -n "${TIMESCALEDB_VERSION:-}" ]; then
  actual_version=$(psql -X -At -h "$work_dir" -d postgres \
    -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb'")
  if [ "$actual_version" != "$TIMESCALEDB_VERSION" ]; then
    echo "Expected TimescaleDB $TIMESCALEDB_VERSION, found $actual_version" >&2
    exit 1
  fi
fi

echo "Runtime extensions and backup commands validated"
