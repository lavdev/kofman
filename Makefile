# Byte Eater — a pacman-like maze game, 100% Kof.
# Frontend (kofjs) + backend (kof.web/JVM) + sprite pipeline.
#
# Toolchain: needs `kof` on the PATH (see README "Instalando o Kof").
# Override per-invocation with: make KOF=/caminho/para/bin/kof web
KOF ?= kof
PORT ?= 8080

.PHONY: all slice web serve test api-smoke run clean

all: web

# 1. slice the atlas into per-frame sprites (assets/sprites/)
slice:
	./assets/slice.sh

# 2. compile the kofjs frontend and assemble the static site (web/)
web: slice
	rm -rf web
	mkdir -p web
	$(KOF) build src/game --target=js --output web
	cp -r assets/sprites web/sprites
	./assets/patch_web.sh

# 3. run the kof.web backend on $(PORT) (JVM): serves web/ + /api/*
serve: web
	$(KOF) serve src/server/server.kf --port $(PORT)

# Pure module tests. Kof's test runner compiles each file independently.
test:
	$(KOF) test src/game/draw_ops.kf --target jvm
	$(KOF) test src/game/difficulty.kf --target jvm
	$(KOF) test src/game/directions.kf --target jvm
	$(KOF) test src/game/game_rules.kf --target jvm
	$(KOF) test src/game/maze_rules.kf --target jvm
	$(KOF) test src/game/movement_rules.kf --target jvm
	$(KOF) test src/game/pellets.kf --target jvm
	$(KOF) test src/game/state.kf --target jvm

# API smoke test; start `make serve` in another terminal first.
api-smoke:
	./tests/api-smoke.sh

# quick local preview without the backend (python http server)
preview: web
	python3 -m http.server $(PORT) --directory web

clean:
	rm -rf web data
