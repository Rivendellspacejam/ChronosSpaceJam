# PROMPT - Undo Tick Button and Hotkey

## Objective

Add a one-step **Undo Tick** feature to **Chrono Slide**.

The player should be able to press an undo hotkey or click an HUD button to return to the board state from before the most recent accepted movement input. This should help the player rethink a move without fully restarting the chamber.

Undo must also work after the player dies. If the last accepted movement caused death, pressing undo should restore the player to the pre-move state and return the game to normal play.

---

## Scope Locked

### In scope

1. Add a new input action named `undo_tick`.
2. Bind `undo_tick` to the physical **Z** key by default.
3. Add a scene-authored HUD button for undo, with copy such as `UNDO (Z)`.
4. Store a snapshot before each accepted movement input commits its tick.
5. Restore exactly one previous accepted-tick snapshot when undo is triggered.
6. Allow undo while the game is in `PLAYING` or `DEAD` state.
7. After undoing from `DEAD`, return to `GameManager.GameState.PLAYING`, hide the death panel, and let the player move again.
8. Restore tick count, move count, player grid position, gravity direction, mutable level state, enemy phase positions, and phase object visuals.
9. Keep undo from advancing time, changing move count, triggering death, clearing the level, or collecting additional items.
10. Preserve existing tick order for normal moves: Input -> Tick Update -> World Phase Update -> Player Slide.

### Out of scope

- Do not add a free rewind timeline, timeline scrubber, or multi-step history UI.
- Do not add a wait / skip-turn button.
- Do not change normal movement, slide scanning, collision priority, hazard rules, level clear rules, or tick order.
- Do not rebalance levels.
- Do not make undo work from pause, story, sliding, or level-clear state in this first pass.
- Do not add a new autoload unless the local scene ownership becomes clearly worse.
- Do not update task rows to `Done` unless implementation and validation are completed.

---

## Design Intent

Undo is a correction tool, not a new puzzle verb.

The player should be able to ask:

> What if I take back the last shift and choose another direction?

The feature should feel immediate and predictable:

- If the player is alive, undo returns to the state before the last accepted move.
- If the player died because of that move, undo revives them at the pre-move state.
- If there is no undo snapshot for the current level, the button is disabled and the hotkey does nothing.
- Restart remains available with **R** and still resets the whole level.

---

## Project Context

| Item | Detail |
|------|--------|
| Engine | Godot 4.6, GL Compatibility renderer |
| Main game scene | `scenes/game/game_level.tscn` / `scripts/game_level.gd` |
| HUD | `scenes/ui/hud.tscn` / `scripts/hud.gd` |
| Player | `scripts/player.gd` |
| Level state | `scripts/level_manager.gd` |
| Tick state | `scripts/autoload/tick_manager.gd` |
| Game state | `scripts/autoload/game_manager.gd` |
| Input map | `project.godot` |
| Current movement actions | `move_up`, `move_down`, `move_left`, `move_right` |
| Current utility actions | `restart`, `preview_future`, `ui_cancel`, `ui_accept` |
| Normal tick order | Input -> Tick Update -> World Phase Update -> Player Slide |

Relevant current behavior:

- `player.gd` commits a move tick through `TickManager.advance_tick()`.
- `TickManager.advance_tick()` increments both `current_tick` and `move_count`, then updates phase objects and enemies.
- `GameManager.on_player_died()` sets state to `DEAD` and emits `player_died`.
- `hud.gd` shows `DeathPanel` when the game state becomes `DEAD`.
- `game_level.gd` allows **R** restart while `DEAD`, `LEVEL_CLEAR`, `PLAYING`, or `STORY`.
- `level_manager.gd` owns mutable level details such as collected coins, coin gates, phase goal visuals, future preview layers, phase object registries, and enemy objects.

---

## Feature Specification

### 1. Input action

Add a new action to `project.godot`:

| Action | Default key | Notes |
|--------|-------------|-------|
| `undo_tick` | Physical Z | Use a direct key action, not Ctrl+Z, so it works consistently in web builds. |

Handle this action from the game-level input owner, preferably `scripts/game_level.gd`, so it can work even when `player.gd` ignores input in `DEAD` state.

