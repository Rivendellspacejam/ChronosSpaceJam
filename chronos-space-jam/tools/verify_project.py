from __future__ import annotations

import re
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
    verify_script_patterns()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
