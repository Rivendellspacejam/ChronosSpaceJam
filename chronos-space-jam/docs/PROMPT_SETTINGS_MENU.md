# PROMPT — Settings Menu (Main Menu + Pause Menu)

## Objective

Add a **Settings menu** to **Chrono Slide** that is accessible from **two entry points**:

1. The **Main Menu** (`scenes/ui/main_menu.tscn`) — via a new "SETTINGS" button.
2. The **Pause Menu** (`scenes/ui/pause_menu.tscn`) — via a new "SETTINGS" button.

Both entry points must open the **same** reusable `SettingsMenu` scene. When the player closes Settings, they return to whichever menu they came from.

---

## Project Context

| Item | Detail |
|------|--------|
| Engine | Godot 4.6, GL Compatibility renderer |
| Viewport | 1280 × 720, stretch mode `canvas_items` |
| Autoloads | `GameManager` (`scripts/autoload/game_manager.gd`), `TickManager` (`scripts/autoload/tick_manager.gd`) |
| Main Scene | `scenes/ui/main_menu.tscn` (script: `scripts/main_menu.gd`) |
| Pause Menu | `scenes/ui/pause_menu.tscn` (script: `scripts/pause_menu.gd`), instanced inside `scenes/ui/hud.tscn` |
| Game Level | `scenes/game/game_level.tscn` (script: `scripts/game_level.gd`), handles Esc toggle for pause |
| UI Color Palette | Background: `Color(0.04, 0.04, 0.08, 1)`, Accent: `Color(0.3, 0.9, 1, 1)` (cyan), Subtitle: `Color(0.5, 0.6, 0.8, 0.8)`, Button font size: 20, Title font size: 48 |
| Pause Overlay | Semi-transparent `Color(0, 0, 0, 0.588)` |
| Process Mode | Pause menu uses `process_mode = 2` (ALWAYS) so it works while tree is paused |

---

## Settings Categories & Controls

### 1. Audio

| Setting | Control Type | Range / Options | Default | Notes |
|---------|-------------|-----------------|---------|-------|
| Master Volume | `HSlider` | 0 – 100 | 100 | Maps to `AudioServer.set_bus_volume_db("Master", ...)`. Convert linear (0–1) to dB using `linear_to_db()`. Mute at 0. |
| Music Volume | `HSlider` | 0 – 100 | 100 | Requires an audio bus named **"Music"**. Create it if it doesn't exist. |
| SFX Volume | `HSlider` | 0 – 100 | 100 | Requires an audio bus named **"SFX"**. Create it if it doesn't exist. |
| Mute All | `CheckButton` | On / Off | Off | Mutes the Master bus entirely via `AudioServer.set_bus_mute()`. |

### 2. Display

| Setting | Control Type | Range / Options | Default | Notes |
|---------|-------------|-----------------|---------|-------|
| Fullscreen | `CheckButton` | On / Off | Off | Toggle between `Window.MODE_EXCLUSIVE_FULLSCREEN` and `Window.MODE_WINDOWED`. |
| VSync | `CheckButton` | On / Off | On | `DisplayServer.window_set_vsync_mode()` — `VSYNC_ENABLED` or `VSYNC_DISABLED`. |

### 3. Gameplay / Accessibility

| Setting | Control Type | Range / Options | Default | Notes |
|---------|-------------|-----------------|---------|-------|
| Screen Shake | `CheckButton` | On / Off | On | When Off, `GameLevel.apply_shake()` should be suppressed. Store this flag in `SettingsManager`. |
| Screen Shake Intensity | `HSlider` | 0 – 100 | 100 | Multiplier on shake intensity. Only visible/effective when Screen Shake is On. |

---

## Files to Create

### 1. `scripts/autoload/settings_manager.gd`

- New **Autoload** singleton (register in `project.godot` under `[autoload]`).
- Holds all settings values as variables.
- Exposes methods: `apply_audio()`, `apply_display()`, `save_settings()`, `load_settings()`.
- Persistence: save to `user://settings.cfg` using `ConfigFile`.
- On `_ready()`, call `load_settings()` and `apply_audio()` / `apply_display()` to restore saved preferences.
- Emits signal `settings_changed` after any apply, so other systems can react.

### 2. `scenes/ui/settings_menu.tscn`

- Root node: `Control` (anchors full-rect, `process_mode = PROCESS_MODE_ALWAYS`).
- Background: `ColorRect` with `Color(0.04, 0.04, 0.08, 0.95)` (slightly transparent dark).
- Layout: Centered `VBoxContainer` containing:
  - Title `Label`: "SETTINGS", font size 32, accent color `Color(0.3, 0.9, 1, 1)`.
  - **Audio Section** header label, then slider rows for Master / Music / SFX / Mute toggle.
  - **Display Section** header label, then Fullscreen / VSync toggles.
  - **Gameplay Section** header label, then Screen Shake toggle + intensity slider.
  - A "BACK" `Button` at the bottom.
- Each slider row: `HBoxContainer` with a `Label` (setting name) and `HSlider`.
- Each toggle row: `HBoxContainer` with a `Label` and `CheckButton`.
- Style the buttons and sliders to match existing UI (font size 18–20, same color theme).

### 3. `scripts/settings_menu.gd`

- Script attached to the `SettingsMenu` scene root.
- `_ready()`: Read current values from `SettingsManager` and set all UI controls to match.
- Connect every slider's `value_changed` and every toggle's `toggled` signal to update `SettingsManager` + call the relevant apply method.
- "BACK" button: call `SettingsManager.save_settings()`, then hide self (`visible = false`). If opened from the main menu scene, show the main menu VBox again. If opened from pause, show the pause menu VBox again.
- Use a simple `var return_target : Control` variable set by the caller to know who to show on back.

