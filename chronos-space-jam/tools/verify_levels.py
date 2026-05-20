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
BOUNCE = "O"
BLOCK_H = "-"
BLOCK_V = "|"
SPECIAL_TILES = {ANCHOR, GATE, COIN_GATE, COIN, LASER, SPIKE, ENEMY, BOUNCE, BLOCK_H, BLOCK_V}
ENEMY_PATH_PREFIX = "@enemy_path"
START_TICK_PREFIX = "@start_tick"
MEDAL_TARGETS_PREFIX = "@medal_targets"
PHASE_GOAL_PREFIX = "@phase_goal"
DEFAULT_ENEMY_PATH = ((0, 0), (1, 0), (1, 1), (0, 1))


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
    enemy_paths: tuple[tuple[tuple[int, int], ...], ...]
    start_tick: int
    phase_goal_period: int
    phase_goal_active: frozenset[int]

    @property
    def width(self) -> int:
        return max(len(row) for row in self.rows)

    @property
    def height(self) -> int:
        return len(self.rows)


def parse_enemy_path_line(line: str) -> tuple[tuple[int, int], ...]:
    payload = line[len(ENEMY_PATH_PREFIX) :].strip()
    offsets: list[tuple[int, int]] = []
    for part in payload.split(";"):
        trimmed = part.strip()
        if not trimmed:
            continue
        x_text, y_text = trimmed.split(",", 1)
        offsets.append((int(x_text), int(y_text)))
    return tuple(offsets) if offsets else DEFAULT_ENEMY_PATH


def parse_phase_goal_line(line: str) -> tuple[int, frozenset[int]]:
    payload = line[len(PHASE_GOAL_PREFIX) :].strip()
    period = 0
    active: set[int] = set()
    for token in payload.split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        if key == "period":
            period = int(value)
        elif key == "active":
            active.update(int(part.strip()) for part in value.split(",") if part.strip())
    return period, frozenset(active)


def load_level(path: Path) -> Level:
    raw_lines = [line.strip() for line in path.read_text().splitlines() if line.strip()]
    rows = tuple(
        line
        for line in raw_lines
        if not line.startswith(ENEMY_PATH_PREFIX)
        and not line.startswith(START_TICK_PREFIX)
        and not line.startswith(MEDAL_TARGETS_PREFIX)
        and not line.startswith(PHASE_GOAL_PREFIX)
    )
    parsed_paths = tuple(
        parse_enemy_path_line(line) for line in raw_lines if line.startswith(ENEMY_PATH_PREFIX)
    )
    start_tick = 0
    phase_goal_period = 0
    phase_goal_active: frozenset[int] = frozenset()
    for line in raw_lines:
        if line.startswith(START_TICK_PREFIX):
            _, value = line.split("=", 1)
            start_tick = int(value.strip())
        elif line.startswith(PHASE_GOAL_PREFIX):
            phase_goal_period, phase_goal_active = parse_phase_goal_line(line)

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

    enemy_paths = list(parsed_paths)
    if not enemy_paths:
        enemy_paths = [DEFAULT_ENEMY_PATH] * len(enemies)
    elif len(enemy_paths) < len(enemies):
        enemy_paths.extend([DEFAULT_ENEMY_PATH] * (len(enemies) - len(enemy_paths)))

    return Level(
        path.name,
        rows,
        start,
        goal,
        tuple(lasers),
        tuple(spikes),
        tuple(enemies),
        tuple(coins),
        tuple(enemy_paths),
        start_tick,
        phase_goal_period,
        phase_goal_active,
    )


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


def normalized_phase(tick: int, period: int) -> int:
    if period <= 0:
        return 0
    return tick % period


def goal_active(level: Level, tick: int) -> bool:
    if level.phase_goal_period <= 0 or not level.phase_goal_active:
        return True
    return normalized_phase(tick, level.phase_goal_period) in level.phase_goal_active


def enemy_positions(level: Level, tick: int) -> set[tuple[int, int]]:
    positions: set[tuple[int, int]] = set()
    for (spawn_x, spawn_y), path in zip(level.enemies, level.enemy_paths, strict=True):
        phase = tick % len(path)
        ox, oy = path[phase]
        positions.add((spawn_x + ox, spawn_y + oy))
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
    return pos in laser_cells(level, tick)


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
    coins = set(collected)
    moved = False

    while True:
        next_pos = (x + dx, y + dy)
        if is_blocked(level, next_pos, direction, tick, frozenset(coins)):
            return current, frozenset(coins), False, moved

        previous = current
        current = next_pos
        x, y = current
        moved = True
        if tile(level, current) == COIN:
            coins.add(current)

        if is_enemy_deadly(level, current, tick) or is_laser_deadly(level, current, tick):
            return current, frozenset(coins), False, moved
        if tile(level, current) == GOAL and goal_active(level, tick):
            return current, frozenset(coins), True, moved
        if tile(level, current) == ANCHOR:
            return current, frozenset(coins), False, moved
        if tile(level, current) == BOUNCE:
            bounce_destination = (current[0] - dx * 2, current[1] - dy * 2)
            if is_blocked(level, bounce_destination, direction, tick, frozenset(coins)):
                bounce_destination = previous
            return bounce_destination, frozenset(coins), False, moved


