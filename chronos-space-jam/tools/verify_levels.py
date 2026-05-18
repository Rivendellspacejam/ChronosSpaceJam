from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from math import lcm
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LEVEL_DIR = ROOT / "levels"

DIRECTIONS = {
    "U": (0, -1),
    "D": (0, 1),
    "L": (-1, 0),
    "R": (1, 0),
}

WALL = "#"
GATE = "T"
LASER = "L"
SPIKE = "S"
ENEMY = "E"
ANCHOR = "A"
GOAL = "G"
BLOCK_H = "-"
BLOCK_V = "|"
SPECIAL_TILES = {ANCHOR, GATE, LASER, SPIKE, ENEMY, BLOCK_H, BLOCK_V}


@dataclass(frozen=True)
class Level:
    name: str
    rows: tuple[str, ...]
    start: tuple[int, int]
    goal: tuple[int, int]
    lasers: tuple[tuple[int, int], ...]
    spikes: tuple[tuple[int, int], ...]
    enemies: tuple[tuple[int, int], ...]

    @property
    def width(self) -> int:
        return max(len(row) for row in self.rows)

    @property
    def height(self) -> int:
        return len(self.rows)


def load_level(path: Path) -> Level:
    rows = tuple(line.strip() for line in path.read_text().splitlines() if line.strip())
    start = None
    goal = None
    lasers: list[tuple[int, int]] = []
    spikes: list[tuple[int, int]] = []
    enemies: list[tuple[int, int]] = []

    for y, row in enumerate(rows):
        for x, symbol in enumerate(row):
            if symbol == "P":
                start = (x, y)
            elif symbol == GOAL:
                goal = (x, y)
            elif symbol == LASER:
                lasers.append((x, y))
            elif symbol == SPIKE:
                spikes.append((x, y))
            elif symbol == ENEMY:
                enemies.append((x, y))

    if start is None:
        raise ValueError(f"{path.name} has no player start")
    if goal is None:
        raise ValueError(f"{path.name} has no goal")

    return Level(path.name, rows, start, goal, tuple(lasers), tuple(spikes), tuple(enemies))


def tile(level: Level, pos: tuple[int, int]) -> str:
    x, y = pos
    if x < 0 or y < 0 or y >= level.height or x >= level.width:
        return WALL
    row = level.rows[y]
    if x >= len(row):
        return WALL
    return row[x]


def is_static_blocked_before_tick(level: Level, pos: tuple[int, int], direction: tuple[int, int]) -> bool:
    symbol = tile(level, pos)
    if symbol == WALL:
        return True
    if symbol == BLOCK_H:
        return direction[0] != 0
    if symbol == BLOCK_V:
        return direction[1] != 0
    return False


def gate_open(tick: int) -> bool:
    return tick % 2 == 1


def spike_active(tick: int) -> bool:
    return tick % 3 == 2


def enemy_positions(level: Level, tick: int) -> set[tuple[int, int]]:
    offsets = ((0, 0), (1, 0), (1, 1), (0, 1))
    phase = tick % len(offsets)
    ox, oy = offsets[phase]
    return {(x + ox, y + oy) for x, y in level.enemies}


def laser_active(tick: int) -> bool:
    return tick % 2 == 1


def is_solid_for_laser(level: Level, pos: tuple[int, int], tick: int) -> bool:
    symbol = tile(level, pos)
    if symbol == WALL:
        return True
    if symbol == GATE:
        return not gate_open(tick)
    return False


def laser_cells(level: Level, tick: int) -> set[tuple[int, int]]:
    if not laser_active(tick):
        return set()

    cells: set[tuple[int, int]] = set()
    for laser in level.lasers:
        cells.add(laser)
        for direction in ((1, 0), (-1, 0)):
            x, y = laser
            dx, dy = direction
            probe = (x + dx, y + dy)
            while not is_solid_for_laser(level, probe, tick):
                cells.add(probe)
                probe = (probe[0] + dx, probe[1] + dy)
    return cells


def is_blocked(level: Level, pos: tuple[int, int], direction: tuple[int, int], tick: int) -> bool:
    symbol = tile(level, pos)
    if symbol == WALL:
        return True
    if symbol == GATE:
        return not gate_open(tick)
    if symbol == BLOCK_H:
        return direction[0] != 0
    if symbol == BLOCK_V:
        return direction[1] != 0
    return False