---

## Files to Modify

### 1. `project.godot`

- Add to `[autoload]`:
  ```
  SettingsManager="*res://scripts/autoload/settings_manager.gd"
  ```

### 2. `scripts/main_menu.gd`

- Add `@onready var settings_button` reference for the new SETTINGS button.
- Add `@onready var settings_menu` reference for the instanced SettingsMenu.
- Connect `settings_button.pressed` → `_on_settings()`.
- `_on_settings()`: Hide the main VBoxContainer, show the SettingsMenu, set `settings_menu.return_target = $VBoxContainer`.

### 3. `scenes/ui/main_menu.tscn`

- Add a new `Button` node named `SettingsButton` inside `VBoxContainer` (between Credits and Quit), text "SETTINGS", same style as other buttons (min height 45, font size 20).
- Instance `settings_menu.tscn` as a child of the root `MainMenu` node, initially `visible = false`.

### 4. `scripts/pause_menu.gd`

- Add `@onready var settings_button` and `@onready var settings_menu` references.
- Connect `settings_button.pressed` → `_on_settings()`.
- `_on_settings()`: Hide `$VBoxContainer`, show SettingsMenu, set return target.

### 5. `scenes/ui/pause_menu.tscn`

- Add a new `Button` node named `SettingsButton` inside `VBoxContainer` (between Restart and Main Menu), text "SETTINGS".
- Instance `settings_menu.tscn` as a child of root `PauseMenu` node, initially `visible = false`.

### 6. `scripts/game_level.gd`

- In `apply_shake()`, check `SettingsManager.screen_shake_enabled`. If disabled, return early.
- Multiply `intensity` by `SettingsManager.screen_shake_intensity / 100.0`.

---

## Audio Bus Setup

If the project doesn't already have "Music" and "SFX" audio buses, they need to be created. Either:
- Create them programmatically in `SettingsManager._ready()` using `AudioServer.add_bus()` and `AudioServer.set_bus_name()`, OR
- Create a `default_bus_layout.tres` resource with Master → Music and Master → SFX buses.

The second approach (resource file) is preferred for Godot projects.

---

## Persistence Format (`user://settings.cfg`)

```ini
[audio]
master_volume=100
music_volume=100
sfx_volume=100
mute_all=false

[display]
fullscreen=false
vsync=true

[gameplay]
screen_shake=true
screen_shake_intensity=100
```

---

## Implementation Notes

1. **Process Mode**: The `SettingsMenu` scene root must use `process_mode = PROCESS_MODE_ALWAYS` (value `2`) so settings are accessible while the game tree is paused (from the Pause Menu).
2. **No New GameState**: Settings does not need its own `GameState` enum value. When opened from Pause, the game remains in `PAUSED` state. When opened from Main Menu, the game remains in `MENU` state.
3. **Volume dB Conversion**: Use `linear_to_db(value / 100.0)` for slider → bus mapping. At value `0`, mute the bus instead of using `-inf` dB.
4. **Existing Style**: Match button appearance, colors, and font sizes to the existing `main_menu.tscn` and `pause_menu.tscn` files. Use the same `theme_override_font_sizes/font_size = 20` and `theme_override_colors/font_color` patterns.
5. **Slider Styling**: Use `custom_minimum_size = Vector2(200, 0)` on sliders for consistent width. Set `min_value = 0`, `max_value = 100`, `step = 1`.
6. **Section Headers**: Style section headers (Audio, Display, Gameplay) with a smaller font (size 14), dimmer color `Color(0.5, 0.6, 0.8, 0.6)`, and ALL CAPS text.
7. **Back Button Flow**: When pressing BACK:
   - Save settings to disk.
   - Hide the SettingsMenu.
   - Show the `return_target` control (the VBoxContainer of whichever menu opened it).

---

## Acceptance Criteria

- [ ] "SETTINGS" button appears on Main Menu between "CREDITS" and "QUIT".
- [ ] "SETTINGS" button appears on Pause Menu between "RESTART" and "MAIN MENU".
- [ ] Clicking SETTINGS from Main Menu shows the Settings panel and hides the main menu buttons.
- [ ] Clicking SETTINGS from Pause Menu shows the Settings panel and hides the pause menu buttons.
- [ ] Clicking BACK from Settings returns to whichever menu opened it.
- [ ] Master / Music / SFX volume sliders adjust audio in real-time.
- [ ] Mute toggle silences all audio immediately.
- [ ] Fullscreen toggle switches between windowed and fullscreen.
- [ ] VSync toggle works.
- [ ] Screen Shake toggle disables/enables screen shake in gameplay.
- [ ] Screen Shake Intensity slider scales shake effect.
- [ ] Settings persist across sessions (saved to `user://settings.cfg`).
- [ ] Settings load on game startup and apply automatically.
- [ ] Settings work correctly while the game tree is paused.
- [ ] No new `GameState` is required; existing states remain unchanged.
- [ ] All UI elements match the existing neon/dark visual theme.
- [ ] `SettingsManager` autoload is registered in `project.godot`.

---

## Task ID Reference

This feature maps to a new task:

| Task ID | Title | Category | Priority | Dependencies | Effort |
|---------|-------|----------|----------|--------------|--------|
| UI-10 | Settings Menu | UI/HUD | Medium | UI-04, UI-08 | M |
