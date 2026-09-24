# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

This repository is currently empty — no Godot project has been scaffolded yet (no `project.godot`, no source files, not even a git repo initialized). The intent is to build a PC (desktop) implementation of kyykkä, a traditional Finnish throwing/skittles game, using the Godot game engine.

The full game rules — field/square layout, kyykkä and karttu equipment, turn structure, and the plus/minus point scoring system — are documented in `README.md`. Read it before implementing any game logic: correctly modeling those rules (two opposing squares, alternating throws, pieces knocked out vs. left standing, two-half matches with sides swapped) is the core of this project.

## Setup notes for whoever scaffolds the project

- No engine version or scripting language has been decided yet. Confirm with the user before assuming a specific Godot version or GDScript vs. C#.
- Once a real project exists, replace this section with actual build/lint/test commands and a high-level architecture overview (scene structure, how the physical throw/court simulation is organized, how turns and scoring are tracked) — don't leave this placeholder guidance once there is real code to describe.
