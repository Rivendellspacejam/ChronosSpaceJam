# Chrono Slide — Task Breakdown

- **Project:** Chrono Slide
- **Engine / Tech Target:** Godot engine
- **Art Direction:** Minimalist neon grid / readable top-down puzzle tiles
- **Last Updated:** 2026-05-16
- **GDD Reference:** `GDD Chrono.md` (v0.1)
- **Game Jam Duration:** 14–21 Mei
- **Team Size:** 4 People

> **MVP Scope:** Gravity sliding, wall collision, goal tile, restart, global tick system, Time Gate, one phase-based hazard, at least 5 playable levels, and basic UI showing tick / gravity / move count.

> **Recommended Full Gamejam Scope:** 8 levels total, Time Gate, Laser, Spike, Enemy Patrol, Anchor Tile, Gravity Blocker, simple menu, level select, SFX placeholders, music loop, death / clear feedback, itch.io submission assets.

> **Legend — Effort:** XS < 2 h · S < 1 d · M 1–2 d · L 2–3 d · XL risky for 1-week jam  
> **Legend — Priority:** Critical > High > Medium > Low  
> **Legend — Status:** Not Started > In Progress > Done > Cut / Deferred  
> **⚠️** = GDD ambiguity / implementation decision needed

---

## Team Role Split

| Role | Suggested Owner | Main Responsibility | Secondary Responsibility |
|------|-----------------|---------------------|--------------------------|
| Programmer 1 — Core Systems | Member A | Player sliding, collision, tick manager, game state, level loading | Debug tools and integration support |
| Programmer 2 — Gameplay Objects | Member B | Time Gate, Laser, Spike, Enemy Patrol, Gravity Blocker, Anchor Tile | Phase pattern editor / data setup |
| Designer / Level Designer | Member C | Level layout, tutorial progression, balancing, move count targets | Playtesting and puzzle documentation |
| Artist / UI / Audio / Publishing | Member D | Tile readability, HUD, menu, SFX/music integration, itch.io page | Screenshots, trailer clips, final build packaging |

> If all members are programmers, keep this split by feature ownership so merge conflicts stay small and everyone has a clear domain.

---

## Phase 0 — Foundation & Project Setup

| Task ID | Title | Category | Priority | Status | Dependencies | Assignee | Effort | Acceptance Criteria |
|---------|-------|----------|----------|--------|--------------|----------|--------|---------------------|
| FOUND-01 | Project Scaffold | Core Systems | Critical | Done | — | Programmer 1 | S | • Project opens/runs in browser or chosen engine; • folder structure for scripts, levels, assets, audio, and UI exists; • README or run instructions added |
| FOUND-02 | Grid Coordinate System | Core Systems | Critical | Done | FOUND-01 | Programmer 1 | S | • Level uses grid/tile coordinates; • conversion between grid position and screen position works; • tile size is configurable in one place |
| FOUND-03 | Level Data Format | Level System | Critical | Done | FOUND-02 | Programmer 1, Designer | M | • Level can be represented as text grid or JSON; • supports symbols for wall, empty, player, goal, hazard, gate, anchor, blocker, enemy; • at least one test level loads from data |
| FOUND-04 | Basic Render Layer | Visual | Critical | Done | FOUND-03 | Artist / UI / Audio | S | • Wall, floor, player, and goal render clearly; • visual scale fits small puzzle arenas; • colors are readable without final art |
| FOUND-05 | Input Handling | Core Systems | Critical | Done | FOUND-01 | Programmer 1 | S | • W/A/S/D accepted as directional input; • R restarts current level; • Esc opens or reserves pause behavior; • input ignored during sliding/death/clear state |
| FOUND-06 | Game State Machine | Core Systems | Critical | Done | FOUND-05 | Programmer 1 | S | • States exist for Menu, Playing, Sliding, Dead, LevelClear, Paused; • transitions are predictable; • no input causes double movement during state transition |
| FOUND-07 | Debug Overlay | Debug / QA | Medium | Done | FOUND-02 | Programmer 1 | XS | • Shows current level, player grid position, tick count, and state; • can be hidden for final build |

