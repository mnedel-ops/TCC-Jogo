extends Node
class_name GameSettings
# Configurações do jogador: áudio (liga/desliga) e FPS. Salvas em user://settings.cfg.
#
# ÁUDIO: cria os buses "Music" e "SFX" em runtime. Para o som respeitar os
# botões, toque músicas no bus "Music" e efeitos no bus "SFX":
#   $AudioStreamPlayer.bus = GameSettings.MUSIC_BUS   # ou GameSettings.SFX_BUS

signal changed

const PATH := "user://settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

# -1 = VSync (padrão do projeto), 0 = ilimitado, N = limite de N FPS
const FPS_OPTIONS: Array[int] = [-1, 30, 60, 120, 0]

var music_on := true
var sfx_on := true
var show_fps := false
var fps_limit := -1

var _default_vsync := DisplayServer.VSYNC_ENABLED
var _fps_label: Label
var _fps_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_default_vsync = DisplayServer.window_get_vsync_mode()
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_build_fps_overlay()
	_load()
	_apply()


func set_music(on: bool) -> void:
	music_on = on
	_commit()


func set_sfx(on: bool) -> void:
	sfx_on = on
	_commit()


func set_show_fps(on: bool) -> void:
	show_fps = on
	_commit()


# dir = +1 próximo, -1 anterior
func cycle_fps_limit(dir: int = 1) -> void:
	var i := FPS_OPTIONS.find(fps_limit)
	fps_limit = FPS_OPTIONS[wrapi(i + dir, 0, FPS_OPTIONS.size())]
	_commit()


func fps_limit_text() -> String:
	match fps_limit:
		-1:
			return "VSync"
		0:
			return "Ilimitado"
		_:
			return "%d FPS" % fps_limit


func _commit() -> void:
	_apply()
	_save()
	changed.emit()


func _apply() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS), not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), not sfx_on)

	if fps_limit == -1:
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(_default_vsync)
	else:
		Engine.max_fps = fps_limit
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	_fps_label.get_parent().visible = show_fps
	set_process(show_fps)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _build_fps_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.visible = false
	add_child(layer)
	_fps_label = Label.new()
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fps_label.offset_top = 8.0
	_fps_label.offset_right = -12.0
	_fps_label.add_theme_font_size_override("font_size", 20)
	_fps_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 6)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fps_label)


func _process(delta: float) -> void:
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.25
		_fps_label.text = "FPS: %d" % int(Engine.get_frames_per_second())


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_on", music_on)
	cfg.set_value("audio", "sfx_on", sfx_on)
	cfg.set_value("video", "fps_limit", fps_limit)
	cfg.set_value("video", "show_fps", show_fps)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("GameSettings: não salvou configurações (%s)." % error_string(err))


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	music_on = bool(cfg.get_value("audio", "music_on", true))
	sfx_on = bool(cfg.get_value("audio", "sfx_on", true))
	show_fps = bool(cfg.get_value("video", "show_fps", false))
	var lim := int(cfg.get_value("video", "fps_limit", -1))
	fps_limit = lim if FPS_OPTIONS.has(lim) else -1
