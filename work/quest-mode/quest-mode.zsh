[[ -n "${QUEST_MODE_LOADED:-}" ]] && return
typeset -g QUEST_MODE_LOADED=1

[[ -o interactive ]] || return

zmodload zsh/datetime 2>/dev/null || true

typeset -g QUEST_MODE_CLASS="${QUEST_MODE_CLASS:-Wayfinder}"
typeset -g QUEST_MODE_BADGE_PREFIX="${QUEST_MODE_BADGE_PREFIX:-QUEST MODE}"
typeset -g QUEST_MODE_ENABLE_BANNER="${QUEST_MODE_ENABLE_BANNER:-1}"
typeset -g QUEST_STATE_DIR="${HOME}/.config/quest-mode/state"
typeset -g QUEST_STATE_FILE="${QUEST_STATE_DIR}/hero.zsh"
typeset -g QUEST_BOSS_STATE_FILE="${QUEST_STATE_DIR}/boss.zsh"
typeset -g QUEST_JOURNAL_FILE="${QUEST_STATE_DIR}/journal.log"
typeset -g QUEST_ZONES_FILE="${QUEST_STATE_DIR}/discovered-zones"
typeset -g QUEST_AUDIO_DIR="${HOME}/.config/quest-mode/audio"
typeset -g QUEST_AUDIO_PID_FILE="${QUEST_STATE_DIR}/music.pid"
typeset -g QUEST_AUDIO_AMBIENT="${QUEST_AUDIO_DIR}/quest-ambient.wav"
typeset -g QUEST_AUDIO_DISCOVERY="${QUEST_AUDIO_DIR}/quest-discovery.wav"
typeset -g QUEST_AUDIO_LEVEL_UP="${QUEST_AUDIO_DIR}/quest-level-up.wav"
typeset -g QUEST_AUDIO_DAMAGE="${QUEST_AUDIO_DIR}/quest-damage.wav"
typeset -g QUEST_AUDIO_REST="${QUEST_AUDIO_DIR}/quest-rest.wav"
typeset -g QUEST_MUSIC_ENABLED="${QUEST_MUSIC_ENABLED:-1}"
typeset -g QUEST_MUSIC_AUTOSTART="${QUEST_MUSIC_AUTOSTART:-1}"
typeset -g QUEST_SFX_ENABLED="${QUEST_SFX_ENABLED:-1}"
typeset -g QUEST_MUSIC_ANNOUNCED=0
typeset -g QUEST_STATE_ENABLED=1
typeset -g QUEST_BANNER_SHOWN=0
typeset -g QUEST_STATE_DIRTY=0
typeset -g QUEST_LAST_STATUS=0
typeset -g QUEST_LAST_DURATION=0
typeset -g QUEST_LAST_DAMAGE=0
typeset -g QUEST_LAST_REWARD_XP=0
typeset -g QUEST_LAST_REWARD_GOLD=0
typeset -g QUEST_FAILURE_STREAK=0
typeset -g QUEST_COMMAND_STARTED_AT=''
typeset -g QUEST_LAST_COMMAND=''
typeset -g QUEST_BOSS_ACTIVE=0
typeset -g QUEST_BOSS_NAME=''
typeset -g QUEST_BOSS_HP=0
typeset -g QUEST_BOSS_MAX_HP=0
typeset -g QUEST_BOSS_PHASE=1
typeset -g QUEST_BOSS_TURNS=0
typeset -g QUEST_BOSS_GUARD=0
typeset -g QUEST_BOSS_CHARGE=0
typeset -g QUEST_BOSS_CONTEXT=''
typeset -g QUEST_BOSS_AUTO_ENABLED="${QUEST_BOSS_AUTO_ENABLED:-1}"
typeset -g QUEST_BOSS_AUTO_KEY=''
typeset -g QUEST_BOSS_AUTO_SOURCE=''
typeset -g QUEST_BOSS_AUTO_COOLDOWN_UNTIL=0
typeset -ga QUEST_PENDING_MESSAGES=()

export CLICOLOR=1
export LSCOLORS="${LSCOLORS:-Gxfxcxdxbxegedabagacad}"
PROMPT_EOL_MARK=''

typeset -g POWERLEVEL9K_MODE=awesome-fontconfig
typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
  quest_class
  quest_realm
  quest_zone
  quest_questline
  prompt_char
)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  quest_rank
  quest_vitals
  quest_turn
  quest_mana
  quest_clock
)

typeset -g POWERLEVEL9K_BACKGROUND=
typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=$'\uE0B0'
typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=$'\uE0B2'
typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR=' '
typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR=' '
typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=''
typeset -g POWERLEVEL9K_RIGHT_PROMPT_LAST_SEGMENT_END_SYMBOL=''

typeset -g POWERLEVEL9K_PROMPT_CHAR_BACKGROUND=
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_FOREGROUND=178
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_FOREGROUND=160
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_CONTENT_EXPANSION='❯'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_CONTENT_EXPANSION='✖'
typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=''
typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=''
typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_LEFT_WHITESPACE=''
typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_RIGHT_WHITESPACE=''

function _quest_git_branch() {
  git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null
}

function _quest_zone_name() {
  print -P '%3~'
}

function _quest_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

function _quest_xp_for_level() {
  local level="${1:-1}"
  local total=0
  local step

  for (( step = 1; step < level; step++ )); do
    (( total += 80 + step * 40 ))
  done

  print -- "$total"
}

function _quest_queue_message() {
  QUEST_PENDING_MESSAGES+=("$1")
}

function _quest_audio_ready() {
  command -v afplay >/dev/null 2>&1 || return 1
  [[ -f "$QUEST_AUDIO_AMBIENT" ]] || return 1
  return 0
}

function _quest_music_is_running() {
  local pid
  [[ -f "$QUEST_AUDIO_PID_FILE" ]] || return 1
  pid="$(<"$QUEST_AUDIO_PID_FILE")"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

function _quest_play_sfx() {
  local kind file
  kind="$1"
  (( QUEST_SFX_ENABLED )) || return
  command -v afplay >/dev/null 2>&1 || return

  case "$kind" in
    discovery) file="$QUEST_AUDIO_DISCOVERY" ;;
    level-up) file="$QUEST_AUDIO_LEVEL_UP" ;;
    damage) file="$QUEST_AUDIO_DAMAGE" ;;
    rest) file="$QUEST_AUDIO_REST" ;;
    *) return ;;
  esac

  [[ -f "$file" ]] || return
  { afplay "$file" >/dev/null 2>&1 &! } 2>/dev/null
}

