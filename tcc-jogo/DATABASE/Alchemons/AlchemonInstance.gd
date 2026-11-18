class_name AlchemonInstance
extends Resource


const UNSET := -1
const MAX_ATTACKS := 4

@export var uid: String = ""
@export var species_id: int = -1
@export var creature_name: String = ""

@export var level: int = 1
@export var experience: int = 0
@export var individual_value: int = 1
@export var personality: String = AlchemonPersonality.NEUTRAL

@export var current_hp: int = UNSET
@export var current_energy: int = UNSET

@export var attack_ids: Array[int] = []


func ensure_uid() -> void:
	if uid == "":
		uid = CreatureFactory.new_uid()


func init_from_template(template: AlchemonSheet) -> void:
	species_id = template.id
	if current_hp == UNSET:
		current_hp = max_hp_for(template)


func max_hp_for(sheet: AlchemonSheet) -> int:
	return _stat(sheet.base_hp, "max_hp")


## Atributos desta instância no nível atual.
func compute_stats(sheet: AlchemonSheet) -> Dictionary:
	return compute_stats_at(sheet, level)


## Atributos desta instância em um nível qualquer (ex.: nível de destino).
func compute_stats_at(sheet: AlchemonSheet, at_level: int) -> Dictionary:
	return compute_stats_for(sheet, individual_value, personality, at_level)


## Fonte única do cálculo: base químico + IV + nível, depois multiplicador de personalidade.
## Estático para quem ainda não tem uma AlchemonInstance (ex.: CombatantState).
static func compute_stats_for(sheet: AlchemonSheet, iv: int, personality_id: String, at_level: int) -> Dictionary:
	return {
		"max_hp": stat_for(sheet.base_hp, iv, at_level, personality_id, "max_hp"),
		"attack": stat_for(sheet.base_attack, iv, at_level, personality_id, "attack"),
		"defense": stat_for(sheet.base_defense, iv, at_level, personality_id, "defense"),
		"mechanical_speed": stat_for(sheet.base_mechanical_speed, iv, at_level, personality_id, "mechanical_speed"),
		"action_energy": stat_for(sheet.energia_de_acao, iv, at_level, personality_id, "action_energy"),
	}


## X = floor(0,01 * (2B + IV) * L) + 5; X_final = round(X * M), mínimo 1.
static func stat_for(base: int, iv: int, at_level: int, personality_id: String, key: String) -> int:
	var v := AlchemonFormulas.compute_stat(base, iv, at_level)
	var m := AlchemonPersonality.multiplier(personality_id, key)
	return v if m == 1.0 else maxi(1, int(round(v * m)))


const STAT_PERSONALITY_KEYS := {
	"hp": "max_hp",
	"attack": "attack",
	"defense": "defense",
	"speed": "mechanical_speed",
	"energy": "action_energy",
}


## Base da ficha usada pelo jogo para o atributo (stat: hp|attack|defense|speed|energy).
func base_for_stat(sheet: AlchemonSheet, stat: String) -> int:
	match stat:
		"hp":
			return sheet.base_hp
		"attack":
			return sheet.base_attack
		"defense":
			return sheet.base_defense
		"speed":
			return sheet.base_mechanical_speed
		"energy":
			return sheet.energia_de_acao
	return 0


## Etapa final do cálculo (base + IV + nível + personalidade), para exibição.
## Usa as mesmas funções de compute_stats, então "result" é o valor real do jogo.
## Retorna {base, iv, level, raw, multiplier, result, steps: Array}.
func stat_breakdown(sheet: AlchemonSheet, stat: String) -> Dictionary:
	var base := base_for_stat(sheet, stat)
	var pkey: String = STAT_PERSONALITY_KEYS.get(stat, stat)
	var raw := AlchemonFormulas.compute_stat(base, individual_value, level)
	var mult := AlchemonPersonality.multiplier(personality, pkey)
	var result := stat_for(base, individual_value, level, personality, pkey)
	var pname := AlchemonPersonality.display_name(personality)
	var steps: Array = ["X = piso(0,01 · (2 · %d + %d) · %d) + 5 = %d" % [base, individual_value, level, raw]]
	if mult != 1.0:
		var m_txt := AlchemonStatGenerator.fmt(mult, 2)
		steps.append("Personalidade %s: M = %s" % [pname, m_txt])
		steps.append("Final = arred(%d · %s) = %d" % [raw, m_txt, result])
	return {
		"base": base, "iv": individual_value, "level": level, "raw": raw,
		"multiplier": mult, "result": result, "steps": steps,
	}


func _stat(base: int, key: String) -> int:
	return stat_for(base, individual_value, level, personality, key)


func hp_or_full(max_hp: int) -> int:
	return max_hp if current_hp == UNSET else clampi(current_hp, 0, max_hp)


func energy_or_full(max_energy: int) -> int:
	return max_energy if current_energy == UNSET else clampi(current_energy, 0, max_energy)


func is_fainted() -> bool:
	return current_hp == 0


func display_name(sheet: AlchemonSheet) -> String:
	if creature_name != "":
		return creature_name
	return sheet.creature_name if sheet != null else "???"


func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"species_id": species_id,
		"name": creature_name,
		"level": level,
		"xp": experience,
		"iv": individual_value,
		"personality": personality,
		"hp": current_hp,
		"energy": current_energy,
		"attacks": attack_ids.duplicate(),
	}


static func from_dict(d: Dictionary) -> AlchemonInstance:
	if not d.has("species_id"):
		push_warning("AlchemonInstance.from_dict: no species_id, entry skipped.")
		return null
	var inst := AlchemonInstance.new()
	inst.uid = str(d.get("uid", ""))
	inst.species_id = int(d["species_id"])
	inst.creature_name = str(d.get("name", ""))
	inst.level = maxi(int(d.get("level", 1)), 1)
	inst.experience = maxi(int(d.get("xp", 0)), 0)
	inst.individual_value = maxi(int(d.get("iv", 1)), 0)
	inst.personality = AlchemonPersonality.normalize(str(d.get("personality", "")))
	inst.current_hp = maxi(int(d.get("hp", UNSET)), UNSET)
	inst.current_energy = maxi(int(d.get("energy", UNSET)), UNSET)
	var raw = d.get("attacks", [])
	if raw is Array:
		for a in raw:
			if inst.attack_ids.size() >= MAX_ATTACKS:
				break
			inst.attack_ids.append(int(a))
	return inst