---

## Phase 1 — Core Loop / Vertical Slice

| Task ID | Title | Category | Priority | Status | Dependencies | Assignee | Effort | Acceptance Criteria |
|---------|-------|----------|----------|--------|--------------|----------|--------|---------------------|
| CORE-01 | Player Gravity Sliding | Player | Critical | Done | FOUND-02, FOUND-05 | Programmer 1 | M | • Pressing W/A/S/D sets gravity direction; • player slides in a straight line until stopped; • player cannot stop manually mid-slide; • movement is fast but readable |
| CORE-02 | Wall Collision Stop | Collision | Critical | Done | CORE-01 | Programmer 1 | S | • Wall blocks movement; • player stops on the tile before the wall; • player cannot clip outside arena; • boundary walls behave consistently |
| CORE-03 | Goal Tile & Level Clear | Objective | Critical | Done | CORE-01 | Programmer 1 | S | • Player clears level when reaching goal; • clear state prevents extra input; • next level or level select progression can be triggered |
| CORE-04 | Restart Current Level | Core Systems | Critical | Done | FOUND-03, CORE-03 | Programmer 1 | XS | • Pressing R reloads current level instantly; • tick, move count, player position, hazards, and gates reset; • restart works after death and clear |
| CORE-05 | Player Death Rule | Player | Critical | Done | CORE-01 | Programmer 1 | S | • Player dies on active hazard/enemy contact; • death stops movement; • restart prompt appears or R restart works immediately |
| CORE-06 | Sliding Collision Scan | Collision | Critical | Done | CORE-01, CORE-05 | Programmer 1 | M | • Every tile crossed during sliding is checked; • active hazard on path kills player; • goal reached during sliding clears level; • anchor and blocker rules can hook into this scan |
| CORE-07 | Move Count System | Scoring | High | Done | FOUND-05, CORE-01 | Programmer 1 | XS | • Every accepted W/A/S/D input increases move count by 1; • failed/ignored input does not increase move count; • count resets per level |
| CORE-08 | Basic Level Progression | Level System | High | Done | FOUND-03, CORE-03 | Programmer 1 | S | • Game can load Level 1 to next level sequentially; • current level index is tracked; • final level returns to menu or ending screen |
| CORE-09 | First Playable Level | Level Design | Critical | Done | CORE-01, CORE-02, CORE-03 | Designer | S | • Level 1 teaches gravity sliding only; • no traps; • can be cleared in several inputs; • includes visual start and goal clarity |

---

## Phase 2 — Time System & Phase-Based Objects

| Task ID | Title | Category | Priority | Status | Dependencies | Assignee | Effort | Acceptance Criteria |
|---------|-------|----------|----------|--------|--------------|----------|--------|---------------------|
| TIME-01 | Global Tick Manager | Time System | Critical | Done | CORE-01, CORE-07 | Programmer 1 | M | • Every accepted movement input advances tick by 1; • tick starts at 0 on level load; • tick can broadcast update to all phase-based objects |
| TIME-02 | Tick Update Order Implementation | Time System | Critical | Done | TIME-01 | Programmer 1, Programmer 2 | S | • Uses chosen order: Input → Tick Update → World Phase Update → Player Slide; • order is documented in code comments; • no object updates twice per input ⚠️ *If playtest feels too hard, this may be switched to slide-before-update* |
| TIME-03 | Phase Object Interface | Time System | Critical | Done | TIME-01 | Programmer 2 | M | • Time-based objects expose `updatePhase(tick)` or equivalent; • phase uses `tick % phaseCount`; • object-specific patterns can be configured per level |
| TIME-04 | Time Gate | Gameplay Object | Critical | Done | TIME-03, CORE-02 | Programmer 2 | M | • Gate opens/closes based on phase pattern; • closed gate behaves like wall; • open gate can be passed through; • visual state clearly differs between open and closed |
| TIME-05 | Laser Trap | Gameplay Object | High | Done | TIME-03, CORE-06 | Programmer 2 | M | • Laser alternates active/inactive by phase; • active laser kills player when crossed; • inactive laser is safe; • visual clarity supports red active and dim inactive state |
| TIME-06 | Spike Trap | Gameplay Object | High | Done | TIME-03, CORE-06 | Programmer 2 | M | • Spike supports Safe, Warning, Active phases; • only Active kills player; • Warning phase is visually obvious; • pattern can be tuned per level |
| TIME-07 | Enemy Patrol | Gameplay Object | High | Done | TIME-03, CORE-06 | Programmer 2 | M | • Enemy position changes by tick phase; • player dies if crossing or landing on enemy tile; • enemy path can be defined per level; • at least one 4-phase patrol works |
| TIME-08 | Phase Pattern Data | Tools / Data | Medium | Done | TIME-03, TIME-04 | Programmer 2 | S | • Gates, lasers, spikes, and enemies use reusable phase patterns; • designer can edit pattern values without changing core logic; • invalid pattern fails safely |
| TIME-09 | No-Wait Rule Enforcement | Core Systems | Critical | Done | TIME-01 | Programmer 1 | XS | • No wait / skip turn button exists; • tick only advances from valid directional input; • invalid blocked input decision is consistent and documented ⚠️ *Need decide whether pressing into an immediate wall counts as valid movement or ignored input* |

