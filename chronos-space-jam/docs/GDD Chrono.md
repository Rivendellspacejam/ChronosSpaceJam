# Chrono Slide — Game Design Document

**Working Title:** Chrono Slide  
**Genre:** Top-Down Puzzle Arcade / Spacetime Sliding Puzzle  
**Platform Target:** PC / Web Build  
**Game Jam Duration:** 14–21 Mei  
**Theme:** Time and Space  
**Team Size:** 4 People  
**Document Version:** v0.2  
**Last Updated:** 18 Mei 2026  
**Implementation Reference:** `docs/TASK_BREAKDOWN.md`

---

## Development Status (Current Phase)

**Current production phase:** **Phase 7 — QA, Balancing & Submission Prep**  
Core gameplay, all planned mechanics, UI flow, and level content are **complete**. Remaining work is **export, itch.io packaging, and optional art/audio polish**.

| Phase | Focus | Status |
| :---- | :---- | :---- |
| 0 — Foundation | Project scaffold, grid, level format, input, game states | **Done** |
| 1 — Core Loop | Sliding, collision, goal, death, move count, progression | **Done** |
| 2 — Time System | Tick manager, phase objects, gate, laser, spike, enemy patrol | **Done** |
| 3 — Space Mechanics | Anchor, gravity blocker, collision priority, puzzle loops | **Done** |
| 4 — Level Content | Tutorial curve + playable chambers | **Done** (12 levels shipped in build) |
| 5 — UI & Feel | HUD, menus, tutorials, death/clear, pause, tick pulse, screen shake | **Done** |
| 6 — Polish & Publishing | Final art, full SFX, web export, itch.io page | **Partial** |
| 7 — QA & Submission | Playthrough, edge cases, readability, upload checklist | **In progress** |

### Playable build snapshot (18 Mei 2026)

- **Engine:** Godot 4.6 (GL Compatibility)  
- **Levels:** 12 (`level_1.txt` … `level_12.txt`) with move-count targets and best-shift tracking  
- **Tick order (locked):** Input → Tick Update → World Phase Update → Player Slide  
- **Phase objects:** Time Gate, Laser (2-phase), Spike (3-phase), Enemy Patrol (configurable path)  
- **Space tiles:** Anchor, horizontal/vertical Gravity Blocker  
- **UI:** Main menu, level select, pause, settings (audio/display/shake), credits, level-clear panel, intro + ending story  
- **Audio (partial):** Menu music loop, UI click/back, slide, tick, death, level-clear SFX  
- **Feedback:** Phase visuals on hazards/gates, tick HUD pulse, enemy next-move preview ghosts, configurable screen shake  
- **Not in build:** Medal tiers, global phase preview HUD, bounce tile, phase-only goal, one-way blocker, level editor, rewind

### Level roster (implemented names)

| # | Name | Primary teaching / focus |
| :---- | :---- | :---- |
| 1 | First Shift | Gravity sliding only |
| 2 | Pulse Door | Tick + Time Gate |
| 3 | No Waiting | No-wait rule + timing loop |
| 4 | Red Silence | Laser rhythm |
| 5 | Warning Teeth | Spike warning + anchor |
| 6 | Patrol Memory | Enemy patrol |
| 7 | Bent Hall | Gravity blocker |
| 8 | Doubt Loop | Combined mechanics (original finale) |
| 9 | Foldback | Extended difficulty |
| 10 | Pressure Route | Extended difficulty |
| 11 | Clock Floor | Extended difficulty |
| 12 | Direction for Time | Final chamber → ending screen |

Levels 9–12 extend the original 8-level gamejam plan; mechanics reuse and combine earlier teachings with larger arenas and tighter move targets.

### Submission blockers (remaining)

- Web/export build verification (`PUB-01`)  
- itch.io page assets, screenshots, and public upload (`PUB-02`, `QA-08`)  
- Optional: final tile art pass, gameplay music loop beyond menu, full trap SFX set (`ART-01`, `AUDIO-01`, `AUDIO-02`)

---

## 1\. High Concept

**Chrono Slide** adalah game puzzle arcade top-down di mana player tidak bergerak secara bebas, melainkan mengubah arah gravitasi dengan tombol **W/A/S/D**. Setiap input membuat player meluncur ke arah gravitasi tersebut dan sekaligus memajukan waktu sebanyak **1 tick**.

