#!/usr/bin/env bash

up() {
    sqlite <<-'SQL'
        BEGIN;

        CREATE TABLE
            migrations_settings (
                version integer NOT NULL
            );

        INSERT INTO
            migrations_settings (
                version
            )
        VALUES
            (
                1
            );

        COMMIT;
SQL
}

down() {
    sqlite <<-'SQL'
        BEGIN;

        DROP TABLE
            migrations_settings;

        COMMIT;
SQL
}
