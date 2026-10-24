class_name CreatureFactory
extends RefCounted

## The ONLY place that creates a brand-new individual (wild spawn, capture,
## gift...). Rolls the per-creature data (IV, personality) once and gives it
## a permanent uid.

## IV range rolled for new creatures. Starters in the .tres keep IV 1.
## Set IV_MAX = IV_MIN to turn individual variation off.
const IV_MIN := 1
const IV_MAX := 31


static func new_uid() -> String:
	return Crypto.new().generate_random_bytes(8).hex_encode()


static func create(species_id: int, level: int = 1, rng: RandomNumberGenerator = null) -> AlchemonInstance:
	var r := rng if rng != null else RandomNumberGenerator.new()
	var inst := AlchemonInstance.new()
	inst.uid = new_uid()
	inst.species_id = species_id
	inst.level = maxi(level, 1)
	inst.individual_value = r.randi_range(IV_MIN, IV_MAX)
	inst.personality = AlchemonPersonality.roll(r)
	return inst
