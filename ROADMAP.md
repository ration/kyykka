# Roadmap

Task breakdown for the full kyykkä game. Phases build on each other roughly
in order, but later phases may reveal that an earlier one needs revisiting.
See `README.md` for the game rules and `CLAUDE.md` for engine/project
conventions.

- [x] **Phase 0 — Foundations**
  Godot project setup, build tooling (`Makefile`, `tools/*.sh`), base 3D
  court (ground + boundary/pesä lines).

- [x] **Phase 1 — Rules engine (no visuals)**
  - Data model: `Team`, `Pesa`, `ThrowResult`, `Attack`, `Half`, `KyykkaMatch`
    (`scripts/rules/`)
  - Pesä square state: which kyykkä are standing/gone per square
  - Scoring calculator: plus points (removed kyykkä, unused karttu), minus
    points (kyykkä left inside/on lines, per README)
  - Half/match completion and winner determination
  - Unit tests (GUT, `tests/rules/`) for the above

- [ ] **Phase 2 — Equipment & scene setup**
  - Kyykkä piece scene (cylinder, 10 cm tall × 6–8 cm diameter, per rules)
  - Karttu (bat) scene
  - Place 20 pairs of kyykkä along each pesä's front line
  - Wire equipment counts to Phase 1's data model

- [ ] **Phase 3 — Throwing mechanics**
  - Aiming input (direction + power)
  - Physics-based throw (RigidBody3D karttu vs. kyykkä)
  - Detect "knocked fully out of pesä" vs. "still inside/on a line"
  - Feed throw results into the rules engine

- [ ] **Phase 4 — Game loop integration**
  - Turn switching, half switching (reset/repopulate pesä), match end →
    results
  - Camera follows current thrower

- [ ] **Phase 5 — UI**
  - HUD (score, whose turn, karttu remaining, kyykkä remaining)
  - Main menu, pause menu, results/winner screen

- [ ] **Phase 6 — AI opponent**
  - Throw targeting with tunable accuracy for difficulty levels

- [ ] **Phase 7 — Local multiplayer (hot-seat)**
  - Player/team switching, per-player controls

- [ ] **Phase 8 — Audio & polish**
  - Impact SFX, ambient/music, hit particles, throw replay/slow-mo

- [ ] **Phase 9 — Settings & persistence**
  - Options menu, key bindings, save/load config

- [ ] **Phase 10 — Release prep**
  - Export presets (Windows/Linux/macOS), packaging
