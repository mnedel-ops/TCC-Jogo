class_name PlayerPartyData
extends Resource


@export var party: Array[AlchemonInstance] = []
func find_by_uid(uid: String) -> AlchemonInstance:
	for i in party:
		if i != null and i.uid == uid:
			return i
	return null


var species_ids: Array[int]:
	get:
		var ids :Array[int]= []
		for alchemon in party:
			ids.append(alchemon.species_id)
		return ids
