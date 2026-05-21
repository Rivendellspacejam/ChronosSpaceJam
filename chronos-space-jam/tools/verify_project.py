from __future__ import annotations

import re
import math
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GAMEPLAY_THEMES = [
    "gravity",
    "hazard",
    "patrol",
    "gold",
    "bounce",
    "phase",
]


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
    settings_manager = read("scripts/autoload/settings_manager.gd")
    game_level = read("scripts/game_level.gd")
    main_menu = read("scripts/main_menu.gd")
    level_select = read("scripts/level_select.gd")
    credits = read("scripts/credits.gd")
    intro = read("scripts/intro.gd")
    ending = read("scripts/ending.gd")
    main_menu_scene = read("scenes/ui/main_menu.tscn")
    level_select_scene = read("scenes/ui/level_select.tscn")
    credits_scene = read("scenes/ui/credits.tscn")
    game_level_scene = read("scenes/game/game_level.tscn")
    ending_scene = read("scenes/ui/ending.tscn")

    required_assets = [
        "assets/audio/menu_loop.wav",
        "assets/audio/ending_loop.wav",
    ]
    required_assets.extend(f"assets/audio/gameplay_{theme}_loop.wav" for theme in GAMEPLAY_THEMES)
    for asset in required_assets:
        asset_path = ROOT / asset
        if not asset_path.exists():
            fail(f"missing context music asset: {asset}")
        import_path = ROOT / f"{asset}.import"
        if not import_path.exists() or "edit/loop_mode=1" not in import_path.read_text():
            fail(f"context music asset must import as a loop: {asset}")
        duration, rms, high_ratio, harsh_ratio, tonal_peak_share = read_wav_metrics(asset_path)
        if duration < 45.0:
            fail(f"context music asset too short: {asset} duration={duration:.2f}s")
        if rms < 1400.0:
            fail(f"context music asset too quiet: {asset} rms={rms:.0f}")
        if rms > 6500.0:
            fail(f"context music asset too loud: {asset} rms={rms:.0f}")
        if high_ratio > 0.18 or harsh_ratio > 0.7:
            fail(f"context music asset too high-pitched: {asset} high={high_ratio:.3f} harsh={harsh_ratio:.3f}")
        if tonal_peak_share < 0.075:
            fail(f"context music asset lacks melodic/tonal focus: {asset} tonal={tonal_peak_share:.3f}")

    signatures = {
        asset: read_wav_signature(ROOT / asset)
        for asset in required_assets
        if asset.endswith("_loop.wav")
    }
    for left_name, left_signature in signatures.items():
        for right_name, right_signature in signatures.items():
            if left_name >= right_name:
                continue
            distance = signature_distance(left_signature, right_signature)
            if "gameplay_" in left_name and "gameplay_" in right_name and distance < 0.045:
                fail(f"gameplay music themes are too similar: {left_name} vs {right_name} distance={distance:.3f}")
            if distance < 0.005:
                fail(f"music tracks are too similar: {left_name} vs {right_name} distance={distance:.3f}")

    menu_duration, _menu_rms, _menu_high_ratio, _menu_harsh_ratio, _menu_tonal = read_wav_metrics(ROOT / "assets/audio/menu_loop.wav")
    gameplay_duration, _gameplay_rms, gameplay_high_ratio, gameplay_harsh_ratio, _gameplay_tonal = read_wav_metrics(ROOT / "assets/audio/gameplay_gravity_loop.wav")
    if abs(menu_duration - gameplay_duration) < 12.0:
        fail("menu and first gameplay loops need different musical pacing/duration")
    if gameplay_harsh_ratio <= 0.35:
        fail(f"gameplay music should keep an energetic chiptune identity: harsh={gameplay_harsh_ratio:.3f}")
    menu_transients = estimate_transient_rate(ROOT / "assets/audio/menu_loop.wav")
    gameplay_transients = estimate_transient_rate(ROOT / "assets/audio/gameplay_gravity_loop.wav")
    if gameplay_transients - menu_transients < 4.0:
        fail(f"gameplay music needs a stronger rhythmic identity than menu music: menu={menu_transients:.2f} gameplay={gameplay_transients:.2f}")

    required = {
        "gameplay music preload": "const GAMEPLAY_MUSIC := preload(\"res://assets/audio/gameplay_gravity_loop.wav\")" in audio_manager,
        "ending music preload": "const ENDING_MUSIC := preload(\"res://assets/audio/ending_loop.wav\")" in audio_manager,
        "menu scenes own reliable background players": "BackgroundMusic" in main_menu_scene and "BackgroundMusic" in level_select_scene and "BackgroundMusic" in credits_scene,
        "menu scenes resume persistent position": "AudioManager.configure_menu_music_player(background_music)" in main_menu and "AudioManager.configure_menu_music_player(background_music)" in level_select and "AudioManager.configure_menu_music_player(background_music)" in credits,
        "persistent menu music remembers position": "func remember_menu_music_position" in audio_manager and "player.get_playback_position()" in audio_manager,
        "persistent menu music does not restart same track": "func configure_menu_music_player" in audio_manager and "_menu_music_player.play(_menu_music_position)" in audio_manager,
        "ui sfx does not restart playing music": "if _music_player.playing:\n\t\treturn" in audio_manager and "get_music_recovery_play_count" in audio_manager,
        "gameplay scene has background player": "BackgroundMusic" in game_level_scene and "gameplay_gravity_loop.wav" in game_level_scene,
        "ending scene has background player": "BackgroundMusic" in ending_scene and "ending_loop.wav" in ending_scene,
        "settings audio defaults versioned": "const AUDIO_DEFAULTS_VERSION := 2" in settings_manager,
        "settings saves audio defaults version": '"defaults_version", AUDIO_DEFAULTS_VERSION' in settings_manager,
        "settings migrates old 100 percent saves": "saved_audio_defaults_version < AUDIO_DEFAULTS_VERSION" in settings_manager,
        "settings reset audio defaults to 50": "func _reset_audio_defaults() -> void:" in settings_manager,
        "gameplay selects theme music": "func _music_stream_for_level(index: int) -> AudioStream:" in game_level,
        "gameplay maps six music themes": all(f"GAMEPLAY_{theme.upper()}_MUSIC" in game_level for theme in GAMEPLAY_THEMES),
        "menu music is loud enough at 50 percent": "_menu_music_player.volume_db = 2.0" in audio_manager,
        "gameplay music leaves room for sfx": "const MUSIC_TARGET_VOLUME_DB: float = 1.0" in game_level,
        "gameplay music uses fades": "const MUSIC_FADE_OUT_TIME" in game_level and "create_tween()" in game_level and "tween_property(background_music, \"volume_db\"" in game_level,
        "gameplay music has transition pause": "const MUSIC_TRANSITION_PAUSE" in game_level and "create_timer(MUSIC_TRANSITION_PAUSE)" in game_level,
        "ending music is loud enough at 50 percent": "background_music.volume_db = 2.0" in ending,
        "autoload keeps music playing": "_resume_music_if_needed()" in audio_manager and "MUSIC_KEEPALIVE_INTERVAL" in audio_manager,
        "gameplay process keeps music playing": "_ensure_background_music_playing()" in game_level,
        "ending process keeps music playing": "_ensure_background_music_playing()" in ending,
        "menu navigation does not stop music": "AudioManager.stop_music()" not in main_menu and "AudioManager.stop_music()" not in credits and "func _ready() -> void:\n\tAudioManager.configure_menu_music_player(background_music)" in level_select,
        "level start stops menu music": "AudioManager.stop_music()\n\tGameManager.current_level_index = index" in level_select,
        "gameplay stops autoload music": "AudioManager.stop_music()" in game_level,
        "ending stops autoload music": "AudioManager.stop_music()" in ending,
        "intro dialogue accepts gui click": "gui_input.connect(_on_dialog_gui_input)" in intro and "accept_event()" in intro,
        "ending dialogue accepts gui click": "gui_input.connect(_on_dialog_gui_input)" in ending and "accept_event()" in ending,
    }

    for label, passed in required.items():
        if not passed:
            fail(f"missing context music behavior: {label}")

    print("OK context music")