function _quest_music_start() {
  local ambient_q
  (( QUEST_MUSIC_ENABLED )) || return 1
  _quest_ensure_state_fs || return 1
  _quest_audio_ready || return 1

  if _quest_music_is_running; then
    return 0
  fi

  ambient_q="${(q)QUEST_AUDIO_AMBIENT}"
  nohup /bin/sh -c "trap 'exit 0' TERM INT; while :; do /usr/bin/afplay ${ambient_q}; done" \
    >/dev/null 2>&1 &
  print -r -- "$!" >| "$QUEST_AUDIO_PID_FILE"
  return 0
}

function _quest_music_stop() {
  local pid
  [[ -f "$QUEST_AUDIO_PID_FILE" ]] || return 0
  pid="$(<"$QUEST_AUDIO_PID_FILE")"
  if [[ -n "$pid" ]]; then
    kill "$pid" 2>/dev/null || true
  fi
  rm -f "$QUEST_AUDIO_PID_FILE"
}

function _quest_maybe_start_music() {
  (( QUEST_MUSIC_AUTOSTART )) || return
  (( QUEST_MUSIC_ENABLED )) || return
  [[ "${TERM_PROGRAM:-}" == "iTerm.app" || "${LC_TERMINAL:-}" == "iTerm2" ]] || return
  _quest_audio_ready || return

  if _quest_music_start && (( QUEST_MUSIC_ANNOUNCED == 0 )); then
    typeset -g QUEST_MUSIC_ANNOUNCED=1
    _quest_queue_message 'The tavern band has begun to play.'
  fi
}

function _quest_ensure_state_fs() {
  (( QUEST_STATE_ENABLED )) || return 1

  mkdir -p "$QUEST_STATE_DIR" >/dev/null 2>&1 || {
    typeset -g QUEST_STATE_ENABLED=0
    return 1
  }
  [[ -f "$QUEST_ZONES_FILE" ]] || : >| "$QUEST_ZONES_FILE" 2>/dev/null || {
    typeset -g QUEST_STATE_ENABLED=0
    return 1
  }
  [[ -f "$QUEST_JOURNAL_FILE" ]] || : >| "$QUEST_JOURNAL_FILE" 2>/dev/null || {
    typeset -g QUEST_STATE_ENABLED=0
    return 1
  }

  return 0
}

function _quest_log_event() {
  _quest_ensure_state_fs || return
  print -r -- "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$QUEST_JOURNAL_FILE"
}

function _quest_save_boss_state() {
  _quest_ensure_state_fs || return

  if (( QUEST_BOSS_ACTIVE )); then
    cat >| "$QUEST_BOSS_STATE_FILE" <<EOF
typeset -g QUEST_BOSS_ACTIVE=${QUEST_BOSS_ACTIVE}
typeset -g QUEST_BOSS_NAME=${(qqq)QUEST_BOSS_NAME}
typeset -g QUEST_BOSS_HP=${QUEST_BOSS_HP}
typeset -g QUEST_BOSS_MAX_HP=${QUEST_BOSS_MAX_HP}
typeset -g QUEST_BOSS_PHASE=${QUEST_BOSS_PHASE}
typeset -g QUEST_BOSS_TURNS=${QUEST_BOSS_TURNS}
typeset -g QUEST_BOSS_GUARD=${QUEST_BOSS_GUARD}
typeset -g QUEST_BOSS_CHARGE=${QUEST_BOSS_CHARGE}
typeset -g QUEST_BOSS_CONTEXT=${(qqq)QUEST_BOSS_CONTEXT}
typeset -g QUEST_BOSS_AUTO_KEY=${(qqq)QUEST_BOSS_AUTO_KEY}
typeset -g QUEST_BOSS_AUTO_SOURCE=${(qqq)QUEST_BOSS_AUTO_SOURCE}
EOF
  else
    rm -f "$QUEST_BOSS_STATE_FILE"
  fi
}

function _quest_save_state() {
  (( QUEST_STATE_DIRTY )) || return
  _quest_ensure_state_fs || return

  cat >| "$QUEST_STATE_FILE" <<EOF
typeset -g QUEST_PLAYER_NAME=${(qqq)QUEST_PLAYER_NAME}
typeset -g QUEST_LEVEL=${QUEST_LEVEL}
typeset -g QUEST_XP=${QUEST_XP}
typeset -g QUEST_GOLD=${QUEST_GOLD}
typeset -g QUEST_HP=${QUEST_HP}
typeset -g QUEST_MAX_HP=${QUEST_MAX_HP}
typeset -g QUEST_COMMAND_COUNT=${QUEST_COMMAND_COUNT}
typeset -g QUEST_SUCCESS_STREAK=${QUEST_SUCCESS_STREAK}
typeset -g QUEST_FAILURE_STREAK=${QUEST_FAILURE_STREAK}
typeset -g QUEST_ZONES_DISCOVERED=${QUEST_ZONES_DISCOVERED}
typeset -g QUEST_LEVEL_UPS=${QUEST_LEVEL_UPS}
typeset -g QUEST_MUSIC_ENABLED=${QUEST_MUSIC_ENABLED}
typeset -g QUEST_SFX_ENABLED=${QUEST_SFX_ENABLED}
typeset -g QUEST_BOSS_AUTO_ENABLED=${QUEST_BOSS_AUTO_ENABLED}
typeset -g QUEST_BOSS_AUTO_COOLDOWN_UNTIL=${QUEST_BOSS_AUTO_COOLDOWN_UNTIL}
EOF

  _quest_save_boss_state
  typeset -g QUEST_STATE_DIRTY=0
}

