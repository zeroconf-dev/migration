-- 00000000000000_v1.postgresql.sql
-- MIGRATE UP BEGIN

BEGIN;

CREATE TABLE
	migration.settings (
		version integer NOT NULL
	);

INSERT INTO
	migration.settings (
		version
	)
VALUES
	(
		1
	);

COMMIT;

-- MIGRATE UP END
-- MIGRATE DOWN BEGIN

BEGIN;

DROP TABLE
	migration.settings;

COMMIT;

-- MIGRATE DOWN END