---

## Phase 3 — Space Mechanics & Puzzle Tools

| Task ID | Title | Category | Priority | Status | Dependencies | Assignee | Effort | Acceptance Criteria |
|---------|-------|----------|----------|--------|--------------|----------|--------|---------------------|
| SPACE-01 | Anchor Tile | Space Mechanic | High | Done | CORE-06 | Programmer 2 | S | • Anchor stops player when crossed; • player lands on anchor tile; • anchor creates reliable timing-control spots; • visual is readable as a stop pad |
| SPACE-02 | Gravity Blocker — Basic | Space Mechanic | High | Done | CORE-06 | Programmer 2 | M | • Blocker can stop horizontal or vertical movement; • blocker behaves differently from normal wall; • player understands blocked direction from visual shape |
| SPACE-03 | One-Way Gravity Blocker | Space Mechanic | Medium | Cut / Deferred | SPACE-02 | Programmer 2 | S | • Optional one-way blocker allows entry from allowed side only; • invalid side stops player; • used only if levels need more spatial variety |
| SPACE-04 | Bounce Tile Optional | Space Mechanic | Low | Done | CORE-06 | Programmer 2 | M | • `O` Bounce Tile is parsed, rendered, preview-safe, and validated; • sliding toward it contacts the plate, moves two cells back from the plate, leaves a one-cell gap, and stops; • introduced in levels 16-20 |
| SPACE-05 | Phase Goal Optional | Time + Objective | Low | Done | TIME-03, CORE-03 | Programmer 2 | S | • `@phase_goal period=<n> active=<phases>` metadata gates goal clears; • inactive goals are visually dim and passable; • introduced in levels 21-24 |
| SPACE-06 | Tile Collision Priority Rules | Collision | High | Done | CORE-06, TIME-04, SPACE-01 | Programmer 1, Programmer 2 | S | • Collision order is documented: wall/blocker/closed gate, active hazard/enemy, active goal, anchor, bounce, empty; • edge cases are tested; • tile with multiple elements follows consistent priority |
| SPACE-07 | Puzzle Loop Support | Level Design | High | Done | SPACE-01, TIME-04 | Designer | S | • Levels include loops or anchors to advance tick without feeling unfair; • no-wait rule is accounted for; • at least 2 levels intentionally use timing loops |

---

## Phase 4 — Level Content & Difficulty Progression