Recommended order in `game_level.gd._unhandled_input(event)`:

1. If `event.is_action_pressed("undo_tick")`, attempt undo.
2. Then existing restart / level clear / pause handling.

The undo action should only succeed when:

- Current state is `GameManager.GameState.PLAYING` or `GameManager.GameState.DEAD`.
- The player is not sliding.
- The current level has an available undo snapshot.

### 2. HUD button

Add an undo button to `scenes/ui/hud.tscn`.

Recommended placement:

- Inside or directly below `StatsPanel/MarginContainer/VBoxContainer`, near Tick / Time Shifts.
- Copy: `UNDO (Z)`.
- Match the existing neon grid UI style.
- Static styling and layout belong in the `.tscn`.
- Runtime script only toggles disabled/visible state and emits a request signal.

Recommended script shape in `scripts/hud.gd`:

```gdscript
signal undo_requested()

@onready var undo_button: Button = $StatsPanel/MarginContainer/VBoxContainer/UndoButton

func set_undo_available(is_available: bool) -> void:
	undo_button.disabled = not is_available

func _on_undo_button_pressed() -> void:
	undo_requested.emit()
```

Connect the button signal in the scene where practical. If scene-authored signal wiring is awkward for the cross-scene call, connect `hud.undo_requested` from `game_level.gd`.

Update the death panel hint copy in `hud.tscn` from only restart copy to something like:

```text
Z to undo last shift  |  R to restart
```

The death panel should still appear on death. Undo from death should make it disappear through the normal `GameManager.state_changed` path.

### 3. Snapshot ownership

Prefer local scene ownership:

- `game_level.gd` should own the undo history for the current level.
- Clear the undo history whenever a level loads or restarts.
- Avoid a new global autoload unless the implementation proves it is necessary.

The player script currently decides whether a move is accepted. Capture the undo snapshot only after a move has been proven valid and immediately before the move commits its tick.

Recommended hook:

- In `player.gd`, after `_slide_path` is known to be non-empty and before `_commit_move_tick()`, notify the game level that an undo snapshot should be captured.
- Keep the hook small, for example:

```gdscript
var game_level := get_parent()
if game_level != null and game_level.has_method("capture_undo_snapshot"):
	game_level.capture_undo_snapshot()
```

Do not capture snapshots for blocked inputs, ignored inputs, preview input, restart, pause, story input, or level clear continuation.

### 4. Snapshot contents

The snapshot must contain enough data to restore the prior board state without reloading the level.

Minimum snapshot data:

| Area | Data to capture |
|------|-----------------|
| Tick | `TickManager.current_tick`, `TickManager.move_count` |
| Game state | Previous state should restore to `PLAYING` |
| Player | `grid_pos`, `position`, `gravity_direction`, player local state, visibility, slide path/progress cleared |
| Level manager | Current slide direction cleared, collected coins, coin visibility, coin gate visuals, goal visual state, future previews cleared |
| Phase objects | Gate/laser/spike state for restored tick |
| Enemies | Enemy positions for restored tick |
| UI | Undo availability, death panel state through normal game state signal |

If adding helper methods, keep them explicit and narrow:

```gdscript
# scripts/level_manager.gd
func capture_undo_state() -> Dictionary
func restore_undo_state(snapshot: Dictionary) -> void

# scripts/player.gd
func capture_undo_state() -> Dictionary
func restore_undo_state(snapshot: Dictionary) -> void
```

This is preferable to exposing or mutating many private dictionaries from `game_level.gd`.

### 5. Restore behavior

When undo is triggered:

1. Refuse if no snapshot exists.
2. Clear movement buffering and active slide data.
3. Restore `TickManager.current_tick` and `TickManager.move_count` from the snapshot.
4. Restore player grid/world position and make player idle/alive.
5. Restore collected coins and coin gate visuals.
6. Refresh goal, gates, lasers, spikes, and enemies for the restored tick.
7. Clear any future preview visuals.
8. Set `GameManager` state back to `PLAYING`.
9. Update HUD undo availability.
10. Optionally play existing `AudioManager.play_ui_click()` or a very small existing UI sound.

