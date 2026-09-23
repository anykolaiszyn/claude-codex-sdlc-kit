#!/usr/bin/env bash
# Create (or update) the process labels in the target repo's GitHub project.
#   scripts/labels.sh <target-repo>
set -euo pipefail
cd "${1:?usage: labels.sh <target-repo>}"
while IFS='|' read -r name color desc; do
  gh label create "$name" --color "$color" --description "$desc" --force >/dev/null && echo "  + label: $name"
done <<'EOF'
bug|d73a4a|Wrong behaviour for something the product ships
edge-case|fbca04|Valid finding outside the current milestone's data or scope
feature|0e8a16|New capability
process|5319e7|Development workflow, tooling, docs
from-codex|1d76db|Found by Codex (local review or PR bot)
from-review|0052cc|Found by a Claude reviewer
blocked|b60205|Cannot proceed until something else lands
needs-decision|d876e3|Needs the user's call
EOF