Setiap tick membuat musuh, trap, gate, dan obstacle berganti phase sesuai pola masing-masing. Player harus mencapai goal dengan mengatur **arah gravitasi**, **posisi berhenti**, dan **urutan input** agar dapat melewati hazard pada waktu yang tepat.

Inti game ini adalah:

**Space menentukan ke mana player bergerak. Time menentukan kapan dunia berubah.**

---

## 2\. Theme Interpretation: Time and Space

Tema **Time and Space** diterjemahkan langsung ke dalam core gameplay.

### 2.1 Space

Space hadir melalui:

- Arena top-down berbasis grid.  
- Player yang bergerak berdasarkan arah gravitasi.  
- Sliding movement sampai menabrak obstacle.  
- Gravity blocker yang membatasi arah gerak tertentu.  
- Tile khusus yang memengaruhi posisi, jalur, atau kondisi ruang.

### 2.2 Time

Time hadir melalui:

- Setiap input player memajukan waktu sebanyak **1 tick**.  
- Musuh dan trap berganti phase setiap tick.  
- Gate dapat terbuka atau tertutup berdasarkan tick tertentu.  
- Puzzle diselesaikan dengan membaca pola waktu, bukan hanya mencari jalur ruang.

### 2.3 Core Theme Statement

Pemain tidak hanya bergerak di dalam ruang, tetapi juga menggerakkan waktu melalui setiap keputusan arah.

---

## 3\. Core Gameplay Pillars

### 3.1 Gravity-Based Movement

Player tidak berjalan normal. Saat player menekan **W/A/S/D**, gravitasi berpindah ke arah tersebut, lalu player meluncur sampai berhenti karena menabrak obstacle atau tile khusus.

### 3.2 Input-Driven Time

Waktu tidak berjalan otomatis. Waktu hanya bergerak ketika player melakukan input arah.

- Tekan W/A/S/D \= player bergerak \+ time tick maju 1\.  
- Tidak ada tombol wait.  
- Player tidak bisa memajukan waktu tanpa bergerak.

Hal ini membuat setiap input memiliki konsekuensi posisi dan waktu sekaligus.

### 3.3 Pattern-Based Hazard

Enemy, trap, dan gate memiliki phase masing-masing. Setiap kali time tick maju, semua elemen tersebut memperbarui kondisinya.

Contoh:

- Laser menyala pada tick genap dan mati pada tick ganjil.  
- Spike muncul setiap 3 tick.  
- Musuh berpindah posisi mengikuti pola 4 langkah.  
- Gate terbuka hanya pada phase tertentu.

### 3.4 Puzzle Precision

Game menantang player untuk menentukan urutan input terbaik. Kesalahan arah atau timing dapat membuat player terkena trap, terjebak, atau gagal mencapai goal.

---

## 4\. Player Fantasy

Player merasa seperti sedang mengendalikan sebuah objek kecil di dalam ruang eksperimen waktu. Setiap gerakan bukan hanya perpindahan posisi, tetapi juga keputusan yang mengubah kondisi dunia.

Sensasi yang ingin dicapai:

- Tegang karena setiap input berisiko.  
- Puas saat menemukan urutan gerak yang tepat.  
- Cepat dipahami, tetapi menantang untuk dikuasai.  
- Mirip sliding puzzle, tetapi dengan tekanan obstacle ala arcade.

---

## 5\. Core Loop

1. Player mengamati level.  
2. Player membaca posisi goal, obstacle, enemy, trap, dan gate.  
3. Player memilih input W/A/S/D.  
4. Player meluncur ke arah gravitasi.  
5. Time tick maju 1\.  
6. Enemy, trap, dan gate berganti phase.  
7. Player mengevaluasi posisi baru dan phase baru.  
8. Ulangi sampai player mencapai goal atau mati.

---

## 6\. Controls

| Input | Action |
| :---- | :---- |
| W | Set gravity upward / slide upward |
| A | Set gravity left / slide left |
| S | Set gravity downward / slide downward |
| D | Set gravity right / slide right |
| R | Restart level |
| Esc | Pause menu |

### Catatan Penting

Tidak ada tombol untuk menunggu satu tick. Waktu hanya maju jika player melakukan input gerakan.

---

## 7\. Main Mechanics

---

# 7.1 Space Mechanics

## 7.1.1 Gravity Direction

Player dapat mengubah gravitasi ke empat arah:

- Up  
- Down  
- Left  
- Right

Ketika gravitasi berubah, player akan bergerak terus ke arah tersebut sampai bertemu kondisi penghenti.

