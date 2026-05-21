# PROMPT - Anchor Capture GDShader Effect

## Objective

Revise the **Chrono Slide** Anchor Tile capture effect so it uses a Godot CanvasItem `.gdshader` instead of runtime-created ring and pull-line nodes.

The anchor should still read as a stop pad, but when the player slides onto it, the tile should briefly look like it captures spacetime momentum: cyan/white energy pulls inward from the incoming slide direction, tightens around the anchor, then fades quickly.

This is a visual polish task only. Do not change anchor movement rules, collision priority, tick order, input timing, level data, or puzzle solutions.

---

## Scope Locked

### In scope

1. Create a CanvasItem `.gdshader` for the existing anchor sprite:

```text
assets/anchor_tile.png
```

2. Apply a unique `ShaderMaterial` instance to each Anchor Tile sprite created by `LevelManager._create_anchor_tile()`.
3. Replace the current runtime `Line2D` / `Node2D` capture burst with shader-driven capture parameters on the anchor sprite.
4. Keep the current `play_anchor_capture(anchor_pos, incoming_direction)` call contract.
5. Pass the incoming slide direction into the shader so the effect pulls from the side the player came from.
6. Keep occupied-anchor alpha behavior working with enemies and future preview.
7. Keep the effect crisp and readable on the dark neon grid board.
8. Keep the effect short enough to read during fast slides.

### Out of scope

- Do not replace `assets/anchor_tile.png`.
- Do not create an anchor sprite sheet.
- Do not change the anchor symbol `A`.
- Do not change `TileInfo.is_anchor`.
- Do not change player movement, slide scanning, death, goal, bounce, coin, gate, hazard, or enemy behavior.
- Do not alter `levels/*.txt`.
- Do not edit `.import`, `.uid`, or `.godot/` files manually.
- Do not mark broad art tasks as Done for this narrow shader slice.

---

## Project Context

| Item | Detail |
|------|--------|
| Engine | Godot 4.6, GL Compatibility renderer |
| Renderer | GL Compatibility |
| Tile size | 48x48 |
| Anchor asset | `assets/anchor_tile.png` |
| Anchor texture constant | `scripts/level_manager.gd` -> `ANCHOR_TEXTURE` |
| Anchor symbol | `scripts/level_manager.gd` -> `SYM_ANCHOR = "A"` |
| Anchor node storage | `scripts/level_manager.gd` -> `_anchor_nodes: Dictionary` |
| Anchor spawn path | `LevelManager._build_visuals()` -> `_create_anchor_tile(gpos, world_pos)` |
| Capture call path | `scripts/player.gd` calls `level_manager.play_anchor_capture(grid_pos, gravity_direction)` when landing on an anchor |
| Current capture effect | `LevelManager.play_anchor_capture()` scales/rotates/modulates the anchor and calls `_spawn_anchor_capture_effect()` |
| Current extra nodes | `_spawn_anchor_capture_effect()`, `_make_anchor_capture_ring()`, `_add_anchor_pull_lines()` create runtime `Node2D` and `Line2D` visuals |
| Current task status | `docs/TASK_BREAKDOWN.md` -> `SPACE-01 | Anchor Tile` is Done |
| Related collision task | `docs/TASK_BREAKDOWN.md` -> `SPACE-06 | Tile Collision Priority Rules` is Done |

The current anchor rule must remain unchanged:

- anchor stops player when crossed
- player lands on anchor tile
- anchor creates timing-control spots
- collision priority remains wall/blocker/closed gate, active hazard/enemy, active goal, anchor, bounce, empty

---

## Design Intent

The Anchor Tile should feel like it catches and pins the player in spacetime.

Use shader animation for:

- a brief inward pull from the incoming slide direction
- a cyan/white capture ring that contracts into the center of the tile
- a small center flash at the moment of capture
- a subtle edge pulse that fades quickly
- optional directional streaks contained inside the 48x48 cell

Avoid effects that hurt puzzle readability:

- no large UV displacement that makes the tile appear to leave its grid cell
- no blur, smear, or anti-aliased softness
- no persistent idle animation that distracts from phase hazards
- no red/orange/yellow color language that can be confused with hazards or warnings
- no rotation or scaling that makes the anchor's occupied cell ambiguous
- no effect that hides enemies, player position, or future-preview readability

