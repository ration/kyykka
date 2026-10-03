# Kyykkä

A PC (desktop) implementation of **kyykkä**, a traditional Finnish throwing game, built with the [Godot](https://godotengine.org/) game engine.

## About the game

Kyykkä ("Finnish skittles") is one of Finland's oldest traditional games. Two teams take turns throwing wooden pieces called *kyykkä* out of a marked square using wooden bats called *karttu*. Organized competitive play in Finland is governed by the Suomen Kyykkäliitto (Finnish Kyykkä Association).

## Rules

The game follows the official rules of the Finnish kyykkä league — [Kyykän säännöt (kyykkaliiga.fi)](https://www.kyykkaliiga.fi/kyykansaannot) — for team play by men's rules.

### Playing field

- A flat 5 × 20 m court with a 5 × 5 m square at each end; the squares are 10 m apart.
- Each square holds the kyykkä of the team that throws from it: you throw from the square with the opponent's kyykkä at the far square, where your own stand.

### Equipment

- **Kyykkä** — wooden cylinders about 10 cm tall and 6–8 cm across. 40 per square: 20 pairs, stacked two high, along the square's front line, 10 cm clear of the side lines.
- **Karttu** — a wooden throwing club with a round shaft and a handle, at most 85 cm long and 8 cm thick.

### Teams and turns

- Teams of four. A turn (*heittovuoro*) is two players throwing two karttu each — four in all — and then it's the other team's turn.
- Each player throws four karttu per half, so a team has 16, in four turns. Turns alternate until both teams have thrown them all or cleared their target square; a team that's finished hands over at once and the other throws on alone.
- **Opening** (*avaus*): you throw from the back line of your throwing square until a kyykkä has gone out of play, then from its front line.
- Don't touch the opponent's kyykkä: any you knock in your own throwing square (a short throw) are put back where they were.

### Where a kyykkä ends up

- **Out** — knocked out of the square (and not into the gap in front of it): out of play.
- **Akka** — still inside the square, or on its front line (or a side line within 10 cm of it).
- **Pappi** — on a side or back line; it's stood upright on the line.
- **Kuokkavieras** — knocked forward into the gap between the squares; still in play.

### Scoring

- Scoring is by penalty points for what's left when a team's karttu run out: **−2** per akka, **−1** per pappi, **−2** per kuokkavieras. Knocked-out kyykkä score nothing — a half starts at −80 and climbs toward zero.
- Clearing the square before the karttu run out instead scores **+1 per unused karttu**.
- A match is two halves, with ends and the starting team swapped between them. Most points (fewest minus points) wins.

## Project

This project aims to recreate kyykkä as a digital PC game using the Godot engine. The repository is in its early stages — see `CLAUDE.md` for the current project status and guidance for contributors, and `ROADMAP.md` for the full task breakdown.

## Playing a build

Ready-to-play builds for Linux, Windows and macOS are built automatically from every commit on `main`: download them from the [latest release](https://github.com/ration/kyykka/releases/tag/latest). Nothing to install — unzip and run:

- **Windows** — unzip `kyykka-windows.zip` and run `kyykka.exe`. The build isn't code-signed, so SmartScreen may warn about an unknown publisher: click **More info → Run anyway**.
- **Linux** — unzip `kyykka-linux.zip` and run `./kyykka.x86_64` (`chmod +x kyykka.x86_64` first if your unzip tool dropped the executable bit).
- **macOS** — unzip `kyykka-macos.zip` and move `Kyykkä.app` to Applications. The app isn't signed or notarised, so the first time right-click it → **Open** → **Open** (or run `xattr -dr com.apple.quarantine /Applications/Kyykkä.app`).

- **Android** — download `kyykka-android.apk` on the phone and open it; Android will ask you to allow installing apps from your browser or file manager the first time. It's a debug-signed build for sideloading, not from the Play Store.

Any graphics card with OpenGL 3.3 (Linux/Windows) or Metal/OpenGL (macOS) should run it; on Android, any phone with OpenGL ES 3.

### Controls

| | Desktop | Touchscreen |
|---|---|---|
| Aim | move the mouse | drag a finger anywhere |
| Swing / throw | hold the left button, release to throw | hold **THROW**, release to throw |
| Step along the line | hold the right button and move sideways | drag along the **STEP** pad |
| Zoom | scroll wheel | pinch |
| Pause | Esc | the **II** button |

Release the swing when the gauge is in the middle for a flush hit; running it past the end cancels the swing.

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

Android also needs the Android SDK and a JDK (set their paths in Editor → Editor Settings → Export → Android, along with a debug keystore), then: `godot --headless --path . --export-debug Android builds/android/kyykka.apk`, and `adb install -r builds/android/kyykka.apk` to put it on a phone or emulator.

You don't normally need to: `.github/workflows/build.yml` does this on GitHub Actions. On every push to `main` (and on pull requests) it runs the tests and exports all four builds (Linux, Windows, macOS, Android), uploading them as workflow artifacts; for pushes to `main` it also replaces the [`latest`](https://github.com/ration/kyykka/releases/tag/latest) pre-release with the new builds. Pushing a tag like `v0.1.0` publishes a versioned release.

### Playing online

Main menu → **Play Online**. One player hosts (UDP port 24480), the other joins with the host's address. The host tries to open the port with UPnP; if that doesn't work (CGNAT, office networks), use a VPN such as Tailscale or ZeroTier and join the host's VPN address.