### Rules

- Input arah selalu mencoba mengubah gravitasi.  
- Jika arah valid, player mulai sliding.  
- Player tidak bisa berhenti di tengah jalan secara manual.  
- Player berhenti saat menabrak wall, blocker, atau tile penghenti.

---

## 7.1.2 Sliding Movement

Player bergerak dalam garis lurus sesuai arah gravitasi.

### Behavior

- Player bergerak dari tile ke tile.  
- Player berhenti saat tile berikutnya tidak dapat dilewati.  
- Jika player melewati hazard aktif, player mati.  
- Jika player masuk goal aktif, level selesai.

---

## 7.1.3 Wall

Wall adalah obstacle dasar yang menghentikan player.

### Function

- Tidak bisa dilewati.  
- Menjadi batas arena.  
- Digunakan untuk membentuk jalur puzzle.

---

## 7.1.4 Gravity Blocker

Gravity Blocker adalah tile yang hanya memblokir player dari arah gravitasi tertentu.

Contoh:

- Blocker horizontal hanya menghentikan gerakan kiri/kanan.  
- Blocker vertical hanya menghentikan gerakan atas/bawah.  
- One-way blocker hanya bisa dilewati dari arah tertentu.

### Design Purpose

Gravity Blocker memperkuat aspek **space** karena player harus memahami hubungan antara arah gravitasi dan bentuk ruang.

---

## 7.1.5 Anchor Tile

Anchor Tile adalah tile khusus yang dapat menghentikan player tanpa harus menabrak wall.

### Function

- Memberikan titik berhenti strategis.  
- Membantu membuat puzzle lebih fleksibel.  
- Mengurangi frustrasi karena player tidak selalu harus mencari wall.

### Rule

Jika player melewati Anchor Tile, player berhenti di atas tile tersebut.

---

## 7.1.6 Bounce Tile Optional

Bounce Tile memantulkan player ke arah tertentu.

### Function

- Menambah variasi level.  
- Dapat dipakai di level lanjutan.  
- Tidak wajib untuk MVP.

### Recommendation

Gunakan hanya jika core mechanic utama sudah stabil.

---

# 7.2 Time Mechanics

## 7.2.1 Input \= Time Tick

Setiap input arah memajukan waktu sebanyak **1 tick**.

### Rule

- Player tekan W/A/S/D.  
- Player bergerak sesuai arah gravitasi.  
- Setelah input diterima, global time tick bertambah 1\.  
- Semua elemen time-based memperbarui phase.

### Important Constraint

Player tidak bisa menunggu tanpa bergerak.

Ini berarti:

- Tidak ada tombol skip turn.  
- Tidak ada tombol wait.  
- Setiap kemajuan waktu harus dibayar dengan perubahan posisi.

---

## 7.2.2 Global Tick Counter

Level memiliki counter waktu global.

Contoh:

Tick: 0

Tick: 1

Tick: 2

Tick: 3

Tick: 4

...

Tick digunakan untuk menentukan phase setiap objek.

Contoh formula sederhana:

current\_phase \= tick % phase\_count

Jika sebuah laser memiliki 2 phase:

phase \= tick % 2

Jika sebuah enemy memiliki 4 phase:

phase \= tick % 4

---

## 7.2.3 Phase-Based Objects

Setiap object time-based dapat memiliki jumlah phase berbeda.

Contoh:

| Object | Phase Count | Behavior |
| :---- | ----: | :---- |
| Laser A | 2 | On, Off |
| Spike | 3 | Safe, Warning, Active |
| Enemy Patrol | 4 | Move Right, Down, Left, Up |
| Time Gate | 4 | Closed, Closed, Open, Closed |

Object tidak harus memiliki phase count yang sama. Ini membuat level memiliki ritme yang menarik.

---

## 7.2.4 Tick Update Timing

Untuk menghindari kebingungan, update tick harus konsisten.

### Recommended Order

1. Player memilih input.  
2. Time tick bertambah 1\.  
3. Trap, enemy, dan gate update phase.  
4. Player bergerak/sliding.  
5. Collision dicek selama player bergerak.  
6. Player berhenti atau mati.

### Alternative Order

1. Player memilih input.  
2. Player bergerak/sliding.  
3. Time tick bertambah 1\.  
4. Trap, enemy, dan gate update phase.  
5. Collision dicek di posisi akhir.

### Recommended Choice for This Game

Gunakan urutan pertama:

Input → Tick Update → World Phase Update → Player Slide

Alasannya:

- Setiap input terasa seperti memutar waktu sebelum ruang bergerak.  
- Player bisa membaca phase berikutnya dari UI.  
- Hazard yang aktif saat player melintas terasa lebih jelas.

Namun, jika playtest terasa terlalu sulit, gunakan urutan kedua agar lebih mudah dipahami.

---

# 7.3 Combined Time \+ Space Mechanics

## 7.3.1 Time Gate

Time Gate adalah gate yang terbuka atau tertutup berdasarkan tick/phase.

### Rule

- Jika gate open, player bisa melewati.  
- Jika gate closed, gate berfungsi seperti wall.  
- Gate dapat memiliki phase pattern berbeda.

Contoh:

Gate A Pattern: Closed, Open, Closed, Open

Gate B Pattern: Open, Closed, Closed, Closed

Gate C Pattern: Closed, Closed, Open, Closed

### Design Purpose

Time Gate memaksa player menggabungkan:

- Jalur sliding yang benar.  
- Urutan input yang benar.  
- Timing phase yang benar.

---

## 7.3.2 Time Trap

Trap yang berubah berdasarkan tick.

Jenis yang disarankan:

### Laser Trap

Laser aktif/mati berdasarkan phase.

Phase 0: Off

Phase 1: On

### Spike Trap

Spike memiliki warning phase sebelum aktif.

Phase 0: Safe

Phase 1: Warning

Phase 2: Active

### Rotating Beam

Trap yang arah serangannya berubah setiap tick.

Phase 0: Horizontal

Phase 1: Vertical

---

## 7.3.3 Time Enemy

Enemy bergerak atau berubah posisi setiap tick.

### Basic Patrol Enemy

Enemy mengikuti path phase-based.

Contoh:

Phase 0: Position A

Phase 1: Position B

Phase 2: Position C

Phase 3: Position B

Enemy tidak bergerak real-time, melainkan berpindah saat tick berubah.

### Collision Rule

Player mati jika:

- Player berhenti di tile yang sama dengan enemy.  
- Player melewati tile yang ditempati enemy.  
- Enemy phase berikutnya berpindah ke tile player, jika rule ini diaktifkan.

Untuk MVP, cukup gunakan aturan:

Player mati jika menyentuh tile enemy aktif saat sliding atau setelah berhenti.

---

## 7.3.4 Goal Timing Optional

Goal dapat selalu aktif atau hanya aktif pada phase tertentu.

### MVP Recommendation

Goal selalu aktif.

### Advanced Level Option

Goal hanya aktif pada tick tertentu.

Contoh:

Goal active only when tick % 4 \== 0

Gunakan hanya di level akhir agar tidak terlalu membingungkan.

---

## 8\. Level Elements

| Element | Category | Description | MVP Priority |
| :---- | :---- | :---- | :---- |
| Player | Core | Box yang dikendalikan player | Must Have |
| Wall | Space | Menghentikan player | Must Have |
| Goal | Objective | Area akhir level | Must Have |
| Hazard | Danger | Membunuh player saat disentuh | Must Have |
| Time Tick System | Time | Waktu maju setiap input | Must Have |
| Time Gate | Time \+ Space | Gate buka/tutup berdasarkan phase | Must Have |
| Laser | Time Trap | Trap aktif/mati berdasarkan tick | Should Have |
| Spike | Time Trap | Trap safe/warning/active | Should Have |
| Enemy Patrol | Time Enemy | Enemy berpindah setiap tick | Should Have |
| Anchor Tile | Space | Tile untuk berhenti | Should Have |
| Gravity Blocker | Space | Blocker berdasarkan arah gravitasi | Should Have |
| Bounce Tile | Space | Tile pantul | Could Have |
| Phase Goal | Time | Goal aktif di tick tertentu | Could Have |

---

## 9\. Game Rules

### 9.1 Win Condition

Player menang jika mencapai goal.

### 9.2 Lose Condition

Player kalah jika:

- Menyentuh hazard aktif.  
- Menyentuh enemy.  
- Keluar dari arena, jika level memungkinkan.  
- Terjebak tanpa kemungkinan input yang valid, jika sistem detect deadlock diterapkan.

### 9.3 Restart

Player dapat menekan **R** untuk restart level kapan saja.

### 9.4 Move Count

Setiap input arah dihitung sebagai satu move dan satu time tick.

End screen menampilkan:

