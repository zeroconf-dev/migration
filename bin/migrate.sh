#!/usr/bin/env bash

set -e

migrate() {
    DOC="Usage:
    migrate (g|generate) [--template=TEMPLATE] NAME
    migrate down [-pn NUM]
    migrate probe [-n NUM]
    migrate [up -pn NUM]

Options:
    -n --amount=NUM         The amount of migrations to go up or down, must be a positive number
                            0 is considered to be infinite.
    -t --template=TEMPLATE  Generate a new migration from a specific template.
    -p --paranoia           Convert shasum mismatch warning to error and quit the process.
EXAMPLE

Bring state up-to-date.

    $ migrate

Generate a new migration.

    $ migrate generate --template=postgres pg_create_users_template

Run 5 migrations forward.

    $ migrate up -n5

Reset state / run all down migrations.

    $ migrate down -n0
"
# docopt parser below, refresh this parser with `docopt.sh migrate.sh`
# shellcheck disable=2016,1075
docopt() { parse() { if ${DOCOPT_DOC_CHECK:-true}; then local doc_hash
if doc_hash=$(printf "%s" "$DOC" | (sha256sum 2>/dev/null || shasum -a 256)); then
if [[ ${doc_hash:0:5} != "$digest" ]]; then
stderr "The current usage doc (${doc_hash:0:5}) does not match \
what the parser was generated with (${digest})
Run \`docopt.sh\` to refresh the parser."; _return 70; fi; fi; fi
local root_idx=$1; shift; argv=("$@"); parsed_params=(); parsed_values=()
left=(); testdepth=0; local arg; while [[ ${#argv[@]} -gt 0 ]]; do
if [[ ${argv[0]} = "--" ]]; then for arg in "${argv[@]}"; do
parsed_params+=('a'); parsed_values+=("$arg"); done; break
elif [[ ${argv[0]} = --* ]]; then parse_long
elif [[ ${argv[0]} = -* && ${argv[0]} != "-" ]]; then parse_shorts
elif ${DOCOPT_OPTIONS_FIRST:-false}; then for arg in "${argv[@]}"; do
parsed_params+=('a'); parsed_values+=("$arg"); done; break; else
parsed_params+=('a'); parsed_values+=("${argv[0]}"); argv=("${argv[@]:1}"); fi
done; local idx; if ${DOCOPT_ADD_HELP:-true}; then
for idx in "${parsed_params[@]}"; do [[ $idx = 'a' ]] && continue
if [[ ${shorts[$idx]} = "-h" || ${longs[$idx]} = "--help" ]]; then
stdout "$trimmed_doc"; _return 0; fi; done; fi
if [[ ${DOCOPT_PROGRAM_VERSION:-false} != 'false' ]]; then
for idx in "${parsed_params[@]}"; do [[ $idx = 'a' ]] && continue
if [[ ${longs[$idx]} = "--version" ]]; then stdout "$DOCOPT_PROGRAM_VERSION"
_return 0; fi; done; fi; local i=0; while [[ $i -lt ${#parsed_params[@]} ]]; do
left+=("$i"); ((i++)) || true; done
if ! required "$root_idx" || [ ${#left[@]} -gt 0 ]; then error; fi; return 0; }
parse_shorts() { local token=${argv[0]}; local value; argv=("${argv[@]:1}")
[[ $token = -* && $token != --* ]] || _return 88; local remaining=${token#-}
while [[ -n $remaining ]]; do local short="-${remaining:0:1}"
remaining="${remaining:1}"; local i=0; local similar=(); local match=false
for o in "${shorts[@]}"; do if [[ $o = "$short" ]]; then similar+=("$short")
[[ $match = false ]] && match=$i; fi; ((i++)) || true; done
if [[ ${#similar[@]} -gt 1 ]]; then
error "${short} is specified ambiguously ${#similar[@]} times"
elif [[ ${#similar[@]} -lt 1 ]]; then match=${#shorts[@]}; value=true
shorts+=("$short"); longs+=(''); argcounts+=(0); else value=false
if [[ ${argcounts[$match]} -ne 0 ]]; then if [[ $remaining = '' ]]; then
if [[ ${#argv[@]} -eq 0 || ${argv[0]} = '--' ]]; then
error "${short} requires argument"; fi; value=${argv[0]}; argv=("${argv[@]:1}")
else value=$remaining; remaining=''; fi; fi; if [[ $value = false ]]; then
value=true; fi; fi; parsed_params+=("$match"); parsed_values+=("$value"); done
}; parse_long() { local token=${argv[0]}; local long=${token%%=*}
local value=${token#*=}; local argcount; argv=("${argv[@]:1}")
[[ $token = --* ]] || _return 88; if [[ $token = *=* ]]; then eq='='; else eq=''
value=false; fi; local i=0; local similar=(); local match=false
for o in "${longs[@]}"; do if [[ $o = "$long" ]]; then similar+=("$long")
[[ $match = false ]] && match=$i; fi; ((i++)) || true; done
if [[ $match = false ]]; then i=0; for o in "${longs[@]}"; do
if [[ $o = $long* ]]; then similar+=("$long"); [[ $match = false ]] && match=$i
fi; ((i++)) || true; done; fi; if [[ ${#similar[@]} -gt 1 ]]; then
error "${long} is not a unique prefix: ${similar[*]}?"
elif [[ ${#similar[@]} -lt 1 ]]; then
[[ $eq = '=' ]] && argcount=1 || argcount=0; match=${#shorts[@]}
[[ $argcount -eq 0 ]] && value=true; shorts+=(''); longs+=("$long")
argcounts+=("$argcount"); else if [[ ${argcounts[$match]} -eq 0 ]]; then
if [[ $value != false ]]; then
error "${longs[$match]} must not have an argument"; fi
elif [[ $value = false ]]; then
if [[ ${#argv[@]} -eq 0 || ${argv[0]} = '--' ]]; then
error "${long} requires argument"; fi; value=${argv[0]}; argv=("${argv[@]:1}")
fi; if [[ $value = false ]]; then value=true; fi; fi; parsed_params+=("$match")
parsed_values+=("$value"); }; required() { local initial_left=("${left[@]}")
local node_idx; ((testdepth++)) || true; for node_idx in "$@"; do
if ! "node_$node_idx"; then left=("${initial_left[@]}"); ((testdepth--)) || true
return 1; fi; done; if [[ $((--testdepth)) -eq 0 ]]; then
left=("${initial_left[@]}"); for node_idx in "$@"; do "node_$node_idx"; done; fi
return 0; }; either() { local initial_left=("${left[@]}"); local best_match_idx
local match_count; local node_idx; ((testdepth++)) || true
for node_idx in "$@"; do if "node_$node_idx"; then
if [[ -z $match_count || ${#left[@]} -lt $match_count ]]; then
best_match_idx=$node_idx; match_count=${#left[@]}; fi; fi
left=("${initial_left[@]}"); done; ((testdepth--)) || true
if [[ -n $best_match_idx ]]; then "node_$best_match_idx"; return 0; fi
left=("${initial_left[@]}"); return 1; }; optional() { local node_idx
for node_idx in "$@"; do "node_$node_idx"; done; return 0; }; _command() {
local i; local name=${2:-$1}; for i in "${!left[@]}"; do local l=${left[$i]}
if [[ ${parsed_params[$l]} = 'a' ]]; then
if [[ ${parsed_values[$l]} != "$name" ]]; then return 1; fi
left=("${left[@]:0:$i}" "${left[@]:((i+1))}")
[[ $testdepth -gt 0 ]] && return 0; if [[ $3 = true ]]; then
eval "((var_$1++)) || true"; else eval "var_$1=true"; fi; return 0; fi; done
return 1; }; switch() { local i; for i in "${!left[@]}"; do local l=${left[$i]}
if [[ ${parsed_params[$l]} = "$2" ]]; then
left=("${left[@]:0:$i}" "${left[@]:((i+1))}")
[[ $testdepth -gt 0 ]] && return 0; if [[ $3 = true ]]; then
eval "((var_$1++))" || true; else eval "var_$1=true"; fi; return 0; fi; done
return 1; }; value() { local i; for i in "${!left[@]}"; do local l=${left[$i]}
if [[ ${parsed_params[$l]} = "$2" ]]; then
left=("${left[@]:0:$i}" "${left[@]:((i+1))}")
[[ $testdepth -gt 0 ]] && return 0; local value
value=$(printf -- "%q" "${parsed_values[$l]}"); if [[ $3 = true ]]; then
eval "var_$1+=($value)"; else eval "var_$1=$value"; fi; return 0; fi; done
return 1; }; stdout() { printf -- "cat <<'EOM'\n%s\nEOM\n" "$1"; }; stderr() {
printf -- "cat <<'EOM' >&2\n%s\nEOM\n" "$1"; }; error() {
[[ -n $1 ]] && stderr "$1"; stderr "$usage"; _return 1; }; _return() {
printf -- "exit %d\n" "$1"; exit "$1"; }; set -e; trimmed_doc=${DOC:0:731}
usage=${DOC:0:137}; digest=5ce6d; shorts=(-t -p -n)
longs=(--template --paranoia --amount); argcounts=(1 0 1); node_0(){
value __template 0; }; node_1(){ switch __paranoia 1; }; node_2(){
value __amount 2; }; node_3(){ value NAME a; }; node_4(){ _command g; }
node_5(){ _command generate; }; node_6(){ _command down; }; node_7(){
_command probe; }; node_8(){ _command up; }; node_9(){ either 4 5; }; node_10(){
required 9; }; node_11(){ optional 0; }; node_12(){ required 10 11 3; }
node_13(){ optional 1 2; }; node_14(){ required 6 13; }; node_15(){ optional 2
}; node_16(){ required 7 15; }; node_17(){ optional 8 1 2; }; node_18(){
required 17; }; node_19(){ either 12 14 16 18; }; node_20(){ required 19; }
cat <<<' docopt_exit() { [[ -n $1 ]] && printf "%s\n" "$1" >&2
printf "%s\n" "${DOC:0:137}" >&2; exit 1; }'; unset var___template \
var___paranoia var___amount var_NAME var_g var_generate var_down var_probe \
var_up; parse 20 "$@"; local prefix=${DOCOPT_PREFIX:-''}
unset "${prefix}__template" "${prefix}__paranoia" "${prefix}__amount" \
"${prefix}NAME" "${prefix}g" "${prefix}generate" "${prefix}down" \
"${prefix}probe" "${prefix}up"; eval "${prefix}"'__template=${var___template:-}'
eval "${prefix}"'__paranoia=${var___paranoia:-false}'
eval "${prefix}"'__amount=${var___amount:-}'
eval "${prefix}"'NAME=${var_NAME:-}'; eval "${prefix}"'g=${var_g:-false}'
eval "${prefix}"'generate=${var_generate:-false}'
eval "${prefix}"'down=${var_down:-false}'
eval "${prefix}"'probe=${var_probe:-false}'
eval "${prefix}"'up=${var_up:-false}'; local docopt_i=1
[[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2; for ((;docopt_i>0;docopt_i--)); do
declare -p "${prefix}__template" "${prefix}__paranoia" "${prefix}__amount" \
"${prefix}NAME" "${prefix}g" "${prefix}generate" "${prefix}down" \
"${prefix}probe" "${prefix}up"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh migrate.sh`
    eval "$(docopt "$@")"
    local migration_table_name=migrations

    find_migration_files() {
        if [[ ! ${#ZC_MIGRATIONS_PATHS[@]} ]]; then
            printf -- 'The default lookup paths for migrations does not appear to exist
please configure the lookup paths by setting ZC_MIGRATIONS_PATHS variable
either manually before every invokation, or in a .env file.
' >&2
            return 1
        fi

        # shellcheck disable=2068
        find \
            ${ZC_MIGRATIONS_PATHS[@]} \
            \( -name "*.sql" -o -name "*.sqlite" \) \
            -not \( -name "*.down.sql" -name "*.down.sqlite" \) \
        | sort -V
    }

    find_migrations_run() {
        $ZC_MIGRATION_ENGINE <<-SQL
            SELECT
                migration_path,
                sha1sum
            FROM
                $migration_table_name
            WHERE
                NOT is_system_migration
            ORDER BY
                run_at DESC,
                migration_path DESC
SQL
    }

    verify() {
        local migration_path=$1 sha1sum=$2 sum
        sum=$(sha1 "$migration_path")
        if [[ "$sum" != "$sha1sum" ]]; then
            printf -- 'Migration: %s shasum does not match with database.
Database:   %s
Filesystem: %s\n' "$migration_path" "$sha1sum" "$sum" >&2
            # shellcheck disable=2154
            $__paranoia && return 1
        fi
        return 0
    }

    migrate_up() {
        local migrations_missing=() migrations_run=() \
              migration_path sha1sum sum wait_pids=()
        printf -- 'Sanity checking already run migrations.\n'

        while IFS=$'|\n' read -r migration_path sha1sum; do
            [ -z "$migration_path" ] && continue
            if [ ! -f "$migration_path" ]; then
                # printf -- 'Migration not found: %s\n' "$migration_path" >&2
                migrations_missing+=( "${ZC_PROJECT_PATH}/${migration_path}" )
            else
                verify "${ZC_PROJECT_PATH}/${migration_path}" "$sha1sum" "$sum" &
                wait_pids+=( $! )
                migrations_run+=( "${ZC_PROJECT_PATH}/${migration_path}" "$sha1sum" )
            fi
        done <<< "$(find_migrations_run)"

        if (( "${#wait_pids[@]}" > 0 )); then
            wait "${wait_pids[@]}"
        fi

        is_migration_run() {
            local path i
            for ((i=0;i<${#migrations_run[@]};i+=2)); do
                path=${migrations_run[i]}
                [[ "$path" == "$1" ]] && return 0
            done
            return 1
        }

        printf -- 'Running migrations\n'
        for migration_path in $(find_migration_files up); do
            if ! is_migration_run "$migration_path"; then
                migrate_run "$migration_path" up
            fi
        done
        printf -- 'Done\n'
    }

    migrate_down() {
        local migrations_run=() migration_path sha1sum
        while IFS=$'|\n' read -r migration_path sha1sum; do
            [ -z "$migration_path" ] && continue
            migrations_run+=( "${ZC_PROJECT_PATH}/${migration_path}" "$sha1sum" )
        done <<< "$(find_migrations_run)"

        if (( ${#migrations_run[@]} > 0 )); then
            printf -- 'Undoing migrations\n'
            local migration_path i j
            for ((i=0,j=1;i<${#migrations_run[@]};i+=2,j++)); do
                migration_path=${migrations_run[i]}
                migrate_run "$migration_path" down
                (( __amount == j )) && break
            done
            printf -- 'Done\n'
        else
            printf -- 'No migrations to undo\n'
        fi
    }

    migrate_generate() {
        # shellcheck disable=2153,2154
        local name="$NAME" relpath suffix='sql' timestamp
        timestamp="$(date +%Y%m%d%H%M%S)"
        relpath="$(realpath --relative-to="$(pwd)" "$ZC_PROJECT_PATH/migrations")"

        printf -- 'Generating migrations\n'

        # shellcheck disable=2154
        if [ -n "$__template" ]; then
            if ! test -f "$ZC_MIGRATION_LIB/templates/$__template"*; then
                printf -- 'Template %s was not found.' "$__template" >&2
                return 1
            fi

            printf -- '%s/%s_%s_%s.%s\n' "$relpath" "$timestamp" "$__template" "$name" "$suffix"
            (sed -e "s/{TIMESTAMP}/$timestamp/g" -e "s/{NAME}/$NAME/g" < "$ZC_MIGRATION_LIB/templates/$__template"*) > "$ZC_PROJECT_PATH/migrations/${timestamp}_${__template}_${name}.${suffix}"
            return 0
        fi

        printf -- '%s_%s.%s\n' "$timestamp" "$name" "$suffix"
        touch "$ZC_PROJECT_PATH/migrations/${timestamp}_${name}.${suffix}"
    }

    migrate_probe() {
        printf -- 'Probing migrations\n'
        echo "$__amount"
    }

    # shellcheck disable=2120
    sqlite() {
        if [ -z "$1" ]; then
            cat - >&3
            printf -- ';SELECT x'\''04'\'';\n' >&3
        else
            printf -- '%s;SELECT x'\''04'\'';\n' "$1" >&3
        fi

        local row
        while IFS=$'\n' read -u 4 -t 1 -r row; do
            [ "$row" = $'\x04' ] && break
            printf -- '%s\n' "$row"
        done
        return 0
    }

    # shellcheck disable=2120
    postgres() {
        if [ -z "$1" ]; then
            cat - >&5
            printf -- ';SELECT E'\''\04'\'';\n' >&5
        else
            printf -- '%s;SELECT E'\''\04'\'';\n' "$1" >&5
        fi

        local row
        while IFS=$'\n' read -u 6 -t 1 -r row; do
            [ "$row" = $'\x04' ] && break
            printf -- '%s\n' "$row"
        done

        return 0
    }

    sha1() {
        local path="$1"
        shasum -a 1 "$path" | cut -d ' ' -f 1
    }

    migrate_run() {
        local migration_path sum direction="${2:-up}" is_system_migration=${3:-false}
        migration_path=$(realpath --relative-to="$ZC_PROJECT_PATH" "$1")
        sum=$(sha1 "$migration_path")

        if [[ "$direction" == "up" ]]; then
            printf -- '%s\n' "$migration_path"

            if [[ $migration_path = *.sh ]]; then
                up() { return 0; }
                # shellcheck disable=1090
                source "$migration_path"
                up
            elif [[ $migration_path = *.up.sql ]]; then
                # shellcheck disable=2119
                postgres < "$migration_path" > /dev/null
            elif [[ $migration_path = *.sql ]]; then
                # shellcheck disable=2119
                postgres < <(sed -n '/^-- MIGRATE UP BEGIN/,${p;/^-- MIGRATE UP END/q}' "$migration_path") > /dev/null
            elif [[ $migration_path = "*.sqlite" ]]; then
                sqlite < "$migration_path" > /dev/null
            fi

            if $is_system_migration; then
                migration_path=$(basename "$migration_path")
            fi

            $ZC_MIGRATION_ENGINE <<-SQL
                INSERT INTO
                    $migration_table_name (
                        migration_path,
                        sha1sum,
                        is_system_migration
                    )
                VALUES
                    (
                        '$migration_path',
                        '$sum',
                        $is_system_migration
                    )
SQL
        elif [[ "$direction" == "down" ]]; then
            printf -- '%s\n' "$migration_path"

            if [[ $migration_path = *.sh ]]; then
                down() { return 0; }
                # shellcheck disable=1090
                source "$migration_path"
                down
            elif [[ $migration_path = *.up.sql ]]; then
                local migration_path_down
                migration_path_down="$(dirname "$migration_path")/$(basename "$migration_path" .up.sql).down.sql"
                [ -f "$migration_path_down" ] && postgres < "$migration_path_down" > /dev/null
            elif [[ $migration_path = *.sql ]]; then
                postgres < <(sed -n '/^-- MIGRATE DOWN BEGIN/,${p;/^-- MIGRATE DOWN END/q}' "$migration_path") > /dev/null
            fi

            $ZC_MIGRATION_ENGINE <<-SQL
                DELETE FROM
                    $migration_table_name
                WHERE
                    migration_path = '$migration_path' AND
                    is_system_migration = $is_system_migration
SQL
        else
            return 1
        fi
    }

    find_project_root() {
        local path
        path="$(pwd)"
        while [ "$path" != '/' ] ; do
            if [[ -d "$path/.git" || -f "$path/.env" || -f "$path/package.json" ]]; then
                printf -- '%s' "$path"
                return 0
            fi
            path="$(dirname "$path")"
        done
        return 1
    }

    load_dotenv() {
        if [ -f "$ZC_PROJECT_PATH/.env" ]; then
            read_dotenv_file "$ZC_PROJECT_PATH/.env"
        elif [ -f "$ZC_PROJECT_PATH/config/.env" ]; then
            read_dotenv_file "$ZC_PROJECT_PATH/config/.env"
        elif [ -f "$ZC_PROJECT_PATH/config/env" ]; then
            read_dotenv_file "$ZC_PROJECT_PATH/config/env"
        elif [ -f "$ZC_PROJECT_PATH/.config/env" ]; then
            read_dotenv_file "$ZC_PROJECT_PATH/.config/env"
        elif [ -f "$ZC_PROJECT_PATH/.config/.env" ]; then
            read_dotenv_file "$ZC_PROJECT_PATH/.config/.env"
        fi

        ZC_MIGRATION_LIB="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.."
        export ZC_MIGRATION_LIB

        if [ -z "$ZC_MIGRATIONS_PATHS" ]; then
            ZC_MIGRATIONS_PATHS=()
            [ -d "$ZC_PROJECT_PATH/migrations" ] && ZC_MIGRATIONS_PATHS+=( "$ZC_PROJECT_PATH/migrations" )
            export ZC_MIGRATIONS_PATHS
        fi

        if [ -z "$ZC_MIGRATION_ENGINE" ]; then
            ZC_MIGRATION_ENGINE=sqlite
            export ZC_MIGRATION_ENGINE
        fi

        if [ -z "$ZC_MIGRATION_DATABASE_PATH" ]; then
            ZC_MIGRATION_DATABASE_PATH="$ZC_PROJECT_PATH/migrations.sqlite3"
            export ZC_MIGRATION_DATABASE_PATH
        fi
    }

    read_dotenv_file() {
        local raw_env_line dotenv_file=$1
        while IFS= read -r raw_env_line; do
            [[ -z $raw_env_line || $raw_env_line = '#'* ]] && continue
            eval "export $raw_env_line"
        done < "$dotenv_file"
    }

    ensure_database() {
        local database_path="$ZC_MIGRATION_DATABASE_PATH" migrations_path migration_path
        migrations_path="$ZC_MIGRATION_LIB/engine/$ZC_MIGRATION_ENGINE"

        if [ ! -d "$migrations_path" ]; then
            printf -- 'Could not find migration database migrations.\n' >&2
            return 1
        fi

        local migrations_run=()
        local migrations_table_exist_result
        if [ "$ZC_MIGRATION_ENGINE" = postgres ]; then
            migrations_table_exist_result="$(postgres <<-'SQL'
                SELECT
                    1
                FROM
                    information_schema.tables
                WHERE
                    table_schema = 'migration' AND
                    table_name = 'migrations'
SQL
            )"
        elif [ "$ZC_MIGRATION_ENGINE" = sqlite ]; then
            if [ ! -f "$database_path" ]; then
                printf -- 'Migration database: %s does not exist\n' "$database_path" >&2
                if [ -t 1 ]; then
                    local answer
                    while read -p 'Would like to create it? [Y/n] ' -r answer; do
                        if [ -z "$answer" ] || [[ "$answer" =~ [yY] ]]; then
                            break
                        elif [[ "$answer" =~ [nN] ]]; then
                            return 1
                        else
                            printf -- '\033[1A\033[2K\r'
                        fi
                    done
                else
                    return 1
                fi
            fi

            if [ -s "$database_path" ]; then
                migrations_table_exist_result="$(sqlite <<-'SQL'
                    SELECT
                        1
                    FROM
                        sqlite_master
                    WHERE
                        type = 'table' AND
                        name = 'migrations'
SQL
                )"
            fi
        fi

        if (( migrations_table_exist_result == 1 )); then
            local sha1sum
            while IFS=$'|\n' read -r migration_path sha1sum; do
                migrations_run+=( "$migration_path" "$sha1sum" )
            done <<< "$($ZC_MIGRATION_ENGINE <<-SQL
                SELECT
                    migration_path,
                    sha1sum
                FROM
                    $migration_table_name
                WHERE
                    is_system_migration
SQL
            )"
        fi

        is_migration_run() {
            local path i
            for ((i=0;i<${#migrations_run[@]};i+=2)); do
                path=${migrations_run[i]}
                [[ "$path" == "$1" ]] && return 0
            done
            return 1
        }

        for migration_path in $(find "$migrations_path" -maxdepth 1 -name '*.sh' -o -name '*.sql' | sort -V); do
            if ! is_migration_run "$(basename "$migration_path")"; then
                migrate_run "$migration_path" "up" true > /dev/null
            fi
        done
    }

    if [ -z "$ZC_PROJECT_PATH" ]; then
        if [ -z "$PROJECT_PATH" ]; then
            PROJECT_PATH=$(find_project_root)
        fi
        export ZC_PROJECT_PATH="$PROJECT_PATH"
    fi

    load_dotenv

    #shellcheck disable=2154
    if $generate || $g; then
        migrate_generate
        return 0
    fi

    if [ "$ZC_MIGRATION_ENGINE" = postgres ]; then
        migration_table_name='migration.migrations';
    fi

    local sqlite_fifo
    sqlite_fifo=$(mktemp -up/tmp P.zc_migration.XXX)
    mkfifo --mode=0700 "$sqlite_fifo.in" "$sqlite_fifo.out"
    trap "rm ""$sqlite_fifo.in"" ""$sqlite_fifo.out""" EXIT
    sqlite3 --bail "$ZC_MIGRATION_DATABASE_PATH" <"$sqlite_fifo.in" >"$sqlite_fifo.out" &
    exec 3> "$sqlite_fifo.in" 4< "$sqlite_fifo.out"

    local postgres_fifo
    postgres_fifo=$(mktemp -up/tmp P.zc_migration.XXX)
    mkfifo --mode=0700 "$postgres_fifo.in" "$postgres_fifo.out"
    trap "rm ""$postgres_fifo.in"" ""$postgres_fifo.out""" EXIT
    psql -v ON_ERROR_STOP=1 -F '|' -R $'\n' -A -t -q <"$postgres_fifo.in" >"$postgres_fifo.out" &
    exec 5> "$postgres_fifo.in" 6< "$postgres_fifo.out"

    ensure_database

    #shellcheck disable=2154
    if $down; then
        __amount=${__amount:-1}
        migrate_down
    elif $up; then
        __amount=${__amount:-1}
        migrate_up
    elif $probe; then
        __amount=${__amount:-1}
        migrate_probe
    else
        __amount=${__amount:-0}
        migrate_up
    fi

    printf -- 'Execution took: %ds\n' "$(ps -ho etimes $$ | tr -d ' ')"
}

migrate "$@"
