from __future__ import annotations

import re
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def fail(message: str) -> None:
    print(f"FAIL {message}")
    raise SystemExit(1)


def extract_int_constant(text: str, name: str) -> int:
    match = re.search(rf"const\s+{name}\s*:\s*int\s*=\s*(\d+)", text)
    if not match:
        fail(f"missing int constant {name}")
    return int(match.group(1))


def count_dictionary_numeric_keys(text: str, name: str) -> int:
    inline_empty = re.search(rf"const\s+{name}\s*:\s*Dictionary\s*=\s*\{{\s*\}}", text)
    if inline_empty:
        return 0

    match = re.search(rf"const\s+{name}\s*:\s*Dictionary\s*=\s*\{{(.*?)\n\}}", text, re.S)
    if not match:
        fail(f"missing dictionary {name}")
    return len(re.findall(r"^\s*\d+\s*:", match.group(1), re.M))


def parse_level_file_medal_targets(path: Path) -> tuple[int, int]:
    pattern = re.compile(r"^@medal_targets\s+gold=(\d+)\s+silver=(\d+)$", re.M)
    match = pattern.search(path.read_text())
    if not match:
        fail(f"{path.name} missing @medal_targets gold=<n> silver=<n>")

    gold = int(match.group(1))
    silver = int(match.group(2))
    if gold > silver:
        fail(f"{path.name} gold target {gold} exceeds silver target {silver}")
    return gold, silver


def verify_level_contract() -> None:
    game_manager = read("scripts/autoload/game_manager.gd")
    story_manager = read("scripts/autoload/story_manager.gd")
    total_levels = extract_int_constant(game_manager, "TOTAL_LEVELS")
    level_files = sorted((ROOT / "levels").glob("level_*.txt"), key=lambda item: int(item.stem.split("_")[1]))

    if len(level_files) != total_levels:
        fail(f"TOTAL_LEVELS is {total_levels}, but found {len(level_files)} level files")

    expected_names = [f"level_{index}.txt" for index in range(1, total_levels + 1)]
    actual_names = [path.name for path in level_files]
    if actual_names != expected_names:
        fail(f"level files are not contiguous: {actual_names}")

    names_count = count_dictionary_numeric_keys(story_manager, "LEVEL_NAMES")
    if names_count != total_levels:
        fail(f"LEVEL_NAMES has {names_count} entries, expected {total_levels}")

    story_count = count_dictionary_numeric_keys(story_manager, "LEVEL_STORIES")
    if story_count >= total_levels:
        fail("LEVEL_STORIES should only contain selected chapter beats, not every level")
    if "C-0RE:" in story_manager:
        fail("story still contains C-0RE self-dialogue")

    for level_file in level_files:
        parse_level_file_medal_targets(level_file)

    if "ENDING_LINES" not in story_manager:
        fail("StoryManager has no ENDING_LINES")

    print("OK level/story contract")


def verify_resource_paths() -> None:
    missing = []
    for path in ROOT.rglob("*.tscn"):
        text = path.read_text()
        for resource in re.findall(r'path="res://([^"]+)"', text):
            if not (ROOT / resource).exists():
                missing.append((path.relative_to(ROOT), resource))

    project = read("project.godot")
    for resource in re.findall(r'="\*res://([^"]+)"', project):
        if not (ROOT / resource).exists():
            missing.append((Path("project.godot"), resource))

    if missing:
        for source, resource in missing:
            print(f"FAIL missing resource from {source}: {resource}")
        raise SystemExit(1)

    print("OK resource paths")


def verify_scene_flow() -> None:
    game_manager = read("scripts/autoload/game_manager.gd")
    main_menu = read("scripts/main_menu.gd")
    project = read("project.godot")

    required = {
        "intro scene from start": 'res://scenes/ui/intro.tscn' in main_menu,
        "ending scene after final level": 'res://scenes/ui/ending.tscn' in game_manager,
        "StoryManager autoload": 'StoryManager="*res://scripts/autoload/story_manager.gd"' in project,
    }

    for label, passed in required.items():
        if not passed:
            fail(f"missing scene flow: {label}")

    print("OK scene flow")

def verify_level_select_locking() -> None:
    game_manager = read("scripts/autoload/game_manager.gd")
    level_select = read("scripts/level_select.gd")

    required = {
        "GameManager level unlock query": "func is_level_unlocked(index: int) -> bool:" in game_manager,
        "GameManager dev unlock all": "func unlock_all_levels() -> void:" in game_manager,
        "Level select disables locked buttons": "button.disabled = not unlocked" in level_select,
        "Level select ignores locked selections": "not GameManager.is_level_unlocked(index)" in level_select,
        "Ctrl+Q dev unlock shortcut": "KEY_Q" in level_select and "ctrl_pressed" in level_select,
    }

    for label, passed in required.items():
        if not passed:
            fail(f"missing level select locking: {label}")

    print("OK level select locking")

