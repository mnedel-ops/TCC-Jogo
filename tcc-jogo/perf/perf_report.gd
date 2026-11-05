class_name PerfReport
extends RefCounted

const PASS := "Aprovado"
const FAIL := "Reprovado"
const WARN := "Atenção"
const NA := "N/D"
const RECORDED := "Registrado"
const WARMUP_SECONDS := 3.0

const DEFAULT_CRITERIA := {
	"fps_target": 60.0,
	"fps_tolerance_pct": 10.0,
	"fps_floor": 30.0,
	"fps_floor_max_seconds": 2,
	"load_max_ms": null,
	"load_outlier_ratio": 2.0,
	"ram_growth_tolerance_pct": 5.0,
	"orphan_growth_allowed": 0,
}

const LOAD_OPS: Array = [
	["init_ms", "Inicialização", false],
	["explore_ms", "Carregamento da exploração", false],
	["combat_ms", "Carregamento do combate", false],
	["level_swap_ms", "Troca de fase (cena 1 → 2) (adicional)", true],
	["combat_return_ms", "Retorno do combate à exploração (adicional)", true],
]


static func load_criteria(path: String = "res://perf/criteria.json") -> Dictionary:
	var c: Dictionary = DEFAULT_CRITERIA.duplicate()
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for k in DEFAULT_CRITERIA:
				if parsed.has(k):
					c[k] = parsed[k]
	return c