Level Cleared\!

Time Shifts Used: 12

Best: 9

---

## 10\. UI / HUD

HUD minimal harus menampilkan:

Gravity: →

Tick: 7

Phase: 3/4

Time Shifts: 7

### 10.1 Gravity Indicator

Menampilkan arah gravitasi saat ini.

Bisa berupa:

- Panah besar di dekat player.  
- Ikon di HUD.  
- Efek visual arah gerak.

### 10.2 Tick Counter

Menampilkan jumlah tick/move yang sudah dilakukan.

### 10.3 Phase Preview Optional

Menampilkan phase berikutnya untuk membantu pemain.

Contoh:

Current Phase: 2

Next Phase: 3

Untuk gamejam, cukup tampilkan current phase terlebih dahulu.

**Implementation (v0.2):** HUD shows Gravity, Tick, and Time Shifts (no global `Phase: n/m` line). Hold **P** during play (when Move Previews is enabled in settings) to peek **next-tick** enemy ghosts/lines and hazard overlays for upcoming state changes. Release P to return to the normal board view. Phase objects pulse briefly when their state changes on tick advance. Per-object phase state is also communicated through trap/gate sprites.

---

## 11\. Level Design Guidelines

### 11.1 Start Simple

Level awal harus mengajarkan satu konsep per level.

Recommended progression:

1. Gravity slide only.  
2. Add wall and basic goal.  
3. Add time tick display.  
4. Add time gate.  
5. Add laser phase.  
6. Add spike warning.  
7. Add enemy patrol.  
8. Combine all mechanics.

---

### 11.2 No-Wait Rule Must Be Designed Carefully

Karena player tidak bisa menunggu, setiap puzzle harus menyediakan cara untuk mengubah tick melalui movement.

Artinya level harus punya:

- Jalur untuk “membuang tick”.  
- Loop kecil untuk mengatur timing.  
- Anchor atau wall agar player bisa mengontrol posisi.

Jika tidak, puzzle bisa terasa unfair.

---

### 11.3 Make Timing Readable

Trap dan gate harus punya visual phase yang jelas.

Contoh:

- Laser off \= redup.  
- Laser on \= terang.  
- Spike warning \= bergetar / warna berubah.  
- Gate about to open \= ada glow.

---

### 11.4 Avoid Overcrowding

Jangan isi level dengan terlalu banyak obstacle sekaligus.

Untuk level gamejam, lebih baik arena kecil tetapi puzzle-nya jelas.

Recommended size:

- Tutorial: 6x6 sampai 8x8.  
- Main level: 8x8 sampai 12x12.  
- Final level: maksimal 14x14.

---

## 12\. Example Levels

---

## Level 1 — First Shift

### Purpose

Mengajarkan gravity sliding.

### Elements

- Player  
- Wall  
- Goal

### Description

Player harus mencapai goal dengan beberapa input sederhana. Tidak ada trap.

### Learning Outcome

Player memahami bahwa WASD bukan movement biasa, melainkan mengubah arah gravitasi dan membuat player meluncur sampai berhenti.

---

## Level 2 — Time Starts Moving

### Purpose

Mengajarkan bahwa input memajukan tick.

### Elements

- Tick counter  
- Simple gate

### Description

Gate terbuka pada tick ganjil dan tertutup pada tick genap. Player harus memilih urutan input agar sampai saat gate terbuka.

---

## Level 3 — No Waiting

### Purpose

Mengajarkan bahwa player tidak bisa skip tick tanpa bergerak.

### Elements

- Time Gate  
- Wall loop kecil

### Description

Player perlu mengambil jalur memutar untuk memajukan tick sebelum masuk gate.

---

## Level 4 — Laser Rhythm

### Purpose

Mengajarkan trap phase.

### Elements

- Laser on/off  
- Time Gate optional

### Description

Laser aktif pada tick genap dan mati pada tick ganjil. Player harus melintasi area laser pada phase aman.

---

## Level 5 — Spike Warning

### Purpose

Mengajarkan trap 3 phase.

### Elements

- Spike safe/warning/active  
- Anchor Tile

### Description

Spike memberi warning satu tick sebelum aktif. Player harus membaca pola dan bergerak melewati area saat safe.

---

## Level 6 — Patrol Pattern

### Purpose

Mengajarkan enemy phase.

### Elements

- Enemy Patrol 4 phase  
- Time Gate

### Description