def verify_context_music() -> None:
    audio_manager = read("scripts/autoload/audio_manager.gd")
    game_level = read("scripts/game_level.gd")
    main_menu = read("scripts/main_menu.gd")
    ending = read("scripts/ending.gd")
    main_menu_scene = read("scenes/ui/main_menu.tscn")
    game_level_scene = read("scenes/game/game_level.tscn")
    ending_scene = read("scenes/ui/ending.tscn")

    required_assets = [
        "assets/audio/menu_loop.wav",
        "assets/audio/gameplay_loop.wav",
        "assets/audio/ending_loop.wav",
    ]
    for asset in required_assets:
        asset_path = ROOT / asset
        if not asset_path.exists():
            fail(f"missing context music asset: {asset}")
        duration, rms = read_wav_duration_and_rms(asset_path)
        if duration < 6.0:
            fail(f"context music asset too short: {asset} duration={duration:.2f}s")
        if rms < 3200.0:
            fail(f"context music asset too quiet: {asset} rms={rms:.0f}")

    required = {
        "gameplay music preload": "const GAMEPLAY_MUSIC := preload(\"res://assets/audio/gameplay_loop.wav\")" in audio_manager,
        "ending music preload": "const ENDING_MUSIC := preload(\"res://assets/audio/ending_loop.wav\")" in audio_manager,
        "menu scene has background player": "BackgroundMusic" in main_menu_scene and "menu_loop.wav" in main_menu_scene,
        "gameplay scene has background player": "BackgroundMusic" in game_level_scene and "gameplay_loop.wav" in game_level_scene,
        "ending scene has background player": "BackgroundMusic" in ending_scene and "ending_loop.wav" in ending_scene,
        "menu process keeps music playing": "_ensure_background_music_playing()" in main_menu,
        "gameplay process keeps music playing": "_ensure_background_music_playing()" in game_level,
        "ending process keeps music playing": "_ensure_background_music_playing()" in ending,
        "menu stops autoload music": "AudioManager.stop_music()" in main_menu,
        "gameplay stops autoload music": "AudioManager.stop_music()" in game_level,
        "ending stops autoload music": "AudioManager.stop_music()" in ending,
    }

    for label, passed in required.items():
        if not passed:
            fail(f"missing context music behavior: {label}")

    print("OK context music")

def read_wav_duration_and_rms(path: Path) -> tuple[float, float]:
    with wave.open(str(path), "rb") as wav:
        if wav.getsampwidth() != 2:
            fail(f"{path.name} must be 16-bit WAV")
        frame_count = wav.getnframes()
        raw = wav.readframes(frame_count)
        samples = struct.unpack("<" + "h" * (len(raw) // 2), raw)
        if not samples:
            return 0.0, 0.0
        square_sum = sum(sample * sample for sample in samples)
        rms = (square_sum / len(samples)) ** 0.5
        return frame_count / float(wav.getframerate()), rms

def verify_script_patterns() -> None:
    bad_patterns = {
        ".modulate.a": "assign Color alpha through a copied Color instead of a sub-property",
        "-> Array[String]:\n\treturn LEVEL_STORIES.get": "convert Dictionary arrays to typed Array[String] before returning",
        "-> Array[String]:\n\treturn INTRO_LINES.duplicate()": "duplicate() may erase typed array guarantees; return a typed copy",
        "-> Array[String]:\n\treturn ENDING_LINES.duplicate()": "duplicate() may erase typed array guarantees; return a typed copy",
        "-> String:\n\treturn LEVEL_NAMES.get": "wrap Dictionary.get values in str() before returning String",
    }
    failures = []
    for path in ROOT.rglob("*.gd"):
        text = path.read_text()
        for pattern, reason in bad_patterns.items():
            if pattern in text:
                failures.append((path.relative_to(ROOT), pattern, reason))

    if failures:
        for source, pattern, reason in failures:
            print(f"FAIL risky script pattern in {source}: {pattern} ({reason})")
        raise SystemExit(1)

    print("OK script patterns")


def main() -> int:
    verify_level_contract()
    verify_resource_paths()
    verify_scene_flow()
    verify_level_select_locking()
    verify_context_music()
    verify_script_patterns()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
