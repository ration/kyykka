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
  - Place 10 pairs of kyykkä (stacked two high) along each pesä's front
    line — `PesaView` (`scripts/pesa_view.gd`), instantiated twice by
    `court.gd`
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

- [x] **Phase 4 — Game loop integration**
  - Turn switching — `Half.next_attack()` (rule, tested) drives
    `MatchController` (`scripts/match_controller.gd`), which reconfigures
    the single hot-seat `ThrowController` for whichever side goes next
  - Half switching (reset/repopulate pesä) — fresh `PesaView`s each half
  - Match end → results — printed to console for now (no HUD, Phase 5)
  - Camera follows current thrower — falls out of `ThrowController.configure()`
    repositioning it each turn
  - Hot-seat only for now (same controls, both sides) — real per-player
    polish is Phase 7, AI is Phase 6
  - Verified end-to-end with a throwaway headless script through a full
    2-half match (turns alternate, halves reset kyykkä counts, match
    finishes, thrower disables)

- [x] **Phase 5 — UI**
  - HUD — `scripts/ui/hud.gd`: running score, current half, whose turn,
    karttu remaining, kyykkä in-square/on-line/removed. Subscribes to
    `MatchController.half_started`/`turn_changed`/`attack_scored`/
    `match_finished`; the HUD holds no game state of its own.
  - Main menu — `scenes/main_menu.tscn` + `scripts/ui/main_menu.gd`:
    Start Match / Quit; set as `run/main_scene` so the game boots here
    instead of jumping straight into the court.
  - Pause menu — `scripts/ui/pause_menu.gd`: Esc-toggled overlay
    (`process_mode = ALWAYS`, pauses the tree, releases mouse capture
    while open); Resume / Main Menu / Quit. Silences itself once the
    match ends so the results screen owns the exit flow.
  - Results/winner screen — `scripts/ui/results_screen.gd`: appears on
    `MatchController.match_finished` with final scores + winner (or Tie)
    and Rematch / Main Menu / Quit.

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
