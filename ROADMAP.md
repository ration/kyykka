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

- [x] **Phase 2 — Equipment & scene setup**
  - Kyykkä piece scene (cylinder, 10 cm tall × ~7 cm diameter, per rules) —
    `scenes/kyykka.tscn`
  - Karttu (bat) scene — `scenes/karttu.tscn` (built, not yet placed on the
    court: needs the throwing line, which isn't drawn yet)
  - Place 20 pairs of kyykkä along each pesä's front line — `PesaView`
    (`scripts/pesa_view.gd`), instantiated twice by `court.gd`
  - Wire equipment counts to Phase 1's data model — `PesaView.piece_count`
    defaults to `KyykkaMatch.DEFAULT_KYYKKA_PAIRS * 2`
  - Also added ground collision (`court.gd`'s `GroundBody`), needed for
    any of the above to physically rest on the court

- [x] **Phase 3 — Throwing mechanics**
  - Aiming input — `ThrowController`: mouse-look yaw cone + a swing-timing
    gauge (release near the middle for a clean, flush hit; power is fixed
    for now, a later feature)
  - Physics-based throw (RigidBody3D karttu vs. kyykkä)
  - Detect "knocked fully out of pesä" vs. "still inside/on a line" —
    `PieceClassifier` (pure geometry) + `PesaScorer` (bridges to rules)
  - Feed throw results into the rules engine — wired to a live `Attack`
    in `court.gd` (Phase 4 will replace this demo wiring with the real
    match/turn loop)
  - Verified end-to-end headlessly (settle → classify → score works);
    throw ballistics are a first-pass estimate, not yet tuned by feel —
    see CLAUDE.md's Throwing section

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
