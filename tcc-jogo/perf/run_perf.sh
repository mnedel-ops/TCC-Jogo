#!/usr/bin/env bash
# Bateria completa: N execuções de carregamento + 1 execução sustentada (FPS/RAM/ciclos) + relatório.
#   GODOT=/caminho/godot RUNS=5 STAGE_SECONDS=60 CYCLES=5 ./perf/run_perf.sh
#   HEADLESS=1 ./perf/run_perf.sh   # sem janela: só carregamento/RAM (FPS fica N/D)
#   GAME_EXE=/caminho/tcc-jogo.x86_64 usa uma build exportada em vez do editor.
set -u
GODOT="${GODOT:-godot}"
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
RUNS="${RUNS:-5}"
STAGE_SECONDS="${STAGE_SECONDS:-60}"
CYCLES="${CYCLES:-5}"
OUT="${OUT:-$PROJECT/perf_results/$(date +%Y%m%d_%H%M%S)}"
COMMIT="$(git -C "$PROJECT" rev-parse --short HEAD 2>/dev/null || echo n/d)"
VIDEO=(--windowed --resolution 1280x720)
[ "${HEADLESS:-0}" = "1" ] && VIDEO=(--headless)
mkdir -p "$OUT"

run() { # nome timeout args...
	local name="$1" limit="$2"; shift 2
	timeout "$limit" "$GODOT" --path "$PROJECT" "${VIDEO[@]}" res://perf/perf_runner.tscn -- "$@" --out="$OUT" --commit="$COMMIT" >"$OUT/perf_$name.log" 2>&1
	echo $? >"$OUT/exit_$name.txt"
	echo "[$name] saída $(cat "$OUT/exit_$name.txt")"
}

for i in $(seq 1 "$RUNS"); do
	run "load_$i" 300 --mode=load --run="$i"
done
run sustained $((2 * STAGE_SECONDS + CYCLES * 15 + 180)) --mode=sustained --seconds="$STAGE_SECONDS" --cycles="$CYCLES"

"$GODOT" --headless --path "$PROJECT" -s res://perf/perf_report_cli.gd -- --dir="$OUT"
