#!/usr/bin/env bash
set -euo pipefail

QUEST_DIR="$HOME/.config/quest-mode"
BACKUP_ROOT="$QUEST_DIR/backups"
LATEST_BACKUP=""

if [[ -d "$BACKUP_ROOT" ]]; then
  while IFS= read -r backup_dir; do
    LATEST_BACKUP="$backup_dir"
  done < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sort)
fi

restore_file() {
  local backup_file="$1"
  local target_file="$2"

  if [[ -f "$backup_file" ]]; then
    mkdir -p "$(dirname "$target_file")"
    cp "$backup_file" "$target_file"
    printf 'Restored %s\n' "$target_file"
  fi
}

if [[ -n "$LATEST_BACKUP" ]]; then
  restore_file "$LATEST_BACKUP/.zshrc" "$HOME/.zshrc"
  restore_file "$LATEST_BACKUP/com.googlecode.iterm2.plist" \
    "$HOME/Library/Preferences/com.googlecode.iterm2.plist"
else
  cat <<'EOF'
No Quest Mode backup was found.

The uninstall will remove Quest Mode files, but it cannot automatically restore
your previous ~/.zshrc or iTerm2 profile without a backup snapshot.
EOF
fi

if [[ -d "$QUEST_DIR" ]]; then
  rm -rf "$QUEST_DIR"
  printf 'Removed %s\n' "$QUEST_DIR"
fi

cat <<'EOF'

Quest Mode uninstalled.

Next steps:
  1. Quit iTerm2 completely and reopen it.
  2. Run: exec zsh

If you had multiple backups, the most recent Quest Mode backup was used.
EOF