The anchor must still read as a stable stop pad before, during, and after capture.

---

## Direction Contract

Use the incoming player slide direction as the shader contract.

Recommended uniforms:

```glsl
uniform vec2 capture_direction = vec2(0.0, 0.0);
uniform float capture_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
```

Interpretation:

| Player movement direction | Player came from | Shader pull should begin from |
|---------------------------|------------------|-------------------------------|
| `Vector2i.RIGHT` / `(1, 0)` | left | left side of anchor |
| `Vector2i.LEFT` / `(-1, 0)` | right | right side of anchor |
| `Vector2i.DOWN` / `(0, 1)` | top | top side of anchor |
| `Vector2i.UP` / `(0, -1)` | bottom | bottom side of anchor |

Do not invert this accidentally. The visual should describe the incoming capture direction, not a rebound direction.

---

## Recommended Implementation

### 1. Add an anchor capture shader

Create:

```text
assets/shaders/anchor_capture_pulse.gdshader
```

Use `shader_type canvas_item`.

Recommended starting point:

```glsl
shader_type canvas_item;

uniform vec2 capture_direction = vec2(0.0, 0.0);
uniform float capture_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 capture_color : source_color = vec4(0.42, 1.0, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float ring_radius : hint_range(0.05, 0.75, 0.01) = 0.34;
uniform float ring_width : hint_range(0.01, 0.25, 0.005) = 0.055;
uniform float streak_strength : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float glow_strength : hint_range(0.0, 1.0, 0.01) = 0.42;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);

	vec2 dir = capture_direction;
	if (length(dir) < 0.001) {
		dir = vec2(0.0, -1.0);
	}
	dir = normalize(dir);

	float amount = clamp(capture_amount, 0.0, 1.0);
	float incoming_alignment = max(dot(normalize(centered + dir * 0.001), -dir), 0.0);
	float lane = 1.0 - smoothstep(0.02, 0.22, abs(dot(centered, vec2(-dir.y, dir.x))));
	float inward_band = smoothstep(0.60, 0.18, dist + amount * 0.18);
	float streak = lane * incoming_alignment * inward_band * amount;

	float collapsing_radius = mix(0.48, ring_radius, amount);
	float ring = 1.0 - smoothstep(ring_width, ring_width + 0.018, abs(dist - collapsing_radius));
	ring *= amount;

	float flash = smoothstep(0.18, 0.0, dist) * pow(amount, 1.8);
	float edge_lift = tex.a * amount * (0.5 + 0.5 * sin(TIME * 18.0)) * 0.08;

	vec3 color = tex.rgb;
	color += capture_color.rgb * (ring * glow_strength + streak * streak_strength + edge_lift);
	color = mix(color, core_color.rgb, flash * 0.35);

	COLOR = vec4(color, tex.a);
}
```

Tune values in-game. The effect should be visible, but it should not look like a portal, hazard, or bounce rebound.

### 2. Preload the shader in `level_manager.gd`

Add near the other shader/texture constants:

```gdscript
const ANCHOR_CAPTURE_SHADER := preload("res://assets/shaders/anchor_capture_pulse.gdshader")
```

### 3. Apply a unique material per anchor

Update `_create_anchor_tile(gpos, world_pos)` so each anchor sprite gets its own material:

```gdscript
func _create_anchor_tile(gpos: Vector2i, world_pos: Vector2) -> void:
	var anchor := _create_sprite(ANCHOR_TEXTURE, world_pos, objects_container)
	var material := ShaderMaterial.new()
	material.shader = ANCHOR_CAPTURE_SHADER
	anchor.material = material
	_anchor_nodes[gpos] = anchor
```

Each Anchor Tile needs its own `ShaderMaterial` instance. Do not share one material across all anchors unless only the contacted anchor can animate.

Reason: if every anchor shares one material, all anchors may pulse when only one was captured.

### 4. Revise `play_anchor_capture()`

Keep this method as the only public visual hook for anchor captures.

Recommended behavior:

- kill any existing capture tween for that anchor
- reset `capture_amount` to `1.0`
- set `capture_direction` from `incoming_direction`
- tween `shader_parameter/capture_amount` back to `0.0`
- keep the existing occupied-alpha/modulate behavior intact
- avoid runtime-created `Line2D` and `Node2D` effect nodes

Example direction/material helper:

```gdscript
func _get_anchor_material(anchor: Sprite2D) -> ShaderMaterial:
	return anchor.material as ShaderMaterial

func play_anchor_capture(anchor_pos: Vector2i, incoming_direction: Vector2i) -> void:
	var anchor := _anchor_nodes.get(anchor_pos) as Sprite2D
	if anchor == null:
		return

	if _anchor_capture_tweens.has(anchor_pos):
		var existing_tween := _anchor_capture_tweens[anchor_pos] as Tween
		if existing_tween != null:
			existing_tween.kill()

	var shader_material := _get_anchor_material(anchor)
	if shader_material == null:
		return

	var direction := Vector2(float(incoming_direction.x), float(incoming_direction.y))
	if direction.length_squared() <= 0.0:
		direction = Vector2.UP

	shader_material.set_shader_parameter("capture_direction", direction.normalized())
	shader_material.set_shader_parameter("capture_amount", 1.0)

	var tween := create_tween()
	_anchor_capture_tweens[anchor_pos] = tween
	tween.tween_property(shader_material, "shader_parameter/capture_amount", 0.0, ANCHOR_CAPTURE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if _anchor_capture_tweens.get(anchor_pos) == tween:
			_anchor_capture_tweens.erase(anchor_pos)
	)
```

If tweening shader parameters through `tween_property()` is unreliable in Godot 4.6, use a tiny local helper method to step `capture_amount`. Keep the workaround local to anchor visuals.

### 5. Remove or stop using the old effect-node helpers

The implementation should no longer call:

```gdscript
_spawn_anchor_capture_effect(...)
```

The following helpers should be removed if nothing else uses them:

```gdscript
_spawn_anchor_capture_effect()
_make_anchor_capture_ring()
_add_anchor_pull_lines()
```

Also remove stale constants that only exist for those old `Line2D` visuals if they become unused:

```gdscript
ANCHOR_CAPTURE_RING_POINTS
ANCHOR_CAPTURE_RING_RADIUS
ANCHOR_CAPTURE_COLOR
```

Keep `ANCHOR_CAPTURE_TIME` if it still drives the shader pulse.

---

## Files Likely To Modify

### `assets/shaders/anchor_capture_pulse.gdshader`

- New CanvasItem shader for anchor capture feedback.
- Use `capture_direction` and `capture_amount` uniforms.
- Keep all visual energy contained inside the 48x48 tile.
- Keep the effect crisp and lightweight.

### `scripts/level_manager.gd`

- Preload the new shader.
- Apply a unique `ShaderMaterial` to each anchor in `_create_anchor_tile()`.
- Revise `play_anchor_capture()` to set and tween shader parameters.
- Remove or stop using old runtime `Line2D` capture effect helpers.
- Preserve `_anchor_nodes`, `_anchor_capture_tweens`, `update_anchor_overlap_visibility()`, and future-preview overlap alpha behavior.
- Do not change parsing, collision priority, grid rules, or level loading.

### Optional: `assets/shaders/anchor_capture_pulse_material.tres`

- Only create this if it helps tune the shader.
- Do not share one mutable material across all anchors unless it is duplicated per anchor at runtime.

---

## Behavior Rules

| Event | Expected behavior |
|-------|-------------------|
| Level loads with `A` tile | Anchor uses `assets/anchor_tile.png` and the capture shader material. |
| Player slides right onto anchor | Capture energy starts from the left side and pulls inward. |
| Player slides left onto anchor | Capture energy starts from the right side and pulls inward. |
| Player slides down onto anchor | Capture energy starts from the top side and pulls inward. |
| Player slides up onto anchor | Capture energy starts from the bottom side and pulls inward. |
| Multiple anchors exist | Only the captured anchor animates. |
| Capture repeats quickly | New capture restarts the shader pulse cleanly. |
| Enemy overlaps anchor | Existing anchor occupied alpha still works. |
| Future preview is held | Anchor overlap visibility remains correct; preview does not trigger capture animation. |
| Level restarts | No stale tweens, materials, or old effect nodes remain. |