Do not call `TickManager.advance_tick()` during undo.

If `TickManager` gets a restore method, keep it explicit:

```gdscript
func restore_tick_state(tick: int, moves: int) -> void:
	current_tick = tick
	move_count = moves
	_update_environment_objects()
	_update_enemies(current_tick)
	phase_update_requested.emit(current_tick)
	tick_advanced.emit(current_tick)
```

If emitting `tick_advanced` causes misleading tick-pulse/audio feedback, add a separate signal or a `refresh_current_tick()` helper instead. The important part is that all phase visuals and HUD values refresh without incrementing the tick.

### 6. Undo from death

Death recovery is a required part of this task.

Expected flow:

1. Player accepts a movement input.
2. Snapshot is captured before `TickManager.advance_tick()`.
3. The movement causes hazard/enemy death.
4. `GameManager.current_state` becomes `DEAD` and `DeathPanel` appears.
5. Player presses **Z** or clicks `UNDO (Z)`.
6. Snapshot restores.
7. `GameManager.current_state` becomes `PLAYING`.
8. `DeathPanel` hides through `hud.gd._on_state_changed`.
9. Player can choose another move.

Do not clear the undo snapshot just because death happened. The death state is exactly where the last snapshot is most useful.

### 7. Undo stack depth

For this first pass, one-step undo is enough.

Acceptable implementations:

- Store only the latest snapshot and clear it after successful undo.
- Or store a small stack and allow repeated **Z** presses, as long as behavior remains stable.

If repeated undo is not implemented, state that clearly in code comments or docs:

```gdscript
# One-step undo only: this snapshot represents the state before the latest accepted shift.
```

Do not build UI for full history depth in this task.

---

## Files Likely To Modify

### `project.godot`

- Add `undo_tick` input action bound to physical **Z**.

### `scenes/ui/hud.tscn`

- Add scene-authored `UndoButton`.
- Style it to match the existing HUD.
- Update death panel hint copy to mention undo and restart.

### `scripts/hud.gd`

- Add `undo_requested` signal.
- Add `set_undo_available(is_available: bool)`.
- Wire button pressed behavior.
- Keep static style out of script when possible.

### `scripts/game_level.gd`

- Own the current undo snapshot or stack.
- Connect `hud.undo_requested`.
- Handle `undo_tick` hotkey.
- Clear undo history on level load.
- Implement `capture_undo_snapshot()` and `attempt_undo()`.
- Keep undo available while `DEAD`.

### `scripts/player.gd`

- Notify `game_level.gd` to capture a snapshot immediately before a valid move commits its tick.
- Add narrow capture/restore helpers if needed.
- Ensure undo restore clears sliding fields and input buffer.

### `scripts/autoload/tick_manager.gd`

- Add an explicit restore/refresh helper if direct assignment from `game_level.gd` would spread internals.
- Restore should not increment `current_tick` or `move_count`.

### `scripts/level_manager.gd`

- Add capture/restore helpers for mutable board state.
- Restore collected coin visibility and coin gates.
- Refresh phase goal, gate, laser, spike, and enemy visuals for the restored tick.
- Clear future previews after undo.

### Optional docs

If implementation ships, update:

- `docs/GDD Chrono.md` because it currently describes rewind as not in build.
- `docs/TASK_BREAKDOWN.md` with a new row if the team wants this tracked formally.

---

## Behavior Rules

| Situation | Expected behavior |
|-----------|-------------------|
| No accepted move has happened in this level | Undo button disabled; Z does nothing. |
| Last input was blocked by wall/gate/blocker | No snapshot captured; undo target remains unchanged. |
| Player is alive after a move | Z or button restores the state before that move. |
| Player died after a move | Z or button restores the state before that move and resumes play. |
| Player is sliding | Undo is ignored until the slide resolves. |
| Game is paused | Undo is ignored; pause controls keep ownership. |
| Story text is active | Undo is ignored. |
| Level is clear | Undo is ignored in this first pass. |
| Restart is pressed | Current level reloads and undo history clears. |
| Future preview is visible | Undo clears preview visuals before/after restoring. |

---

## Edge Cases To Verify

