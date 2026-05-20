# PROMPT - Phase Preview UI Future Peek

## Objective

Finish the **Phase Preview UI** for **Chrono Slide** as a hold-to-peek future board view.

When the player holds **P**, the level should look like it is **one tick in the future**, as if the player made an accepted move and time advanced by 1 tick, **but the player character did not move**.

Do **not** communicate the future state by modulating real tiles, tinting tiles, adding colored overlays, warning rings, glow-only hints, ghost squares, or movement lines. The preview should use the same normal tile/object visuals the game already uses for real current states.

Add a small clear text cue while **P** is held so the player understands they are looking at the future, not the current board.

---

## Scope Locked

### In scope

1. Replace colored phase preview overlays with a normal-looking **one-tick future board view**.
2. Keep using the existing `preview_future` input action, bound to **P** in `project.godot`.
3. While **P** is held, show phase-based objects at `TickManager.current_tick + 1`.
4. Keep the player visible at the real current position during preview.
5. Show future enemy positions as normal enemy visuals, not ghost markers or lines.
6. Add a concise on-screen cue while preview is active, such as `Future Preview: +1 Tick`, `Peeking 1 Tick Ahead`, or similar.
7. Ensure the preview is visual only: no tick advance, no move count change, no collision checks, no death, no level clear, and no object registration changes.
8. Keep the existing Settings option `Move Previews (P)` as the enable/disable control.
9. Preserve existing tick order: Input -> Tick Update -> World Phase Update -> Player Slide.

### Out of scope

- Do not add a global phase counter such as `Phase: 2/4` or `Next Phase: 3`.
- Do not add rewind, wait, step-forward, timeline scrub, or turn planning.
- Do not change movement rules or tick order.
- Do not rebalance levels.
- Do not add new hazard types, new level symbols, or new tutorial text unless a tiny label update is needed because existing text describes the old overlay behavior.
- Do not mark task rows Done unless implementation and validation are actually completed.

---

## Design Intent

The player should be able to hold **P** and ask:

> What will the board look like after the next accepted move, if my character stays still in this preview?

This preview represents **time advancing by one tick**, not player movement.

That means:

- Time Gates visually appear open or closed exactly as they normally would at `current_tick + 1`.
- Lasers visually appear active or inactive exactly as they normally would at `current_tick + 1`, including their normal active beam appearance.
- Spikes visually appear safe, warning, or active exactly as they normally would at `current_tick + 1`.
- Enemies visually appear at their `current_tick + 1` patrol position using normal enemy visuals.
- The player stays at the real current grid position and does not preview-slide.
- Static tiles such as floor, wall, goal, anchor, and blocker remain visually unchanged.

Important distinction: normal object visuals may still use their existing gameplay colors, such as active laser red or warning spike yellow. The restriction is against **preview-specific tile modulation, overlays, or tint-only hints**.

---

## Project Context

| Item | Detail |
|------|--------|
| Engine | Godot 4.6, GL Compatibility renderer |
| Viewport | 1280 x 720, stretch mode `canvas_items` |
| Autoloads | `GameManager`, `TickManager`, `SettingsManager`, `AudioManager`, `StoryManager` |
| Game scene | `scenes/game/game_level.tscn` -> `LevelManager` (`scripts/level_manager.gd`) |
| HUD | `scenes/ui/hud.tscn` / `scripts/hud.gd` - Gravity, Tick, Time Shifts only |
| Tick order | Input -> Tick Update -> World Phase Update -> Player Slide |
| Phase objects | `time_gate.gd`, `laser.gd`, `spike.gd`, `enemy_patrol.gd` |
| Settings | `scripts/autoload/settings_manager.gd`, `scenes/ui/settings_menu.tscn` |

---

## Current Baseline

The repository may already have some or all of this preview infrastructure:

| Area | Existing file / behavior |
|------|--------------------------|
| Input | `project.godot` has or should have `preview_future` bound to physical key **P**. |
| Toggle | `scripts/autoload/settings_manager.gd` stores `move_previews_enabled`. |
| Settings UI | `scenes/ui/settings_menu.tscn` shows `Move Previews (P)`. |
| Preview layers | `scenes/game/game_level.tscn` may have `HazardPreviewLayer` and `EnemyPreviewLayer`. |
| Preview logic | `scripts/level_manager.gd` may build colored hazard overlays and enemy ghost/line previews. |
| Future queries | `time_gate.gd`, `laser.gd`, and `spike.gd` may expose `get_state_for_tick(tick)`. |
| Enemy future position | `enemy_patrol.gd` exposes `get_grid_pos_for_tick(tick)`. |

This task revises the preview model away from overlay hints and toward a same-art future board presentation.

---

## Feature Specification

### 1. Hold-P future board preview

