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
                created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

        CREATE INDEX idx_migrations__is_system_migration__created_at__migration_path ON
            migrations (
                is_system_migration,
                created_at,
                migration_path
            );

        CREATE INDEX idx_migrations__created_at__migration_path ON
            migrations (
                created_at,
                migration_path
            );

        CREATE INDEX idx_migrations__migration_path__created_at ON
            migrations (
                migration_path,
                created_at
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
