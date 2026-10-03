# Kyykkä

A PC (desktop) implementation of **kyykkä**, a traditional Finnish throwing game, built with the [Godot](https://godotengine.org/) game engine.

## About the game

Kyykkä ("Finnish skittles") is one of Finland's oldest traditional games. Two teams take turns throwing wooden pieces called *kyykkä* out of a marked square using wooden bats called *karttu*. Organized competitive play in Finland is governed by the Suomen Kyykkäliitto (Finnish Kyykkä Association).

## Rules

### Playing field

- A rectangular sand/gravel court, roughly 5–7 m wide and 20–22 m long.
- A 5 m × 5 m square (*pesä*, "nest") is marked at each end of the court, with about 10 m of open space between the two squares.
- A throwing line is marked in front of each square. The distance from the square depends on the category of player (e.g. men throw from further back than women or junior players).

### Equipment

- **Kyykkä** — short wooden cylinders, about 10 cm tall and 6–8 cm in diameter. A full game uses 20 kyykkä per side (10 pairs, each pair stacked two high), lined up along the front edge of the opponent's square.
- **Karttu** — wooden throwing bats, up to about 85 cm long, with a handle and no weight restriction. Each turn allows a limited number of karttu (commonly two per turn in team/pair play, four in individual play).

### Teams and turns

- Played by teams of four, by pairs, or individually.
- Each side's kyykkä are set up in the square they are defending; the opposing side throws at that square.
- Teams alternate turns, throwing their karttu at the opponent's square and trying to knock the kyykkä pieces completely outside of it.
- Each team's first throws are made from the back edge of the playing area, behind their own square. Once they have knocked their first kyykkä out of the opponent's square, they move up and throw from their own square's front line (their kyykkä line) for the rest of the half.
- A short throw can hit your own kyykkä. Any knocked out of your own square count straight away as removed for the opposing team, who get the points — and, since a kyykkä is now out, may move up to their own line on their next throw.
- A throw that fails to remove any kyykkä from the square counts as a miss.

### Scoring

- Each kyykkä knocked out of the square scores a point for the throwing team.
- Each karttu left unused once the square has been fully cleared also scores a point.
- A kyykkä that lands on one of the square's lines is turned upright on that line.
- Any kyykkä still remaining once all karttu have been thrown counts against the throwing team: −2 for each one inside the square, −1 for each one standing on a line.
- A match is played in two halves, with sides swapping ends between halves so both teams attack and defend both squares.
- The team with the higher total score across both halves wins the match.

## Project

This project aims to recreate kyykkä as a digital PC game using the Godot engine. The repository is in its early stages — see `CLAUDE.md` for the current project status and guidance for contributors, and `ROADMAP.md` for the full task breakdown.

## Playing a build

Ready-to-play builds for Linux, Windows and macOS are built automatically from every commit on `main`: download them from the [latest release](https://github.com/ration/kyykka/releases/tag/latest). Nothing to install — unzip and run:

- **Windows** — unzip `kyykka-windows.zip` and run `kyykka.exe`. The build isn't code-signed, so SmartScreen may warn about an unknown publisher: click **More info → Run anyway**.
- **Linux** — unzip `kyykka-linux.zip` and run `./kyykka.x86_64` (`chmod +x kyykka.x86_64` first if your unzip tool dropped the executable bit).
- **macOS** — unzip `kyykka-macos.zip` and move `Kyykkä.app` to Applications. The app isn't signed or notarised, so the first time right-click it → **Open** → **Open** (or run `xattr -dr com.apple.quarantine /Applications/Kyykkä.app`).

Any graphics card with OpenGL 3.3 (Linux/Windows) or Metal/OpenGL (macOS) should run it.

## Development

### Requirements

- [Godot 4.7](https://godotengine.org/download) — the standard build, **not** the .NET/C# one. No other dependencies: the test framework ([GUT](https://gut.readthedocs.io/)) is vendored in `addons/gut`, and all sounds and music are synthesised at runtime.
- `make` and a POSIX shell (Linux/macOS; on Windows use WSL or Git Bash, or run the `godot` commands below directly).
- The Makefile calls Godot as `godot`. If your binary is named differently or isn't on your `PATH`, pass it in: `make run GODOT=/path/to/Godot_v4.7-stable_linux.x86_64`.

### First run

```sh
git clone <repo url> kyykka
cd kyykka
make run
```

On a fresh clone Godot hasn't imported the project yet (the `.godot/` cache is gitignored), and until it has, the game fails with errors like `Identifier "MusicSynth" not declared in the current scope`. Every `make` target that runs the project imports it first if needed, so `make run` just works. Without `make`, import once by hand:

```sh
godot --headless --path . --import   # once after cloning, or after touching addons/
godot --path .                       # run the game
```

If you ever see those "not declared" errors (e.g. after pulling new scripts), run `make import` — or `make clean` to rebuild the cache from scratch.

You can also open the project in the Godot editor (`make edit`, or Import → `project.godot` from the project manager) and press F5.

### Make targets

- `make run` — run the game
- `make edit` — open the project in the editor
- `make import` — (re)import assets and register class names
- `make check` — headless smoke test (loads the project, then quits)
- `make test` — run the GUT test suite headlessly
- `make simulate [COUNT=16] [MODE=summer|winter|tower]` — headless throw simulator: contact rate, score rate and settle time over many throws, for tuning physics
- `make screenshot [MODE=summer|winter|tower] [OUT_DIR=screenshots]` — render a few fixed views of the court to PNGs (needs a display; opens a window for a few seconds)
- `make net-selftest [THROWS=6]` — run an online host and client over localhost and check they agree on every throw (logs in `builds/`)
- `make export PRESET="<preset name>" OUT=builds/kyykka` — export a build; see below
- `make clean` — remove local build/import artifacts
- `make help` — list all targets

### Exporting a build

`export_presets.cfg` has three presets: `Linux`, `Windows` and `macOS`. You need the Godot 4.7.2 export templates installed once (Editor → Manage Export Templates → Download and Install). Then:

```sh
make export PRESET=Linux   OUT=builds/linux/kyykka.x86_64
make export PRESET=Windows OUT=builds/windows/kyykka.exe
make export PRESET=macOS   OUT=builds/macos/kyykka-macos.zip
```

You don't normally need to: `.github/workflows/build.yml` does this on GitHub Actions. On every push to `main` (and on pull requests) it runs the tests and exports all three builds, uploading them as workflow artifacts; for pushes to `main` it also replaces the [`latest`](https://github.com/ration/kyykka/releases/tag/latest) pre-release with the new builds. Pushing a tag like `v0.1.0` publishes a versioned release.

### Playing online

Main menu → **Play Online**. One player hosts (UDP port 24480), the other joins with the host's address. The host tries to open the port with UPnP; if that doesn't work (CGNAT, office networks), use a VPN such as Tailscale or ZeroTier and join the host's VPN address.
