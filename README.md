# Quest Mode

A portable `zsh + iTerm2` quest overlay with:

- RPG-style prompt and persistent stats
- ambience and sound effects
- zone discovery, XP, gold, HP, and streaks
- manual and natural boss encounters
- a one-command installer for another Mac

## What This Repo Contains

- `work/quest-mode/quest-mode.zsh`
  The main shell/game logic.
- `work/quest-mode/install_quest_mode.py`
  Installs the theme into your home directory and iTerm2 profile.
- `work/quest-mode/zshrc.example`
  A minimal example showing the single `~/.zshrc` hook Quest Mode needs.
- `outputs/quest-mode-bg.png`
  The quest background image.
- `outputs/quest-audio/`
  Ambient track and sound effects.
- `install.sh`
  The easiest way to install from this repo on another device.
- `uninstall.sh`
  Restores the latest backup and removes Quest Mode files.

## Requirements

- macOS
- `zsh`
- `iTerm2`
- Python 3
- `MesloLGS NF` or another Nerd Font installed

The installer expects iTerm2 preferences to exist already, so open iTerm2 once before installing.

## Shell Hook

Quest Mode does not need your full personal `~/.zshrc` in version control. The
only shell hook it needs is:

```zsh
[[ -f "$HOME/.config/quest-mode/quest-mode.zsh" ]] && source "$HOME/.config/quest-mode/quest-mode.zsh"
```

That example also lives in:

```text
work/quest-mode/zshrc.example
```

The installer adds that line automatically if it is missing.
It also rewrites the Quest Mode block so it stays at the very end of `~/.zshrc`,
which helps avoid prompt conflicts on other Macs.

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

## Uninstall

To revert Quest Mode with the least manual cleanup:

```bash
./uninstall.sh
```

This will:

- restore the most recent backed-up `~/.zshrc` if available
- restore the most recent backed-up iTerm2 plist if available
- remove `~/.config/quest-mode`

Then quit iTerm2 fully, reopen it, and run:

```bash
exec zsh
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

## Cross-Mac Notes

Quest Mode now seeds the iTerm2 profile from the known-good snapshot in this
repo instead of only inheriting the target Mac's default profile. That makes
powerline glyphs, spacing, colors, badge styling, and the background image more
consistent across machines.

If a new Mac still looks off, check these first:

- open iTerm2 once before installing
- make sure `MesloLGS NF` or another Nerd Font is installed
- run `exec zsh` after installation
- quit and reopen iTerm2 so the refreshed profile is picked up cleanly

## Notes

- Ambient music supports `mp3`, `wav`, and `m4a`.
- Sound playback uses `afplay`.
- This project is currently Mac/iTerm2-specific.
