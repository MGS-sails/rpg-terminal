# Quest Mode

A portable `zsh + iTerm2` quest overlay with:

- RPG-style prompt and persistent stats
- ambient music and sound effects
- zone discovery, XP, gold, HP, and streaks
- manual and natural boss encounters
- a one-command installer for another Mac

## What This Repo Contains

- `work/quest-mode/quest-mode.zsh`
  The main shell/game logic.
- `work/quest-mode/install_quest_mode.py`
  Installs the theme into your home directory and iTerm2 profile.
- `outputs/quest-mode-bg.png`
  The quest background image.
- `outputs/quest-audio/`
  Ambient track and sound effects.
- `install.sh`
  The easiest way to install from this repo on another device.

## Requirements

- macOS
- `zsh`
- `iTerm2`
- Python 3
- `MesloLGS NF` or another Nerd Font installed

The installer expects iTerm2 preferences to exist already, so open iTerm2 once before installing.

## Install On Another Device

1. Clone this repo.
2. Open iTerm2 at least once.
3. Run:

```bash
./install.sh
```

This will:

- back up your current `~/.zshrc` and iTerm2 plist
- copy the quest shell overlay into `~/.config/quest-mode/`
- copy the background and audio assets
- create/update a `Quest Mode` iTerm2 profile
- make `Quest Mode` the default iTerm2 profile

Then refresh your shell:

```bash
exec zsh
```

If music is already running from an older session:

```bash
quest-music-stop
quest-music-start
```

## Daily Commands

```bash
quest-docs
quest-examples
quest-stats
quest-journal
quest-boss-status
quest-boss-auto
```

## Moving Between Devices

To reuse this on another machine, the clean path is:

1. Put this repo on GitHub, GitLab, or a private remote.
2. Clone it on the other device.
3. Run `./install.sh`.

Your live game state is not automatically synced across devices. The portable code and assets live in this repo, but your personal runtime state lives under:

```bash
~/.config/quest-mode/state
```

If you want cross-device continuity, sync that folder separately or I can make the repo support an exported/imported save file.

## Updating After Changes

After editing the repo locally, reinstall with:

```bash
./install.sh
```

## Notes

- Ambient music supports `mp3`, `wav`, and `m4a`.
- Sound playback uses `afplay`.
- This project is currently Mac/iTerm2-specific.
