# ChronosSpaceJam

Godot project for **Chrono Slide**, a top-down spacetime sliding puzzle.

## Play

Open `chronos-space-jam/project.godot` in Godot 4.6, then run the project.

Flow:
- Main menu
- Story intro
- 12 puzzle chambers
- Ending scene

Controls:
- `W/A/S/D`: shift gravity and slide
- `R`: restart chamber
- `Esc`: pause
- `Enter`: continue after clear/dialogue

## Verification

From this folder:

```powershell
py chronos-space-jam/tools/verify_levels.py
py chronos-space-jam/tools/verify_project.py
```

`verify_levels.py` checks every chamber has a solution and that the minimum solution length does not drop as levels progress.
`verify_project.py` checks level/story counts, key scene flow, and resource paths.

If Godot is available from a terminal, run the scene smoke test too:

```powershell
godot --headless --path chronos-space-jam --script res://tools/godot_smoke_test.gd
```