def verify_immersive_polish_assets() -> None:
    audio_manager = read("scripts/autoload/audio_manager.gd")
    main_menu = read("scripts/main_menu.gd")
    player = read("scripts/player.gd")
    level_manager = read("scripts/level_manager.gd")
    main_menu_scene = read("scenes/ui/main_menu.tscn")
    level_select_scene = read("scenes/ui/level_select.tscn")
    ending_scene = read("scenes/ui/ending.tscn")
    arena_backdrop = read("scripts/arena_backdrop.gd")

    image_assets = [
        "assets/backgrounds/menu_timescape.png",
        "assets/backgrounds/gameplay_void.png",
        "assets/backgrounds/ending_timescape.png",
    ]
    for asset in image_assets:
        asset_path = ROOT / asset
        if not asset_path.exists():
            fail(f"missing immersive background asset: {asset}")
        if asset_path.stat().st_size < 64_000:
            fail(f"immersive background asset too small/simple: {asset}")
    for theme in GAMEPLAY_THEMES:
        asset = f"assets/backgrounds/gameplay_{theme}.png"
        asset_path = ROOT / asset
        if not asset_path.exists():
            fail(f"missing themed gameplay background asset: {asset}")
        if asset_path.stat().st_size < 72_000:
            fail(f"themed gameplay background asset too small/simple: {asset}")

    stinger_path = ROOT / "assets/audio/start_stinger.wav"
    if not stinger_path.exists():
        fail("missing cinematic start stinger")
    duration, rms = read_wav_duration_and_rms(stinger_path)
    if duration < 1.4:
        fail(f"start stinger too short: duration={duration:.2f}s")
    if rms < 2500.0:
        fail(f"start stinger too quiet: rms={rms:.0f}")

    gameplay_sfx = [
        "coin_pickup",
        "coin_gate_open",
        "bounce_pad",
        "goal_enter",
        "anchor_stop",
        "blocked_move",
        "time_gate_shift",
        "laser_shift",
        "spike_shift",
        "enemy_step",
    ]
    for name in gameplay_sfx:
        asset = f"assets/audio/{name}.wav"
        asset_path = ROOT / asset
        if not asset_path.exists():
            fail(f"missing gameplay sfx asset: {asset}")
        duration, rms = read_wav_duration_and_rms(asset_path)
        if duration < 0.08:
            fail(f"gameplay sfx too short: {asset} duration={duration:.2f}s")
        if duration > 1.2:
            fail(f"gameplay sfx too long: {asset} duration={duration:.2f}s")
        if rms < 1200.0:
            fail(f"gameplay sfx too quiet: {asset} rms={rms:.0f}")

    required = {
        "AudioManager exposes start stinger": "func play_start_stinger() -> void:" in audio_manager,
        "AudioManager exposes gameplay sfx": all(f"func play_{name}() -> void:" in audio_manager for name in gameplay_sfx),
        "Start button uses cinematic stinger": "AudioManager.play_start_stinger()" in main_menu,
        "coin pickup uses sfx": "AudioManager.play_coin_pickup()" in level_manager,
        "coin gate open uses sfx": "AudioManager.play_coin_gate_open()" in level_manager,
        "bounce plate uses sfx": "AudioManager.play_bounce_pad()" in player,
        "core movement feedback remains audible": "AudioManager.play_slide_start()" in player and "AudioManager.play_blocked_move()" in player and "AudioManager.play_goal_enter()" in player and "AudioManager.play_anchor_stop()" in player,
        "level tick metronome is muted": "AudioManager.play_tick()" not in read("scripts/game_level.gd"),
        "environment pulse sfx is muted": "AudioManager.play_time_gate_shift()" not in level_manager and "AudioManager.play_laser_shift()" not in level_manager and "AudioManager.play_spike_shift()" not in level_manager and "AudioManager.play_enemy_step()" not in level_manager,
        "menu uses background art": "menu_timescape.png" in main_menu_scene and "TextureRect" in main_menu_scene,
        "level select uses background art": "menu_timescape.png" in level_select_scene and "TextureRect" in level_select_scene,
        "ending uses background art": "ending_timescape.png" in ending_scene and "TextureRect" in ending_scene,
        "gameplay backdrop maps six themes": all(f"gameplay_{theme}.png" in arena_backdrop for theme in GAMEPLAY_THEMES),
        "gameplay backdrop accepts theme": "func set_theme(level_index: int) -> void:" in arena_backdrop,
        "gameplay backdrop uses texture art": "draw_texture_rect" in arena_backdrop,
        "gameplay backdrop fills viewport": "func _viewport_backdrop_rect" in arena_backdrop and "get_viewport_rect().size" in arena_backdrop and "get_camera_2d()" in arena_backdrop,
        "gameplay backdrop avoids fixed cropped rect": "Vector2(-420.0, -300.0)" not in arena_backdrop and "arena_size + Vector2(840.0, 600.0)" not in arena_backdrop,
        "gameplay backdrop has full-width base color": "_theme_base_color" in arena_backdrop and "draw_rect(backdrop_rect, _theme_base_color" in arena_backdrop,
        "gameplay backdrop stretches texture without visible tile seams": "draw_texture_rect(_theme_texture, backdrop_rect, false" in arena_backdrop and "Vector2(2400.0, 1600.0)" in arena_backdrop,
        "gameplay backdrop draws full viewport detail": "func _draw_viewport_theme_grid" in arena_backdrop,
        "gameplay backdrop has right-side energy detail": "func _draw_viewport_energy_bands" in arena_backdrop and "rect.end.x" in arena_backdrop,
        "arena has professional framing": "draw_arc" in arena_backdrop and "corner" in arena_backdrop.lower(),
    }

    for label, passed in required.items():
        if not passed:
            fail(f"missing immersive polish: {label}")

    print("OK immersive polish")

