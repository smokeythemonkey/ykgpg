#!/usr/bin/env bash
# Refuse staged files whose paths look like key material. This is the
# fast, explicit guard; gitleaks (also in the pre-commit hook) scans
# content. Both must pass.
set -euo pipefail

patterns='(^|/)(private-keys-v1\.d/|\.gnupg/)|(\.tar\.gpg|\.key|secret\.asc|revoke\.asc|\.rev|pubring\.kbx|trustdb\.gpg|\.state)$'

bad=$(git diff --cached --name-only --diff-filter=ACMR | grep -Ei "$patterns" || true)
if [ -n "$bad" ]; then
    printf 'Refusing to commit key material:\n%s\n\nIf this is a false positive, extend .gitleaks.toml and scripts/git-guard.sh together.\n' "$bad" >&2
    exit 1
fi
