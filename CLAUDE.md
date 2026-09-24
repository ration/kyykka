# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

This is an early-stage Godot 4 project, now 3D. The main scene lets you mouse-aim and throw a karttu at the far pesä's kyykkä, with hits/misses fed live into the rules engine and the score printed to console (no HUD yet — that's Phase 5, and there's no turn/team switching yet — that's Phase 4). `scripts/rules/` remains the visual-independent source of truth for scoring.

The full game rules — field/square layout, kyykkä and karttu equipment, turn structure, and the plus/minus point scoring system — are documented in `README.md`. Read it before implementing any game logic: correctly modeling those rules (two opposing squares, alternating throws, pieces knocked out vs. left standing, two-half matches with sides swapped) is the core of this project.

`ROADMAP.md` tracks the phased task breakdown for the full game (rules engine, equipment, throwing physics, UI, AI, multiplayer, polish, release). Check it for current progress and update its checkboxes as phases complete.

## Engine and language

- Godot **4.7**, GDScript (no C# / .NET module involved), **3D** (`Node3D`/`Camera3D`/etc., not the 2D API).
- Rendering method is set to `gl_compatibility` in `project.godot` for broad hardware compatibility rather than `forward_plus`. Change this deliberately (and check it still runs) if a feature requires the Forward+ renderer.

## Court and equipment

`scripts/court.gd` (attached to the `Court` root of `scenes/court.tscn`) procedurally builds the ground plane, ground collision, and court lines at runtime rather than storing them as static scene geometry, so the dimensions live in one place (the script's `@export` fields) instead of being baked into hand-placed meshes. Current layout, per README.md: a 5×20 m court with a 5×5 m pesä square at each end (so only the two pesä "front lines" need drawing in addition to the outer boundary — the pesä's other three edges coincide with the court boundary). Throwing lines are not drawn yet since their exact placement wasn't pinned down from the rule sources. When adding throwing lines, extend this script rather than hand-authoring geometry in the `.tscn` file, to keep dimensions consistent and adjustable.

`scripts/court.gd` also gives the ground a `StaticBody3D`/`CollisionShape3D` (a flat box, `ground_margin` wider than the drawn court on each side) so `RigidBody3D` props have something to land on, and instantiates two `PesaView`s (see below) at the near/far pesä front lines.

Equipment:
- `scenes/kyykka.tscn` — one kyykkä: `RigidBody3D` + `CylinderMesh`/`CylinderShape3D` (10 cm tall, ~7 cm diameter, per README.md), with damping (`linear_damp`/`angular_damp` 0.5) so it settles to a firm, sleeping rest — see the physics-jitter note under Throwing below.
- `scenes/karttu.tscn` — one karttu (throwing bat): same pattern, 85 cm long, lying on its side, low-friction `PhysicsMaterial` (0.1) so it slides through a target rather than stopping dead on landing.
- `scripts/pesa_view.gd` (`class_name PesaView`) — spawns `piece_count` kyykkä as pairs evenly spaced along local X, at a small inward offset from the front line (`spawn_inward_offset`, see Throwing below — not exactly on the line); `court.gd` positions one instance at each pesä's front line. `piece_count` defaults to `KyykkaMatch.DEFAULT_KYYKKA_PAIRS * 2` (see Rules engine below) so the visual count stays wired to the rules engine's constant instead of being a second hardcoded 40. `to_pesa_local()` converts a world position into (x, depth-from-front-line) for `PieceClassifier`. `PesaView` only sets up the *initial* layout — it doesn't yet remove pieces from the scene as they're scored out; that's Phase 4's job (real game-loop integration).

## Throwing (Phase 3 demo — see ROADMAP.md)

`court.gd`'s `_ready()` builds one `Attack` against the far `PesaView` (Phase 4 will replace this with the real match/turn loop — kept intentionally minimal here) and wires up:
- `scripts/throwing/throw_controller.gd` (`class_name ThrowController`) — mouse-captured aiming (yaw clamped to a cone). Throw distance is currently **fixed** (`throw_speed`) — variable power is a later feature. The skill mechanic is swing timing: holding the button sweeps a 0–180° gauge (a bare-bones `CanvasLayer` bar built in code — a placeholder; Phase 5 owns the real HUD) over `swing_seconds`; releasing at the middle (90°) spins the karttu exactly one full rotation by the time it lands (a "flush" hit), releasing early/late under/over-rotates it, and running the gauge past 180° without releasing **cancels** the swing (shows a "MISSED SWING" flash, requires releasing and pressing again). Launches the (single, reused) karttu instance, then polls `RigidBody3D.sleeping` on it and the target pesä's pieces (with a timeout) before emitting `throw_settled`. Repositions/reorients the *existing* `court.tscn` `Camera3D` each frame rather than creating a new one.
- `scripts/throwing/spin_calculator.gd` (`class_name SpinCalculator`) — pure math (GUT-testable): `time_of_flight()` from projectile motion, `spin_rate()` mapping gauge angle to angular speed (linear, 90°→exactly `TAU` radians of rotation over the flight).
- `scripts/rules/piece_classifier.gd` (`class_name PieceClassifier`) — pure geometry (no Node dependency, GUT-testable): classifies a (x, depth) position against a pesä rectangle into `IN_SQUARE`/`ON_LINE`/`REMOVED` by distance to the nearest edge.
- `scripts/throwing/pesa_scorer.gd` (`class_name PesaScorer`) — bridges `PesaView`'s live positions to `PieceClassifier`, remembers each piece's last zone, and turns the transitions since the last call into a `ThrowResult` for `Attack.throw()`.

**Spin axis went through two wrong guesses before landing on the right one — worth knowing about if it needs revisiting:** the karttu spins about `Vector3.UP` (vertical) — a level, flat spin like a twirled baton or thrown frisbee, not a tumble. The karttu's length starts broadside (perpendicular to travel, so it can sweep across a row of kyykkä); yawing it 180° returns it to that same broadside alignment (symmetric end-to-end), while 90°/270° points it lengthwise down the throw direction instead — narrow, hits far fewer kyykkä. That's what "release at 90° to land flush" actually means physically. Earlier attempts got this wrong twice: first `dir.cross(Vector3.UP)`, which for a straight throw coincides with the karttu's own length axis (a no-op rolling-pin roll); then the horizontal aim direction itself, which tumbles the karttu end-over-end through vertical (pitching it up onto its end) instead of keeping it level — "spinning on the same plane as the ground" specifically meant the rotation *plane* should be horizontal, i.e. the axis is vertical, the opposite of what a horizontal-axis tumble does.

**Rotation is driven kinematically while airborne, not left to the physics solver:** setting `angular_velocity` once (or even re-asserting it every physics frame) still let the karttu's spin visibly wobble off-axis — measured directly, with the axis set as above: `angular_velocity`'s off-axis components reached double digits (rad/s) within a single physics step even with a per-frame reset, i.e. real solver-computed torque/precession, not float drift. `ThrowController` now overrides `global_transform.basis` every `_physics_process` tick with an exact analytic rotation (`_lock_start_basis.rotated(_lock_axis, _lock_rate * _lock_elapsed)`) for as long as `_locking_spin` is true, which keeps the *actual geometry* level (verified: the karttu's length-axis world-Y component stays under ~0.03 throughout) regardless of what the solver's own reported `angular_velocity` looks like. This releases back to normal physics (`_locking_spin = false`) on the karttu's first real contact — but `get_contact_count()` can keep reporting the *pre-launch* resting-on-ground contact for a few frames right after unfreezing, so contacts are ignored for `lock_grace_seconds` (0.15s) after launch; without that grace period the lock released after 3-4 frames instead of the ~54 (≈0.9s, the full flight) it should. The resulting *feel* (does a flush hit visibly sweep more kyykkä than a bad-angle one) still hasn't been checked visually — get a screen-share or description before trusting another guess on this.

**Physics jitter caveat (found and fixed once, worth knowing about):** kyykkä standing upright on a flat plane are prone to slow RigidBody3D solver jitter even while nominally "at rest" — an early version placed pieces only 1.5 cm past `PieceClassifier`'s margin, and several seconds of *undisturbed* simulation was enough to drift them across it, scoring phantom hits. `PesaView.spawn_inward_offset` (0.15 m) and the kyykkä's damping are the fix; keep a healthy margin if either dimension changes.

**Throw distance is a first-pass estimate, not tuned by feel:** `ThrowController.throw_speed`/`launch_elevation_degrees` were sized from projectile-motion math to *reach* the far pesä (~10–15 m away), verified headlessly (a scripted throw does register a real hit), but connecting isn't perfectly consistent throw-to-throw yet, and none of this — aim sensitivity, swing timing feel, the cancel indicator — has been checked visually. I don't have a safe way to view this session's live display (see git history around the Phase 3 commits). Expect to retune these constants once someone actually plays it.

## Rules engine

`scripts/rules/` implements the game rules (README.md) as plain `RefCounted` GDScript classes with no `Node`/scene dependency, so they're directly testable and reusable once physics (Phase 3) and UI (Phase 5) need to drive them:

- `Team` — minimal, just a name for now.
- `Pesa` — one team's playing square: `in_square`/`on_line`/`removed` kyykkä counts and the `apply()` transition between them. Positions aren't modeled yet (no physics), so a piece's zone is just asserted directly by whatever calls `apply()` — currently the tests, eventually Phase 3's collision detection.
- `ThrowResult` — one throw's effect on a `Pesa`; this is the seam Phase 3 will produce instances of.
- `Attack` — one team's attempt to clear the opponent's `Pesa` within a karttu budget; owns `score()`, which is only meaningful once `is_finished()` (asserts otherwise).
- `Half` — both teams' simultaneous `Attack`s against each other's square.
- `KyykkaMatch` — `HALVES_PER_MATCH` halves, `total_score()`, `winner()` (`null` on a tie).

`Attack.PENALTY_IN_SQUARE`/`PENALTY_ON_LINE` and `KyykkaMatch.DEFAULT_KYYKKA_PAIRS`/`DEFAULT_KARTTU_BUDGET` are the values that were least certain from the rule sources (see README.md) — they're named constants specifically so they're easy to correct against the official Suomen Kyykkäliitto rulebook without hunting through logic.

## Commands

Run via `make` (see `make help`); each target just wraps a `tools/*.sh` script or a direct Godot CLI call:

- `make run` — run the game (`tools/run.sh`, wraps `godot --path .`)
- `make edit` — open the project in the editor (`godot -e --path .`)
- `make check` — headless smoke test: loads the project and main scene, then quits. Useful to catch script/scene errors without a display: `godot --headless --path . --quit`
- `make export PRESET="<preset name>" OUT=builds/kyykka` — export a build (`tools/export.sh`). This requires export presets to exist first — none are checked in yet. Create them once via the editor (Project > Export...), which writes `export_presets.cfg`, and install matching export templates first (Editor > Manage Export Templates). `export_presets.cfg` is safe to commit once it exists.
- `make clean` — remove local build/import artifacts (`.godot/`, `builds/`)
- `make test` — run the [GUT](https://gut.readthedocs.io/) test suite (`tests/`) headlessly. GUT is vendored directly at `addons/gut` (copied from the `addons/gut` subfolder of the [Gut repo](https://github.com/bitwes/Gut) tag `v9.7.1`, not a submodule — that repo's top level is itself a demo Godot project, so only its inner `addons/gut` folder is the actual redistributable addon) and enabled as an editor plugin in `project.godot`. After first cloning, or after touching anything under `addons/`, run `godot --headless --path . --import` once so Godot registers GUT's `class_name`s before `make test` will work.
- There is no dedicated linter configured. [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) (`gdformat`, `gdlint`) is the common external option if one is wanted later — it is not installed as part of this repo.

## Project structure

- `project.godot` — engine config; `run/main_scene` points at `scenes/court.tscn`; `[editor_plugins]` enables GUT.
- `scenes/` — `.tscn` scene files. `court.tscn` holds the camera, sun light, and world environment; the court geometry itself is generated at runtime by `court.gd` (see Court and equipment above). `kyykka.tscn`/`karttu.tscn` are the equipment props.
- `scripts/` — GDScript files. `court.gd` is attached to the `court.tscn` root; `pesa_view.gd`/`scripts/throwing/*` are instantiated by it at runtime (no `.tscn` of their own — see Court and equipment / Throwing above). `scripts/rules/` is the rules engine (see Rules engine above).
- `tests/rules/`, `tests/scenes/`, `tests/throwing/` — GUT tests, mirroring the `scripts/` layout: one `test_*.gd` file per class.
- `addons/gut/` — vendored GUT addon (see Commands above); third-party code, not maintained here.
- `assets/` — art/audio/etc. (currently empty).
- `Makefile` — common command entry points (see Commands above).
- `tools/` — repo-local shell scripts the Makefile wraps (`run.sh`, `export.sh`), not Godot engine code.
- `.godot/` is the engine's local import/cache directory, regenerated automatically and gitignored — never edit or commit it.

As real gameplay code lands, expand this section with the actual scene/script architecture (how the court and pieces are represented, how turns and scoring are tracked) rather than leaving it at this file-layout level.
