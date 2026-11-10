extends Node
# Configurações do jogador. Autoload "GameSettings" (project.godot).
# Salvas em user://settings.cfg.
#
# ÁUDIO: volumes 0-100 para Geral (bus "Master"), Música e SFX. Os buses "Music"
# e "SFX" são criados em runtime. Para o som respeitar os controles, toque
# músicas no bus "Music" e efeitos no bus "SFX":
#   $AudioStreamPlayer.bus = GameSettings.MUSIC_BUS   # ou GameSettings.SFX_BUS
#
# VÍDEO: tipo de tela (janela / tela cheia), resolução (só em janela) e limite de FPS.
#
# CONTROLES: teclas das ações listadas em ACTIONS (uma tecla por ação).
#
# Mudanças valem na hora (pré-visualização), mas só persistem após save().
# revert() volta ao último estado salvo; is_dirty() diz se há mudança pendente.

signal changed

enum WindowMode { WINDOWED, FULLSCREEN }

const DEFAULT_PATH := "user://settings.cfg"
const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

const WINDOW_MODE_NAMES: Array[String] = ["Janela", "Tela cheia"]
const BASE_RESOLUTION := Vector2i(1920, 1080)
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
# -1 = VSync (padrão do projeto), 0 = ilimitado, N = limite de N FPS
const FPS_OPTIONS: Array[int] = [-1, 30, 60, 120, 0]

# Ações remapeáveis: [ação do InputMap, nome mostrado na tabela de controles].
# (As ações menu_* de navegação de menu ficam fixas de propósito: setas/WASD
# sempre funcionam, então nunca dá pra "se trancar pra fora" dos menus.)
const ACTIONS := [
	["move_up", "Mover para cima"],
	["move_down", "Mover para baixo"],
	["move_left", "Mover para a esquerda"],
	["move_right", "Mover para a direita"],
	["ui_interact", "Interagir"],
	["ui_menu", "Abrir / fechar o menu"],
]

const KEY_NAMES := {
	KEY_ESCAPE: "Esc",
	KEY_TAB: "Tab",
	KEY_SPACE: "Espaço",
	KEY_ENTER: "Enter",
	KEY_KP_ENTER: "Enter (num.)",
	KEY_BACKSPACE: "Backspace",
	KEY_UP: "Seta cima",
	KEY_DOWN: "Seta baixo",
	KEY_LEFT: "Seta esquerda",
	KEY_RIGHT: "Seta direita",
	KEY_SHIFT: "Shift",
	KEY_CTRL: "Ctrl",
	KEY_ALT: "Alt",
	KEY_MENU: "Menu",
}

var settings_path := DEFAULT_PATH

var master_volume := 100
var music_volume := 100
var sfx_volume := 100
var window_mode: int = WindowMode.WINDOWED
var resolution := BASE_RESOLUTION
var fps_limit := -1
var show_fps := false
# ação -> Array[int] com os códigos das teclas atuais (tecla física, ou keycode
# quando não há física, como na tecla "Menu").
var keys := {}

var _default_keys := {}
var _default_events := {}
var _saved := {}
var _applied_window: Array = [WindowMode.WINDOWED, BASE_RESOLUTION]
var _default_vsync := DisplayServer.VSYNC_ENABLED
var _fps_label: Label
var _fps_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_default_vsync = DisplayServer.window_get_vsync_mode()
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_build_fps_overlay()
	_read_default_controls()
	reload()


# ---------------------------------------------------------------- áudio

func set_master_volume(v: int) -> void:
	master_volume = clampi(v, 0, 100)
	_apply_audio()
	changed.emit()


func set_music_volume(v: int) -> void:
	music_volume = clampi(v, 0, 100)
	_apply_audio()
	changed.emit()


func set_sfx_volume(v: int) -> void:
	sfx_volume = clampi(v, 0, 100)
	_apply_audio()
	changed.emit()


# ---------------------------------------------------------------- vídeo