| Task ID | Title | Category | Priority | Status | Dependencies | Assignee | Effort | Acceptance Criteria |
|---------|-------|----------|----------|--------|--------------|----------|--------|---------------------|
| LEVEL-01 | Level 1 — First Shift | Level Design | Critical | Done | CORE-09 | Designer | S | • Teaches gravity slide only; • player reaches goal without time objects; • short and low-friction |
| LEVEL-02 | Level 2 — Time Starts Moving | Level Design | Critical | Done | TIME-04 | Designer | S | • Introduces tick counter and simple gate; • gate pattern is readable; • level can be solved without hidden knowledge |
| LEVEL-03 | Level 3 — No Waiting | Level Design | Critical | Done | TIME-04, SPACE-07 | Designer | S | • Demonstrates no-wait rule; • includes small movement loop to adjust timing; • player learns that movement is the only way to advance time |
| LEVEL-04 | Level 4 — Laser Rhythm | Level Design | Critical | Done | TIME-05 | Designer | S | • Introduces laser on/off pattern; • player must cross laser during safe phase; • death teaches timing without feeling random |
| LEVEL-05 | Level 5 — Spike Warning | Level Design | Critical | Done | TIME-06, SPACE-01 | Designer | S | • Introduces 3-phase spike with warning; • anchor tile helps player control timing; • clear visual warning before active phase |
| LEVEL-06 | Level 6 — Patrol Pattern | Level Design | High | Done | TIME-07, TIME-04 | Designer | S | • Introduces enemy patrol; • enemy path is short and readable; • combines patrol with at most one gate |
| LEVEL-07 | Level 7 — Gravity Blocker | Level Design | High | Done | SPACE-02, TIME-04 | Designer | S | • Introduces blocker as spatial constraint; • player must approach from correct gravity direction; • timing remains secondary but present |
| LEVEL-08 | Level 8 — Final Sync | Level Design | High | Done | LEVEL-01, LEVEL-02, LEVEL-03, LEVEL-04, LEVEL-05, LEVEL-06, LEVEL-07 | Designer, All | M | • Combines Time Gate, Laser, Spike, Enemy Patrol, Anchor, and Gravity Blocker; • puzzle is hard but readable; • final level has satisfying clear moment |
| LEVEL-09 | Move Count Targets | Scoring | Medium | Done | LEVEL-01 | Designer | S | • Each level has Bronze clear, Silver target, and Gold target if medals are implemented; • target values are playtested; • best shift data can be shown or stored |
| LEVEL-10 | Level Order & Difficulty Pass | Level Design | High | Done | LEVEL-01, LEVEL-02, LEVEL-03, LEVEL-04, LEVEL-05 | Designer | M | • Mechanics introduced one at a time; • no level requires unexplained behavior; • difficulty curve rises gradually |
| LEVEL-11 | Level Notes / Solutions | Documentation | Medium | Cut / Deferred | LEVEL-01 | Designer | S | • Each level has intended solution notes; • approximate minimum move count written; • known alternative routes documented |

---

## Phase 5 — UI, Feedback & Game Feel

