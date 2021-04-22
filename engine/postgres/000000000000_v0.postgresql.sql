-- 00000000000000_v0.postgresql.sql
-- MIGRATE UP BEGIN

BEGIN;

CREATE SCHEMA
	migration;

CREATE TABLE
	migration.migrations (
		rowid SERIAL PRIMARY KEY,
		migration_path text NOT NULL,
		sha1sum text NOT NULL,
		is_system_migration boolean NOT NULL DEFAULT false,
		run_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
		UNIQUE (migration_path)
	);

CREATE INDEX ON
	migration.migrations (
		is_system_migration,
		run_at,
		migration_path
	);

CREATE INDEX ON
	migration.migrations (
		run_at,
		migration_path
	);

CREATE INDEX ON
	migration.migrations (
		migration_path,
		run_at
	);

COMMIT;

-- MIGRATE UP END
-- MIGRATE DOWN BEGIN

BEGIN;

DROP TABLE
	migration.migrations;

DROP SCHEMA
	migration;

COMMIT;

-- MIGRATE DOWN END