1. Undo after dying on an active laser.
2. Undo after dying to an enemy patrol.
3. Undo after collecting a coin restores the coin and closes coin gates if needed.
4. Undo after a move that changes a time gate restores the previous gate visual and collision state.
5. Undo after a move that changes spike warning/active state restores the previous spike visual and collision state.
6. Undo from a phase-goal level restores the previous goal active/inactive visual.
7. Undo on a level with non-zero `@start_tick` restores display tick and move count correctly.
8. Undo does not create a wait action: it restores a previous state instead of advancing time.
9. Undo button disabled state updates after level load, after first valid move, after undo, and after restart.
10. Restart still works after death even if undo is available.

---

## UI Style

Match the existing neon grid HUD:

| Element | Guidance |
|---------|----------|
| Button text | `UNDO (Z)` |
| Normal color | Dark translucent navy with cyan border/accent |
| Disabled state | Dim blue-grey, readable but clearly inactive |
| Font size | Similar to existing HUD rows, around 13-16 |
| Placement | Near Tick / Time Shifts so it reads as a time-control affordance |
| Death hint | Include both undo and restart: `Z to undo last shift  |  R to restart` |

Avoid default grey Godot button styling. Static colors, font sizes, and layout should be authored in `hud.tscn`.

---

## Implementation Notes

1. **Scene-first UI:** Add the HUD button and death-panel copy in `hud.tscn`.
2. **Local ownership:** Let `game_level.gd` coordinate undo for the current level.
3. **Snapshot before mutation:** Capture before `TickManager.advance_tick()` and before player slide side effects happen.
4. **No tick increment:** Undo is not a move and must not call `advance_tick()`.
5. **Death support:** `DEAD` must be a valid undo state when a snapshot exists.
6. **Level clear blocked:** Keep level-clear undo out of this task to avoid best-move/progression complications.
7. **History reset:** Clear snapshots on level load/restart.
8. **Private state:** Prefer narrow capture/restore methods over direct external mutation of private dictionaries.
9. **Typed GDScript:** Be careful assigning untyped `Dictionary` or `Array` results into typed fields.
10. **No broad refactor:** Keep changes local to input, HUD, game-level coordination, player snapshot hook, and level/tick restoration.

---

## Acceptance Criteria

- [ ] `project.godot` has `undo_tick` bound to physical **Z**.
- [ ] HUD has a styled `UNDO (Z)` button that is disabled when no undo is available.
- [ ] Pressing **Z** and clicking the HUD button call the same undo path.
- [ ] A snapshot is captured only for accepted movement inputs.
- [ ] Blocked or ignored movement inputs do not create an undo snapshot.
- [ ] Undo restores player position, gravity direction, tick count, and move count to the pre-move state.
- [ ] Undo restores phase object visuals/collision state for the restored tick.
- [ ] Undo restores enemy patrol positions for the restored tick.
- [ ] Undo restores collected coin state and coin gate state.
- [ ] Undo after player death returns to `PLAYING`, hides the death panel, and allows another move.
- [ ] Undo does not work during slide, pause, story, or level-clear state.
- [ ] Normal movement tick order remains unchanged.
- [ ] Restart still works after death and clears undo history on reload.
- [ ] `py tools/verify_levels.py` passes.
- [ ] `py tools/verify_project.py` passes.
- [ ] If available, Godot headless smoke test passes:

```powershell
godot --headless --path . --script res://tools/godot_smoke_test.gd
```

---

## Proposed Task ID Reference

There is no existing undo task row in `docs/TASK_BREAKDOWN.md` at the time this prompt was written.

If the task breakdown is updated, use a new row like:

| Task ID | Title | Category | Priority | Dependencies | Effort |
|---------|-------|----------|----------|--------------|--------|
| TIME-10 | Undo Tick | Time System / UI | Medium | TIME-01, CORE-05, UI-01 | M |

Suggested acceptance summary for that row:

- Undo button and Z hotkey restore the state before the last accepted movement.
- Undo works after death.
- Undo does not advance tick, count as a move, or work as a wait button.
- Restart and level-clear flow remain stable.

---

## Suggested Commit Message

```text
Add undo tick implementation prompt
```
