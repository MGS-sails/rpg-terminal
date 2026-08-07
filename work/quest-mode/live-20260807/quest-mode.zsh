[[ -n "${QUEST_MODE_LOADED:-}" ]] && return
typeset -g QUEST_MODE_LOADED=1

[[ -o interactive ]] || return

zmodload zsh/datetime 2>/dev/null || true

typeset -g QUEST_MODE_CLASS="${QUEST_MODE_CLASS:-Wayfinder}"
typeset -g QUEST_MODE_BADGE_PREFIX="${QUEST_MODE_BADGE_PREFIX:-QUEST MODE}"
typeset -g QUEST_MODE_ENABLE_BANNER="${QUEST_MODE_ENABLE_BANNER:-1}"
typeset -g QUEST_LAST_STATUS=0
typeset -g QUEST_LAST_DURATION=0
typeset -g QUEST_COMMAND_STARTED_AT=''
typeset -g QUEST_BANNER_SHOWN=0

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
  badge="${QUEST_MODE_BADGE_PREFIX}\nRealm: ${HOST%%.*}\nZone: ${zone}"

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
  print -P '%F{143}   Realm:%f %F{230}${HOST%%.*}%f   %F{143}Zone:%f %F{229}$(_quest_zone_name)%f'
  if [[ -n "$(_quest_git_branch 2>/dev/null)" ]]; then
    print -P '%F{143}   Active Quest:%f %F{216}$(_quest_git_branch 2>/dev/null)%f'
  fi
  print -P '%F{66}   Tip:%f use %F{230}quest-log%f, %F{230}quest-map%f, or %F{230}quest-rest%f'
}

function _quest_preexec() {
  typeset -g QUEST_COMMAND_STARTED_AT="${EPOCHREALTIME:-}"
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

  _quest_set_window_title
  _quest_set_iterm_badge
  _quest_print_banner_once
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

function prompt_quest_vitals() {
  if (( QUEST_LAST_STATUS == 0 )); then
    p10k segment -f 230 -b 22 -i '♥' -t 'HP full'
  else
    p10k segment -f 230 -b 160 -i '☠' -t "HP ${QUEST_LAST_STATUS}"
  fi
}

function prompt_quest_turn() {
  p10k segment -f 230 -b 60 -i '⌛' -t "$(_quest_format_duration "$QUEST_LAST_DURATION")"
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

function quest-rest() {
  clear
  typeset -g QUEST_BANNER_SHOWN=0
  _quest_print_banner_once
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _quest_preexec
add-zsh-hook precmd _quest_precmd
add-zsh-hook chpwd _quest_set_window_title
add-zsh-hook chpwd _quest_set_iterm_badge

if typeset -f p10k >/dev/null 2>&1; then
  p10k reload >/dev/null 2>&1
fi
