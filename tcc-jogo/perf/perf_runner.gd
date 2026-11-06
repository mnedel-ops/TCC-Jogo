class_name PerfRunner
extends Node

# Mede FPS e imprime direto no debug (painel Saída / console). Sem JSON, sem relatório.
#
# Uso:
#   Editor: abrir res://perf/perf_runner.tscn e apertar F6 (Executar cena atual).
#   CLI:    godot --path . res://perf/perf_runner.tscn -- --seconds=30
#
# Saída (uma linha por segundo):
#   [FPS][exploracao] 1s: 60
#   [FPS][combate]    1s: 58
# e, ao fim de cada etapa, uma linha com média e mínimo.

const MAIN_SCENE := "res://scenes/main.tscn"
const LEVELS: Array[String] = ["res://scenes/scene_1.tscn", "res://scenes/scene_2.tscn"]
const SPAWN := "SpawnPointPlayer"
const WARMUP_SECONDS := 3.0
const SETTLE_SECONDS := 1.0
const WALK_RADIUS := 3.0

var seconds := 30
var _main: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "seconds" and kv.size() > 1:
			seconds = maxi(int(kv[1]), 1)
	_run()


func _run() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		push_warning("[FPS] modo headless: FPS não é válido. Rode com janela.")
	GameSession.autosave = false
	GameSession.new_game()

	var scene := load(MAIN_SCENE) as PackedScene
	_main = scene.instantiate()
	get_tree().root.add_child(_main)
	await _wait(SETTLE_SECONDS)

	await _sample_stage("exploracao", true)

	_start_combat()
	await _wait(SETTLE_SECONDS)
	await _sample_stage("combate", false)

	print("[FPS] fim")
	get_tree().quit(0)


func _sample_stage(label: String, walk: bool) -> void:
	await _wait(WARMUP_SECONDS)
	var player := _main.get_node_or_null("player") as Node3D
	var center := player.global_position if player != null else Vector3.ZERO
	var samples: Array[int] = []
	var start := Time.get_ticks_msec()
	var next_sample := 1.0
	var switched := false
	while true:
		await get_tree().process_frame
		var t := (Time.get_ticks_msec() - start) / 1000.0
		if walk and player != null:
			player.global_position = center + Vector3(cos(t * 0.8), 0.0, sin(t * 0.8)) * WALK_RADIUS
		if walk and not switched and t >= seconds * 0.5:
			switched = true
			_swap_level(LEVELS[1])
		if t >= next_sample:
			next_sample += 1.0
			var fps := int(Engine.get_frames_per_second())
			samples.append(fps)
			print("[FPS][%s] %ds: %d" % [label, samples.size(), fps])
		if t >= seconds:
			break
	var total := 0
	for s in samples:
		total += s
	print("[FPS][%s] média: %.1f | mín: %d" % [label, float(total) / maxf(samples.size(), 1), samples.min() if not samples.is_empty() else 0])


func _swap_level(path: String) -> void:
	var sm := get_tree().get_first_node_in_group("scene_manager") as SceneManager
	if sm != null:
		sm.change_level(load(path) as PackedScene, SPAWN)


func _start_combat() -> void:
	var ids: Array[int] = []
	for a in GameSession.database.alchemons:
		if a.id > 0 and a.id < 900:
			ids.append(a.id)
		if ids.size() == 2:
			break
	CombatSignal.enemy_level = 5
	CombatSignal.is_trainer_battle = false
	CombatSignal.combat_start.emit(ids[0], ids[1] if ids.size() > 1 else -1)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
