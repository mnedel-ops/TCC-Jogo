class_name PerfRunner
extends Node

# Uso (argumentos após "--"):
#   godot --path . res://perf/perf_runner.tscn -- --mode=load --run=1 --out=DIR
#   godot --path . res://perf/perf_runner.tscn -- --mode=sustained --seconds=60 --cycles=5 --out=DIR
# Use run_perf.sh / run_perf.ps1 para executar a bateria completa e gerar o relatório.

const MAIN_SCENE := "res://scenes/main.tscn"
const LEVELS: Array[String] = ["res://scenes/scene_1.tscn", "res://scenes/scene_2.tscn"]
const SPAWN := "SpawnPointPlayer"
const WARMUP_SECONDS := PerfReport.WARMUP_SECONDS
const SETTLE_SECONDS := 1.0
const COMBAT_HOLD_SECONDS := 2.0
const WALK_RADIUS := 3.0
const MB := 1048576.0

var mode := "load"
var run_index := 1
var seconds := 60
var cycles := 5
var out_dir := ""
var commit := "n/d"

var _main: Node
var _sampling := false
var _frame_ms: Array[float] = []
var _result := {}


func _ready() -> void:
	_parse_args()
	_run()


func _process(delta: float) -> void:
	if _sampling:
		_frame_ms.append(delta * 1000.0)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		var v := kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"mode": mode = v
			"run": run_index = maxi(int(v), 1)
			"seconds": seconds = maxi(int(v), 1)
			"cycles": cycles = maxi(int(v), 1)
			"out": out_dir = v
			"commit": commit = v
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("user://perf")


func _run() -> void:
	await get_tree().process_frame
	var init_ms := Time.get_ticks_msec()
	GameSession.autosave = false
	_result = {
		"mode": mode, "run": run_index, "completed": false,
		"env": _env(), "init_ms": init_ms, "mem_start": _mem(),
	}
	GameSession.new_game()
	if mode == "sustained":
		await _run_sustained()
	else:
		await _run_load()
	_result["completed"] = true
	_write()
	get_tree().quit(0)


# ---------- modo load: tempos de carregamento (uma execução = um processo) ----------

func _run_load() -> void:
	_result["explore_ms"] = await _load_main()
	_result["mem_explore"] = _mem()
	await _wait(SETTLE_SECONDS)
	_result["level_swap_ms"] = await _swap_level(LEVELS[1])
	await _swap_level(LEVELS[0])
	await _wait(SETTLE_SECONDS)
	_result["combat_ms"] = await _start_combat()
	_result["mem_combat"] = _mem()
	await _wait(COMBAT_HOLD_SECONDS)
	_result["combat_return_ms"] = await _end_combat()
	_result["mem_end"] = _mem()


# ---------- modo sustained: FPS, RAM e estabilidade ----------

func _run_sustained() -> void:
	await _load_main()
	_result["seconds"] = seconds
	_result["mem_explore"] = _mem()
	_result["explore"] = await _sample_stage(true, true)
	await _start_combat()
	_result["mem_combat"] = _mem()
	_result["combat"] = await _sample_stage(false, false)
	await _end_combat()
	await _wait(SETTLE_SECONDS)
	var cycle_list: Array = []
	for i in cycles:
		var t0 := Time.get_ticks_msec()
		await _swap_level(LEVELS[(i + 1) % 2])
		await _wait(SETTLE_SECONDS)
		await _start_combat()
		await _wait(COMBAT_HOLD_SECONDS)
		await _end_combat()
		await _wait(SETTLE_SECONDS)
		var m := _mem()
		m["cycle"] = i + 1
		m["cycle_ms"] = Time.get_ticks_msec() - t0
		cycle_list.append(m)
	_result["cycles"] = cycle_list


func _sample_stage(walk: bool, switch_levels: bool) -> Dictionary:
	await _wait(WARMUP_SECONDS)
	var player := _main.get_node_or_null("player") as Node3D
	var center := player.global_position if player != null else Vector3.ZERO
	var fps: Array = []
	var mem_samples: Array = []
	var switched := false
	_frame_ms.clear()
	_sampling = true
	var start := Time.get_ticks_msec()
	var next_sample := 1.0
	while true:
		await get_tree().process_frame
		var t := (Time.get_ticks_msec() - start) / 1000.0
		if walk and player != null:
			player.global_position = center + Vector3(cos(t * 0.8), 0.0, sin(t * 0.8)) * WALK_RADIUS
		if switch_levels and not switched and t >= seconds * 0.5:
			switched = true
			_swap_level_now(LEVELS[1])
			center = player.global_position if player != null else center
		if t >= next_sample:
			next_sample += 1.0
			fps.append(Engine.get_frames_per_second())
			mem_samples.append(_mem(false))
		if t >= seconds:
			break
	_sampling = false
	return {
		"fps": fps,
		"frame_ms_avg": PerfStats.mean(_frame_ms),
		"frame_ms_p99": PerfStats.percentile(_frame_ms, 99.0),
		"frame_ms_max": PerfStats.maximum(_frame_ms),
		"frames": _frame_ms.size(),
		"mem_samples": mem_samples,
	}


# ---------- operações medidas ----------

func _load_main() -> float:
	var t0 := Time.get_ticks_msec()
	var scene := load(MAIN_SCENE) as PackedScene
	_main = scene.instantiate()
	get_tree().root.add_child(_main)
	await _frames()
	return Time.get_ticks_msec() - t0


func _swap_level_now(path: String) -> void:
	var sm := get_tree().get_first_node_in_group("scene_manager") as SceneManager
	sm.change_level(load(path) as PackedScene, SPAWN)


func _swap_level(path: String) -> float:
	var t0 := Time.get_ticks_msec()
	_swap_level_now(path)
	await _frames()
	return Time.get_ticks_msec() - t0


func _start_combat() -> float:
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


func _end_combat() -> float:
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


# ---------- coleta de ambiente e memória ----------

func _env() -> Dictionary:
	var headless := DisplayServer.get_name() == "headless"
	return {
		"commit": commit,
		"date": Time.get_datetime_string_from_system(false, true),
		"os": "%s %s" % [OS.get_name(), OS.get_version()],
		"cpu": OS.get_processor_name(),
		"cores": OS.get_processor_count(),
		"ram_total_mb": int(OS.get_memory_info().get("physical", 0) / MB),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"resolution": "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "n/d")),
		"godot": Engine.get_version_info()["string"],
		"build": "release (export template)" if OS.has_feature("template_release") else ("debug" if OS.is_debug_build() else "release"),
		"display_server": DisplayServer.get_name(),
		"vsync": DisplayServer.window_get_vsync_mode() if not headless else -1,
		"fps_valid": not headless,
	}


func _mem(full := true) -> Dictionary:
	var d := {
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / MB,
		"vram_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / MB,
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	}
	if full:
		d["rss_mb"] = _rss_mb()
	return d


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


func _write() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var name := "perf_sustained.json" if mode == "sustained" else "perf_load_%d.json" % run_index
	var f := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	if f == null:
		push_error("PerfRunner: cannot write %s" % out_dir.path_join(name))
		return
	f.store_string(JSON.stringify(_result, "\t"))