function _quest_bootstrap_state() {
  : "${QUEST_PLAYER_NAME:=${USER}}"
  : "${QUEST_LEVEL:=1}"
  : "${QUEST_XP:=0}"
  : "${QUEST_GOLD:=0}"
  : "${QUEST_HP:=100}"
  : "${QUEST_MAX_HP:=100}"
  : "${QUEST_COMMAND_COUNT:=0}"
  : "${QUEST_SUCCESS_STREAK:=0}"
  : "${QUEST_FAILURE_STREAK:=0}"
  : "${QUEST_ZONES_DISCOVERED:=0}"
  : "${QUEST_LEVEL_UPS:=0}"
  : "${QUEST_MUSIC_ENABLED:=1}"
  : "${QUEST_SFX_ENABLED:=1}"
  : "${QUEST_BOSS_AUTO_ENABLED:=1}"
  : "${QUEST_BOSS_AUTO_COOLDOWN_UNTIL:=0}"
  : "${QUEST_BOSS_ACTIVE:=0}"
  : "${QUEST_BOSS_NAME:=}"
  : "${QUEST_BOSS_HP:=0}"
  : "${QUEST_BOSS_MAX_HP:=0}"
  : "${QUEST_BOSS_PHASE:=1}"
  : "${QUEST_BOSS_TURNS:=0}"
  : "${QUEST_BOSS_GUARD:=0}"
  : "${QUEST_BOSS_CHARGE:=0}"
  : "${QUEST_BOSS_CONTEXT:=}"
  : "${QUEST_BOSS_AUTO_KEY:=}"
  : "${QUEST_BOSS_AUTO_SOURCE:=}"

  _quest_ensure_state_fs || return

  if [[ -f "$QUEST_STATE_FILE" ]]; then
    source "$QUEST_STATE_FILE"
  fi

  : "${QUEST_PLAYER_NAME:=${USER}}"
  : "${QUEST_LEVEL:=1}"
  : "${QUEST_XP:=0}"
  : "${QUEST_GOLD:=0}"
  : "${QUEST_HP:=100}"
  : "${QUEST_MAX_HP:=100}"
  : "${QUEST_COMMAND_COUNT:=0}"
  : "${QUEST_SUCCESS_STREAK:=0}"
  : "${QUEST_FAILURE_STREAK:=0}"
  : "${QUEST_ZONES_DISCOVERED:=0}"
  : "${QUEST_LEVEL_UPS:=0}"
  : "${QUEST_MUSIC_ENABLED:=1}"
  : "${QUEST_SFX_ENABLED:=1}"
  : "${QUEST_BOSS_AUTO_ENABLED:=1}"
  : "${QUEST_BOSS_AUTO_COOLDOWN_UNTIL:=0}"
  if [[ -f "$QUEST_BOSS_STATE_FILE" ]]; then
    source "$QUEST_BOSS_STATE_FILE"
  fi
  : "${QUEST_BOSS_ACTIVE:=0}"
  : "${QUEST_BOSS_NAME:=}"
  : "${QUEST_BOSS_HP:=0}"
  : "${QUEST_BOSS_MAX_HP:=0}"
  : "${QUEST_BOSS_PHASE:=1}"
  : "${QUEST_BOSS_TURNS:=0}"
  : "${QUEST_BOSS_GUARD:=0}"
  : "${QUEST_BOSS_CHARGE:=0}"
  : "${QUEST_BOSS_CONTEXT:=}"
  : "${QUEST_BOSS_AUTO_KEY:=}"
  : "${QUEST_BOSS_AUTO_SOURCE:=}"

  typeset -g QUEST_STATE_DIRTY=1
  _quest_save_state
}

function _quest_format_duration() {
  local seconds="${1:-0}"

  if (( seconds < 1 )); then
    printf '%.2fs' "$seconds"
  elif (( seconds < 60 )); then
    printf '%.1fs' "$seconds"
  elif (( seconds < 3600 )); then
    printf '%dm%02ds' "$(( seconds / 60 ))" "$(( seconds % 60 ))"
  else
    printf '%dh%02dm' "$(( seconds / 3600 ))" "$(( (seconds % 3600) / 60 ))"
  fi
}

function _quest_battery_percent() {
  pmset -g batt 2>/dev/null | awk -F'; *' 'NR == 2 { gsub(/%/, "", $2); print $2 }'
}

function _quest_level_floor() {
  _quest_xp_for_level "$QUEST_LEVEL"
}

function _quest_level_ceiling() {
  _quest_xp_for_level "$(( QUEST_LEVEL + 1 ))"
}

function _quest_resolve_level_progress() {
  local next_threshold

  while true; do
    next_threshold="$(_quest_xp_for_level "$(( QUEST_LEVEL + 1 ))")"
    (( QUEST_XP < next_threshold )) && break

    (( QUEST_LEVEL += 1 ))
    (( QUEST_LEVEL_UPS += 1 ))
    (( QUEST_MAX_HP += 10 ))
    (( QUEST_HP = QUEST_MAX_HP ))
    (( QUEST_GOLD += 20 ))
    _quest_play_sfx level-up
    typeset -g QUEST_STATE_DIRTY=1
    _quest_queue_message "Level up! You are now level ${QUEST_LEVEL}. Max HP +10, +20 gold."
    _quest_log_event "Leveled up to ${QUEST_LEVEL}"
  done
}

function _quest_discover_zone() {
  local zone_key zone_name
  zone_key="${PWD:A}"
  zone_name="$(_quest_zone_name)"

  if ! _quest_ensure_state_fs; then
    _quest_queue_message "Entered zone: ${zone_name}"
    return
  fi

  if ! grep -Fqx -- "$zone_key" "$QUEST_ZONES_FILE" 2>/dev/null; then
    print -r -- "$zone_key" >> "$QUEST_ZONES_FILE"
    (( QUEST_ZONES_DISCOVERED += 1 ))
    (( QUEST_XP += 12 ))
    (( QUEST_GOLD += 4 ))
    _quest_play_sfx discovery
    typeset -g QUEST_STATE_DIRTY=1
    _quest_queue_message "New zone discovered: ${zone_name} (+12 XP, +4 gold)"
    _quest_log_event "Discovered zone ${zone_key}"
    _quest_resolve_level_progress
  else
    _quest_queue_message "Entered zone: ${zone_name}"
  fi
}

function _quest_spawn_boss() {
  local name hp context auto_key auto_source
  name="$1"
  hp="$2"
  context="$3"
  auto_key="${4:-}"
  auto_source="${5:-manual}"

  (( QUEST_BOSS_ACTIVE )) && return 1

  typeset -g QUEST_BOSS_NAME="$name"
  typeset -g QUEST_BOSS_MAX_HP="$hp"
  typeset -g QUEST_BOSS_CONTEXT="$context"
  typeset -g QUEST_BOSS_ACTIVE=1
  typeset -g QUEST_BOSS_HP="$hp"
  typeset -g QUEST_BOSS_PHASE=1
  typeset -g QUEST_BOSS_TURNS=0
  typeset -g QUEST_BOSS_GUARD=0
  typeset -g QUEST_BOSS_CHARGE=0
  typeset -g QUEST_BOSS_AUTO_KEY="$auto_key"
  typeset -g QUEST_BOSS_AUTO_SOURCE="$auto_source"
  typeset -g QUEST_BOSS_AUTO_COOLDOWN_UNTIL=$(( QUEST_COMMAND_COUNT + 10 ))
  typeset -g QUEST_STATE_DIRTY=1
  _quest_save_state
  _quest_log_event "Started ${auto_source} boss fight against ${QUEST_BOSS_NAME}"
  return 0
}