| Task ID | Title | Category | Priority | Status | Dependencies | Assignee | Effort | Acceptance Criteria |
|---------|-------|----------|----------|--------|--------------|----------|--------|---------------------|
| UI-01 | Basic HUD | UI/HUD | Critical | Done | TIME-01, CORE-07 | Artist / UI / Audio | S | • HUD shows Gravity direction, Tick, Current Phase, and Time Shifts; • values update immediately; • readable at gamejam screen sizes |
| UI-02 | Gravity Direction Indicator | UI/HUD | High | Done | CORE-01 | Artist / UI / Audio | S | • Current gravity direction shown as arrow near player or HUD; • direction changes with input; • does not obstruct puzzle readability |
| UI-03 | Phase Visual Feedback | UI/HUD | High | Done | TIME-04, TIME-05, TIME-06 | Artist / UI / Audio | M | • Gate open/closed, laser active/inactive, spike warning/active are visually distinct; • phase changes animate or flash clearly; • player can predict danger state |
| UI-04 | Main Menu | UI/HUD | High | Done | FOUND-01 | Artist / UI / Audio | S | • Start Game button works; • title shown; • control hint visible; • menu fits final visual direction |
| UI-05 | Level Select | UI/HUD | Medium | Done | CORE-08 | Artist / UI / Audio | S | • Player can choose unlocked or all levels depending jam decision; • level buttons are clear; • useful for judges to quickly see content |
| UI-06 | Level Clear Screen | UI/HUD | High | Done | CORE-03, CORE-07 | Artist / UI / Audio | S | • Shows Level Cleared and Time Shifts Used; • shows Best if implemented; • has Next and Restart options |
| UI-07 | Death Feedback | UI/HUD | High | Done | CORE-05 | Artist / UI / Audio | S | • Death has short visual effect; • restart prompt appears quickly; • death-to-restart target is under 1 second |
| UI-08 | Pause Menu | UI/HUD | Medium | Done | FOUND-06 | Artist / UI / Audio | S | • Esc opens pause; • Resume, Restart, Main Menu available; • paused state prevents input/movement |
| UI-09 | Tutorial Text Prompts | Tutorial | Medium | Done | LEVEL-01, UI-01 | Designer, Artist / UI / Audio | S | • Short prompts explain one concept per early level; • no long paragraph blocks; • text can be skipped or ignored after first read |
| UI-11 | Phase Preview UI | UI/HUD | Medium | Done | UI-03, TIME-03, TIME-07, UI-10 | Artist / UI / Audio | M | • Hold P to show a visual-only one-tick future board view when Move Previews enabled; • gates, lasers, spikes, and enemies use normal future-state visuals instead of preview overlays or ghost paths; • player stays at the current position; • preview cue appears only while active; • previews hidden during slide, when P released, paused, dead, clear, or setting off; • brief pulse when phase objects change on tick |
| FEEL-01 | Slide Speed Tuning | Game Feel | High | Done | CORE-01 | Programmer 1, Designer | S | • Slide is fast enough for repeated restart; • movement remains readable; • collision impact feels responsive |
| FEEL-02 | Screen Shake / Impact | Game Feel | Low | Done | CORE-02, CORE-05 | Artist / UI / Audio | XS | • Tiny impact on wall hit/death; • can be disabled if distracting; • not required for MVP |
| FEEL-03 | Tick Pulse Feedback | Game Feel | High | Done | TIME-01 | Artist / UI / Audio | S | • Every tick has small visual or audio pulse; • reinforces time moving; • not visually overwhelming |

---

## Phase 6 — Audio, Visual Polish & Publishing

| Task ID | Title | Category | Priority | Status | Dependencies | Assignee | Effort | Acceptance Criteria |
|---------|-------|----------|----------|--------|--------------|----------|--------|---------------------|
| ART-01 | Final Tile Visual Set | Art | High | Cut / Deferred | FOUND-04 | Artist / UI / Audio | M | • Floor, wall, goal, gate, laser, spike, anchor, blocker, enemy, player have readable sprites/shapes; • color language matches GDD; • assets remain simple enough for jam scope |
| ART-02 | Player Visual Polish | Art | Medium | Cut / Deferred | CORE-01 | Artist / UI / Audio | S | • Player is a bright readable box or orb; • direction/gravity state can be understood; • death/clear state has simple feedback |
| ART-03 | Background / Arena Framing | Art | Medium | Cut / Deferred | FOUND-04 | Artist / UI / Audio | S | • Puzzle arena is visually framed; • background does not hide hazards; • final screenshots look presentable |
| AUDIO-01 | Core SFX Pack | Audio | High | Cut / Deferred | CORE-01, TIME-01 | Artist / UI / Audio | M | • SFX exists for gravity shift, slide, wall hit, tick, gate change, trap change, death, and level clear; • volume balanced; • no harsh clipping |
| AUDIO-02 | Music Loop | Audio | Medium | Cut / Deferred | FOUND-01 | Artist / UI / Audio | S | • Minimal electronic loop plays during gameplay; • loops cleanly; • music does not mask important SFX |
| AUDIO-03 | Menu / Clear Stingers | Audio | Low | Cut / Deferred | UI-04, UI-06 | Artist / UI / Audio | XS | • Short menu/select/clear sounds added; • optional if time is limited |
| PUB-01 | Web Build Export | Publishing | Critical | Cut / Deferred | QA-01 | Programmer 1 | S | • Final build runs in browser; • no missing asset errors; • playable from clean folder/export |
| PUB-02 | Itch.io Page Assets | Publishing | High | Cut / Deferred | ART-01, PUB-01 | Artist / UI / Audio | M | • Cover image, screenshots, short description, controls, and credits prepared; • page clearly communicates Time and Space hook |
| PUB-03 | Credits Screen / Text | Publishing | Medium | Done | UI-04 | Artist / UI / Audio | XS | • Credits list all 4 members and roles; • asset/audio attribution included if external assets are used |
| PUB-04 | Final Game Description | Publishing | Medium | Cut / Deferred | PUB-02 | Designer | XS | • Itch short description includes: shift gravity, advance time, phase-changing traps, reach the goal; • controls are listed clearly |

