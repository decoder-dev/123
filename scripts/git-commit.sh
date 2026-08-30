#!/usr/bin/env bash
# Commits without Cursor agent metadata (no Co-authored-by, decoder-dev only).
set -euo pipefail
MSG="${1:?Usage: git-commit.sh \"commit message\"}"
export GIT_AUTHOR_NAME="decoder-dev"
export GIT_AUTHOR_EMAIL="96624794+decoder-dev@users.noreply.github.com"
export GIT_COMMITTER_NAME="decoder-dev"
export GIT_COMMITTER_EMAIL="96624794+decoder-dev@users.noreply.github.com"
git -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -m "$MSG"