func set_window_mode(mode: int) -> void:
	window_mode = clampi(mode, 0, WINDOW_MODE_NAMES.size() - 1)
	_apply_video()
	changed.emit()


func set_resolution(res: Vector2i) -> void:
	resolution = res
	_apply_video()
	changed.emit()


func set_fps_limit(limit: int) -> void:
	fps_limit = limit if FPS_OPTIONS.has(limit) else -1
	_apply_video()
	changed.emit()


func set_show_fps(on: bool) -> void:
	show_fps = on
	_apply_video()
	changed.emit()


# Resoluções que cabem na tela atual (sempre inclui a resolução escolhida).
func available_resolutions() -> Array[Vector2i]:
	var screen := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var out: Array[Vector2i] = []
	for r in RESOLUTIONS:
		if r.x <= screen.x and r.y <= screen.y:
			out.append(r)
	if out.is_empty():
		for r in RESOLUTIONS:
			out.append(r)
	if not out.has(resolution):
		out.append(resolution)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return out


# ---------------------------------------------------------------- controles

# Nome legível de uma tecla.
func key_name(id: int) -> String:
	if KEY_NAMES.has(id):
		return KEY_NAMES[id]
	return OS.get_keycode_string(id as Key)


# Código usado pra identificar a tecla de um evento.
func key_id(e: InputEventKey) -> int:
	return e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode


# Teclas atuais da ação, em texto ("W / Seta cima").
func keys_text(action: String) -> String:
	var parts := PackedStringArray()
	for id in keys.get(action, []):
		parts.append(key_name(id))
	return " / ".join(parts) if not parts.is_empty() else "(nenhuma)"


# Define a tecla da ação. Se outra ação já usa essa tecla, ela perde a tecla; se
# ficar sem nenhuma, herda a tecla anterior desta ação (troca).
func bind_key(action: String, id: int) -> void:
	if not keys.has(action):
		return
	var old: Array = keys[action].duplicate()
	for other: String in keys.keys():
		if other == action or not keys[other].has(id):
			continue
		keys[other].erase(id)
		if keys[other].is_empty():
			keys[other] = old.slice(0, 1)
	keys[action] = [id]
	_apply_controls()
	changed.emit()


# Volta todas as teclas ao padrão do projeto.
func reset_controls() -> void:
	for action: String in _default_keys:
		keys[action] = _default_keys[action].duplicate()
	_apply_controls()
	changed.emit()


# ---------------------------------------------------------------- salvar / reverter

func snapshot() -> Dictionary:
	return {
		"master": master_volume,
		"music": music_volume,
		"sfx": sfx_volume,
		"window_mode": window_mode,
		"resolution": resolution,
		"fps_limit": fps_limit,
		"show_fps": show_fps,
		"keys": keys.duplicate(true),
	}


func restore(s: Dictionary) -> void:
	master_volume = s["master"]
	music_volume = s["music"]
	sfx_volume = s["sfx"]
	window_mode = s["window_mode"]
	resolution = s["resolution"]
	fps_limit = s["fps_limit"]
	show_fps = s["show_fps"]
	keys = s["keys"].duplicate(true)
	_apply_all()
	changed.emit()


func is_dirty() -> bool:
	return snapshot() != _saved


# Descarta o que não foi salvo.
func revert() -> void:
	restore(_saved)


# Grava no disco. Retorna false se falhar.
func save() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "window_mode", window_mode)
	cfg.set_value("video", "width", resolution.x)
	cfg.set_value("video", "height", resolution.y)
	cfg.set_value("video", "fps_limit", fps_limit)
	cfg.set_value("video", "show_fps", show_fps)
	for a in ACTIONS:
		cfg.set_value("controls", a[0], keys[a[0]])
	var err := cfg.save(settings_path)
	if err != OK:
		push_warning("GameSettings: não salvou configurações (%s)." % error_string(err))
		return false
	_saved = snapshot()
	changed.emit()
	return true


