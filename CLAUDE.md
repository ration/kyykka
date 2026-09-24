# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

This is an early-stage Godot 4 project. The only content so far is scaffolding: an empty main scene and a couple of helper scripts — no actual kyykkä gameplay (court, pieces, throwing, scoring) has been implemented yet.

The full game rules — field/square layout, kyykkä and karttu equipment, turn structure, and the plus/minus point scoring system — are documented in `README.md`. Read it before implementing any game logic: correctly modeling those rules (two opposing squares, alternating throws, pieces knocked out vs. left standing, two-half matches with sides swapped) is the core of this project.

## Engine and language

- Godot **4.7**, GDScript (no C# / .NET module involved).
- Rendering method is set to `gl_compatibility` in `project.godot` for broad hardware compatibility rather than `forward_plus`. Change this deliberately (and check it still runs) if a feature requires the Forward+ renderer.

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

- `project.godot` — engine config; `run/main_scene` points at `scenes/main.tscn`.
- `scenes/` — `.tscn` scene files.
- `scripts/` — GDScript files. `main.gd` is attached to the current placeholder root scene.
- `assets/` — art/audio/etc. (currently empty).
- `Makefile` — common command entry points (see Commands above).
- `tools/` — repo-local shell scripts the Makefile wraps (`run.sh`, `export.sh`), not Godot engine code.
- `.godot/` is the engine's local import/cache directory, regenerated automatically and gitignored — never edit or commit it.

As real gameplay code lands, expand this section with the actual scene/script architecture (how the court and pieces are represented, how turns and scoring are tracked) rather than leaving it at this file-layout level.