function _quest_repo_todo_count() {
  local repo_root="$1"
  rg -n --no-messages '\b(TODO|FIXME|XXX)\b' "$repo_root" -g '!/.git' 2>/dev/null | wc -l | tr -d ' '
}

function _quest_maybe_trigger_auto_boss() {
  local repo_root branch unmerged changed untracked todo_count spawn_key total_changes

  (( QUEST_BOSS_AUTO_ENABLED )) || return
  (( QUEST_BOSS_ACTIVE == 0 )) || return
  (( QUEST_COMMAND_COUNT < QUEST_BOSS_AUTO_COOLDOWN_UNTIL )) && return

  if (( QUEST_FAILURE_STREAK >= 3 )); then
    spawn_key="error:${PWD:A}"
    if _quest_spawn_boss "The Error Wraith" \
      $(( 68 + QUEST_LEVEL * 8 + QUEST_FAILURE_STREAK * 3 )) \
      "$(_quest_zone_name)" \
      "$spawn_key" \
      "natural"; then
      _quest_play_sfx discovery
      _quest_queue_message "Repeated failures have summoned The Error Wraith."
    fi
    return
  fi

  repo_root="$(_quest_repo_root)" || return
  branch="$(_quest_git_branch 2>/dev/null)"
  unmerged="$(git -C "$repo_root" diff --name-only --diff-filter=U 2>/dev/null | awk 'END{print NR+0}')"
  if (( unmerged > 0 )); then
    spawn_key="merge:${repo_root}:${branch}"
    if _quest_spawn_boss "The Merge Warden" \
      $(( 92 + QUEST_LEVEL * 10 + unmerged * 4 )) \
      "${branch:-detached-quest}" \
      "$spawn_key" \
      "natural"; then
      _quest_play_sfx discovery
      _quest_queue_message "Merge conflict energy has awakened The Merge Warden."
    fi
    return
  fi

  changed="$(git -C "$repo_root" status --porcelain 2>/dev/null | awk '$1 != "??" {count++} END{print count+0}')"
  untracked="$(git -C "$repo_root" status --porcelain 2>/dev/null | awk '$1 == "??" {count++} END{print count+0}')"
  total_changes=$(( changed + untracked ))
  if (( total_changes >= 8 )); then
    spawn_key="chaos:${repo_root}:${branch}"
    if _quest_spawn_boss "The Chaos Warden" \
      $(( 84 + QUEST_LEVEL * 9 + total_changes * 2 )) \
      "${branch:-working-tree}" \
      "$spawn_key" \
      "natural"; then
      _quest_play_sfx discovery
      _quest_queue_message "Your cluttered working tree has drawn The Chaos Warden."
    fi
    return
  fi

  todo_count="$(_quest_repo_todo_count "$repo_root")"
  if (( todo_count >= 12 )); then
    spawn_key="debt:${repo_root}"
    if _quest_spawn_boss "The Debt Specter" \
      $(( 78 + QUEST_LEVEL * 8 + todo_count / 2 )) \
      "${branch:-technical-debt}" \
      "$spawn_key" \
      "natural"; then
      _quest_play_sfx discovery
      _quest_queue_message "Neglected TODOs have conjured The Debt Specter."
    fi
  fi
}

function _quest_apply_command_outcome() {
  local command exit_code xp gold heal damage
  command="${QUEST_LAST_COMMAND}"
  exit_code="${QUEST_LAST_STATUS}"

  [[ -n "$command" ]] || return

  xp=0
  gold=0
  heal=0
  damage=0

  (( QUEST_COMMAND_COUNT += 1 ))

  if (( exit_code == 0 )); then
    (( QUEST_SUCCESS_STREAK += 1 ))
    typeset -g QUEST_FAILURE_STREAK=0
    xp=3
    gold=1
    heal=1

    [[ "$command" == git\ commit* ]] && (( xp += 25, gold += 10 ))
    [[ "$command" == git\ push* || "$command" == git\ pull* || "$command" == git\ rebase* ]] && (( xp += 15, gold += 6 ))
    [[ "$command" == git\ add* || "$command" == git\ status* || "$command" == git\ diff* || "$command" == git\ log* ]] && (( xp += 5, gold += 2 ))
    [[ "$command" == *pytest* || "$command" == *test* || "$command" == *lint* || "$command" == *check* || "$command" == *build* ]] && (( xp += 12, gold += 5 ))
    [[ "$command" == rg\ * || "$command" == fd\ * || "$command" == find\ * || "$command" == ls* || "$command" == tree* || "$command" == eza* || "$command" == exa* ]] && (( xp += 4, gold += 1 ))
    [[ "$command" == mkdir* || "$command" == touch* ]] && (( xp += 6, gold += 2 ))

    if (( QUEST_SUCCESS_STREAK > 0 && QUEST_SUCCESS_STREAK % 7 == 0 )); then
      (( xp += 12, gold += 3 ))
      _quest_queue_message "Momentum bonus! ${QUEST_SUCCESS_STREAK} successful actions in a row."
    fi

    (( QUEST_XP += xp ))
    (( QUEST_GOLD += gold ))
    (( QUEST_HP = QUEST_HP + heal > QUEST_MAX_HP ? QUEST_MAX_HP : QUEST_HP + heal ))
    typeset -g QUEST_LAST_DAMAGE=0
    typeset -g QUEST_LAST_REWARD_XP="$xp"
    typeset -g QUEST_LAST_REWARD_GOLD="$gold"

    if (( xp >= 15 || gold >= 6 )); then
      _quest_queue_message "Reward earned: +${xp} XP, +${gold} gold from ${command}"
      _quest_log_event "Rewarded ${xp} XP and ${gold} gold for ${command}"
    fi
  else
    (( QUEST_SUCCESS_STREAK = 0 ))
    (( QUEST_FAILURE_STREAK += 1 ))
    damage=$(( exit_code > 12 ? 12 : exit_code + 2 ))
    (( QUEST_HP -= damage ))
    _quest_play_sfx damage
    typeset -g QUEST_LAST_DAMAGE="$damage"
    typeset -g QUEST_LAST_REWARD_XP=0
    typeset -g QUEST_LAST_REWARD_GOLD=0
    _quest_queue_message "You took ${damage} damage from ${command}"

    if (( QUEST_HP <= 0 )); then
      (( QUEST_GOLD = QUEST_GOLD > 10 ? QUEST_GOLD - 10 : 0 ))
      (( QUEST_HP = QUEST_MAX_HP ))
      _quest_queue_message "You were downed and respawned at camp. -10 gold, HP restored."
      _quest_log_event "Downed by ${command}"
      if (( QUEST_BOSS_ACTIVE )); then
        _quest_queue_message "${QUEST_BOSS_NAME} has driven you from the arena."
        _quest_log_event "Lost boss fight against ${QUEST_BOSS_NAME}"
        typeset -g QUEST_BOSS_ACTIVE=0
        typeset -g QUEST_BOSS_NAME=''
        typeset -g QUEST_BOSS_HP=0
        typeset -g QUEST_BOSS_MAX_HP=0
        typeset -g QUEST_BOSS_PHASE=1
        typeset -g QUEST_BOSS_TURNS=0
        typeset -g QUEST_BOSS_GUARD=0
        typeset -g QUEST_BOSS_CHARGE=0
        typeset -g QUEST_BOSS_CONTEXT=''
      fi
    fi
  fi

  typeset -g QUEST_STATE_DIRTY=1
  _quest_resolve_level_progress
  typeset -g QUEST_LAST_COMMAND=''
}