def verify_gameplay_ui_polish() -> None:
    hud = read("scripts/hud.gd")
    hud_scene = read("scenes/ui/hud.tscn")
    pause_menu = read("scripts/pause_menu.gd")
    pause_scene = read("scenes/ui/pause_menu.tscn")
    game_level = read("scripts/game_level.gd")

    required = {
        "HUD uses a styled stats panel": "StatsPanel" in hud_scene and "_apply_hud_panel_style" in hud,
        "HUD exposes stats safe rect": "func get_stats_panel_screen_rect() -> Rect2:" in hud and "stats_panel.global_position" in hud,
        "HUD stats use label/value rows": "GravityValue" in hud_scene and "TickValue" in hud_scene and "CoinsValue" in hud_scene,
        "HUD updates values instead of plain text block": 'gravity_value_label.text = str(GRAVITY_LABELS.get(gravity, "NONE"))' in hud,
        "HUD stat rows get capsule styling": "_apply_stat_row_style" in hud and "CoinsRow" in hud_scene,
        "clear overlay has styled result rows": "ClearStats" in hud_scene and "_apply_result_row_style" in hud,
        "pause menu uses a styled command panel": "PausePanel" in pause_scene and "_apply_pause_panel_style" in pause_menu,
        "pause buttons use themed styles": "_apply_button_style" in pause_menu and "RESUME RUN" in pause_scene,
        "gameplay camera protects HUD safe area": "_hud_safe_rect()" in game_level and "_gameplay_safe_rect" in game_level and "default_screen_rect.intersects(hud_rect)" in game_level,
        "gameplay camera fits large levels beside HUD": "_zoom_to_fit_level(level_size, safe_rect.size)" in game_level and "_camera_position_for_screen_center" in game_level,
    }

    for label, passed in required.items():
        if not passed:
            fail(f"missing gameplay UI polish: {label}")

    print("OK gameplay UI polish")