Enemy berpindah posisi setiap tick. Player harus menghindari posisi enemy sambil mencapai gate yang terbuka pada phase tertentu.

---

## Level 7 — Gravity Blocker

### Purpose

Mengajarkan space constraint.

### Elements

- Gravity Blocker  
- Time Gate

### Description

Beberapa jalur hanya bisa dilewati jika player datang dengan arah gravitasi tertentu. Player harus mengatur arah dan timing.

---

## Level 8 — Final Sync

### Purpose

Final challenge.

### Elements

- Time Gate  
- Laser  
- Spike  
- Enemy Patrol  
- Gravity Blocker  
- Anchor Tile

### Description

Player harus membaca semua pola dan mencapai goal dengan urutan input yang tepat.

---

## Level 9–12 — Extended Chambers (Post–Gamejam Scope)

Added after the original 8-level curve. No new mechanics; difficulty comes from larger layouts, combined hazards, and lower move-count targets.

| Level | Name | Notes |
| :---- | :---- | :---- |
| 9 | Foldback | Recombines gate, laser, spike, patrol |
| 10 | Pressure Route | Tighter routes, more tick pressure |
| 11 | Clock Floor | Multi-hazard sync puzzles |
| 12 | Direction for Time | Final challenge; clears to ending narrative |

---

## 13\. Difficulty Design

### 13.1 Easy Levels

- Sedikit hazard.  
- Pattern 2 phase.  
- Arena kecil.  
- Banyak wall untuk berhenti.

### 13.2 Medium Levels

- Kombinasi time gate dan trap.  
- Pattern 3–4 phase.  
- Ada kebutuhan untuk membuang tick.

### 13.3 Hard Levels

- Enemy patrol dan trap bersamaan.  
- Gate terbuka pada phase spesifik.  
- Space lebih sempit.  
- Move count challenge.

---

## 14\. Scoring System

Scoring berbasis jumlah input/time shift.

### 14.1 Time Shifts Used

Setiap input arah menambah:

Time Shifts \+1

Tick \+1

### 14.2 Medal System Optional

Setiap level dapat punya target move.

| Medal | Requirement |
| :---- | :---- |
| Gold | Clear dengan move sangat sedikit |
| Silver | Clear dengan move sedang |
| Bronze | Clear level tanpa batas move |

Contoh:

Gold: ≤ 8 shifts

Silver: ≤ 12 shifts

Bronze: Clear

Untuk MVP, cukup tampilkan total shift dan best shift.

---

## 15\. Visual Style

### 15.1 Overall Direction

Visual sederhana, clean, dan readable.

Recommended style:

- Minimalist neon grid.  
- Sci-fi laboratory.  
- Abstract spacetime chamber.  
- Player berupa kotak kecil dengan glow.  
- Time objects memiliki animasi phase yang jelas.

### 15.2 Color Language

| Element | Suggested Visual |
| :---- | :---- |
| Player | White / bright box |
| Goal | Green / cyan glowing area |
| Wall | Dark solid block |
| Time Gate Closed | Red / orange barrier |
| Time Gate Open | Transparent / blue outline |
| Laser Active | Bright red line |
| Laser Inactive | Dim red line |
| Spike Warning | Yellow flash |
| Spike Active | Red sharp tile |
| Anchor Tile | Blue circular pad |

---

## 16\. Audio Direction

### 16.1 Music

- Minimal electronic loop.  
- Tension-based but not too intense.  
- Tempo dapat terasa seperti clock/tick.

### 16.2 SFX

Required SFX:

- Gravity shift input.  
- Player slide.  
- Player hit wall.  
- Tick change.  
- Gate open/close.  
- Trap activate/deactivate.  
- Player death.  
- Level clear.

### 16.3 Audio Theme

Setiap tick bisa diberi subtle sound agar player merasa waktu bergerak.

Contoh:

Input → tick sound → world phase changes → slide sound

---

## 17\. Technical Design

## 17.1 Suggested Data Structure

Setiap level dapat disimpan sebagai grid.

Example tile symbols:

\# \= Wall

. \= Empty

P \= Player Start

G \= Goal

A \= Anchor Tile

L \= Laser

S \= Spike

E \= Enemy

T \= Time Gate

B \= Gravity Blocker

Example level layout:

\#\#\#\#\#\#\#\#

\#P.....\#

\#..T...\#

\#..\#...\#

\#..L.G.\#

\#\#\#\#\#\#\#\#

---

## 17.2 Tick Manager