function _quest_flush_pending_messages() {
  local message

  (( ${#QUEST_PENDING_MESSAGES[@]} == 0 )) && return

  for message in "${QUEST_PENDING_MESSAGES[@]}"; do
    print -P "%F{178}>>%f %F{230}${message}%f"
  done

  QUEST_PENDING_MESSAGES=()
}

function _quest_set_window_title() {
  local zone branch title
  zone="$(_quest_zone_name)"
  branch="$(_quest_git_branch 2>/dev/null)"
  title="Realm ${HOST%%.*} :: ${zone}"

  [[ -n "$branch" ]] && title="${title} :: Quest ${branch}"
  print -Pn "\e]0;${title}\a"
}

function _quest_set_iterm_badge() {
  [[ "${TERM_PROGRAM:-}" == "iTerm.app" || "${LC_TERMINAL:-}" == "iTerm2" ]] || return

  local zone branch badge encoded
  zone="$(_quest_zone_name)"
  branch="$(_quest_git_branch 2>/dev/null)"
  badge="${QUEST_MODE_BADGE_PREFIX}\n${QUEST_PLAYER_NAME} | Lv ${QUEST_LEVEL}\nHP ${QUEST_HP}/${QUEST_MAX_HP} | ${QUEST_GOLD}g | ${QUEST_XP}xp\nZone: ${zone}"

  [[ -n "$branch" ]] && badge="${badge}\nQuest: ${branch}"
  encoded="$(print -nr -- "$badge" | base64 | tr -d '\n')"
  print -Pn "\e]1337;SetBadgeFormat=${encoded}\a"
}

function _quest_print_banner_once() {
  (( QUEST_MODE_ENABLE_BANNER )) || return
  (( QUEST_BANNER_SHOWN == 0 )) || return

  typeset -g QUEST_BANNER_SHOWN=1

  print -P ''
  print -P '%F{178}      .::.      Quest Mode Engaged      .::.%f'
  print -P "%F{143}   Hero:%f %F{230}${QUEST_PLAYER_NAME}%f   %F{143}Level:%f %F{229}${QUEST_LEVEL}%f   %F{143}Gold:%f %F{220}${QUEST_GOLD}g%f"
  print -P "%F{143}   HP:%f %F{230}${QUEST_HP}/${QUEST_MAX_HP}%f   %F{143}Zones:%f %F{229}${QUEST_ZONES_DISCOVERED}%f   %F{143}XP:%f %F{222}${QUEST_XP}%f"
  print -P '%F{66}   Tip:%f use %F{230}quest-docs%f, %F{230}quest-stats%f, %F{230}quest-journal%f, or %F{230}quest-rest%f'
}

function _quest_preexec() {
  typeset -g QUEST_COMMAND_STARTED_AT="${EPOCHREALTIME:-}"
  typeset -g QUEST_LAST_COMMAND="$1"
}

function _quest_precmd() {
  local exit_code=$?
  local now
  now="${EPOCHREALTIME:-}"

  typeset -g QUEST_LAST_STATUS="$exit_code"
  if [[ -n "$QUEST_COMMAND_STARTED_AT" && -n "$now" ]]; then
    typeset -g QUEST_LAST_DURATION="$(( now - QUEST_COMMAND_STARTED_AT ))"
  else
    typeset -g QUEST_LAST_DURATION=0
  fi

  _quest_apply_command_outcome
  _quest_maybe_trigger_auto_boss
  _quest_set_window_title
  _quest_set_iterm_badge
  _quest_maybe_start_music
  _quest_print_banner_once
  _quest_flush_pending_messages
  _quest_save_state
}

function prompt_quest_class() {
  p10k segment -f 230 -b 58 -i '⚔' -t "$QUEST_MODE_CLASS"
}

function prompt_quest_realm() {
  p10k segment -f 230 -b 24 -i '♜' -t "${USER}@${HOST%%.*}"
}

function prompt_quest_zone() {
  p10k segment -f 230 -b 28 -i '🗺' -t "$(_quest_zone_name)"
}

function prompt_quest_questline() {
  local branch
  branch="$(_quest_git_branch 2>/dev/null)" || return
  p10k segment -f 230 -b 88 -i '✦' -t "$branch"
}

function prompt_quest_rank() {
  p10k segment -f 230 -b 60 -i '★' -t "Lv ${QUEST_LEVEL} ${QUEST_XP}xp ${QUEST_GOLD}g"
}

function prompt_quest_vitals() {
  local color
  color=22

  if (( QUEST_HP * 100 / QUEST_MAX_HP < 60 )); then
    color=94
  fi
  if (( QUEST_HP * 100 / QUEST_MAX_HP < 30 )); then
    color=160
  fi

  if (( QUEST_LAST_DAMAGE > 0 )); then
    p10k segment -f 230 -b "$color" -i '♥' -t "HP ${QUEST_HP}/${QUEST_MAX_HP} -${QUEST_LAST_DAMAGE}"
  else
    p10k segment -f 230 -b "$color" -i '♥' -t "HP ${QUEST_HP}/${QUEST_MAX_HP}"
  fi
}

function prompt_quest_turn() {
  p10k segment -f 230 -b 24 -i '⌛' -t "$(_quest_format_duration "$QUEST_LAST_DURATION")"
}

function prompt_quest_mana() {
  local battery color
  battery="$(_quest_battery_percent)"
  [[ -n "$battery" ]] || return

  if (( battery >= 70 )); then
    color=24
  elif (( battery >= 35 )); then
    color=94
  else
    color=124
  fi

  p10k segment -f 230 -b "$color" -i '✧' -t "Mana ${battery}%"
}

function prompt_quest_clock() {
  p10k segment -f 230 -b 95 -i '☽' -t "$(date +%H:%M)"
}

function quest-map() {
  print -P '%F{178}Current zone:%f %F{230}%~%f'
}

function quest-log() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git status -sb
  else
    print -P '%F{160}No questline here.%f'
  fi
}

function quest-stats() {
  local floor ceiling needed
  floor="$(_quest_level_floor)"
  ceiling="$(_quest_level_ceiling)"
  needed=$(( ceiling - QUEST_XP ))

  print -P "%F{178}Hero:%f %F{230}${QUEST_PLAYER_NAME}%f"
  print -P "%F{178}Level:%f %F{230}${QUEST_LEVEL}%f   %F{178}XP:%f %F{230}${QUEST_XP}%f   %F{178}To next level:%f %F{230}${needed}%f"
  print -P "%F{178}HP:%f %F{230}${QUEST_HP}/${QUEST_MAX_HP}%f   %F{178}Gold:%f %F{220}${QUEST_GOLD}g%f   %F{178}Streak:%f %F{230}${QUEST_SUCCESS_STREAK}%f"
  print -P "%F{178}Commands:%f %F{230}${QUEST_COMMAND_COUNT}%f   %F{178}Zones discovered:%f %F{230}${QUEST_ZONES_DISCOVERED}%f   %F{178}Level-ups:%f %F{230}${QUEST_LEVEL_UPS}%f"
  print -P "%F{178}Failure streak:%f %F{230}${QUEST_FAILURE_STREAK}%f   %F{178}Auto bosses:%f %F{230}${QUEST_BOSS_AUTO_ENABLED}%f"
  if _quest_music_is_running; then
    print -P "%F{178}Music:%f %F{230}playing%f   %F{178}SFX:%f %F{230}${QUEST_SFX_ENABLED}%f"
  else
    print -P "%F{178}Music:%f %F{160}stopped%f   %F{178}SFX:%f %F{230}${QUEST_SFX_ENABLED}%f"
  fi
  if (( QUEST_BOSS_ACTIVE )); then
    print -P "%F{178}Boss:%f %F{160}${QUEST_BOSS_NAME}%f   %F{178}Boss HP:%f %F{230}${QUEST_BOSS_HP}/${QUEST_BOSS_MAX_HP}%f   %F{178}Charge:%f %F{230}${QUEST_BOSS_CHARGE}/3%f"
    print -P "%F{178}Boss source:%f %F{230}${QUEST_BOSS_AUTO_SOURCE:-manual}%f"
  fi
}

function quest-journal() {
  if ! _quest_ensure_state_fs; then
    print -P '%F{160}Your journal is unavailable in this shell.%f'
    return
  fi

  if [[ -s "$QUEST_JOURNAL_FILE" ]]; then
    tail -n 12 "$QUEST_JOURNAL_FILE"
  else
    print -P '%F{160}Your journal is still blank.%f'
  fi
}

function quest-docs() {
  cat <<'EOF'
Quest Mode Commands

Core
  quest-docs         Show this guide.
  quest-examples     Show copy-paste examples that trigger quest mechanics.
  quest-boss         Show the current boss encounter or tell you how to start one.
  quest-boss-auto    Show or toggle natural auto-boss spawning.
  quest-stats        Show hero stats, progression, music, and SFX state.
  quest-journal      Show recent quest events.
  quest-log          Show git status for the current repo.
  quest-map          Show your current zone.
  quest-rest         Recover 10 HP.

Boss Fight
  quest-boss-start   Start a real boss fight for the current zone.
  quest-boss-status  Show current boss and available actions.
  quest-boss-attack  Perform a basic attack.
  quest-boss-defend  Brace for the next boss hit and recover a little HP.
  quest-boss-special Spend 3 charge to unleash a heavy attack.
  quest-boss-flee    Leave the boss fight and lose 5 gold.

Audio
  quest-music-start  Start ambient tavern music.
  quest-music-stop   Stop ambient tavern music.
  quest-music-toggle Toggle ambient music on or off.
  quest-sfx-toggle   Toggle quest sound effects on or off.

How HP Works
  HP goes down when a command fails with a non-zero exit code.
  Damage formula: exit code + 2, capped at 12 damage.
  Example: exit code 1 -> 3 damage, exit code 2 -> 4 damage, exit code 127 -> 12 damage.
  Successful commands heal 1 HP up to your max HP.
  quest-rest heals 10 HP.
  Leveling up fully restores HP and raises max HP by 10.
  If HP falls to 0 or below, you respawn at full HP and lose 10 gold.

How Progression Works
  First time entering a directory counts as discovering a new zone: +12 XP, +4 gold.
  Any successful command grants a small baseline reward: +3 XP, +1 gold.
  Some commands grant extra rewards, especially git work, tests, checks, builds, and exploration commands.
  Every 7 successful commands in a row grants a momentum bonus.

Natural Boss Triggers
  Three failed commands in a row can summon The Error Wraith.
  Entering a repo with merge conflicts can summon The Merge Warden.
  Working in a repo with many changed and untracked files can summon The Chaos Warden.
  Entering a repo dense with TODO, FIXME, or XXX markers can summon The Debt Specter.
EOF
}

function quest-examples() {
  cat <<'EOF'
Quest Mode Examples

See HP go down
  false
  This exits with code 1, so you take 3 damage.

  not_a_real_command
  This usually exits with code 127, so you take the capped 12 damage.

See healing and small rewards
  pwd
  ls
  rg quest ~/.config/quest-mode 2>/dev/null
  Each successful command heals 1 HP and grants baseline XP/gold.

See zone discovery
  mkdir -p /tmp/quest-ruins
  cd /tmp/quest-ruins
  The first time you enter a new directory, it counts as a discovered zone.

See rest
  quest-rest
  Recovers 10 HP and plays the rest sound.

See audio controls
  quest-music-toggle
  quest-sfx-toggle

See a full mini run
  quest-stats
  false
  mkdir -p /tmp/quest-ruins && cd /tmp/quest-ruins
  pwd
  quest-rest
  quest-journal

See a boss-fight style sequence
  quest-boss-start
  quest-boss-status
  quest-boss-attack
  quest-boss-defend
  quest-boss-special
  quest-boss-flee
  Start the fight, build charge with attack or defend, then spend it with special.

See a natural boss trigger
  false
  false
  false
  Three failures in a row can naturally summon The Error Wraith.
EOF
}

function _quest_reset_boss() {
  typeset -g QUEST_BOSS_ACTIVE=0
  typeset -g QUEST_BOSS_NAME=''
  typeset -g QUEST_BOSS_HP=0
  typeset -g QUEST_BOSS_MAX_HP=0
  typeset -g QUEST_BOSS_PHASE=1
  typeset -g QUEST_BOSS_TURNS=0
  typeset -g QUEST_BOSS_GUARD=0
  typeset -g QUEST_BOSS_CHARGE=0
  typeset -g QUEST_BOSS_CONTEXT=''
  typeset -g QUEST_STATE_DIRTY=1
  _quest_save_state
}

function _quest_boss_maybe_phase_shift() {
  if (( QUEST_BOSS_ACTIVE && QUEST_BOSS_PHASE == 1 && QUEST_BOSS_HP * 2 <= QUEST_BOSS_MAX_HP )); then
    typeset -g QUEST_BOSS_PHASE=2
    _quest_play_sfx discovery
    _quest_queue_message "${QUEST_BOSS_NAME} enters phase two and enrages."
    _quest_log_event "${QUEST_BOSS_NAME} entered phase two"
  fi
}

function _quest_boss_victory() {
  local xp_reward gold_reward
  xp_reward=$(( 40 + QUEST_LEVEL * 10 + QUEST_BOSS_PHASE * 8 ))
  gold_reward=$(( 25 + QUEST_LEVEL * 5 + QUEST_BOSS_PHASE * 6 ))

  (( QUEST_XP += xp_reward ))
  (( QUEST_GOLD += gold_reward ))
  (( QUEST_HP = QUEST_HP + 12 > QUEST_MAX_HP ? QUEST_MAX_HP : QUEST_HP + 12 ))
  _quest_play_sfx level-up
  _quest_queue_message "Victory! ${QUEST_BOSS_NAME} is defeated. +${xp_reward} XP, +${gold_reward} gold."
  _quest_log_event "Defeated ${QUEST_BOSS_NAME}"
  _quest_reset_boss
  _quest_resolve_level_progress
}

function _quest_boss_enemy_turn() {
  local damage
  (( QUEST_BOSS_ACTIVE )) || return

  _quest_boss_maybe_phase_shift
  damage=$(( (QUEST_BOSS_PHASE == 1 ? 8 : 12) + (RANDOM % 4) + QUEST_LEVEL ))

  if (( QUEST_BOSS_GUARD )); then
    damage=$(( (damage + 1) / 2 ))
    typeset -g QUEST_BOSS_GUARD=0
  fi

  (( QUEST_HP -= damage ))
  typeset -g QUEST_LAST_DAMAGE="$damage"
  _quest_play_sfx damage
  _quest_queue_message "${QUEST_BOSS_NAME} hits you for ${damage} damage."

  if (( QUEST_HP <= 0 )); then
    (( QUEST_GOLD = QUEST_GOLD > 10 ? QUEST_GOLD - 10 : 0 ))
    (( QUEST_HP = QUEST_MAX_HP ))
    _quest_queue_message "You were defeated by ${QUEST_BOSS_NAME}. Respawned at camp, -10 gold."
    _quest_log_event "Lost boss fight against ${QUEST_BOSS_NAME}"
    _quest_reset_boss
    return
  fi

  (( QUEST_BOSS_CHARGE < 3 )) && (( QUEST_BOSS_CHARGE += 1 ))
}

function quest-boss-start() {
  local branch

  if (( QUEST_BOSS_ACTIVE )); then
    quest-boss-status
    return
  fi

  branch="$(_quest_git_branch 2>/dev/null)"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    _quest_spawn_boss "The Merge Warden" \
      $(( 90 + QUEST_LEVEL * 10 )) \
      "${branch:-detached-quest}" \
      "" \
      "manual"
  else
    _quest_spawn_boss "The Ruins Sentinel" \
      $(( 72 + QUEST_LEVEL * 8 )) \
      "$(_quest_zone_name)" \
      "" \
      "manual"
  fi

  print -P "%F{178}${QUEST_BOSS_NAME} emerges in ${QUEST_BOSS_CONTEXT}.%f"
  quest-boss-status
}

function quest-boss-status() {
  if (( ! QUEST_BOSS_ACTIVE )); then
    print -P '%F{178}No boss is active.%f'
    print -P '%F{230}Run `quest-boss-start` to begin an encounter.%f'
    return
  fi

  print -P "%F{178}Boss:%f %F{230}${QUEST_BOSS_NAME}%f"
  print -P "%F{178}Source:%f %F{230}${QUEST_BOSS_AUTO_SOURCE:-manual}%f   %F{178}Arena:%f %F{230}${QUEST_BOSS_CONTEXT}%f"
  print -P "%F{178}Boss HP:%f %F{230}${QUEST_BOSS_HP}/${QUEST_BOSS_MAX_HP}%f   %F{178}Phase:%f %F{230}${QUEST_BOSS_PHASE}%f   %F{178}Turns:%f %F{230}${QUEST_BOSS_TURNS}%f"
  print -P "%F{178}Hero HP:%f %F{230}${QUEST_HP}/${QUEST_MAX_HP}%f   %F{178}Charge:%f %F{230}${QUEST_BOSS_CHARGE}/3%f   %F{178}Guard:%f %F{230}${QUEST_BOSS_GUARD}%f"
  print -P '%F{178}Actions:%f quest-boss-attack, quest-boss-defend, quest-boss-special, quest-boss-flee'
}

function quest-boss-attack() {
  local damage
  (( QUEST_BOSS_ACTIVE )) || { quest-boss-status; return 1; }

  damage=$(( 10 + QUEST_LEVEL * 2 + (RANDOM % 6) + QUEST_SUCCESS_STREAK / 4 ))
  (( QUEST_BOSS_HP -= damage ))
  (( QUEST_BOSS_TURNS += 1 ))
  (( QUEST_BOSS_CHARGE < 3 )) && (( QUEST_BOSS_CHARGE += 1 ))
  _quest_queue_message "You strike ${QUEST_BOSS_NAME} for ${damage} damage."

  if (( QUEST_BOSS_HP <= 0 )); then
    _quest_boss_victory
  else
    _quest_boss_enemy_turn
  fi

  typeset -g QUEST_STATE_DIRTY=1
  _quest_save_state
  quest-boss-status
}

function quest-boss-defend() {
  local recover
  (( QUEST_BOSS_ACTIVE )) || { quest-boss-status; return 1; }

  recover=$(( 3 + QUEST_LEVEL ))
  (( QUEST_HP = QUEST_HP + recover > QUEST_MAX_HP ? QUEST_MAX_HP : QUEST_HP + recover ))
  typeset -g QUEST_BOSS_GUARD=1
  (( QUEST_BOSS_TURNS += 1 ))
  (( QUEST_BOSS_CHARGE < 3 )) && (( QUEST_BOSS_CHARGE += 1 ))
  _quest_queue_message "You brace for impact and recover ${recover} HP."
  _quest_boss_enemy_turn
  typeset -g QUEST_STATE_DIRTY=1
  _quest_save_state
  quest-boss-status
}

function quest-boss-special() {
  local damage
  (( QUEST_BOSS_ACTIVE )) || { quest-boss-status; return 1; }

  if (( QUEST_BOSS_CHARGE < 3 )); then
    print -P '%F{160}Your special is not ready. Build 3 charge first.%f'
    return 1
  fi

  damage=$(( 24 + QUEST_LEVEL * 3 + (RANDOM % 10) ))
  typeset -g QUEST_BOSS_CHARGE=0
  (( QUEST_BOSS_HP -= damage ))
  (( QUEST_BOSS_TURNS += 1 ))
  _quest_play_sfx discovery
  _quest_queue_message "You unleash a special attack for ${damage} damage."

  if (( QUEST_BOSS_HP <= 0 )); then
    _quest_boss_victory
  else
    _quest_boss_enemy_turn
  fi

  typeset -g QUEST_STATE_DIRTY=1
  _quest_save_state
  quest-boss-status
}

function quest-boss-flee() {
  (( QUEST_BOSS_ACTIVE )) || { quest-boss-status; return 1; }

  (( QUEST_GOLD = QUEST_GOLD > 5 ? QUEST_GOLD - 5 : 0 ))
  _quest_queue_message "You flee from ${QUEST_BOSS_NAME}. -5 gold."
  _quest_log_event "Fled boss fight against ${QUEST_BOSS_NAME}"
  _quest_reset_boss
}

function quest-boss() {
  quest-boss-status
}

function quest-boss-auto() {
  case "$1" in
    on)
      typeset -g QUEST_BOSS_AUTO_ENABLED=1
      typeset -g QUEST_STATE_DIRTY=1
      _quest_save_state
      print -P '%F{178}Natural boss spawning enabled.%f'
      ;;
    off)
      typeset -g QUEST_BOSS_AUTO_ENABLED=0
      typeset -g QUEST_STATE_DIRTY=1
      _quest_save_state
      print -P '%F{178}Natural boss spawning disabled.%f'
      ;;
    toggle)
      if (( QUEST_BOSS_AUTO_ENABLED )); then
        quest-boss-auto off
      else
        quest-boss-auto on
      fi
      ;;
    *)
      print -P "%F{178}Auto bosses:%f %F{230}${QUEST_BOSS_AUTO_ENABLED}%f"
      print -P "%F{178}Cooldown until command:%f %F{230}${QUEST_BOSS_AUTO_COOLDOWN_UNTIL}%f"
      print -P '%F{230}Use quest-boss-auto on, quest-boss-auto off, or quest-boss-auto toggle.%f'
      ;;
  esac
}

