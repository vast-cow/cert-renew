#!/usr/bin/env bash
set -Eeuo pipefail

if (( EUID != 0 )); then
    echo "[error] must run as root" >&2
    exit 1
fi

VENV="$CERTBOT_VENV"

echo "[info] preparing Certbot virtual environment" >&2

if [[ ! -x "$VENV/bin/python" ]]; then
    echo "[info] creating virtual environment" >&2

    # The virtual environment must remain root-owned.
    umask 022
    python3 -m venv "$VENV"
fi

echo "[info] updating Python packages" >&2

if command -v uv >/dev/null 2>&1; then
    echo "[info] using uv pip" >&2

    uv pip install \
        --python "$VENV/bin/python" \
        --upgrade \
        certbot
else
    echo "[info] using pip" >&2

    if ! "$VENV/bin/python" -m pip --version \
        >/dev/null 2>&1; then
        "$VENV/bin/python" -m ensurepip --upgrade
    fi

    "$VENV/bin/python" -m pip install \
        --upgrade pip

    "$VENV/bin/python" -m pip install \
        --upgrade \
        --upgrade-strategy eager \
        certbot
fi

echo "[info] checking installed dependencies" >&2

if command -v uv >/dev/null 2>&1; then
    uv pip check --python "$VENV/bin/python"
else
    "$VENV/bin/python" -m pip check
fi

echo "[info] installed Certbot version:" >&2
"$VENV/bin/certbot" --version

echo "[info] Python package update completed" >&2