| Requirement | Detail |
|-------------|--------|
| Activation | Show only while `preview_future` is pressed, `GameManager.is_playing()`, and `SettingsManager.move_previews_enabled` |
| Query tick | Use `TickManager.current_tick + 1` |
| Player | Player remains at current real position |
| Real game state | Do not mutate `TickManager.current_tick`, movement state, collision state, or registered objects |
| Release | Clear preview and restore current board visuals immediately |
| During slide | Hide preview so player motion remains readable |
| Pause / death / clear | Hide or clear preview |

### 2. Future visual layer

Prefer a visual-only preview layer over temporarily changing live gameplay objects.

In `scenes/game/game_level.tscn`, add or repurpose a single layer:

```text
LevelManager
  FuturePreviewLayer (Node2D)
```

Recommended `z_index`: above `Objects`, below or equal to the live player visual. Tune so future objects are readable while the real player remains clearly visible.

If keeping `HazardPreviewLayer` / `EnemyPreviewLayer` is lower risk, they may remain as implementation details, but their player-facing behavior must be the same-art future board preview.

### 3. Hide or de-emphasize live phase objects while preview is held

While **P** is held and previews are enabled:

- Clear any old overlay/ghost preview nodes.
- Hide live phase objects that have a future preview duplicate, or otherwise ensure the duplicate visually replaces them cleanly.
- Draw visual-only future-state duplicates in the preview layer.
- Keep static board tiles and the player unchanged.
- Show the active preview text cue.

When **P** is released:

- Clear the preview layer.
- Restore all live phase objects to visible.
- Hide the preview text cue.
- Do not call `update_phase()` on live objects just to preview.

### 4. Build same-art future duplicates

Create future preview nodes using the same textures, scale, size, colors, and normal state visuals as the real objects.

Acceptable implementation options:

- Add preview-specific helper methods to phase objects:

```gdscript
func build_preview_for_tick(tick: int) -> Node2D
```

- Or centralize preview-node building in `level_manager.gd` if object visuals are simple and this keeps the patch smaller.

Preview nodes must be visual-only. Do not duplicate collision, registration, damage, goal, or gameplay behavior. Do not register preview nodes with `TickManager`.

### 5. Use existing future-state APIs

Use current future query methods as the source of truth:

| Object | Future query |
|--------|--------------|
| Time Gate | `gate.get_state_for_tick(next_tick)` |
| Laser | `laser.get_state_for_tick(next_tick)` |
| Spike | `spike.get_state_for_tick(next_tick)` |
| Enemy | `enemy.get_grid_pos_for_tick(next_tick)` |

If a helper is added, keep the state math shared with `update_phase()` so preview behavior cannot drift from real tick behavior.

### 6. Preview all future phase objects

The future peek should show the complete one-tick-ahead phase-object state, not only objects whose state will change.

Examples:

- A gate that stays closed next tick still appears as the normal closed gate.
- A laser that stays inactive next tick still appears as the normal inactive laser.
- A spike that stays warning next tick still appears as the normal warning spike.
- An enemy that stays in place still appears as the normal enemy at that future cell.

### 7. Player-facing preview cue

Add a small text cue while preview is active so the player knows they are seeing the future.

Recommended behavior:

- Show only while **P** is held and the future preview is visible.
- Hide when **P** is released, the setting is off, the game is sliding, paused, dead, or level clear.
- Use short copy such as `Future Preview: +1 Tick` or `Peeking 1 Tick Ahead`.
- Place it in the HUD or a small scene-authored label near the top center/corner.
- Match the existing neon grid UI style: cyan title/accent, off-white text, no default grey Godot theme.
- Do not make it a global phase counter. The cue tells the player they are in preview mode, not what phase number they are on.

---

## Files Likely To Modify

### `scenes/game/game_level.tscn`

- Add or repurpose a preview layer for future-state visual duplicates.
- Set layer `z_index` in the scene where practical.

### `scripts/level_manager.gd`

- Replace colored overlay/ghost/line preview functions with future-board preview functions.
- Preserve hold-key behavior:
  - Show preview only while `preview_future` is pressed.
  - Show only when `SettingsManager.move_previews_enabled`.
  - Show only during `GameManager.is_playing()`.
  - Hide during slide, pause, death, clear, or when **P** is released.
- Add restore logic for live phase-object visibility if duplicates are used.
- Do not mutate `TickManager.current_tick`.
- Do not call gameplay collision or slide logic.

### `scenes/ui/hud.tscn` and `scripts/hud.gd`

- Add a scene-authored label or compact HUD cue for active future preview mode.
- Keep static appearance in the `.tscn`; script should only toggle text/visibility if needed.
- Do not add a phase-number HUD line.

### `scripts/time_gate.gd`