function quest-rest() {
  (( QUEST_HP = QUEST_HP + 10 > QUEST_MAX_HP ? QUEST_MAX_HP : QUEST_HP + 10 ))
  typeset -g QUEST_STATE_DIRTY=1
  _quest_play_sfx rest
  _quest_queue_message 'You rested by the fire and recovered 10 HP.'
  _quest_log_event 'Rested at camp'
  clear
  typeset -g QUEST_BANNER_SHOWN=0
  _quest_print_banner_once
  _quest_flush_pending_messages
  _quest_save_state
}

function quest-music-start() {
  typeset -g QUEST_MUSIC_ENABLED=1
  typeset -g QUEST_STATE_DIRTY=1
  if _quest_music_start; then
    _quest_save_state
    print -P '%F{178}The tavern band tunes up.%f'
  else
    print -P '%F{160}No band could be found. Check quest audio files.%f'
  fi
}

function quest-music-stop() {
  typeset -g QUEST_MUSIC_ENABLED=0
  typeset -g QUEST_STATE_DIRTY=1
  _quest_music_stop
  _quest_save_state
  print -P '%F{178}The hall falls quiet.%f'
}

function quest-music-toggle() {
  if _quest_music_is_running; then
    quest-music-stop
  else
    quest-music-start
  fi
}

function quest-sfx-toggle() {
  if (( QUEST_SFX_ENABLED )); then
    typeset -g QUEST_SFX_ENABLED=0
    print -P '%F{178}Quest sound effects muted.%f'
  else
    typeset -g QUEST_SFX_ENABLED=1
    print -P '%F{178}Quest sound effects enabled.%f'
    _quest_play_sfx discovery
  fi
  typeset -g QUEST_STATE_DIRTY=1
  _quest_save_state
}

_quest_bootstrap_state
_quest_discover_zone

autoload -Uz add-zsh-hook
add-zsh-hook preexec _quest_preexec
add-zsh-hook precmd _quest_precmd
add-zsh-hook chpwd _quest_discover_zone
add-zsh-hook chpwd _quest_set_window_title
add-zsh-hook chpwd _quest_set_iterm_badge
add-zsh-hook zshexit _quest_save_state

if typeset -f p10k >/dev/null 2>&1; then
  p10k reload >/dev/null 2>&1
fi
