#!/usr/bin/env bash

up() {
    sqlite <<-'SQL'
        BEGIN;

        CREATE TABLE
            migrations (
                rowid INTEGER PRIMARY KEY AUTOINCREMENT,
                migration_path text NOT NULL UNIQUE,
                sha1sum text NOT NULL,
                is_system_migration boolean NOT NULL DEFAULT false,
                run_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

        CREATE INDEX idx_migrations__is_system_migration__run_at__migration_path ON
            migrations (
                is_system_migration,
                run_at,
                migration_path
            );

        CREATE INDEX idx_migrations__run_at__migration_path ON
            migrations (
                run_at,
                migration_path
            );

        CREATE INDEX idx_migrations__migration_path__run_at ON
            migrations (
                migration_path,
                run_at
            );

        COMMIT;
SQL
}

down() {
    sqlite <<-'SQL'
        BEGIN;

        DROP TABLE
            migrations;

        COMMIT;
SQL
}
