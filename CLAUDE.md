# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

This is an early-stage Godot 4 project, now 3D. The main scene renders the base court (ground + collision, boundary/pesä lines) with kyykkä pieces placed in both pesä squares, and a standalone rules engine (`scripts/rules/`, no visuals) models teams, throws, and scoring — no physical throwing (aiming/hitting) or UI wiring yet.

The full game rules — field/square layout, kyykkä and karttu equipment, turn structure, and the plus/minus point scoring system — are documented in `README.md`. Read it before implementing any game logic: correctly modeling those rules (two opposing squares, alternating throws, pieces knocked out vs. left standing, two-half matches with sides swapped) is the core of this project.

`ROADMAP.md` tracks the phased task breakdown for the full game (rules engine, equipment, throwing physics, UI, AI, multiplayer, polish, release). Check it for current progress and update its checkboxes as phases complete.

## Engine and language

- Godot **4.7**, GDScript (no C# / .NET module involved), **3D** (`Node3D`/`Camera3D`/etc., not the 2D API).
- Rendering method is set to `gl_compatibility` in `project.godot` for broad hardware compatibility rather than `forward_plus`. Change this deliberately (and check it still runs) if a feature requires the Forward+ renderer.

## Court and equipment

`scripts/court.gd` (attached to the `Court` root of `scenes/court.tscn`) procedurally builds the ground plane, ground collision, and court lines at runtime rather than storing them as static scene geometry, so the dimensions live in one place (the script's `@export` fields) instead of being baked into hand-placed meshes. Current layout, per README.md: a 5×20 m court with a 5×5 m pesä square at each end (so only the two pesä "front lines" need drawing in addition to the outer boundary — the pesä's other three edges coincide with the court boundary). Throwing lines are not drawn yet since their exact placement wasn't pinned down from the rule sources. When adding throwing lines, extend this script rather than hand-authoring geometry in the `.tscn` file, to keep dimensions consistent and adjustable.

`scripts/court.gd` also gives the ground a `StaticBody3D`/`CollisionShape3D` (a flat box, `ground_margin` wider than the drawn court on each side) so `RigidBody3D` props have something to land on, and instantiates two `PesaView`s (see below) at the near/far pesä front lines.

Equipment:
- `scenes/kyykka.tscn` — one kyykkä: `RigidBody3D` + `CylinderMesh`/`CylinderShape3D` (10 cm tall, ~7 cm diameter, per README.md). No script; it's a passive prop until Phase 3 gives pieces behavior.
- `scenes/karttu.tscn` — one karttu (throwing bat): same pattern, 85 cm long, lying on its side. Built but **not yet placed** anywhere in `court.tscn` — its resting spot depends on the throwing line, which isn't drawn yet either.
- `scripts/pesa_view.gd` (`class_name PesaView`) — spawns `piece_count` kyykkä as pairs evenly spaced along local X at local Z = 0; `court.gd` positions one instance at each pesä's front line. `piece_count` defaults to `KyykkaMatch.DEFAULT_KYYKKA_PAIRS * 2` (see Rules engine below) so the visual count stays wired to the rules engine's constant instead of being a second hardcoded 40. `PesaView` only sets up the *initial* layout — it doesn't yet react to a `Pesa`'s state changing over time (removing pieces as they're knocked out); that needs Phase 3's `ThrowResult`s feeding back into the scene, which is Phase 4's job.

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
- `scripts/` — GDScript files. `court.gd` is attached to the `court.tscn` root; `pesa_view.gd` is instantiated by it at runtime (no `.tscn` of its own — see Court and equipment above). `scripts/rules/` is the rules engine (see Rules engine above).
- `tests/rules/`, `tests/scenes/` — GUT tests, mirroring the `scripts/` layout: one `test_*.gd` file per class.
- `addons/gut/` — vendored GUT addon (see Commands above); third-party code, not maintained here.
- `assets/` — art/audio/etc. (currently empty).
- `Makefile` — common command entry points (see Commands above).
- `tools/` — repo-local shell scripts the Makefile wraps (`run.sh`, `export.sh`), not Godot engine code.
- `.godot/` is the engine's local import/cache directory, regenerated automatically and gitignored — never edit or commit it.

As real gameplay code lands, expand this section with the actual scene/script architecture (how the court and pieces are represented, how turns and scoring are tracked) rather than leaving it at this file-layout level.
