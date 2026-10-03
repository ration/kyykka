.PHONY: run edit import check test simulate screenshot net-selftest export clean help

# Override if your Godot 4.7 binary isn't on PATH as `godot`, e.g.
#   make run GODOT=~/Downloads/Godot_v4.7-stable_linux.x86_64
GODOT ?= godot

# The import cache (.godot/) is gitignored. Until it exists Godot doesn't
# know the project's class_names and the game fails with "Identifier ... not
# declared" errors, so every target that runs the project depends on it.
IMPORT_STAMP := .godot/global_script_class_cache.cfg

help:
	@echo "Targets:"
	@echo "  make run                  - run the game (imports first if needed)"
	@echo "  make edit                 - open the project in the Godot editor"
	@echo "  make import               - (re)import assets and register class names"
	@echo "  make check                - headless smoke test (loads project, then quits)"
	@echo "  make test                 - run the GUT test suite"
	@echo "  make simulate [COUNT=16] [MODE=summer|winter|tower]"
	@echo "                            - headless throw simulator (contact/score stats)"
	@echo "  make screenshot [MODE=summer] [OUT_DIR=screenshots]"
	@echo "                            - render court views to PNGs (needs a display)"
	@echo "  make net-selftest [THROWS=6] - online play over localhost, host vs client diff"
	@echo "  make export PRESET=\"<preset name>\" OUT=builds/kyykka - export a build"
	@echo "  make clean                - remove local build/import artifacts"
	@echo ""
	@echo "Set GODOT=/path/to/godot if the binary isn't on PATH as 'godot'."

$(IMPORT_STAMP):
	$(GODOT) --headless --path . --import

import:
	$(GODOT) --headless --path . --import

run: $(IMPORT_STAMP)
	GODOT="$(GODOT)" ./tools/run.sh

edit:
	$(GODOT) -e --path .

check: $(IMPORT_STAMP)
	$(GODOT) --headless --path . --quit

test: $(IMPORT_STAMP)
	$(GODOT) --headless -d -s --path . addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

COUNT ?= 16
MODE ?= summer
simulate: $(IMPORT_STAMP)
	$(GODOT) --headless --path . --script tools/simulate_throws.gd -- $(COUNT) $(MODE)

OUT_DIR ?= screenshots
screenshot: $(IMPORT_STAMP)
	$(GODOT) --path . --resolution 1280x720 --script tools/screenshot.gd -- $(MODE) "$(abspath $(OUT_DIR))"

THROWS ?= 6
net-selftest: $(IMPORT_STAMP)
	@mkdir -p builds
	$(GODOT) --headless --path . --script tools/net_selftest.gd -- host $(THROWS) > builds/net_host.log 2>&1 & \
	sleep 2; \
	$(GODOT) --headless --path . --script tools/net_selftest.gd -- client $(THROWS) > builds/net_client.log 2>&1; \
	wait; \
	grep RESULT builds/net_host.log > builds/net_host.results; \
	grep RESULT builds/net_client.log > builds/net_client.results; \
	if [ ! -s builds/net_host.results ]; then echo "No results; see builds/net_host.log" >&2; exit 1; fi; \
	diff builds/net_host.results builds/net_client.results && echo "Host and client agree on all $(THROWS) throws."

export: $(IMPORT_STAMP)
	@if [ -z "$(PRESET)" ] || [ -z "$(OUT)" ]; then \
		echo "Usage: make export PRESET=\"<preset name>\" OUT=<output path>" >&2; \
		exit 1; \
	fi
	GODOT="$(GODOT)" ./tools/export.sh "$(PRESET)" "$(OUT)"

clean:
	rm -rf .godot builds screenshots