---

## Phase 7 — QA, Balancing & Submission

| Task ID | Title | Category | Priority | Status | Dependencies | Assignee | Effort | Acceptance Criteria |
|---------|-------|----------|----------|--------|--------------|----------|--------|---------------------|
| QA-01 | MVP End-to-End Test | QA | Critical | Done | CORE-01, TIME-04, LEVEL-01, LEVEL-02, LEVEL-03, LEVEL-04, LEVEL-05 | All | M | • At least 5 levels are playable from start to finish; • restart works; • death works; • clear works; • no crash/blocker bugs |
| QA-02 | Full 8-Level Test | QA | High | Done | LEVEL-08 | All | M | • All 8 levels can be completed; • level order works; • no impossible puzzle unless intentionally marked cut; • judge can reach final level |
| QA-03 | Collision Edge Case Test | QA | High | Done | SPACE-06 | Programmer 1, Programmer 2 | S | • Closed gate stops correctly; • active hazard kills correctly; • anchor stops correctly; • enemy collision works during sliding and landing |
| QA-04 | Readability Test | QA | High | Done | UI-03, ART-01 | Designer, Artist / UI / Audio | S | • New player can tell which hazard is active; • gate open/closed state is obvious; • spike warning is not confused with safe state |
| QA-05 | Difficulty / Frustration Pass | QA | High | Done | LEVEL-10 | Designer, All | M | • Early levels are tutorial-friendly; • no-wait puzzles include timing loops or anchors; • final level is hard but not obscure |
| QA-06 | Browser Compatibility Check | QA | Medium | Cut / Deferred | PUB-01 | Programmer 1 | S | • Build tested in at least Chrome/Edge; • audio starts after user interaction if browser requires it; • fullscreen/window scaling works |
| QA-07 | Performance Pass | QA | Medium | Cut / Deferred | PUB-01 | Programmer 1 | XS | • Game maintains stable frame rate on target laptop/browser; • no heavy memory leak from restarts; • level reload remains fast |
| QA-08 | Submission Checklist | Publishing | Critical | Cut / Deferred | PUB-01, PUB-02, PUB-03 | All | S | • Game uploaded before deadline; • page has controls and screenshots; • build is public or correctly submitted; • final downloadable/web build tested after upload |

---

## 1-Week Production Plan

## Day 1 — Core Prototype

- Finish project scaffold.
- Implement grid level loading.
- Implement player sliding and wall collision.
- Add goal and restart.
- Build Level 1.

## Day 2 — Time Tick System

- Implement global tick manager.
- Confirm tick update order.
- Add HUD tick / move counter.
- Implement Time Gate.
- Build Level 2 and Level 3.

## Day 3 — Trap System

- Implement Laser Trap.
- Implement Spike Trap.
- Add phase visual feedback.
- Build Level 4 and Level 5.

## Day 4 — Space Mechanics

- Implement Anchor Tile.
- Implement Gravity Blocker.
- Polish collision priority rules.
- Build Level 6 and Level 7 if enemy/blocker systems are ready.

## Day 5 — Enemy + Final Level

- Implement Enemy Patrol.
- Build Final Sync level.
- Add level clear screen and level progression.
- Start first full QA pass.

## Day 6 — UI, Art, Audio Polish

- Add main menu and level select.
- Finalize readable visuals.
- Add core SFX and music loop.
- Prepare itch.io assets.