Game membutuhkan satu sistem utama bernama **Tick Manager**.

### Responsibilities

- Menyimpan global tick.  
- Menerima event input player.  
- Memajukan tick.  
- Memberi sinyal update phase ke semua time-based object.

Pseudo-flow:

on\_player\_input(direction):

    if player\_can\_accept\_input:

        tick \+= 1

        update\_all\_time\_objects(tick)

        player.slide(direction)

---

## 17.3 Time-Based Object Interface

Setiap object berbasis waktu memiliki fungsi update phase.

Pseudo-code:

update\_phase(current\_tick):

    phase \= current\_tick % phase\_count

    apply\_phase(phase)

---

## 17.4 Player Movement State

Player sebaiknya punya state:

Idle

Sliding

Dead

LevelClear

Input hanya diterima saat player dalam state **Idle**.

---

## 17.5 Collision Rules During Sliding

Selama sliding, player harus dicek pada setiap tile yang dilalui.

Check order:

1. Is next tile wall/blocker/closed gate?  
2. If yes, stop before it.  
3. If next tile hazard/enemy active, player dies.  
4. If next tile goal, level clear.  
5. If next tile anchor, stop on it.  
6. Otherwise continue sliding.

---

## 18\. MVP Scope

Status as of **18 Mei 2026** (see **Development Status** at top of document).

### Must Have — **Complete**

- [x] Player gravity sliding.  
- [x] Wall collision.  
- [x] Goal tile.  
- [x] Restart level.  
- [x] Global tick system.  
- [x] Time Gate.  
- [x] At least one trap type (laser + spike + enemy in full build).  
- [x] At least 5 playable levels (**12** in current build).  
- [x] Basic UI: tick, gravity direction, move count.

### Should Have — **Complete**

- [x] Laser trap.  
- [x] Spike trap.  
- [x] Enemy patrol.  
- [x] Anchor tile.  
- [x] Gravity blocker.  
- [x] 8 levels total (**12** in current build).  
- [x] Simple main menu.  
- [x] Level select.

### Could Have — **Mixed**

- [ ] Medal system (move targets + best shift only; no Gold/Silver/Bronze tiers).  
- [x] Phase preview UI (enemy next-tick ghosts, hazard next-tick hints, tick pulse; no global phase HUD).  
- [ ] Goal active only on certain ticks.  
- [ ] Bounce tile.  
- [x] Screen shake / polish (with settings toggle).  
- [x] Simple story intro (intro + per-level names; ending screen after level 12).

### Won't Have for Game Jam — **Still out of scope**

- Complex rewind mechanic.  
- Full timeline system.  
- Real-time enemy AI.  
- Large open world.  
- Level editor.  
- Online leaderboard.

---

## 19\. Recommended 1-Week Production Plan

Plan below was the original schedule (14–21 Mei). **Completion status** reflects the build on **18 Mei 2026**.

## Day 1 — Core Prototype — **Done**

- [x] Implement player sliding.  
- [x] Implement wall collision.  
- [x] Implement goal.  
- [x] Implement restart.  
- [x] Make 1 test level.

## Day 2 — Time Tick System — **Done**

- [x] Implement global tick.  
- [x] Tick updates on W/A/S/D input.  
- [x] Add UI tick counter.  
- [x] Add simple time gate.

## Day 3 — Trap System — **Done**

- [x] Add laser trap.  
- [x] Add spike trap or one additional trap.  
- [x] Implement phase pattern per object.  
- [x] Make 2–3 levels.

## Day 4 — Space Mechanics — **Done**

- [x] Add anchor tile.  
- [x] Add gravity blocker.  
- [x] Improve level design.  
- [x] Make 2–3 more levels.

## Day 5 — Enemy \+ Level Polish — **Done**

- [x] Add enemy patrol if scope allows.  
- [x] Build final level.  
- [x] Balance difficulty.  
- [~] Add SFX placeholders (core SFX in; not full pack).

## Day 6 — UI, Art, Audio Polish — **Mostly done**

- [x] Add menu.  
- [x] Add level clear screen.  
- [x] Add death effect.  
- [~] Add simple music (menu loop; no dedicated gameplay loop).  
- [~] Improve visual clarity (readable placeholders + some tile art; final art pass deferred).

## Day 7 — Testing and Submission — **In progress**

- [x] Playtest all levels (12-level pass complete).  
- [x] Fix bugs (ongoing for blockers only).  
- [x] Add credits.  
- [ ] Build and upload.  
- [ ] Prepare screenshots and description.

