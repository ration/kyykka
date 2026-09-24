.PHONY: run edit check export clean help

help:
	@echo "Targets:"
	@echo "  make run                                   - run the game"
	@echo "  make edit                                   - open the project in the Godot editor"
	@echo "  make check                                   - headless smoke test (loads project, then quits)"
	@echo "  make export PRESET=\"<preset name>\" OUT=builds/kyykka - export a build"
	@echo "  make clean                                   - remove local build/import artifacts"

run:
	./tools/run.sh

edit:
	godot -e --path .

check:
	godot --headless --path . --quit

export:
	@if [ -z "$(PRESET)" ] || [ -z "$(OUT)" ]; then \
		echo "Usage: make export PRESET=\"<preset name>\" OUT=<output path>" >&2; \
		exit 1; \
	fi
	./tools/export.sh "$(PRESET)" "$(OUT)"

clean:
	rm -rf .godot builds
