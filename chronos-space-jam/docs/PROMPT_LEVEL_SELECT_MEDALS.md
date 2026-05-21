# PROMPT - Level Select Completed Medals

## Objective

Update the **Level Select** menu so completed chambers show the medal the player earned.

When a player has cleared a level, its level-select entry should display the best earned medal for that level using the existing medal art:

- Gold: `res://assets/first-gold.png`
- Silver: `res://assets/second-silver.png`
- Bronze: `res://assets/third-bronze.png`

Uncleared unlocked levels should remain selectable but should not show a medal. Locked levels should still show `LOCKED` and remain disabled.

---

## Scope Locked

### In scope

1. Show the earned medal on each completed level card in `scenes/ui/level_select.tscn`.
2. Treat a level as completed when `GameManager.best_moves.has(level_index)` is true.
3. Derive the displayed medal from the stored best move count:
   - `var best := int(GameManager.best_moves[level_index])`
   - `GameManager.get_medal_for_moves(level_index, best)`
4. Reuse the existing medal texture paths and color language from `scripts/hud.gd`.
5. Preserve current level select behavior:
   - unlocked levels are selectable
   - locked levels are disabled
   - Ctrl+Q developer unlock still rebuilds the grid
   - Back returns to main menu
6. Keep the existing neon-grid UI style from `main_menu.tscn`, `level_select.tscn`, and `hud.tscn`.
7. Prefer scene-first UI:
   - create a reusable authored level-card scene if the current code-created buttons need more structure
   - set static labels, icon slots, anchors, sizes, and theme overrides in `.tscn`
   - use script only to bind level index, lock state, title, best moves, medal texture, and callbacks
8. Keep changes narrow to level select / medal display state.

### Out of scope

- Do not change movement, tick order, collision, level clear, scoring, or medal target rules.
- Do not retune `@medal_targets` values in `levels/level_*.txt`.
- Do not change the level-clear HUD medal presentation except to share a local helper/constant if needed.
- Do not add new medal art.
- Do not show medals for levels that are merely unlocked but not cleared.
- Do not replace the level select with a new menu flow.
- Do not mark unrelated task rows Done.

---

## Project Context

| Item | Detail |
|------|--------|
| Engine | Godot 4.6, GL Compatibility renderer |
| Main menu | `scenes/ui/main_menu.tscn` -> `scripts/main_menu.gd` |
| Level select | `scenes/ui/level_select.tscn` -> `scripts/level_select.gd` |
| Medal state | `GameManager.best_moves` stores best move count by 0-based level index |
| Medal calculation | `GameManager.get_medal_for_moves(level_index, move_count)` |
| Medal targets | `@medal_targets gold=<n> silver=<n>` inside each `levels/level_*.txt` |
| Clear HUD reference | `scenes/ui/hud.tscn` -> `scripts/hud.gd` |
| Level count | `GameManager.TOTAL_LEVELS` |
| Level names | `StoryManager.get_level_name(index)` |

Relevant completed task rows:

- `UI-05 Level Select`: level buttons are clear and useful for judges.
- `UI-06 Level Clear Screen`: clear results show move stats and earned medal.
- `LEVEL-09 Move Count Targets`: levels have authored Bronze/Silver/Gold target data.

This is a polish extension of those completed systems, not a new scoring system.

---

## Current Baseline

Current `scripts/level_select.gd` builds one `Button` per level at runtime:

- text is `"<level number>\n<level name>"` for unlocked levels
- text is `"<level number>\nLOCKED"` for locked levels
- button size is `Vector2(96, 52)`
- style is applied through `_apply_button_style(button)`

Current medal display exists only in the clear HUD:

- `scripts/hud.gd` defines `MEDAL_TEXTURES`
- `scripts/hud.gd` maps `medal_data["medal"]` to the medal icon and label
- `GameManager.on_level_cleared(move_count)` updates `best_moves` before emitting `level_cleared`

The level select does not currently inspect `best_moves`, so completed levels look the same as merely unlocked levels.

---

## Implementation Guidance

### Preferred UI structure

Use a reusable scene-authored card rather than stuffing more text into a plain `Button`.

Suggested new scene:

`scenes/ui/level_select_card.tscn`

Suggested root:

- `Button` root named `LevelSelectCard`
- same minimum footprint as current cards or slightly taller if needed, such as `Vector2(112, 72)`
- children can include:
  - `VBoxContainer`
  - `Label` for level number
  - `Label` for level name / locked text
  - `TextureRect` named `MedalIcon`, initially hidden