def solve(level: Level, max_moves: int = 80) -> str | None:
    enemy_periods = [len(path) for path in level.enemy_paths] or [len(DEFAULT_ENEMY_PATH)]
    phase_goal_periods = [level.phase_goal_period] if level.phase_goal_period > 0 else []
    period = lcm(2, 3, *enemy_periods, *phase_goal_periods)
    queue = deque([(level.start, level.start_tick, frozenset(), "")])
    seen = {(level.start, level.start_tick % period, frozenset())}

    while queue:
        pos, tick, collected, path = queue.popleft()
        if len(path) >= max_moves:
            continue

        for move, direction in DIRECTIONS.items():
            next_cell = (pos[0] + direction[0], pos[1] + direction[1])
            if is_static_blocked_before_tick(level, next_cell, direction):
                continue

            next_tick = tick + 1
            final_pos, next_collected, won, moved = slide(level, pos, direction, next_tick, collected)
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
    tick = level.start_tick
    collected: frozenset[tuple[int, int]] = frozenset()

    for move in solution:
        direction = DIRECTIONS[move]
        move_tick = tick + 1
        x, y = pos
        current_coins = set(collected)

        while True:
            next_pos = (x + direction[0], y + direction[1])
            if is_blocked(level, next_pos, direction, move_tick, frozenset(current_coins)):
                break

            previous = pos
            pos = next_pos
            x, y = pos
            visited.add(pos)
            if tile(level, pos) == COIN:
                current_coins.add(pos)

            if (
                is_enemy_deadly(level, pos, move_tick)
                or is_laser_deadly(level, pos, move_tick)
                or (tile(level, pos) == GOAL and goal_active(level, move_tick))
                or tile(level, pos) == ANCHOR
            ):
                break
            if tile(level, pos) == BOUNCE:
                bounce_destination = (pos[0] - direction[0] * 2, pos[1] - direction[1] * 2)
                if is_blocked(level, bounce_destination, direction, move_tick, frozenset(current_coins)):
                    bounce_destination = previous
                pos = bounce_destination
                visited.add(pos)
                break

        collected = frozenset(current_coins)
        tick += 1

    return visited


def verify_enemy_paths(level: Level) -> list[str]:
    failures = []
    for enemy, path in zip(level.enemies, level.enemy_paths, strict=True):
        for ox, oy in path:
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
    level_number = int(level.name.removeprefix("level_").removesuffix(".txt"))
    if level_number < 13 or not level.coins:
        return []

    failures = []
    missed_coins = [coin for coin in level.coins if coin not in visited]
    if missed_coins:
        failures.append(f"missed coins {missed_coins}")

    used_gate = any(tile(level, pos) == COIN_GATE for pos in visited)
    if not used_gate:
        failures.append("did not pass through a coin gate")
    return failures


def bounce_route_failures(level: Level, visited: set[tuple[int, int]]) -> list[str]:
    bounces = [
        (x, y)
        for y, row in enumerate(level.rows)
        for x, symbol in enumerate(row)
        if symbol == BOUNCE
    ]
    if bounces and not any(pos in visited for pos in bounces):
        return [f"route did not touch any bounce tile from {bounces}"]
    return []


def phase_goal_failures(level: Level) -> list[str]:
    if level.phase_goal_period <= 0 and not level.phase_goal_active:
        return []
    failures = []
    if level.phase_goal_period <= 0:
        failures.append("phase goal period must be positive")
    if not level.phase_goal_active:
        failures.append("phase goal active phases are empty")
    invalid = sorted(phase for phase in level.phase_goal_active if phase < 0 or phase >= level.phase_goal_period)
    if invalid:
        failures.append(f"phase goal active phases out of range: {invalid}")
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

        phase_failures = phase_goal_failures(level)
        if phase_failures:
            failures.append(level.name)
            print(f"FAIL {level.name}: invalid phase goal config: {phase_failures}")
            continue

        level_number = int(level.name.removeprefix("level_").removesuffix(".txt"))
        if level_number >= 13 and len(level.coins) > 3:
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
            bounce_failures = bounce_route_failures(level, visited)
            if bounce_failures:
                failures.append(level.name)
                print(f"FAIL {level.name}: bounce route incomplete: {bounce_failures}")
                continue
            if level_number == 4 and solution != "RDR":
                failures.append(level.name)
                print(f"FAIL {level.name}: expected laser tutorial route RDR, got {solution}")
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
