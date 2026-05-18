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
COIN_GATE = "K"
COIN = "C"
LASER = "L"
SPIKE = "S"
ENEMY = "E"
ANCHOR = "A"
GOAL = "G"
BLOCK_H = "-"
BLOCK_V = "|"
SPECIAL_TILES = {ANCHOR, GATE, COIN_GATE, COIN, LASER, SPIKE, ENEMY, BLOCK_H, BLOCK_V}

DEFAULT_ENEMY_PATH = ((0, 0), (1, 0), (1, 1), (0, 1))
CUSTOM_ENEMY_PATHS = {
    6: {
        (6, 3): ((0, 0), (-1, 0), (0, 0), (0, 1)),
    },
    8: {
        (2, 5): ((0, 0), (0, -1), (0, -2), (0, -3)),
    },
    9: {
        (8, 6): ((0, 0), (-1, 0), (0, 0), (0, -1)),
    },
    12: {
        (7, 2): ((0, 0), (0, -1), (1, -1), (0, -1)),
    },
    16: {
        (5, 2): ((0, 0), (1, 0), (2, 0), (1, 0)),
    },
    20: {
        (3, 4): ((0, 0), (0, -1), (0, 0), (1, 0)),
    },
    23: {
        (6, 3): ((0, 0), (1, 0), (1, 1), (0, 1)),
    },
    24: {
        (6, 3): ((0, 0), (1, 0), (1, 1), (0, 1)),
    },
}


@dataclass(frozen=True)
class Level:
    name: str
    rows: tuple[str, ...]
    start: tuple[int, int]
    goal: tuple[int, int]
    lasers: tuple[tuple[int, int], ...]
    spikes: tuple[tuple[int, int], ...]
    enemies: tuple[tuple[int, int], ...]
    coins: tuple[tuple[int, int], ...]

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
    coins: list[tuple[int, int]] = []

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
            elif symbol == COIN:
                coins.append((x, y))

    if start is None:
        raise ValueError(f"{path.name} has no player start")
    if goal is None:
        raise ValueError(f"{path.name} has no goal")

    return Level(path.name, rows, start, goal, tuple(lasers), tuple(spikes), tuple(enemies), tuple(coins))


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


def level_number(level: Level) -> int:
    return int(level.name.removeprefix("level_").removesuffix(".txt"))


def enemy_path(level: Level, enemy: tuple[int, int]) -> tuple[tuple[int, int], ...]:
    return CUSTOM_ENEMY_PATHS.get(level_number(level), {}).get(enemy, DEFAULT_ENEMY_PATH)


def enemy_positions(level: Level, tick: int) -> set[tuple[int, int]]:
    positions = set()
    for x, y in level.enemies:
        offsets = enemy_path(level, (x, y))
        phase = tick % len(offsets)
        ox, oy = offsets[phase]
        positions.add((x + ox, y + oy))
    return positions


def laser_active(tick: int) -> bool:
    return tick % 2 == 1


def is_solid_for_laser(level: Level, pos: tuple[int, int], tick: int) -> bool:
    symbol = tile(level, pos)
    if symbol == WALL:
        return True
    if symbol == GATE:
        return not gate_open(tick)
    if symbol == COIN_GATE:
        return True
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


def is_blocked(
    level: Level,
    pos: tuple[int, int],
    direction: tuple[int, int],
    tick: int,
    collected: frozenset[tuple[int, int]],
) -> bool:
    symbol = tile(level, pos)
    if symbol == WALL:
        return True
    if symbol == GATE:
        return not gate_open(tick)
    if symbol == COIN_GATE:
        return len(collected) < len(level.coins)
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


def slide(
    level: Level,
    start: tuple[int, int],
    direction: tuple[int, int],
    tick: int,
    collected: frozenset[tuple[int, int]],
) -> tuple[tuple[int, int], frozenset[tuple[int, int]], bool, bool]:
    x, y = start
    dx, dy = direction
    current = start
    enemy_tick = tick + 1
    coins = set(collected)
    moved = False

    while True:
        next_pos = (x + dx, y + dy)
        if is_blocked(level, next_pos, direction, tick, frozenset(coins)):
            return current, frozenset(coins), False, moved

        current = next_pos
        x, y = current
        moved = True
        if tile(level, current) == COIN:
            coins.add(current)

        if is_enemy_deadly(level, current, enemy_tick):
            return current, frozenset(coins), False, moved
        if tile(level, current) == GOAL:
            return current, frozenset(coins), True, moved
        if tile(level, current) == ANCHOR:
            return current, frozenset(coins), False, moved