def is_enemy_deadly(level: Level, pos: tuple[int, int], tick: int) -> bool:
    return pos in enemy_positions(level, tick)


def is_laser_deadly(level: Level, pos: tuple[int, int], tick: int) -> bool:
    return tile(level, pos) != LASER and pos in laser_cells(level, tick)


def is_deadly_on_stop(level: Level, pos: tuple[int, int], tick: int) -> bool:
    return tile(level, pos) == SPIKE and spike_active(tick)


def slide(level: Level, start: tuple[int, int], direction: tuple[int, int], tick: int) -> tuple[tuple[int, int], bool]:
    x, y = start
    dx, dy = direction
    current = start
    enemy_tick = tick + 1

    while True:
        next_pos = (x + dx, y + dy)
        if is_blocked(level, next_pos, direction, tick):
            return current, False

        current = next_pos
        x, y = current

        if is_enemy_deadly(level, current, enemy_tick):
            return current, False
        if tile(level, current) == GOAL:
            return current, True
        if tile(level, current) == ANCHOR:
            return current, False


def solve(level: Level, max_moves: int = 80) -> str | None:
    period = lcm(2, 3, 4)
    queue = deque([(level.start, 0, "")])
    seen = {(level.start, 0)}

    while queue:
        pos, tick, path = queue.popleft()
        if len(path) >= max_moves:
            continue

        for move, direction in DIRECTIONS.items():
            next_cell = (pos[0] + direction[0], pos[1] + direction[1])
            if is_static_blocked_before_tick(level, next_cell, direction):
                continue

            next_tick = tick + 1
            final_pos, won = slide(level, pos, direction, tick)
            next_path = path + move
            if won:
                return next_path
            if is_enemy_deadly(level, final_pos, next_tick):
                continue
            if is_deadly_on_stop(level, final_pos, next_tick) or is_laser_deadly(
                level, final_pos, next_tick
            ):
                continue

            state = (final_pos, next_tick % period)
            if state not in seen:
                seen.add(state)
                queue.append((final_pos, next_tick, next_path))

    return None

def trace_solution_cells(level: Level, solution: str) -> set[tuple[int, int]]:
    visited = {level.start}
    pos = level.start
    tick = 0

    for move in solution:
        direction = DIRECTIONS[move]
        enemy_tick = tick + 1
        x, y = pos

        while True:
            next_pos = (x + direction[0], y + direction[1])
            if is_blocked(level, next_pos, direction, tick):
                break

            pos = next_pos
            x, y = pos
            visited.add(pos)

            if (
                is_enemy_deadly(level, pos, enemy_tick)
                or tile(level, pos) == GOAL
                or tile(level, pos) == ANCHOR
            ):
                break

        tick += 1

    return visited


def unused_special_tiles(level: Level, visited: set[tuple[int, int]]) -> list[tuple[tuple[int, int], str]]:
    unused = []
    for y, row in enumerate(level.rows):
        for x, symbol in enumerate(row):
            if symbol in SPECIAL_TILES and (x, y) not in visited:
                unused.append(((x, y), symbol))
    return unused


def main() -> int:
    failures = []
    expected_total = 12
    paths = sorted(LEVEL_DIR.glob("level_*.txt"), key=lambda item: int(item.stem.split("_")[1]))
    if len(paths) != expected_total:
        failures.append("level count")
        print(f"FAIL level count: expected {expected_total}, found {len(paths)}")

    previous_solution_length = 0
    for path in paths:
        level = load_level(path)
        solution = solve(level)
        if solution is None:
            failures.append(level.name)
            print(f"FAIL {level.name}: no solution found")
        else:
            solution_length = len(solution)
            if solution_length < previous_solution_length:
                failures.append(level.name)
                print(
                    f"FAIL {level.name}: difficulty drops from "
                    f"{previous_solution_length} to {solution_length} moves"
                )
            else:
                visited = trace_solution_cells(level, solution)
                unused = unused_special_tiles(level, visited)
                if unused:
                    failures.append(level.name)
                    print(f"FAIL {level.name}: unused special tiles in shortest route: {unused}")
                else:
                    print(f"OK   {level.name}: {solution_length} moves, solution={solution}")
            previous_solution_length = solution_length

    if failures:
        print("\nUnsolvable levels: " + ", ".join(failures))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
