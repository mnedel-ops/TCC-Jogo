class_name PlayerPartyData
extends Resource

## Time atual do jogador em combate - so indices (species_id).
## Sem referencia de objeto, sem stats - so o dado puro pra montar o combate.

@export var species_ids: Array[int] = []
