class_name AlchemonInstance
extends Resource

## ONE individual creature, forever. This is the persistent model: it is what
## gets saved, moved between party/storage and handed to combat. It is NOT the
## battle state (CombatantState) - that is built from this, then written back
## through CreatureSync.
##
## Stored = things that are the creature's own history/identity:
##   uid, species, nickname, level, xp, IV, personality, current HP/energy, attacks.
## NOT stored = anything derived (max HP, attack, defense...). Those come from
##   compute_stats(sheet). Storing them let temporary bond bonuses leak into
##   the creature permanently.

const UNSET := -1   ## current_hp / current_energy: never set yet = treat as full.
const MAX_ATTACKS := 4

## Permanent identity. Never changes, never reused. Empty only on hand-authored
## .tres starters - ensure_uid() fills it on first load.
@export var uid: String = ""
@export var species_id: int = -1
## Nickname. Empty = show the species name.
@export var creature_name: String = ""

@export var level: int = 1
@export var experience: int = 0
@export var individual_value: int = 1
## See AlchemonPersonality. Rolled once by CreatureFactory.
@export var personality: String = AlchemonPersonality.NEUTRAL

## UNSET = full HP. 0 = fainted.
@export var current_hp: int = UNSET
## UNSET = full. Only used when CreatureSync.PERSIST_ENERGY is on.
@export var current_energy: int = UNSET

## Learned attack ids (AttackData.indexAttack), max 4. Empty = species default
## moveset (AlchemonSheet.attacks). NOTE: combat does not read this yet.
@export var attack_ids: Array[int] = []


func ensure_uid() -> void:
	if uid == "":
		uid = CreatureFactory.new_uid()


## Compat for old callers (AlchemonBuilder): bind species + make HP valid.
func init_from_template(template: AlchemonSheet) -> void:
	species_id = template.id
	if current_hp == UNSET:
		current_hp = max_hp_for(template)


func max_hp_for(sheet: AlchemonSheet) -> int:
	return AlchemonFormulas.compute_max_hp(sheet.max_hp, individual_value, level)


## Final stats at the current level, personality included. Single source of
## truth for combat AND for every UI screen.
func compute_stats(sheet: AlchemonSheet) -> Dictionary:
	return {
		"max_hp": max_hp_for(sheet),
		"attack": _stat(sheet.base_attack, "attack"),
		"defense": _stat(sheet.base_defense, "defense"),
		"mechanical_speed": _stat(sheet.base_mechanical_speed, "mechanical_speed"),
		"action_energy": _stat(sheet.base_action_energy, "action_energy"),
	}


func _stat(base: int, key: String) -> int:
	var v := AlchemonFormulas.compute_stat(base, individual_value, level)
	var m := AlchemonPersonality.multiplier(personality, key)
	return v if m == 1.0 else maxi(1, int(round(v * m)))


## Real current HP given the real max (UNSET -> full, never above max).
func hp_or_full(max_hp: int) -> int:
	return max_hp if current_hp == UNSET else clampi(current_hp, 0, max_hp)


func is_fainted() -> bool:
	return current_hp == 0


func display_name(sheet: AlchemonSheet) -> String:
	if creature_name != "":
		return creature_name
	return sheet.creature_name if sheet != null else "???"


## Attacks this creature can use. Learned list first; falls back to the species
## moveset so creatures with no list (old data) behave exactly as before.
func resolve_attacks(sheet: AlchemonSheet) -> Array[AttackData]:
	var out: Array[AttackData] = []
	for id in attack_ids:
		for a in sheet.attacks:
			if a != null and a.indexAttack == id:
				out.append(a)
				break
	if out.is_empty():
		for a in sheet.attacks:
			out.append(a)
	return out.slice(0, MAX_ATTACKS)


# ------------------------------------------------------------ serialization
# Plain Dictionary on purpose (JSON-safe). Do NOT save with ResourceSaver:
# a .tres/.res in user:// can carry scripts, so loading a shared/tampered save
# could run code.

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


## Tolerant on purpose: missing keys -> defaults, wrong types -> sanitized.
## Returns null only when there is no usable species.
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
