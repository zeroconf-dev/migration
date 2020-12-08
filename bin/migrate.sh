#!/bin/bash

set -e

migrate() {
    DOC="Usage:
    migrate (g|generate) [--template=TEMPLATE] NAME
    migrate down [-n NUM]
    migrate probe [-n NUM]
    migrate [up -n NUM]

Options:
    -n --amount=NUM         The amount of migrations to go up or down, must be a positive number
                            0 is considered to be infinite.
    -t --template=TEMPLATE  Generate a new migration from a specific template.

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
return 1; }; value() { local i; for i in "${!left[@]}"; do local l=${left[$i]}
if [[ ${parsed_params[$l]} = "$2" ]]; then
left=("${left[@]:0:$i}" "${left[@]:((i+1))}")
[[ $testdepth -gt 0 ]] && return 0; local value
value=$(printf -- "%q" "${parsed_values[$l]}"); if [[ $3 = true ]]; then
eval "var_$1+=($value)"; else eval "var_$1=$value"; fi; return 0; fi; done
return 1; }; stdout() { printf -- "cat <<'EOM'\n%s\nEOM\n" "$1"; }; stderr() {
printf -- "cat <<'EOM' >&2\n%s\nEOM\n" "$1"; }; error() {
[[ -n $1 ]] && stderr "$1"; stderr "$usage"; _return 1; }; _return() {
printf -- "exit %d\n" "$1"; exit "$1"; }; set -e; trimmed_doc=${DOC:0:639}
usage=${DOC:0:135}; digest=c43fe; shorts=(-t -n); longs=(--template --amount)
argcounts=(1 1); node_0(){ value __template 0; }; node_1(){ value __amount 1; }
node_2(){ value NAME a; }; node_3(){ _command g; }; node_4(){ _command generate
}; node_5(){ _command down; }; node_6(){ _command probe; }; node_7(){
_command up; }; node_8(){ either 3 4; }; node_9(){ required 8; }; node_10(){
optional 0; }; node_11(){ required 9 10 2; }; node_12(){ optional 1; }
node_13(){ required 5 12; }; node_14(){ required 6 12; }; node_15(){
optional 7 1; }; node_16(){ required 15; }; node_17(){ either 11 13 14 16; }
node_18(){ required 17; }; cat <<<' docopt_exit() {
[[ -n $1 ]] && printf "%s\n" "$1" >&2; printf "%s\n" "${DOC:0:135}" >&2; exit 1
}'; unset var___template var___amount var_NAME var_g var_generate var_down \
var_probe var_up; parse 18 "$@"; local prefix=${DOCOPT_PREFIX:-''}
unset "${prefix}__template" "${prefix}__amount" "${prefix}NAME" "${prefix}g" \
"${prefix}generate" "${prefix}down" "${prefix}probe" "${prefix}up"
eval "${prefix}"'__template=${var___template:-}'
eval "${prefix}"'__amount=${var___amount:-}'
eval "${prefix}"'NAME=${var_NAME:-}'; eval "${prefix}"'g=${var_g:-false}'
eval "${prefix}"'generate=${var_generate:-false}'
eval "${prefix}"'down=${var_down:-false}'
eval "${prefix}"'probe=${var_probe:-false}'
eval "${prefix}"'up=${var_up:-false}'; local docopt_i=1
[[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2; for ((;docopt_i>0;docopt_i--)); do
declare -p "${prefix}__template" "${prefix}__amount" "${prefix}NAME" \
"${prefix}g" "${prefix}generate" "${prefix}down" "${prefix}probe" "${prefix}up"
done; }
# docopt parser above, complete command for generating this parser is `docopt.sh migrate.sh`
    eval "$(docopt "$@")"

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
            -name '*up.sqlite'
    }

    migrate_up() {
        printf -- 'Running migrations\n'
        # echo "$__amount"
        find_migration_files
    }

    migrate_down() {
        printf -- 'Undoing migrations\n'
        echo "$__amount"
    }

    migrate_generate() {
        # shellcheck disable=2153,2154
        local name="$NAME" suffix='sql' timestamp
        timestamp="$(date +%Y%m%d%H%M%S)"

        printf -- 'Generating migrations\n'
        printf -- '%s_%s.up.%s\n' "$timestamp" "$name" "$suffix"
        printf -- '%s_%s.down.%s\n' "$timestamp" "$name" "$suffix"

        touch "$ZC_PROJECT_PATH/migrations/${timestamp}_${name}.up.${suffix}"
        touch "$ZC_PROJECT_PATH/migrations/${timestamp}_${name}.down.${suffix}"
    }

    migrate_probe() {
        printf -- 'Probing migrations\n'
        echo "$__amount"
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
    }

    read_dotenv_file() {
        local raw_env_line dotenv_file=$1
        while IFS= read -r raw_env_line; do
            [[ -z $raw_env_line || $raw_env_line = '#'* ]] && continue
            eval "export $raw_env_line"
        done < "$dotenv_file"
    }

    ensure_database() {
        local database_path="$ZC_MIGRATION_DATABASE_PATH" migrations_path
        migrations_path="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../database")"
        if [ ! -d "$migrations_path" ]; then
            printf -- 'Could not find migration database migrations.\n' >&2
            return 1
        fi

        for m in $(find "$migrations_path" -maxdepth 1 -name '.sqlite' | sort -n); do
            sqlite3 --bail "$database_path" < "$m"
        done
    }

    if [ -z "$ZC_PROJECT_PATH" ]; then
        if [ -n "$PROJECT_PATH" ]; then
            ZC_PROJECT_PATH="$PROJECT_PATH"
        else
            ZC_PROJECT_PATH=$(find_project_root)
            export PROJECT_PATH=$ZC_PROJECT_PATH
        fi
    fi

    load_dotenv

    if [ -z "$ZC_MIGRATIONS_PATHS" ]; then
        ZC_MIGRATIONS_PATHS=()
        [ -d "$ZC_PROJECT_PATH/migrations" ] && ZC_MIGRATIONS_PATHS+=( "$ZC_PROJECT_PATH/migrations" )
    fi

    if [ -z "$ZC_MIGRATION_DATABASE_PATH" ]; then
        ZC_MIGRATION_DATABASE_PATH="$ZC_PROJECT_PATH/.migrations.db"
        export ZC_MIGRATION_DATABASE_PATH
    fi

    ensure_database
    return 0

    #shellcheck disable=2154
    if $generate || $g; then
        migrate_generate
    elif $down; then
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
}

migrate "$@"
