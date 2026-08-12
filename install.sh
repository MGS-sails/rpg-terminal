#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 "$ROOT_DIR/work/quest-mode/install_quest_mode.py" \
  --quest-file "$ROOT_DIR/work/quest-mode/quest-mode.zsh" \
  --background-file "$ROOT_DIR/outputs/quest-mode-bg.png" \
  --audio-dir "$ROOT_DIR/outputs/quest-audio" \
  --iterm-profile-template-json "$ROOT_DIR/work/quest-mode/live-20260807/iterm-quest-profile.json"

cat <<'EOF'

Quest Mode installed.

Next steps:
  1. Run: exec zsh
  2. In a stale session, run:
       quest-music-stop
       quest-music-start

Useful commands:
  quest-docs
  quest-examples
  quest-stats

Rollback:
  ./uninstall.sh
EOF
