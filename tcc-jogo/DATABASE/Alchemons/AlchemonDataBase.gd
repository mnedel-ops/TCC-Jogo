class_name AlchemonDatabase
extends Resource


@export var alchemons: Array[AlchemonSheet] = []

func get_by_id(id: int) -> AlchemonSheet:
	for a in alchemons:
		if a.id == id:
			return a
	push_warning("AlchemonSheet com id %d nao encontrado no database." % id)
	return null


## Rotina de atualização: regenera os atributos base de todas as fichas que
## têm dados químicos. Retorna {"updated": [nomes], "failed": {nome: erro}, "skipped": [nomes]}.
func regenerate_all_base_stats() -> Dictionary:
	var report := {"updated": [], "failed": {}, "skipped": []}
	for a in alchemons:
		if not a.uses_chemical_stats():
			report["skipped"].append(a.creature_name)
			continue
		var problem := AlchemonStatGenerator.validate(a)
		if problem != "":
			report["failed"][a.creature_name] = problem
		elif a.regenerate_base_stats():
			report["updated"].append(a.creature_name)
	return report
