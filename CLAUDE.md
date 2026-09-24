# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

This is an early-stage Godot 4 project, now 3D. The main scene renders the base court (ground plane + boundary/pesä lines) — no kyykkä pieces, throwing, or scoring yet.

The full game rules — field/square layout, kyykkä and karttu equipment, turn structure, and the plus/minus point scoring system — are documented in `README.md`. Read it before implementing any game logic: correctly modeling those rules (two opposing squares, alternating throws, pieces knocked out vs. left standing, two-half matches with sides swapped) is the core of this project.

`ROADMAP.md` tracks the phased task breakdown for the full game (rules engine, equipment, throwing physics, UI, AI, multiplayer, polish, release). Check it for current progress and update its checkboxes as phases complete.

## Engine and language

- Godot **4.7**, GDScript (no C# / .NET module involved), **3D** (`Node3D`/`Camera3D`/etc., not the 2D API).
- Rendering method is set to `gl_compatibility` in `project.godot` for broad hardware compatibility rather than `forward_plus`. Change this deliberately (and check it still runs) if a feature requires the Forward+ renderer.

## Court

`scripts/court.gd` (attached to the `Court` root of `scenes/court.tscn`) procedurally builds the ground plane and court lines at runtime rather than storing them as static scene geometry, so the dimensions live in one place (the script's `@export` fields) instead of being baked into hand-placed meshes. Current layout, per README.md: a 5×20 m court with a 5×5 m pesä square at each end (so only the two pesä "front lines" need drawing in addition to the outer boundary — the pesä's other three edges coincide with the court boundary). Throwing lines are not drawn yet since their exact placement wasn't pinned down from the rule sources. When adding kyykkä pieces or throwing lines, extend this script (or add sibling scenes) rather than hand-authoring geometry in the `.tscn` file, to keep dimensions consistent and adjustable.

## Commands

Run via `make` (see `make help`); each target just wraps a `tools/*.sh` script or a direct Godot CLI call:

- `make run` — run the game (`tools/run.sh`, wraps `godot --path .`)
- `make edit` — open the project in the editor (`godot -e --path .`)
- `make check` — headless smoke test: loads the project and main scene, then quits. Useful to catch script/scene errors without a display: `godot --headless --path . --quit`
- `make export PRESET="<preset name>" OUT=builds/kyykka` — export a build (`tools/export.sh`). This requires export presets to exist first — none are checked in yet. Create them once via the editor (Project > Export...), which writes `export_presets.cfg`, and install matching export templates first (Editor > Manage Export Templates). `export_presets.cfg` is safe to commit once it exists.
- `make clean` — remove local build/import artifacts (`.godot/`, `builds/`)
- There is no test suite yet. If one is added, prefer [GUT](https://github.com/bitwes/Gut) (the de facto GDScript unit test framework), give it its own `make test` target, and document it here.
- There is no dedicated linter configured. [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) (`gdformat`, `gdlint`) is the common external option if one is wanted later — it is not installed as part of this repo.

## Project structure

- `project.godot` — engine config; `run/main_scene` points at `scenes/court.tscn`.
- `scenes/` — `.tscn` scene files. `court.tscn` holds the camera, sun light, and world environment; the court geometry itself is generated at runtime by `court.gd` (see Court above).
- `scripts/` — GDScript files. `court.gd` is attached to the `court.tscn` root.
- `assets/` — art/audio/etc. (currently empty).
- `Makefile` — common command entry points (see Commands above).
- `tools/` — repo-local shell scripts the Makefile wraps (`run.sh`, `export.sh`), not Godot engine code.
- `.godot/` is the engine's local import/cache directory, regenerated automatically and gitignored — never edit or commit it.

As real gameplay code lands, expand this section with the actual scene/script architecture (how the court and pieces are represented, how turns and scoring are tracked) rather than leaving it at this file-layout level.
