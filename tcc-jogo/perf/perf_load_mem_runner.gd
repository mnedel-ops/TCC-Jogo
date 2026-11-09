class_name PerfLoadMemRunner
extends Node

# Mede tempo de carregamento e memória. Imprime direto no debug (painel Saída / console).
#
# Uso:
#   Editor: abrir res://perf/perf_load_mem_runner.tscn e apertar F6.
#   CLI:    godot --path . res://perf/perf_load_mem_runner.tscn -- --cycles=5
#
# Saída:
#   [LOAD] exploracao: 1234 ms
#   [MEM]  apos exploracao | RAM: 210.5 MB | estatica: 95.2 MB | VRAM: 40.1 MB | objetos: 5400 | nos: 1200 | orfaos: 0

const MAIN_SCENE := "res://scenes/main.tscn"
const LEVELS: Array[String] = ["res://scenes/scene_1.tscn", "res://scenes/scene_2.tscn"]
const SPAWN := "SpawnPointPlayer"
const SETTLE_SECONDS := 1.0
const COMBAT_HOLD_SECONDS := 2.0
const MB := 1048576.0

var cycles := 5
var _main: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "cycles" and kv.size() > 1:
			cycles = maxi(int(kv[1]), 1)
	_run()


func _run() -> void:
	await get_tree().process_frame
	var init_ms := Time.get_ticks_msec()
	GameSession.autosave = false
	GameSession.new_game()
	print("[LOAD] inicializacao: %d ms" % init_ms)
	_print_mem("inicio")

	# --- Carregamentos (primeira passada, a frio) ---
	var ms := await _load_main()
	print("[LOAD] exploracao: %d ms" % ms)
	_print_mem("apos exploracao")
	await _wait(SETTLE_SECONDS)

	ms = await _swap_level(LEVELS[1])
	print("[LOAD] troca de fase (cena 1 -> 2): %d ms" % ms)
	await _swap_level(LEVELS[0])
	await _wait(SETTLE_SECONDS)

	ms = await _start_combat()
	print("[LOAD] combate: %d ms" % ms)
	_print_mem("durante combate")
	await _wait(COMBAT_HOLD_SECONDS)

	ms = await _end_combat()
	print("[LOAD] retorno do combate: %d ms" % ms)
	_print_mem("apos combate")
	await _wait(SETTLE_SECONDS)

	# --- Ciclos: estabilidade da memória (vazamento) ---
	var first_rss := -1.0
	var last_rss := -1.0
	for i in cycles:
		var swap_ms := await _swap_level(LEVELS[(i + 1) % 2])
		await _wait(SETTLE_SECONDS)
		var combat_ms := await _start_combat()
		await _wait(COMBAT_HOLD_SECONDS)
		var back_ms := await _end_combat()
		await _wait(SETTLE_SECONDS)
		print("[LOAD][ciclo %d] troca: %d ms | combate: %d ms | retorno: %d ms" % [i + 1, swap_ms, combat_ms, back_ms])
		var rss := _print_mem("ciclo %d" % (i + 1))
		if i == 0:
			first_rss = rss
		last_rss = rss
	if first_rss > 0.0:
		print("[MEM] variacao RAM ciclo 1 -> %d: %+.1f MB" % [cycles, last_rss - first_rss])

	print("[LOAD/MEM] fim")
	get_tree().quit(0)


# ---------- operações medidas ----------

func _load_main() -> int:
	var t0 := Time.get_ticks_msec()
	var scene := load(MAIN_SCENE) as PackedScene
	_main = scene.instantiate()
	get_tree().root.add_child(_main)
	await _frames()
	return Time.get_ticks_msec() - t0


func _swap_level(path: String) -> int:
	var t0 := Time.get_ticks_msec()
	var sm := get_tree().get_first_node_in_group("scene_manager") as SceneManager
	if sm != null:
		sm.change_level(load(path) as PackedScene, SPAWN)
	await _frames()
	return Time.get_ticks_msec() - t0


func _start_combat() -> int:
	var ids: Array[int] = []
	for a in GameSession.database.alchemons:
		if a.id > 0 and a.id < 900:
			ids.append(a.id)
		if ids.size() == 2:
			break
	var holder := _main.get_node("CombatHolder")
	var t0 := Time.get_ticks_msec()
	CombatSignal.enemy_level = 5
	CombatSignal.is_trainer_battle = false
	CombatSignal.combat_start.emit(ids[0], ids[1] if ids.size() > 1 else -1)
	var guard := 0
	while holder.get_child_count() == 0 and guard < 600:
		await get_tree().process_frame
		guard += 1
	await _frames()
	return Time.get_ticks_msec() - t0


func _end_combat() -> int:
	var t0 := Time.get_ticks_msec()
	for c in _main.get_node("CombatHolder").get_children():
		c.queue_free()
	CombatSignal.combat_ended.emit()
	var guard := 0
	while CombatSignal.in_combat and guard < 600:
		await get_tree().process_frame
		guard += 1
	CombatSignal.in_combat = false
	await _frames()
	return Time.get_ticks_msec() - t0


func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


# ---------- memória ----------

# Imprime e devolve a RAM (RSS) em MB (-1 se indisponível).
func _print_mem(label: String) -> float:
	var rss := _rss_mb()
	var rss_txt := "%.1f MB" % rss if rss >= 0.0 else "N/D"
	print("[MEM] %s | RAM: %s | estatica: %.1f MB | VRAM: %.1f MB | objetos: %d | nos: %d | orfaos: %d" % [
		label,
		rss_txt,
		Performance.get_monitor(Performance.MEMORY_STATIC) / MB,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / MB,
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	])
	return rss


func _rss_mb() -> float:
	var pid := OS.get_process_id()
	match OS.get_name():
		"Linux":
			var f := FileAccess.open("/proc/self/status", FileAccess.READ)
			if f == null:
				return -1.0
			while not f.eof_reached():
				var line := f.get_line()
				if line.begins_with("VmRSS:"):
					return float(line.split(" ", false)[1].strip_edges()) / 1024.0
		"Windows":
			var out: Array = []
			var cmd := "(Get-Process -Id %d).WorkingSet64" % pid
			if OS.execute("powershell", ["-NoProfile", "-Command", cmd], out) == 0 and out.size() > 0:
				return float(str(out[0]).strip_edges()) / MB
		"macOS":
			var out: Array = []
			if OS.execute("ps", ["-o", "rss=", "-p", str(pid)], out) == 0 and out.size() > 0:
				return float(str(out[0]).strip_edges()) / 1024.0
	return -1.0