---

## Visual Style

Match the established neon grid direction:

| Element | Guidance |
|---------|----------|
| Main color | Existing `assets/anchor_tile.png` palette |
| Capture accent | Cyan / teal / white energy |
| Motion | Directional inward pull, quick tightening pulse |
| Duration | Around 0.20-0.30 seconds |
| Readability | Tile remains a clear 48x48 Anchor Tile |
| Grid precision | Visual displacement must not imply a different collision cell |
| Hazard separation | Avoid red, orange, and warning-yellow as primary colors |
| Portal separation | Avoid large portal rings that make it look like the goal |
| Pixel art | No smoothing, blur, smear, or large UV distortion |

The effect should communicate "caught and stopped" rather than "bounced" or "teleported."

---

## Validation

Run the smallest relevant checks after implementation.

From this project root:

```powershell
py tools/verify_levels.py
py tools/verify_project.py
```

If Godot is available:

```powershell
godot --headless --path . --script res://tools/godot_smoke_test.gd
```

If `godot` is not on PATH, try:

```powershell
godot4 --headless --path . --script res://tools/godot_smoke_test.gd
```

If neither command is available, inspect `.godot/editor/project_metadata.cfg` for the editor binary path and report that runtime validation was skipped if it still cannot be run.

Manual visual checks:

1. Open a level that contains an Anchor Tile, such as the spike-warning anchor level.
2. Slide onto an anchor from at least two directions.
3. Confirm the capture pulse begins from the incoming side and collapses inward.
4. Confirm the player still lands on the anchor tile and stops.
5. Confirm tick count and move count still advance exactly once for the accepted slide input.
6. Confirm enemies overlapping anchors still dim the anchor as before.
7. Hold future preview and confirm anchors do not accidentally play capture effects.
8. Restart the level and confirm the anchor shader still works with no stale visual nodes.

---

## Acceptance Criteria

- [ ] Anchor Tile still uses `assets/anchor_tile.png` as its base texture.
- [ ] A CanvasItem `.gdshader` drives the capture effect.
- [ ] The shader is applied only to Anchor Tile sprites.
- [ ] Each Anchor Tile has independent material state.
- [ ] The capture effect uses the incoming slide direction.
- [ ] Only the captured anchor animates when multiple anchors exist.
- [ ] The old runtime `Line2D` / `Node2D` capture burst is removed or no longer called.
- [ ] Anchor movement behavior is unchanged: the player stops and lands on the anchor tile.
- [ ] One accepted anchor slide still advances tick and move count exactly once.
- [ ] Collision priority remains unchanged.
- [ ] Enemy-overlap and future-preview anchor alpha behavior remain correct.
- [ ] Restarting or loading another level does not leave stale anchor tweens, materials, or effect nodes.
- [ ] No `.import`, `.uid`, or `.godot/` files are manually edited.
- [ ] `py tools/verify_levels.py` passes.
- [ ] `py tools/verify_project.py` passes.
- [ ] If available, Godot headless smoke test passes.

---

## Task ID Reference

This is a narrow visual-polish slice related to:

| Task ID | Title | Current Status | Note |
|---------|-------|----------------|------|
| SPACE-01 | Anchor Tile | Done | Preserve existing anchor behavior. |
| SPACE-06 | Tile Collision Priority Rules | Done | Do not reorder collision behavior. |
| SPACE-07 | Puzzle Loop Support | Done | Preserve anchor timing-control role. |
| FEEL-02 | Screen Shake / Impact | Done | This shader effect is local anchor feedback, not a global camera shake change. |
| ART-01 | Final Tile Visual Set | Cut / Deferred | Do not mark Done for this shader-only slice unless the user expands scope. |

Leave a `TODO: ART-01` only if deferring broader final tile art work in a touched implementation file. Do not add a TODO if the shader slice is fully implemented.

---

## Suggested Commit Message

```text
Add anchor capture shader prompt
```
