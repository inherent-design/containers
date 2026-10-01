#!/bin/sh
# Run on disposable storage, as the image's default postgres user.
set -eu

PG_MAJOR=${PG_MAJOR:-18}
export PATH="/usr/lib/postgresql/$PG_MAJOR/bin:$PATH"
test "$(id -u)" = 26
postgres --version
for bin in barman-cloud-backup barman-cloud-wal-archive barman-cloud-check-wal-archive barman-cloud-wal-restore barman-cloud-restore; do
    "$bin" --version
done

# Exercise CNPG's complete/partial WAL collision without cloud credentials.
python3 - <<'PY'
from unittest.mock import patch
from barman.clients import cloud_walrestore

wal = "000000010000000000000001"
prefix = "fixture/cluster/wals/0000000100000000/"
for suffix in ("", ".zst"):
    complete = prefix + wal + suffix
    partial = prefix + wal + ".partial" + suffix
    for listing in ([partial, complete], [complete, partial]):
        with patch("barman.clients.cloud_walrestore.get_cloud_interface") as provider:
            cloud = provider.return_value
            cloud.path = "fixture"
            cloud.list_bucket.return_value = listing
            # A serial restore must also work when no spool directory is writable.
            with patch("barman.cloud.os.makedirs", side_effect=PermissionError):
                cloud_walrestore.main(["s3://fixture", "cluster", wal, "/tmp/restored-wal"])
            assert cloud.download_file.call_count == 1
            assert cloud.download_file.call_args.args[0] == complete
print("Barman prefers complete WAL files without requiring a spool directory")
PY

work=$(mktemp -d)
cleanup() {
    pg_ctl -D "$work/data" -m immediate stop >/dev/null 2>&1 || true
    rm -rf "$work"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
initdb -D "$work/data" --auth-local=trust --auth-host=reject --no-locale >/dev/null
pg_ctl -D "$work/data" -l "$work/postgres.log" \
    -o "-k $work -c listen_addresses='' -c shared_preload_libraries=timescaledb,pgaudit" -w start || {
    cat "$work/postgres.log"
    exit 1
}

psql -X -v ON_ERROR_STOP=1 -h "$work" -d postgres <<'SQL'
CREATE EXTENSION timescaledb;
CREATE EXTENSION vector;
CREATE EXTENSION pgaudit;
CREATE TABLE measurements (time timestamptz NOT NULL, value integer);
SELECT create_hypertable('measurements', by_range('time'));
INSERT INTO measurements VALUES ('2026-01-01', 42);
DO $$ BEGIN
  IF (SELECT sum(value) FROM measurements) <> 42 THEN
    RAISE EXCEPTION 'hypertable data mismatch';
  END IF;
  IF ('[1,2,3]'::vector <-> '[1,2,3]'::vector) <> 0 THEN
    RAISE EXCEPTION 'vector distance mismatch';
  END IF;
END $$;
SELECT extname, extversion FROM pg_extension ORDER BY extname;
SQL

actual=$(psql -X -At -h "$work" -d postgres -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb'")
if [ -n "${TIMESCALEDB_VERSION:-}" ]; then
    test "$actual" = "$TIMESCALEDB_VERSION"
fi
echo "Runtime extensions and backup commands validated"
