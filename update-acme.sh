#!/usr/bin/env bash
set -Eeuo pipefail

if (( EUID == 0 )); then
    echo "[error] must run as non-root" >&2
    exit 1
fi

ACME_HOME="${CACHE_DIRECTORY:?CACHE_DIRECTORY is required}/acme.sh"
CONFIG_PATH="${CONFIG_PATH:-${STATE_DIRECTORY:?STATE_DIRECTORY is required}/acme}"
install -d -m 0700 "$ACME_HOME" "$CONFIG_PATH"

if [[ ! -x "$ACME_HOME/acme.sh" ]]; then
    echo "[info] bootstrapping acme.sh" >&2
    temporary="$(mktemp "$ACME_HOME/.acme.sh.XXXXXX")"
    trap 'rm -f -- "$temporary"' EXIT
    curl --fail --silent --show-error --location \
        --proto '=https' --proto-redir '=https' \
        https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh \
        --output "$temporary"
    sh -n "$temporary"
    chmod 0700 "$temporary"
    mv -f -- "$temporary" "$ACME_HOME/acme.sh"
fi

echo "[info] upgrading cached acme.sh" >&2
"$ACME_HOME/acme.sh" --home "$ACME_HOME" --config-home "$CONFIG_PATH" --upgrade
"$ACME_HOME/acme.sh" --version
