#!/usr/bin/env bash
# Run from anywhere: bash scripts/check-syntax.sh
set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
failed=0
while IFS= read -r -d '' file; do
    if bash -n "$file"; then
        printf 'OK   %s\n' "${file#"$PROJECT_ROOT"/}"
    else
        printf 'FAIL %s\n' "${file#"$PROJECT_ROOT"/}"
        failed=1
    fi
done < <(find "$PROJECT_ROOT" -type f -name '*.sh' -print0)
if (( failed == 0 )); then
    printf '\nAll Bash files passed syntax checks.\n'
else
    printf '\nOne or more Bash files have syntax errors.\n' >&2
fi
exit "$failed"
