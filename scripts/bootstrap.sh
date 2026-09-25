#!/usr/bin/env bash
# Install the Claude + Codex SDLC process into a git repo.
#
#   scripts/bootstrap.sh <target-repo> [--labels] [--milestone "M1 — Title"]
#
# Answers come from env vars (prompted for when unset):
#   PROJECT_NAME  PROJECT_PITCH  MAIN_BRANCH  TEST_CMD  CHECK_CMD
#   CODEX_TEST_CMD  CODEX_CHECK_CMD  REVIEW_PRIORITIES  REVIEW_BUDGET  M1_TITLE
# Existing files are never overwritten; they are reported so you can merge by hand.
set -euo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
target="${1:?usage: bootstrap.sh <target-repo> [--labels] [--milestone \"M1 — Title\"]}"; shift
labels=0; milestone=""
while [ $# -gt 0 ]; do
  case "$1" in
    --labels) labels=1 ;;
    --milestone) milestone="${2:?--milestone needs a title}"; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac; shift
done
git -C "$target" rev-parse --git-dir >/dev/null 2>&1 || { echo "$target is not a git repo" >&2; exit 1; }

ask() { # ask VAR "question" "default"
  local v="${!1:-}"
  if [ -z "$v" ]; then read -r -p "$2 [$3]: " v; v="${v:-$3}"; fi
  printf -v "$1" '%s' "$v"; export "${1?}"   # indirect export of the named variable
}
ask PROJECT_NAME      "Project name"                         "$(basename "$(cd "$target" && pwd)")"
ask PROJECT_PITCH     "One-sentence pitch"                   "TODO: one-sentence pitch."
ask MAIN_BRANCH       "Default branch"                       "main"
ask TEST_CMD          "Test command"                         "npm test"
ask CHECK_CMD         "Typecheck/lint command"               "npm run typecheck"
ask CODEX_TEST_CMD    "Test command Codex runs (Windows: .cmd shims)" "npx.cmd vitest run"
ask CODEX_CHECK_CMD   "Check command Codex runs"             "npx.cmd tsc --noEmit"
ask REVIEW_PRIORITIES "What reviewers must prioritise"       "correctness of user-visible output, data loss, security, and validation gaps."
ask REVIEW_BUDGET     "Codex review budget (risk tolerance)" "risk-based (default): skip Codex on docs/comments/tests-only changes, one targeted review on a localized fix, full review plus PR loop on auth, permissions, data, migrations, or public APIs."
ask M1_TITLE          "First milestone title (without 'M1 — ')" "${milestone#M1 — }"
[ -n "$M1_TITLE" ] || M1_TITLE="TODO"

# "python" first: on Windows, "python3" can be the Microsoft Store stub.
py=""; for c in python python3; do if "$c" -c 1 >/dev/null 2>&1; then py="$c"; break; fi; done
[ -n "$py" ] || { echo "Python 3 is required" >&2; exit 1; }
fill() { # substitute {{VARS}} from the environment
  "$py" - "$1" "$2" <<'PY'
import os, re, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
text = re.sub(r"\{\{(\w+)\}\}", lambda m: os.environ.get(m.group(1), m.group(0)), text)
open(dst, "w", encoding="utf-8", newline="\n").write(text)
PY
}

skipped=()
install_tree() { # install_tree <source dir> <destination prefix inside the repo>
  local src="$1" prefix="$2" f rel dst
  while IFS= read -r -d '' f; do
    rel="$prefix${f#"$src/"}"; dst="$target/$rel"
    if [ -e "$dst" ]; then skipped+=("$rel"); continue; fi
    mkdir -p "$(dirname "$dst")"; fill "$f" "$dst"; echo "  + $rel"
  done < <(find "$src" -type f -print0)
}
install_tree "$kit/template" ""
# A repo copy of the skill: teammates without the plugin, and the paths the process docs use.
install_tree "$kit/skills/pairing-with-codex-cli" ".claude/skills/pairing-with-codex-cli/"
chmod +x "$target/.claude/skills/pairing-with-codex-cli/run-codex.sh" 2>/dev/null || true

gi="$target/.gitignore"; touch "$gi"
grep -qx '.superpowers/' "$gi" || { echo '.superpowers/' >>"$gi"; echo "  + .gitignore: .superpowers/"; }

if [ ${#skipped[@]} -gt 0 ]; then
  echo "Already present, not overwritten (merge by hand from $kit/template):"; printf '  = %s\n' "${skipped[@]}"
fi

if [ "$labels" = 1 ]; then
  "$kit/scripts/labels.sh" "$target"
fi
if [ -n "$milestone" ]; then
  repo="$(cd "$target" && gh repo view --json nameWithOwner -q .nameWithOwner)"
  gh api "repos/$repo/milestones" -f title="$milestone" >/dev/null && echo "  + milestone: $milestone"
fi
echo "Done. Review the files, then commit them on a branch (not $MAIN_BRANCH) and open a PR."
echo "Stage the script as executable: git add --chmod=+x .claude/skills/pairing-with-codex-cli/run-codex.sh"
