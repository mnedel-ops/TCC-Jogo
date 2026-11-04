class_name AlchemonPersonality
extends RefCounted


const NEUTRAL := "neutral"
const STAT_SWING := 0.10

const TABLE := {
	"neutral": {},
	"bold":  {"up": "attack",           "down": "defense"},
	"stoic": {"up": "defense",          "down": "attack"},
	"hasty": {"up": "mechanical_speed", "down": "defense"},
	"calm":  {"up": "defense",          "down": "mechanical_speed"},
	"keen":  {"up": "action_energy",    "down": "mechanical_speed"},
}


static func is_valid(id: String) -> bool:
	return TABLE.has(id)


static func normalize(id: String) -> String:
	return id if TABLE.has(id) else NEUTRAL


static func multiplier(id: String, stat: String) -> float:
	var entry: Dictionary = TABLE.get(id, {})
	if entry.get("up", "") == stat:
		return 1.0 + STAT_SWING
	if entry.get("down", "") == stat:
		return 1.0 - STAT_SWING
	return 1.0


static func roll(rng: RandomNumberGenerator = null) -> String:
	var ids: Array = TABLE.keys()
	var i: int = rng.randi_range(0, ids.size() - 1) if rng != null else randi() % ids.size()
	return ids[i]
