[[ -n "${QUEST_MODE_LOADED:-}" ]] && return
typeset -g QUEST_MODE_LOADED=1

[[ -o interactive ]] || return

zmodload zsh/datetime 2>/dev/null || true

typeset -g QUEST_MODE_CLASS="${QUEST_MODE_CLASS:-Wayfinder}"
typeset -g QUEST_MODE_BADGE_PREFIX="${QUEST_MODE_BADGE_PREFIX:-QUEST MODE}"
typeset -g QUEST_MODE_ENABLE_BANNER="${QUEST_MODE_ENABLE_BANNER:-1}"
typeset -g QUEST_STATE_DIR="${HOME}/.config/quest-mode/state"
typeset -g QUEST_STATE_FILE="${QUEST_STATE_DIR}/hero.zsh"
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
typeset -g QUEST_COMMAND_STARTED_AT=''
typeset -g QUEST_LAST_COMMAND=''
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
typeset -g QUEST_ZONES_DISCOVERED=${QUEST_ZONES_DISCOVERED}
typeset -g QUEST_LEVEL_UPS=${QUEST_LEVEL_UPS}
typeset -g QUEST_MUSIC_ENABLED=${QUEST_MUSIC_ENABLED}
typeset -g QUEST_SFX_ENABLED=${QUEST_SFX_ENABLED}
EOF

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
  : "${QUEST_ZONES_DISCOVERED:=0}"
  : "${QUEST_LEVEL_UPS:=0}"
  : "${QUEST_MUSIC_ENABLED:=1}"
  : "${QUEST_SFX_ENABLED:=1}"

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
  : "${QUEST_ZONES_DISCOVERED:=0}"
  : "${QUEST_LEVEL_UPS:=0}"
  : "${QUEST_MUSIC_ENABLED:=1}"
  : "${QUEST_SFX_ENABLED:=1}"

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

function _quest_apply_command_outcome() {
  local command status xp gold heal damage
  command="${QUEST_LAST_COMMAND}"
  status="${QUEST_LAST_STATUS}"

  [[ -n "$command" ]] || return

  xp=0
  gold=0
  heal=0
  damage=0

  (( QUEST_COMMAND_COUNT += 1 ))

  if (( status == 0 )); then
    (( QUEST_SUCCESS_STREAK += 1 ))
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
      _quest_queue_message "Reward earned: +${xp} XP, +${gold} gold from \`${command}\`"
      _quest_log_event "Rewarded ${xp} XP and ${gold} gold for ${command}"
    fi
  else
    (( QUEST_SUCCESS_STREAK = 0 ))
    damage=$(( status > 12 ? 12 : status + 2 ))
    (( QUEST_HP -= damage ))
    _quest_play_sfx damage
    typeset -g QUEST_LAST_DAMAGE="$damage"
    typeset -g QUEST_LAST_REWARD_XP=0
    typeset -g QUEST_LAST_REWARD_GOLD=0
    _quest_queue_message "You took ${damage} damage from \`${command}\`"

    if (( QUEST_HP <= 0 )); then
      (( QUEST_GOLD = QUEST_GOLD > 10 ? QUEST_GOLD - 10 : 0 ))
      (( QUEST_HP = QUEST_MAX_HP ))
      _quest_queue_message "You were downed and respawned at camp. -10 gold, HP restored."
      _quest_log_event "Downed by ${command}"
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
  print -P '%F{66}   Tip:%f use %F{230}quest-stats%f, %F{230}quest-journal%f, %F{230}quest-log%f, or %F{230}quest-rest%f'
}

function _quest_preexec() {
  typeset -g QUEST_COMMAND_STARTED_AT="${EPOCHREALTIME:-}"
  typeset -g QUEST_LAST_COMMAND="$1"
}

function _quest_precmd() {
  local status now
  status=$?
  now="${EPOCHREALTIME:-}"

  typeset -g QUEST_LAST_STATUS="$status"
  if [[ -n "$QUEST_COMMAND_STARTED_AT" && -n "$now" ]]; then
    typeset -g QUEST_LAST_DURATION="$(( now - QUEST_COMMAND_STARTED_AT ))"
  else
    typeset -g QUEST_LAST_DURATION=0
  fi

  _quest_apply_command_outcome
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
  if _quest_music_is_running; then
    print -P "%F{178}Music:%f %F{230}playing%f   %F{178}SFX:%f %F{230}${QUEST_SFX_ENABLED}%f"
  else
    print -P "%F{178}Music:%f %F{160}stopped%f   %F{178}SFX:%f %F{230}${QUEST_SFX_ENABLED}%f"
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
