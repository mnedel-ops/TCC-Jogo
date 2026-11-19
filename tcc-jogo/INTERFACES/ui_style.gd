class_name UIStyle
extends RefCounted
## Paleta e caixas compartilhadas pelas telas (Alchemons, Mochila, PC...).
## Mesmos valores já usados em alchemons_page.gd / game_menu.gd.

const GOLD := Color(1, 0.85, 0.2)
const PANEL_BG := Color(0.07, 0.07, 0.11, 0.94)
const PANEL_BG_ACTIVE := Color(0.14, 0.13, 0.08, 0.96)
const PANEL_BG_DEEP := Color(0.04, 0.04, 0.07, 0.9)
const PANEL_BORDER := Color(0.5, 0.5, 0.6)
const TEXT := Color(0.92, 0.92, 0.95)
const CLEAR := Color(0, 0, 0, 0)


static func box(bg: Color, border: Color, radius := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2 if border.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


## Linha de lista: com `on` fica dourada; sem, mostra só uma faixa na cor da categoria (se houver).
static func row_box(on: bool, accent := CLEAR) -> StyleBoxFlat:
	var s := box(Color(GOLD, 0.18) if on else CLEAR, GOLD if on else CLEAR, 6)
	if not on and accent.a > 0.0:
		s.border_color = Color(accent, 0.85)
		s.border_width_left = 4
	elif on:
		s.border_width_left = 6
	return s


## Cartão de seleção (retratos/cartas): dourado quando escolhido, borda suave no hover.
static func card_box(chosen: bool, hot := false) -> StyleBoxFlat:
	var border := PANEL_BORDER
	if chosen:
		border = GOLD
	elif hot:
		border = Color(GOLD, 0.45)
	return box(PANEL_BG_ACTIVE if chosen else PANEL_BG, border, 8)


## Etiqueta pequena colorida (categoria, quantidade, "Time"/"Armazenado"...).
static func chip(text: String, color: Color, font_size := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := box(Color(color, 0.18), Color(color, 0.9), 10)
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	s.content_margin_left = 8
	s.content_margin_right = 8
	p.add_theme_stylebox_override("panel", s)
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	p.add_child(l)
	return p


## Cor de cada tipo de Alchemon (mesmas cores dos modelos provisórios).
static func type_color(t: int) -> Color:
	match t:
		AlchemonType.Type.METAL:
			return Color(0.62, 0.68, 0.78)
		AlchemonType.Type.AMETAL:
			return Color(0.45, 0.78, 0.45)
		AlchemonType.Type.METALOIDE:
			return Color(0.9, 0.62, 0.3)
	return PANEL_BORDER


static func section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", GOLD)
	return l


static func hint_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate.a = 0.7
	return l