- Add a visual-only future preview helper, or expose enough normal visual data for `level_manager.gd` to render a future gate.
- Ensure open/closed preview visuals match the real current-state visuals.

### `scripts/laser.gd`

- Add a visual-only future preview helper, or expose enough normal visual data for `level_manager.gd` to render a future laser.
- Active preview should use the same beam look as the real active laser.
- Inactive preview should use the same normal inactive look.

### `scripts/spike.gd`

- Add a visual-only future preview helper, or expose enough normal visual data for `level_manager.gd` to render a future spike.
- Safe/warning/active preview should match real visual states.

### `scripts/enemy_patrol.gd`

- Add a visual-only future preview helper, or expose enough normal visual data for `level_manager.gd` to render a future enemy at `get_grid_pos_for_tick(next_tick)`.
- Do not keep the ghost square or movement line presentation.

### Optional docs

If implementation changes shipped behavior, update:

- `docs/GDD Chrono.md`
- `docs/TASK_BREAKDOWN.md`

Only update task status if implementation and validation satisfy the acceptance criteria.

---

## Behavior Rules

| Event | Expected behavior |
|-------|-------------------|
| P pressed while playing and setting is on | Show the `current_tick + 1` future board view and active preview text cue. |
| P released | Restore the real current board view and hide preview cue. |
| P held during slide | Hide preview and cue; player movement remains readable. |
| P held while paused, dead, or level clear | No preview visible. |
| Move Previews setting off | P does nothing and all preview nodes/cues are cleared. |
| Tick advances normally | Real objects update normally; future preview target becomes the new `current_tick + 1`. |

---

## Visual Style

Match the existing neon/dark palette:

| Element | Guidance |
|---------|----------|
| Future objects | Use normal object visuals for their future state, not preview-only colors |
| Player | Remain at real current position and stay clearly visible |
| Cue text | Cyan/off-white neon UI style, compact and readable |
| Preview layer | Readable above objects without obscuring the player |

Do not modulate actual board tiles for the preview. Static tiles should not change unless they are normal phase-object visuals represented by a future duplicate.

---

## Implementation Notes

1. **Scene-first:** Layer nodes, HUD cue label, static styling, and `z_index` belong in `.tscn` where practical.
2. **No HUD phase counter:** Do not add `PhaseLabel` or any phase-number line to `hud.tscn`.
3. **Performance:** Build/clear future preview on input/state changes, not every `_process` frame unless input polling is already the local pattern.
4. **Single source of truth:** Next-tick simulation must use the same patterns/phase counts as `update_phase`.
5. **Enemy timing:** Enemies already move to `tick + 1` during real moves; future peek should show that same upcoming patrol position without moving the live enemy.
6. **No tile modulation:** Do not tint floors, walls, goals, anchors, blockers, or live tiles to indicate the future.
7. **Verification:** From repo root (`chronos-space-jam/`):
   - `py tools/verify_levels.py`
   - `py tools/verify_project.py`
8. **Manual playtest levels:** 2 (gate), 4 (laser), 5 (spike), 6 (enemy patrol), 8+ (combined).

---

## Acceptance Criteria

- [ ] Holding **P** shows a one-tick future board view without advancing `TickManager.current_tick`.
- [ ] While **P** is held, a clear text cue tells the player they are viewing the future.
- [ ] Releasing **P** restores the exact current board view and hides the text cue.
- [ ] The player does not move in the future preview.
- [ ] Enemy preview uses normal enemy visuals at the future patrol position, not a ghost square or movement line.
- [ ] Gate, laser, and spike previews use their normal current-game visuals for the future tick, not preview-only colors, overlays, rings, or tile tints.
- [ ] Preview shows all future phase-object states, not only objects whose state will change.
- [ ] Preview is hidden during slide, pause, death, clear, and when the Move Previews setting is off.
- [ ] No preview nodes affect collision, death, goal clear, tick count, move count, or enemy registration.
- [ ] HUD still avoids a global phase-number line.
- [ ] Existing tick order remains unchanged: Input -> Tick Update -> World Phase Update -> Player Slide.
- [ ] `py tools/verify_levels.py` passes.
- [ ] `py tools/verify_project.py` passes.
- [ ] If available, Godot headless smoke test passes:

```powershell
godot --headless --path . --script res://tools/godot_smoke_test.gd
```

---

## Task ID Reference

| Task ID | Title | Category | Priority | Dependencies | Effort |
|---------|-------|----------|----------|--------------|--------|
| UI-11 | Phase Preview UI | UI/HUD | Medium | UI-03, TIME-03, TIME-07, UI-10 | M |

**Related completed tasks:** UI-01 (HUD), UI-03 (phase visuals), TIME-07 (enemy patrol), FEEL-03 (tick pulse on HUD label).

---

## Suggested Commit Message

```text
Revise phase preview prompt for one-tick future peek
```