def solve(level: Level, max_moves: int = 80) -> str | None:
    period = lcm(2, 3, 4)
    queue = deque([(level.start, 0, frozenset(), "")])
    seen = {(level.start, 0, frozenset())}

    while queue:
        pos, tick, collected, path = queue.popleft()
        if len(path) >= max_moves:
            continue

        for move, direction in DIRECTIONS.items():
            next_cell = (pos[0] + direction[0], pos[1] + direction[1])
            if is_static_blocked_before_tick(level, next_cell, direction):
                continue

            next_tick = tick + 1
            final_pos, next_collected, won, moved = slide(level, pos, direction, tick, collected)
            if not moved:
                continue
            next_path = path + move
            if won:
                return next_path
            if is_enemy_deadly(level, final_pos, next_tick):
                continue
            if is_deadly_on_stop(level, final_pos, next_tick) or is_laser_deadly(
                level, final_pos, next_tick
            ):
                continue

            state = (final_pos, next_tick % period, next_collected)
            if state not in seen:
                seen.add(state)
                queue.append((final_pos, next_tick, next_collected, next_path))

    return None

def trace_solution_cells(level: Level, solution: str) -> set[tuple[int, int]]:
    visited = {level.start}
    pos = level.start
    tick = 0
    collected: frozenset[tuple[int, int]] = frozenset()

    for move in solution:
        direction = DIRECTIONS[move]
        enemy_tick = tick + 1
        x, y = pos
        current_coins = set(collected)

        while True:
            next_pos = (x + direction[0], y + direction[1])
            if is_blocked(level, next_pos, direction, tick, frozenset(current_coins)):
                break

            pos = next_pos
            x, y = pos
            visited.add(pos)
            if tile(level, pos) == COIN:
                current_coins.add(pos)

            if (
                is_enemy_deadly(level, pos, enemy_tick)
                or tile(level, pos) == GOAL
                or tile(level, pos) == ANCHOR
            ):
                break

        collected = frozenset(current_coins)
        tick += 1

    return visited


def verify_enemy_paths(level: Level) -> list[str]:
    failures = []
    for enemy in level.enemies:
        for ox, oy in enemy_path(level, enemy):
            pos = (enemy[0] + ox, enemy[1] + oy)
            if tile(level, pos) == WALL:
                failures.append(f"{enemy}->{pos} hits wall")
    return failures


def unused_special_tiles(level: Level, visited: set[tuple[int, int]]) -> list[tuple[tuple[int, int], str]]:
    unused = []
    for y, row in enumerate(level.rows):
        for x, symbol in enumerate(row):
            if symbol in SPECIAL_TILES and (x, y) not in visited:
                unused.append(((x, y), symbol))
    return unused


def coin_gate_route_failures(level: Level, visited: set[tuple[int, int]]) -> list[str]:
    if level_number(level) < 13 or not level.coins:
        return []

    failures = []
    missed_coins = [coin for coin in level.coins if coin not in visited]
    if missed_coins:
        failures.append(f"missed coins {missed_coins}")

    used_gate = any(tile(level, pos) == COIN_GATE for pos in visited)
    if not used_gate:
        failures.append("did not pass through a coin gate")
    return failures


def main() -> int:
    failures = []
    expected_total = 24
    paths = sorted(LEVEL_DIR.glob("level_*.txt"), key=lambda item: int(item.stem.split("_")[1]))
    if len(paths) != expected_total:
        failures.append("level count")
        print(f"FAIL level count: expected {expected_total}, found {len(paths)}")

    seen_layouts = set()
    for path in paths:
        level = load_level(path)
        if level.rows in seen_layouts:
            failures.append(level.name)
            print(f"FAIL {level.name}: duplicate level layout")
            continue
        seen_layouts.add(level.rows)

        enemy_path_failures = verify_enemy_paths(level)
        if enemy_path_failures:
            failures.append(level.name)
            print(f"FAIL {level.name}: enemy path crosses wall: {enemy_path_failures}")
            continue

        if level_number(level) >= 13 and len(level.coins) > 3:
            failures.append(level.name)
            print(f"FAIL {level.name}: has {len(level.coins)} coins, expected max 3")
            continue

        solution = solve(level)
        if solution is None:
            failures.append(level.name)
            print(f"FAIL {level.name}: no solution found")
        else:
            solution_length = len(solution)
            visited = trace_solution_cells(level, solution)
            route_failures = coin_gate_route_failures(level, visited)
            if route_failures:
                failures.append(level.name)
                print(f"FAIL {level.name}: coin-gate route incomplete: {route_failures}")
                continue
            unused = unused_special_tiles(level, visited)
            if unused:
                print(f"WARN {level.name}: unused special tiles in shortest route: {unused}")
            else:
                print(f"OK   {level.name}: {solution_length} moves, solution={solution}")
                continue
            print(f"OK   {level.name}: {solution_length} moves, solution={solution}")

    if failures:
        print("\nUnsolvable levels: " + ", ".join(failures))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
