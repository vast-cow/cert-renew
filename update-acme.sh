#!/usr/bin/env bash
set -Eeuo pipefail

if (( EUID == 0 )); then
    echo "[error] must run as non-root" >&2
    exit 1
fi

ACME_HOME="${CACHE_DIRECTORY:?CACHE_DIRECTORY is required}/acme.sh"
install -d -m 0700 "$ACME_HOME"
temporary="$(mktemp "$ACME_HOME/.acme.sh.XXXXXX")"
trap 'rm -f -- "$temporary"' EXIT

echo "[info] updating acme.sh" >&2
curl --fail --silent --show-error --location \
    --proto '=https' --proto-redir '=https' \
    https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh \
    --output "$temporary"
sh -n "$temporary"
chmod 0700 "$temporary"
mv -f -- "$temporary" "$ACME_HOME/acme.sh"
"$ACME_HOME/acme.sh" --version