def read_wav_metrics(path: Path) -> tuple[float, float, float, float, float]:
    with wave.open(str(path), "rb") as wav:
        if wav.getsampwidth() != 2:
            fail(f"{path.name} must be 16-bit WAV")
        frame_count = wav.getnframes()
        raw = wav.readframes(frame_count)
        samples = struct.unpack("<" + "h" * (len(raw) // 2), raw)
        if not samples:
            return 0.0, 0.0, 0.0, 0.0, 0.0
        square_sum = sum(sample * sample for sample in samples)
        rms = (square_sum / len(samples)) ** 0.5
        high_ratio, harsh_ratio = estimate_high_frequency_ratios(samples, wav.getframerate())
        tonal_peak_share = estimate_tonal_peak_share(samples, wav.getframerate())
        return frame_count / float(wav.getframerate()), rms, high_ratio, harsh_ratio, tonal_peak_share

def read_wav_duration_and_rms(path: Path) -> tuple[float, float]:
    duration, rms, _high_ratio, _harsh_ratio, _tonal_peak_share = read_wav_metrics(path)
    return duration, rms

def estimate_high_frequency_ratios(samples: tuple[int, ...], sample_rate: int) -> tuple[float, float]:
    step = max(1, sample_rate // 2000)
    reduced = samples[::step]
    if len(reduced) < 4:
        return 0.0, 0.0

    sign_changes = 0
    previous_sign = 1 if reduced[0] >= 0 else -1
    for sample in reduced[1:]:
        sign = 1 if sample >= 0 else -1
        if sign != previous_sign:
            sign_changes += 1
        previous_sign = sign

    curvature = 0.0
    for index in range(1, len(reduced) - 1):
        curvature += abs(float(reduced[index + 1]) - (2.0 * float(reduced[index])) + float(reduced[index - 1]))

    mean_amplitude = sum(abs(float(sample)) for sample in reduced) / float(len(reduced))
    high_ratio = sign_changes / float(len(reduced) - 1)
    harsh_ratio = (curvature / float(len(reduced) - 2)) / (mean_amplitude + 1.0)
    return high_ratio, harsh_ratio

def estimate_tonal_peak_share(samples: tuple[int, ...], sample_rate: int) -> float:
    # Lightweight spectral peak heuristic: musical loops should have clear note centers
    # below 1 kHz instead of only broad noise/texture energy.
    window_size = 4096
    stride = window_size * 8
    peak_sum = 0.0
    total_sum = 0.0
    for start in range(0, min(len(samples) - window_size, sample_rate * 24), stride):
        chunk = samples[start:start + window_size]
        bins = []
        for bucket in range(24):
            low = int(bucket * len(chunk) / 48)
            high = int((bucket + 1) * len(chunk) / 48)
            if high <= low:
                continue
            energy = sum(abs(sample) for sample in chunk[low:high])
            bins.append(float(energy))
        if not bins:
            continue
        peak_sum += max(bins)
        total_sum += sum(bins)
    if total_sum <= 0.0:
        return 0.0
    return peak_sum / total_sum

def read_wav_signature(path: Path) -> tuple[float, float, float, float]:
    with wave.open(str(path), "rb") as wav:
        frame_count = min(wav.getnframes(), wav.getframerate() * 28)
        raw = wav.readframes(frame_count)
        samples = struct.unpack("<" + "h" * (len(raw) // 2), raw)
        if not samples:
            return (0.0, 0.0, 0.0, 0.0)

    window = max(1, len(samples) // 32)
    envelopes = []
    for index in range(0, len(samples), window):
        chunk = samples[index:index + window]
        if not chunk:
            continue
        envelopes.append(sum(abs(sample) for sample in chunk) / float(len(chunk)))
    mean = sum(envelopes) / float(len(envelopes))
    variance = sum((value - mean) ** 2 for value in envelopes) / float(len(envelopes))
    high_ratio, harsh_ratio = estimate_high_frequency_ratios(samples, 44100)
    return (mean / 32768.0, math.sqrt(variance) / 32768.0, high_ratio, harsh_ratio)

def estimate_transient_rate(path: Path) -> float:
    with wave.open(str(path), "rb") as wav:
        frame_count = min(wav.getnframes(), wav.getframerate() * 32)
        raw = wav.readframes(frame_count)
        samples = struct.unpack("<" + "h" * (len(raw) // 2), raw)
        sample_rate = wav.getframerate()
    if not samples:
        return 0.0

    window = max(1, sample_rate // 50)
    envelopes = []
    for index in range(0, len(samples), window):
        chunk = samples[index:index + window]
        if chunk:
            envelopes.append(sum(abs(sample) for sample in chunk) / float(len(chunk)))
    if len(envelopes) < 3:
        return 0.0

    mean = sum(envelopes) / float(len(envelopes))
    threshold = mean * 0.18
    transient_count = 0
    for index in range(1, len(envelopes)):
        if envelopes[index] - envelopes[index - 1] > threshold:
            transient_count += 1
    duration = len(samples) / float(sample_rate)
    return transient_count / duration

def signature_distance(left: tuple[float, float, float, float], right: tuple[float, float, float, float]) -> float:
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(left, right)))

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
    verify_immersive_polish_assets()
    verify_gameplay_ui_polish()
    verify_script_patterns()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