# Lê do disco (o que não existir fica no padrão) e aplica.
func reload() -> void:
	_load()
	_apply_all()
	_saved = snapshot()
	changed.emit()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	master_volume = clampi(int(cfg.get_value("audio", "master", 100)), 0, 100)
	music_volume = clampi(int(cfg.get_value("audio", "music", 100)), 0, 100)
	sfx_volume = clampi(int(cfg.get_value("audio", "sfx", 100)), 0, 100)
	window_mode = clampi(int(cfg.get_value("video", "window_mode", WindowMode.WINDOWED)), 0, WINDOW_MODE_NAMES.size() - 1)
	var w := int(cfg.get_value("video", "width", BASE_RESOLUTION.x))
	var h := int(cfg.get_value("video", "height", BASE_RESOLUTION.y))
	resolution = Vector2i(w, h) if (w >= 640 and h >= 360 and w <= 7680 and h <= 4320) else BASE_RESOLUTION
	var lim := int(cfg.get_value("video", "fps_limit", -1))
	fps_limit = lim if FPS_OPTIONS.has(lim) else -1
	show_fps = bool(cfg.get_value("video", "show_fps", false))
	for a in ACTIONS:
		if not cfg.has_section_key("controls", a[0]):
			continue
		var saved: Variant = cfg.get_value("controls", a[0])
		if saved is Array:
			var ids: Array = []
			for v in saved:
				if v is int and v > 0 and not ids.has(v):
					ids.append(v)
			if not ids.is_empty():
				keys[a[0]] = ids


# ---------------------------------------------------------------- aplicar

func _apply_all() -> void:
	_apply_audio()
	_apply_video()
	_apply_controls()


func _apply_audio() -> void:
	_set_bus_volume(MASTER_BUS, master_volume)
	_set_bus_volume(MUSIC_BUS, music_volume)
	_set_bus_volume(SFX_BUS, sfx_volume)


func _set_bus_volume(bus_name: String, volume: int) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, volume <= 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volume, 1) / 100.0))


func _apply_video() -> void:
	if fps_limit == -1:
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(_default_vsync)
	else:
		Engine.max_fps = fps_limit
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	_fps_label.get_parent().visible = show_fps
	set_process(show_fps)
	_apply_window()


# Só mexe na janela quando modo/resolução mudam em relação ao que já está aplicado.
func _apply_window() -> void:
	var target: Array = [window_mode, resolution]
	if target == _applied_window:
		return
	_applied_window = target
	var win := get_window()
	if window_mode == WindowMode.FULLSCREEN:
		win.mode = Window.MODE_FULLSCREEN
		return
	win.mode = Window.MODE_WINDOWED
	await get_tree().process_frame  # deixa o SO terminar de sair da tela cheia
	if window_mode != WindowMode.WINDOWED:
		return
	win.size = resolution
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	var offset := (usable.size - win.size) / 2
	win.position = usable.position + Vector2i(maxi(offset.x, 0), maxi(offset.y, 0))


# Teclas iguais ao padrão restauram os eventos originais do projeto (com os
# botões de gamepad intactos); teclas alteradas viram eventos de tecla física.
func _apply_controls() -> void:
	for a in ACTIONS:
		var action: String = a[0]
		if not InputMap.has_action(action):
			continue
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				InputMap.action_erase_event(action, e)
		if keys[action] == _default_keys[action]:
			for e: InputEvent in _default_events[action]:
				if e is InputEventKey:
					InputMap.action_add_event(action, e.duplicate())
		else:
			for id: int in keys[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = id as Key
				InputMap.action_add_event(action, ev)


func _read_default_controls() -> void:
	for a in ACTIONS:
		var action: String = a[0]
		var events: Array = []
		var ids: Array = []
		if InputMap.has_action(action):
			for e in InputMap.action_get_events(action):
				events.append(e.duplicate())
				if e is InputEventKey:
					ids.append(key_id(e))
		_default_events[action] = events
		_default_keys[action] = ids
		keys[action] = ids.duplicate()


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
