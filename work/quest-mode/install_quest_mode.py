#!/usr/bin/env python3

import argparse
import plistlib
import shutil
import uuid
from copy import deepcopy
from datetime import datetime
from pathlib import Path


def rgb(red, green, blue, alpha=1.0):
    return {
        "Red Component": red / 255,
        "Green Component": green / 255,
        "Blue Component": blue / 255,
        "Alpha Component": alpha,
        "Color Space": "sRGB",
    }


def set_color(bookmark, key, value):
    bookmark[key] = value
    bookmark[f"{key} (Dark)"] = value
    bookmark[f"{key} (Light)"] = value


def install_shell_overlay(quest_file: Path, home: Path):
    target_dir = home / ".config" / "quest-mode"
    target_dir.mkdir(parents=True, exist_ok=True)

    target_file = target_dir / "quest-mode.zsh"
    shutil.copy2(quest_file, target_file)

    zshrc = home / ".zshrc"
    source_line = '[[ -f "$HOME/.config/quest-mode/quest-mode.zsh" ]] && source "$HOME/.config/quest-mode/quest-mode.zsh"'
    contents = zshrc.read_text()
    if source_line not in contents:
        zshrc.write_text(contents.rstrip() + "\n\n# Codex quest mode\n" + source_line + "\n")

    return target_file


def install_background(background_file: Path, home: Path):
    target_dir = home / ".config" / "quest-mode" / "backgrounds"
    target_dir.mkdir(parents=True, exist_ok=True)
    target_file = target_dir / "quest-mode-bg.png"
    shutil.copy2(background_file, target_file)
    return target_file


def initialize_state_dir(home: Path):
    state_dir = home / ".config" / "quest-mode" / "state"
    state_dir.mkdir(parents=True, exist_ok=True)
    for file_name in ("journal.log", "discovered-zones"):
        target = state_dir / file_name
        if not target.exists():
            target.write_text("")
    return state_dir


def configure_iterm(background_target: Path, home: Path):
    plist_path = home / "Library" / "Preferences" / "com.googlecode.iterm2.plist"
    with plist_path.open("rb") as handle:
        prefs = plistlib.load(handle)

    bookmarks = prefs.get("New Bookmarks", [])
    if not bookmarks:
        raise RuntimeError("No iTerm2 profiles were found.")

    default_guid = prefs.get("Default Bookmark Guid")
    template = next((b for b in bookmarks if b.get("Guid") == default_guid), bookmarks[0])

    quest_profile = next((b for b in bookmarks if b.get("Name") == "Quest Mode"), None)
    if quest_profile is None:
        quest_profile = deepcopy(template)
        quest_profile["Guid"] = str(uuid.uuid4()).upper()
        bookmarks.append(quest_profile)

    quest_profile["Name"] = "Quest Mode"
    quest_profile["Shortcut"] = "Quest Mode"
    quest_profile["Normal Font"] = "MesloLGS-NF-Regular 16"
    quest_profile["Use Bold Font"] = True
    quest_profile["Use Italic Font"] = True
    quest_profile["Blinking Cursor"] = True
    quest_profile["Background Image Location"] = str(background_target)
    quest_profile["Badge Text"] = "QUEST MODE"
    quest_profile["Transparency"] = 0.14
    quest_profile["Blur"] = True
    quest_profile["Only The Default BG Color Uses Transparency"] = True
    quest_profile["Horizontal Spacing"] = 1.0
    quest_profile["Vertical Spacing"] = 1.05
    quest_profile["Unlimited Scrollback"] = True
    quest_profile["Use Non-ASCII Font"] = False

    set_color(quest_profile, "Foreground Color", rgb(229, 221, 198))
    set_color(quest_profile, "Background Color", rgb(16, 18, 24))
    set_color(quest_profile, "Bold Color", rgb(247, 210, 120))
    set_color(quest_profile, "Selection Color", rgb(75, 59, 34))
    set_color(quest_profile, "Selected Text Color", rgb(248, 240, 217))
    set_color(quest_profile, "Cursor Color", rgb(255, 196, 91))
    set_color(quest_profile, "Cursor Text Color", rgb(20, 20, 24))
    set_color(quest_profile, "Cursor Guide Color", rgb(255, 214, 144, 0.25))
    set_color(quest_profile, "Link Color", rgb(114, 189, 168))
    set_color(quest_profile, "Tab Color", rgb(31, 40, 48))
    set_color(quest_profile, "Badge Color", rgb(173, 117, 42, 0.45))

    ansi = {
        0: rgb(24, 25, 31),
        1: rgb(183, 68, 66),
        2: rgb(98, 150, 77),
        3: rgb(211, 164, 85),
        4: rgb(87, 136, 178),
        5: rgb(126, 92, 160),
        6: rgb(91, 153, 150),
        7: rgb(206, 200, 184),
        8: rgb(83, 86, 98),
        9: rgb(225, 102, 84),
        10: rgb(130, 196, 102),
        11: rgb(244, 198, 104),
        12: rgb(123, 181, 222),
        13: rgb(171, 126, 212),
        14: rgb(122, 214, 208),
        15: rgb(244, 240, 230),
    }
    for index, color in ansi.items():
        set_color(quest_profile, f"Ansi {index} Color", color)

    prefs["New Bookmarks"] = bookmarks
    prefs["Default Bookmark Guid"] = quest_profile["Guid"]

    with plist_path.open("wb") as handle:
        plistlib.dump(prefs, handle, sort_keys=False)

    return plist_path, quest_profile["Guid"]


def backup_files(home: Path):
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_dir = home / ".config" / "quest-mode" / "backups" / stamp
    backup_dir.mkdir(parents=True, exist_ok=True)

    files = [
        home / ".zshrc",
        home / "Library" / "Preferences" / "com.googlecode.iterm2.plist",
    ]

    for file_path in files:
        if file_path.exists():
            shutil.copy2(file_path, backup_dir / file_path.name)

    return backup_dir


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--quest-file", required=True, type=Path)
    parser.add_argument("--background-file", required=True, type=Path)
    parser.add_argument("--home", default=Path.home(), type=Path)
    args = parser.parse_args()

    home = args.home.expanduser().resolve()
    quest_file = args.quest_file.expanduser().resolve()
    background_file = args.background_file.expanduser().resolve()

    backup_dir = backup_files(home)
    quest_target = install_shell_overlay(quest_file, home)
    background_target = install_background(background_file, home)
    state_dir = initialize_state_dir(home)
    plist_path, guid = configure_iterm(background_target, home)

    print(f"backup_dir={backup_dir}")
    print(f"quest_file={quest_target}")
    print(f"background_file={background_target}")
    print(f"state_dir={state_dir}")
    print(f"iterm_plist={plist_path}")
    print(f"iterm_guid={guid}")


if __name__ == "__main__":
    main()