Suggested script:

`scripts/level_select_card.gd`

Expose a setup method such as:

```gdscript
func setup(level_index: int, is_unlocked: bool, is_completed: bool, level_name: String, medal: String) -> void:
```

The card should:

- disable itself when locked
- show `LOCKED` for locked levels
- show the level name for unlocked levels
- show `MedalIcon` only when `is_completed` is true
- use the correct medal texture for `Gold`, `Silver`, or `Bronze`
- keep hover/click behavior compatible with `Button`

If you do not create a separate card script, keep equivalent logic local to `scripts/level_select.gd`, but do not create an unreadable pile of child-node setup code.

### Level select binding

In `scripts/level_select.gd`, `_build_level_buttons()` should compute:

```gdscript
var unlocked := GameManager.is_level_unlocked(i)
var completed := GameManager.best_moves.has(i)
var medal := ""
if completed:
	var best := int(GameManager.best_moves[i])
	medal = GameManager.get_medal_for_moves(i, best)
```

Then bind the card with:

- level number
- locked/unlocked state
- level name from `StoryManager.get_level_name(i)` when unlocked
- completed state
- earned medal
- pressed callback for unlocked cards
- hover SFX for unlocked cards

### Optional progress persistence

Only add persistence if the current implementation goal is medals surviving app restart.

If persistence is added, keep it small and local to `GameManager`:

- save `best_moves` and `highest_unlocked_level_index` to `user://progress.cfg`
- load progress in `GameManager._ready()`
- save after `on_level_cleared()`
- keep `SettingsManager` responsible only for settings, not level progress

If persistence is deferred, leave an explicit `TODO: UI-05` note near the point where progress would be saved or loaded. Do not silently imply persistence exists.

---

## Visual Requirements

- Medal icons must be readable at level-card size.
- Gold, Silver, and Bronze should be visually distinct without requiring text labels.
- Locked cards should remain dim and clearly unavailable.
- Completed cards should not become harder to read or click.
- The menu must still fit at 1280 x 720 with all `GameManager.TOTAL_LEVELS` entries visible.
- Avoid default grey Godot styling on any new labels, icons, panels, or cards.
- Use existing palette:
  - background navy `Color(0.04, 0.04, 0.08, 1)`
  - cyan accents `Color(0.3, 0.9, 1, 1)`
  - off-white text `Color(0.9, 0.9, 0.95, 1)`
  - muted locked text `Color(0.42, 0.48, 0.58, 0.9)`
  - medal highlight gold `Color(1, 0.85, 0.2, 1)`

---

## Files To Read First

- `docs/TASK_BREAKDOWN.md`
- `docs/GDD Chrono.md`
- `scenes/ui/level_select.tscn`
- `scripts/level_select.gd`
- `scripts/autoload/game_manager.gd`
- `scripts/hud.gd`
- `scenes/ui/hud.tscn`

---

## Files Likely To Modify

- `scenes/ui/level_select.tscn`
- `scripts/level_select.gd`

Possible new files:

- `scenes/ui/level_select_card.tscn`
- `scripts/level_select_card.gd`

Only if progress persistence is included:

- `scripts/autoload/game_manager.gd`

---

## Acceptance Criteria

- Completed levels in Level Select show the medal earned from the best stored move count.
- Uncompleted but unlocked levels show no medal.
- Locked levels remain disabled and show `LOCKED`.
- Medal display updates when returning to Level Select after clearing a level.
- Ctrl+Q dev unlock still unlocks all levels without falsely showing medals for uncleared levels.
- Existing clear HUD medals still work.
- No level data, medal targets, movement rules, or scoring thresholds are changed.
- `tools/verify_project.py` passes.
- `tools/verify_levels.py` is run after any level-data changes. If no level data changes are made, it is optional but recommended.

---

## Suggested Validation

From repo root:

```powershell
py tools/verify_project.py
py tools/verify_levels.py
```

If Godot is available:

```powershell
godot --headless --path . --script res://tools/godot_smoke_test.gd
```

Manual check:

1. Start the game.
2. Clear Level 1.
3. Return to Level Select.
4. Confirm Level 1 shows the earned medal.
5. Confirm Level 2 is unlocked but shows no medal until cleared.
6. Use Ctrl+Q on Level Select.
7. Confirm all levels unlock, but medals still appear only for levels with `best_moves` entries.
