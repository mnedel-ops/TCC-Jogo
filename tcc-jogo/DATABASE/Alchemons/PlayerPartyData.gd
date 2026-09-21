class_name PlayerPartyData
extends Resource

## Time atual do jogador em combate - so indices (species_id).
## Sem referencia de objeto, sem stats - so o dado puro pra montar o combate.

@export var party: Array[AlchemonInstance] = []
var species_ids: Array[int]:
	get:
		var ids :Array[int]= []
		for alchemon in party:
			ids.append(alchemon.species_id)
		return ids
