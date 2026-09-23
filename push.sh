#!/usr/bin/env bash

set -ueo pipefail

usage() {
cat << EOF
Push Helm Chart to Nexus repository

This plugin provides ability to push a Helm Chart directory or package to a
remote Nexus Helm repository.

Usage:
  helm nexus-push [repo] login [flags]        Setup login information for repo
  helm nexus-push [repo] logout [flags]       Remove login information for repo
  helm nexus-push [repo] [CHART] [flags]      Pushes chart to repo

Flags:
  -u, --username string                 Username (uses cached login or prompts if omitted)
  -p, --password string                 Password (uses cached login or prompts if omitted)
EOF
}

USERNAME=
PASSWORD=

declare -a POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]
do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -u|--username)
            if [[ -z "${2:-}" || "$2" == -* ]]; then
                echo "Must specify username!"
                echo "---"
                usage
                exit 1
            fi
            shift
            USERNAME=$1
            ;;
        -p|--password)
            if [[ -n "${2:-}" && "$2" != -* ]]; then
                shift
                PASSWORD=$1
            else
                PASSWORD=
            fi
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            ;;
   esac
   shift
done
if [[ ${#POSITIONAL_ARGS[@]} -gt 0 ]]; then
    set -- "${POSITIONAL_ARGS[@]}"
else
    set --
fi

if [[ $# -lt 2 ]]; then
  echo "Missing arguments!"
  echo "---"
  usage
  exit 1
fi

indent() { sed 's/^/  /'; }

HELM_BIN="${HELM_BIN:-helm}"
REPO=$1
REPO_URL="$("$HELM_BIN" repo list | awk -v repo="$REPO" 'NR > 1 && $1 == repo { print $2; exit }')"

if [[ -z "$REPO_URL" ]]; then
    echo "Invalid repo specified!  Must specify one of these repos..."
    "$HELM_BIN" repo list
    echo "---"
    usage
    exit 1
fi

if [[ "$REPO_URL" != */ ]]; then
    REPO_URL+="/"
fi

HELM_CONFIG_DIR="${HELM_CONFIG_HOME:-$("$HELM_BIN" env HELM_CONFIG_HOME)}"
REPO_AUTH_FILE="$HELM_CONFIG_DIR/auth.$REPO"

prompt_missing_credentials() {
    if [[ -z "$USERNAME" ]]; then
        if ! read -r -p "Username: " USERNAME; then
            echo "No input available for username." >&2
            return 1
        fi
    fi
    if [[ -z "$PASSWORD" ]]; then
        if ! read -r -s -p "Password: " PASSWORD; then
            printf '\n' >&2
            echo "No input available for password." >&2
            return 1
        fi
        printf '\n'
    fi
}

case "$2" in
    login)
        prompt_missing_credentials
        mkdir -p "$HELM_CONFIG_DIR"
        (umask 077; printf '%s:%s\n' "$USERNAME" "$PASSWORD" > "$REPO_AUTH_FILE")
        chmod 600 "$REPO_AUTH_FILE"
        ;;
    logout)
        rm -f -- "$REPO_AUTH_FILE"
        ;;
    *)
        CHART=$2

        if [[ -f "$REPO_AUTH_FILE" ]] && { [[ -z "$USERNAME" ]] || [[ -z "$PASSWORD" ]]; }; then
            CACHED_USERNAME=
            CACHED_PASSWORD=
            CACHED_CREDENTIALS_USED=0
            if IFS=: read -r CACHED_USERNAME CACHED_PASSWORD < "$REPO_AUTH_FILE"; then
                if [[ -z "$USERNAME" && -n "$CACHED_USERNAME" ]]; then
                    USERNAME=$CACHED_USERNAME
                    CACHED_CREDENTIALS_USED=1
                fi
                if [[ -z "$PASSWORD" && -n "$CACHED_PASSWORD" ]]; then
                    PASSWORD=$CACHED_PASSWORD
                    CACHED_CREDENTIALS_USED=1
                fi
            fi
            if [[ $CACHED_CREDENTIALS_USED -eq 1 ]]; then
                echo "Using cached login creds..."
            fi
        fi
        prompt_missing_credentials
        AUTH="$USERNAME:$PASSWORD"

        if [[ -d "$CHART" ]]; then
            if ! PACKAGE_OUTPUT="$("$HELM_BIN" package "$CHART")"; then
                echo "Failed to package chart: $CHART" >&2
                exit 1
            fi
            if [[ "$PACKAGE_OUTPUT" != *"saved it to: "* ]]; then
                echo "Could not determine the packaged chart path from Helm output." >&2
                exit 1
            fi
            CHART_PACKAGE="${PACKAGE_OUTPUT#*saved it to: }"
        else
            CHART_PACKAGE="$CHART"
        fi

        echo "Pushing $CHART to repo $REPO_URL..."
        if ! curl --include --silent --show-error --fail --user "$AUTH" --upload-file "$CHART_PACKAGE" "$REPO_URL" | indent; then
            echo "Failed to upload chart '$CHART' to repository '$REPO'." >&2
            exit 1
        fi
        echo "Done"
        ;;
esac

exit 0