## Day 7 — Testing and Submission

- Playtest all levels.
- Fix blocker bugs only.
- Cut optional features if unstable.
- Export web build.
- Upload and test itch.io page.

---

## Cut Line Priority

If time is tight, protect the playable build in this order:

1. **Must Not Cut:** player sliding, wall collision, goal, restart, tick manager, Time Gate, 5 levels, basic HUD.
2. **Cut Last:** Laser, Spike, Anchor Tile, Gravity Blocker, level clear screen, SFX.
3. **Safe to Cut:** Enemy Patrol, Bounce Tile, Phase Goal, medal system, level select polish, advanced animation.
4. **Do Not Add Unless Stable:** complex rewind, level editor, online leaderboard, large narrative intro, procedural levels.

---

## ⚠️ Top 5 Highest-Risk Items

### Risk 1 — Tick Update Order Confusion

**Why risky:** The GDD recommends Input → Tick Update → World Phase Update → Player Slide. This is thematically strong, but it can feel punishing because hazards change before the player moves.

**Mitigation:**
- Lock the order early and write it clearly in the tutorial.
- Add strong phase preview/feedback so players understand what changed.
- If playtesters consistently feel cheated, switch to Player Slide → Tick Update for easier readability.

---

### Risk 2 — No-Wait Rule Can Make Puzzles Unfair

**Why risky:** Because players cannot skip a tick without moving, a puzzle can become impossible or frustrating if there is no safe way to adjust timing.

**Mitigation:**
- Every timing puzzle should include a loop, wall route, or anchor tile for tick adjustment.
- Designer should write intended solutions for each level.
- Avoid very tight phase windows in early levels.

---

### Risk 3 — Collision During Sliding Has Many Edge Cases

**Why risky:** The player may cross gates, lasers, spikes, enemies, anchors, and goals in one slide. If collision priority is unclear, bugs will feel random.

**Mitigation:**
- Implement a single tile-by-tile collision scan.
- Document priority rules before adding many objects.
- Test each tile type in isolation before combining them.

---

### Risk 4 — Visual Phase Readability

**Why risky:** The whole game depends on players understanding whether a trap or gate is currently safe. If visuals are unclear, the puzzle feels unfair.

**Mitigation:**
- Use high-contrast colors: red active danger, dim inactive, yellow warning, blue/cyan safe/open.
- Add small animation or pulse when phase changes.
- Prioritize readability over decorative art.

---

### Risk 5 — Scope Creep from Optional Mechanics

**Why risky:** Bounce Tile, Phase Goal, medals, enemy patrol, and advanced polish are tempting, but the jam build only needs a clear Time + Space core.

**Mitigation:**
- Finish 5-level MVP before adding optional mechanics.
- Treat Enemy Patrol and Bounce Tile as optional unless the base levels feel complete.
- Use the cut line priority list during Day 5–7.

---

## Minimum Playable Build Definition

The game is considered submit-ready if it has:

- 5 playable levels.
- Player slides with W/A/S/D.
- Every accepted input advances tick by 1.
- Time Gate changes based on tick/phase.
- At least one phase-based hazard.
- Player can die and restart quickly.
- Player can reach goal and continue to next level.
- HUD displays tick, gravity direction, and move count.
- Web build runs successfully after upload.

---

## Final Delivery Checklist

| Item | Required? | Owner | Status |
|------|-----------|-------|--------|
| Web playable build | Yes | Programmer 1 | Cut / Deferred |
| 5 MVP levels | Yes | Designer | Done |
| 8 full gamejam levels | Recommended | Designer | Done |
| Basic HUD | Yes | Artist / UI / Audio | Done |
| SFX | Recommended | Artist / UI / Audio | Cut / Deferred |
| Music loop | Recommended | Artist / UI / Audio | Cut / Deferred |
| Itch.io cover image | Recommended | Artist / UI / Audio | Cut / Deferred |
| Screenshots | Yes | Artist / UI / Audio | Cut / Deferred |
| Controls text | Yes | Designer | Cut / Deferred |
| Credits / attribution | Yes | All | Done |