# loads: lista de resultados do modo "load"; sustained: resultado do modo "sustained" ({} se ausente).
# extra: {"exit_codes": {nome: int}, "engine_errors": Array[String]}
static func build(loads: Array, sustained: Dictionary, criteria: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var verdicts := {}
	var env := _pick_env(loads, sustained)
	var md := PackedStringArray()
	md.append("# Relatório de performance — TCC-Jogo\n")
	md.append(_env_section(env))
	md.append(_criteria_section(criteria))
	md.append(_load_section(loads, criteria, verdicts))
	md.append(_fps_section(sustained, env, criteria, verdicts))
	md.append(_memory_section(loads, sustained, criteria, verdicts))
	md.append(_stability_section(loads, sustained, extra, verdicts))
	var overall := _overall(verdicts)
	md.append(_summary_section(verdicts, overall))
	return {
		"markdown": "\n".join(md),
		"csv": _csv(loads, sustained),
		"verdicts": verdicts,
		"overall": overall,
	}


# ---------- seções ----------

static func _env_section(env: Dictionary) -> String:
	var rows := [
		["Data", env.get("date", "n/d")],
		["Commit", env.get("commit", "n/d")],
		["Sistema operacional", env.get("os", "n/d")],
		["CPU", "%s (%d threads)" % [env.get("cpu", "n/d"), int(env.get("cores", 0))]],
		["GPU", "%s (%s)" % [env.get("gpu", "n/d"), env.get("gpu_vendor", "n/d")]],
		["RAM total", "%d MB" % int(env.get("ram_total_mb", 0))],
		["Resolução", env.get("resolution", "n/d")],
		["Renderer", env.get("renderer", "n/d")],
		["Godot", env.get("godot", "n/d")],
		["Tipo de build", env.get("build", "n/d")],
		["DisplayServer", env.get("display_server", "n/d")],
	]
	if not bool(env.get("fps_valid", true)):
		rows.append(["Aviso", "Execução sem janela (headless): FPS e VRAM não são válidos."])
	var s := PackedStringArray(["## 1. Ambiente\n", "| Item | Valor |", "|---|---|"])
	for r in rows:
		s.append("| %s | %s |" % [r[0], r[1]])
	return "\n".join(s) + "\n"


static func _criteria_section(c: Dictionary) -> String:
	var load_rule := "apenas registrar; alerta se uma execução passar de %.1f× a mediana" % float(c["load_outlier_ratio"])
	if c.get("load_max_ms") != null:
		load_rule = "média e máximo <= %.0f ms; alerta se uma execução passar de %.1f× a mediana" % [float(c["load_max_ms"]), float(c["load_outlier_ratio"])]
	var s := PackedStringArray([
		"## 2. Critérios de avaliação\n",
		"| Métrica | Critério aplicado |", "|---|---|",
		"| FPS | Média >= %.0f FPS (meta %.0f com tolerância de %.0f%%) e nenhum período de mais de %d s abaixo de %.0f FPS |" % [
			float(c["fps_target"]) * (1.0 - float(c["fps_tolerance_pct"]) / 100.0), float(c["fps_target"]),
			float(c["fps_tolerance_pct"]), int(c["fps_floor_max_seconds"]), float(c["fps_floor"])],
		"| Carregamento | %s |" % load_rule,
		"| Memória RAM | Após o 1º ciclo exploração-combate-retorno, crescimento <= %.1f%% até o último ciclo e sem crescimento de nós órfãos (tolerância %d) |" % [
			float(c["ram_growth_tolerance_pct"]), int(c["orphan_growth_allowed"])],
		"| Estabilidade | Todas as execuções terminam com código 0, sem erros do engine no log e sem crescimento contínuo de memória |",
	])
	return "\n".join(s) + "\n"


static func _load_section(loads: Array, c: Dictionary, verdicts: Dictionary) -> String:
	var n := loads.size()
	var s := PackedStringArray(["## 3. Tempos de carregamento (ms)\n"])
	if n == 0:
		s.append("Sem execuções do modo `load`.\n")
		verdicts["Carregamento"] = {"status": NA, "detail": "sem dados"}
		return "\n".join(s)
	var head := "| Operação |"
	var sep := "|---|"
	for i in n:
		head += " Execução %d |" % int(loads[i].get("run", i + 1))
		sep += "---:|"
	s.append(head + " Média | Desvio | Mín | Máx |")
	s.append(sep + "---:|---:|---:|---:|")
	var worst := RECORDED
	var detail: Array[String] = []
	for op in LOAD_OPS:
		var vals: Array = []
		var row := "| %s |" % op[1]
		for r in loads:
			if r.has(op[0]):
				vals.append(float(r[op[0]]))
				row += " %.1f |" % float(r[op[0]])
			else:
				row += " — |"
		if vals.is_empty():
			s.append(row + " — | — | — | — |")
			continue
		s.append(row + " %.1f | %.1f | %.1f | %.1f |" % [PerfStats.mean(vals), PerfStats.stddev(vals), PerfStats.minimum(vals), PerfStats.maximum(vals)])
		if op[2]:
			continue
		var limit = c.get("load_max_ms")
		if limit != null and (PerfStats.mean(vals) > float(limit) or PerfStats.maximum(vals) > float(limit)):
			worst = FAIL
			detail.append("%s acima de %.0f ms" % [op[1], float(limit)])
		elif vals.size() >= 3 and PerfStats.median(vals) > 0.0 and PerfStats.maximum(vals) > float(c["load_outlier_ratio"]) * PerfStats.median(vals):
			if worst != FAIL:
				worst = WARN
			detail.append("%s com execução %.1f× acima da mediana" % [op[1], PerfStats.maximum(vals) / PerfStats.median(vals)])
	s.append("\nCada execução é um processo novo. **Inicialização**: do início do engine ao primeiro frame (inclui autoloads). **Exploração/combate**: do comando de carga ao primeiro frame desenhado da cena.")
	verdicts["Carregamento"] = {"status": worst, "detail": "; ".join(detail) if not detail.is_empty() else "tempos registrados, sem outliers"}
	return "\n".join(s) + "\n"


static func _fps_section(sus: Dictionary, env: Dictionary, c: Dictionary, verdicts: Dictionary) -> String:
	var s := PackedStringArray(["## 4. FPS\n"])
	if sus.is_empty():
		s.append("Sem execução do modo `sustained`.\n")
		verdicts["FPS"] = {"status": NA, "detail": "sem dados"}
		return "\n".join(s)
	var valid := bool(env.get("fps_valid", true))
	s.append("| Cenário | Amostras | FPS médio | FPS mínimo | 1%% inferior | Frame máx (ms) | Maior período < %.0f FPS (s) | Veredito |" % float(c["fps_floor"]))
	s.append("|---|---:|---:|---:|---:|---:|---:|---|")
	var worst := PASS
	var detail: Array[String] = []
	for stage in [["explore", "Exploração (2 fases)"], ["combat", "Combate"]]:
		var d: Dictionary = sus.get(stage[0], {})
		var fps: Array = d.get("fps", [])
		if fps.is_empty() or not valid:
			s.append("| %s | %d | N/D | N/D | N/D | N/D | N/D | %s |" % [stage[1], fps.size(), NA])
			continue
		var avg := PerfStats.mean(fps)
		var p99 := float(d.get("frame_ms_p99", 0.0))
		var low := 1000.0 / p99 if p99 > 0.0 else 0.0
		var run_below := PerfStats.longest_run_below(fps, float(c["fps_floor"]))
		var need := float(c["fps_target"]) * (1.0 - float(c["fps_tolerance_pct"]) / 100.0)
		var ok := avg >= need and run_below <= int(c["fps_floor_max_seconds"])
		if not ok:
			worst = FAIL
			detail.append("%s: média %.1f FPS, %d s abaixo de %.0f" % [stage[1], avg, run_below, float(c["fps_floor"])])
		s.append("| %s | %d | %.1f | %.1f | %.1f | %.1f | %d | %s |" % [
			stage[1], fps.size(), avg, PerfStats.minimum(fps), low, float(d.get("frame_ms_max", 0.0)), run_below, PASS if ok else FAIL])
	if not valid:
		s.append("\nFPS não avaliado: execução sem renderização (headless). Rode com janela/GPU para obter esta tabela.")
		worst = NA
		detail = ["execução headless"]
	s.append("\nAmostra de FPS 1 vez por segundo, após %.0f s de aquecimento. '1%% inferior' = 1000 / percentil 99 do tempo de frame." % WARMUP_SECONDS)
	verdicts["FPS"] = {"status": worst, "detail": "; ".join(detail) if not detail.is_empty() else "dentro da meta"}
	return "\n".join(s) + "\n"


static func _rss_or_static(m: Dictionary) -> float:
	var rss := float(m.get("rss_mb", -1.0))
	return rss if rss >= 0.0 else float(m.get("static_mb", 0.0))


static func _mem_row(label: String, m: Dictionary) -> String:
	var rss := float(m.get("rss_mb", -1.0))
	return "| %s | %s | %.1f | %.1f | %d | %d | %d |" % [
		label, ("%.1f" % rss) if rss >= 0.0 else "n/d", float(m.get("static_mb", 0.0)), float(m.get("vram_mb", 0.0)),
		int(m.get("objects", 0)), int(m.get("nodes", 0)), int(m.get("orphans", 0))]


static func _memory_section(loads: Array, sus: Dictionary, c: Dictionary, verdicts: Dictionary) -> String:
	var s := PackedStringArray(["## 5. Memória (RAM / VRAM)\n"])
	s.append("| Momento | RAM do processo (MB) | Memória estática (MB) | VRAM (MB) | Objetos | Nós | Órfãos |")
	s.append("|---|---:|---:|---:|---:|---:|---:|")
	var src: Dictionary = sus if not sus.is_empty() else (loads[0] if not loads.is_empty() else {})
	for k in [["mem_start", "Início"], ["mem_explore", "Após exploração"], ["mem_combat", "Durante combate"]]:
		if src.has(k[0]):
			s.append(_mem_row(k[1], src[k[0]]))
	var cycles: Array = sus.get("cycles", [])
	for cy in cycles:
		s.append(_mem_row("Após ciclo %d" % int(cy.get("cycle", 0)), cy))
	var status := NA
	var detail := "sem ciclos medidos"
	if cycles.size() >= 3:
		var ram: Array = []
		var orphans: Array = []
		for cy in cycles:
			ram.append(_rss_or_static(cy))
			orphans.append(float(cy.get("orphans", 0)))
		var growth := PerfStats.growth_pct(float(ram[0]), float(ram[ram.size() - 1]))
		var tail: Array = ram.slice(1)
		var monotonic := PerfStats.strictly_increasing(tail)
		var orphan_growth := int(orphans[orphans.size() - 1] - orphans[0])
		var vram_growth := PerfStats.growth_pct(float((cycles[0] as Dictionary).get("vram_mb", 0.0)), float((cycles[cycles.size() - 1] as Dictionary).get("vram_mb", 0.0)))
		detail = "RAM %+.1f%% do ciclo 1 ao %d, VRAM %+.1f%%, órfãos %+d, %s" % [
			growth, cycles.size(), vram_growth, orphan_growth, "crescimento monotônico" if monotonic else "sem crescimento monotônico"]
		if growth > float(c["ram_growth_tolerance_pct"]) or orphan_growth > int(c["orphan_growth_allowed"]):
			status = FAIL
		elif monotonic:
			status = WARN
		else:
			status = PASS
	s.append("\nRAM do processo = memória residente (Linux/macOS) ou working set (Windows). Referência de estabilidade: ciclo 1 (aquecimento de caches).")
	verdicts["Memória RAM"] = {"status": status, "detail": detail}
	return "\n".join(s) + "\n"


static func _stability_section(loads: Array, sus: Dictionary, extra: Dictionary, verdicts: Dictionary) -> String:
	var s := PackedStringArray(["## 6. Estabilidade\n"])
	var expected := loads.size() + (1 if not sus.is_empty() else 0)
	var done := 0
	for r in loads:
		if bool(r.get("completed", false)):
			done += 1
	if not sus.is_empty() and bool(sus.get("completed", false)):
		done += 1
	var codes: Dictionary = extra.get("exit_codes", {})
	var bad_codes: Array[String] = []
	for k in codes:
		if int(codes[k]) != 0:
			bad_codes.append("%s=%d" % [k, int(codes[k])])
	var errors: Array = extra.get("engine_errors", [])
	s.append("- Execuções concluídas: %d de %d" % [done, expected])
	s.append("- Códigos de saída diferentes de 0: %s" % (", ".join(bad_codes) if not bad_codes.is_empty() else "nenhum"))
	s.append("- Erros do engine nos logs: %d" % errors.size())
	for e in errors.slice(0, 5):
		s.append("  - `%s`" % str(e))
	var status := PASS
	var detail := "sem falhas, sem erros nos logs"
	if expected == 0:
		status = NA
		detail = "sem execuções"
	elif done < expected or not bad_codes.is_empty():
		status = FAIL
		detail = "%d/%d execuções concluídas" % [done, expected]
	elif not errors.is_empty():
		status = WARN
		detail = "%d erro(s) do engine nos logs" % errors.size()
	var mem_verdict: Dictionary = verdicts.get("Memória RAM", {})
	if mem_verdict.get("status", "") == WARN or mem_verdict.get("status", "") == FAIL:
		detail += "; atenção ao consumo de memória (ver seção 5)"
		if status == PASS:
			status = WARN
	verdicts["Estabilidade"] = {"status": status, "detail": detail}
	return "\n".join(s) + "\n"


static func _overall(verdicts: Dictionary) -> String:
	var any_fail := false
	var any_soft := false
	for k in verdicts:
		var st: String = verdicts[k]["status"]
		if st == FAIL:
			any_fail = true
		elif st == WARN or st == NA:
			any_soft = true
	if any_fail:
		return FAIL
	return "Aprovado com ressalva" if any_soft else PASS


static func _summary_section(verdicts: Dictionary, overall: String) -> String:
	var s := PackedStringArray(["## 7. Resultado\n", "| Métrica | Veredito | Detalhe |", "|---|---|---|"])
	for k in ["FPS", "Carregamento", "Memória RAM", "Estabilidade"]:
		if verdicts.has(k):
			s.append("| %s | %s | %s |" % [k, verdicts[k]["status"], verdicts[k]["detail"]])
	s.append("\n**Resultado geral: %s**" % overall)
	return "\n".join(s) + "\n"


static func _csv(loads: Array, sus: Dictionary) -> String:
	var lines := PackedStringArray(["secao,item,execucao,valor"])
	for op in LOAD_OPS:
		for r in loads:
			if r.has(op[0]):
				lines.append("carregamento,%s,%d,%.3f" % [op[0], int(r.get("run", 0)), float(r[op[0]])])
	for stage in ["explore", "combat"]:
		var fps: Array = (sus.get(stage, {}) as Dictionary).get("fps", [])
		for i in fps.size():
			lines.append("fps,%s,%d,%.3f" % [stage, i + 1, float(fps[i])])
	for cy in sus.get("cycles", []):
		lines.append("ram_mb,ciclo,%d,%.3f" % [int(cy.get("cycle", 0)), _rss_or_static(cy)])
		lines.append("vram_mb,ciclo,%d,%.3f" % [int(cy.get("cycle", 0)), float(cy.get("vram_mb", 0.0))])
		lines.append("orfaos,ciclo,%d,%d" % [int(cy.get("cycle", 0)), int(cy.get("orphans", 0))])
	return "\n".join(lines) + "\n"


static func _pick_env(loads: Array, sus: Dictionary) -> Dictionary:
	if not sus.is_empty() and sus.has("env"):
		return sus["env"]
	for r in loads:
		if r.has("env"):
			return r["env"]
	return {}