---

## 20\. Team Role Suggestions

For a 4-person team:

### Programmer 1 — Core Systems

Responsible for:

- Player movement.  
- Collision.  
- Tick manager.  
- Level transition.

### Programmer 2 — Gameplay Objects

Responsible for:

- Time gate.  
- Trap system.  
- Enemy patrol.  
- Gravity blocker.

### Designer / Level Designer

Responsible for:

- Level layout.  
- Difficulty progression.  
- Tutorialization.  
- Balancing move count.

### Artist / UI / Audio Integrator

Responsible for:

- Tile visuals.  
- Player and obstacle readability.  
- UI/HUD.  
- SFX/music implementation.  
- Itch.io page assets.

Jika semua anggota programmer, tetap bagi berdasarkan fitur agar tidak saling tabrakan.

---

## 21\. Tutorial Strategy

Tutorial harus menggunakan gameplay, bukan teks panjang.

### Tutorial Text Examples

Level 1:

WASD shifts gravity.

You slide until something stops you.

Level 2:

Every move advances time by 1 tick.

Level 3:

Gates open and close with time.

You cannot wait. You must move.

Level 4:

Traps change phase every tick.

Read the rhythm.

---

## 22\. Game Feel Notes

Game akan terasa lebih enak jika:

- Sliding cepat tapi tidak instan.  
- Ada impact kecil saat player menabrak wall.  
- Tick change punya sound/visual feedback.  
- Gate dan trap punya animasi phase yang jelas.  
- Death cepat, restart cepat.

### Restart Speed

Karena game bisa sulit, restart harus sangat cepat.

Target:

Death → Restart available in \< 1 second

---

## 23\. Risks and Solutions

| Risk | Problem | Solution |
| :---- | :---- | :---- |
| Puzzle terlalu sulit | Player bingung dengan tick dan sliding | Buat level kecil dan tutorial bertahap |
| No-wait rule membuat puzzle unfair | Player tidak bisa mengatur timing | Sediakan loop atau anchor tile untuk membuang tick |
| Terlalu banyak phase | Sulit dibaca | Mulai dari 2 phase, lalu naik ke 3–4 phase |
| Scope membesar | Game tidak selesai | Fokus pada Time Gate \+ Laser dulu |
| Visual tidak jelas | Player tidak tahu trap aktif atau tidak | Gunakan warna dan animasi yang kontras |
| Movement terasa lambat | Game jadi membosankan | Sliding harus cepat dan responsif |

---

## 24\. Minimum Playable Build Definition

Game dianggap playable jika sudah memiliki:

- 5 level selesai.  
- Player bisa slide dengan WASD.  
- Setiap input menambah tick.  
- Time Gate berubah berdasarkan tick.  
- Minimal satu hazard berbasis phase.  
- Player bisa mati dan restart.  
- Player bisa mencapai goal dan lanjut level.  
- UI menampilkan tick dan move count.

**Status (18 Mei 2026):** All minimum criteria are met in the current Godot build. Submit-ready checklist items still open: verified **web export**, **itch.io page** (screenshots, controls copy, public build link).

---

## 25\. Final Pitch

**Chrono Slide** adalah top-down puzzle arcade tentang mengendalikan ruang dan waktu melalui satu keputusan sederhana: arah gravitasi berikutnya.

Setiap input mengubah arah gerak player sekaligus memajukan waktu. Musuh, trap, dan gate berubah phase setiap tick. Karena player tidak bisa menunggu, setiap gerakan menjadi keputusan penting: bergerak untuk mencari posisi, sekaligus mengorbankan waktu.

Game ini menggabungkan ketegangan arcade ala World's Hardest Game dengan logika puzzle berbasis timing dan sliding movement.

---

## 26\. One-Sentence Hook

Shift gravity, advance time, and survive a room where every move changes the world.

---

## 27\. Short Itch.io Description

**Chrono Slide** is a top-down spacetime puzzle game where every move shifts gravity and advances time. Slide through deadly rooms, avoid phase-changing traps, and reach the goal by mastering both space and timing.

---

## 28\. Indonesian Short Description

**Chrono Slide** adalah game puzzle top-down bertema ruang dan waktu. Setiap input mengubah arah gravitasi dan memajukan waktu satu tick. Hindari trap yang berubah phase, manfaatkan gate waktu, dan capai goal dengan urutan gerakan yang tepat.  
