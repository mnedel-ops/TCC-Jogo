extends GdUnitTestSuite


func _env(valid: bool = true) -> Dictionary:
	return {"fps_valid": valid, "cpu": "CPU", "cores": 8, "gpu": "GPU", "gpu_vendor": "V", "ram_total_mb": 16000,
		"resolution": "1280x720", "renderer": "gl_compatibility", "godot": "4.6", "build": "release", "os": "Linux",
		"display_server": "X11", "date": "2026-01-01 10:00:00", "commit": "abc"}


func _loads(n: int = 5, base: float = 1000.0) -> Array:
	var out: Array = []
	for i in n:
		out.append({"run": i + 1, "completed": true, "env": _env(), "init_ms": base + i, "explore_ms": 500.0 + i * 10,
			"combat_ms": 200.0, "level_swap_ms": 50.0, "combat_return_ms": 700.0})
	return out


func _mem(rss: float, orphans: int = 0, cycle: int = 1) -> Dictionary:
	return {"rss_mb": rss, "static_mb": rss / 2.0, "vram_mb": 10.0, "objects": 2000, "nodes": 150, "orphans": orphans, "cycle": cycle}


func _sustained(fps_explore: float = 60.0, fps_combat: float = 60.0, rams: Array = [300.0, 300.5, 300.2]) -> Dictionary:
	var cycles: Array = []
	for i in rams.size():
		cycles.append(_mem(rams[i], 0, i + 1))
	return {"completed": true, "env": _env(),
		"explore": {"fps": _repeat(fps_explore, 10), "frame_ms_p99": 17.0, "frame_ms_max": 25.0},
		"combat": {"fps": _repeat(fps_combat, 10), "frame_ms_p99": 17.0, "frame_ms_max": 25.0},
		"mem_start": _mem(200.0), "mem_explore": _mem(280.0), "mem_combat": _mem(290.0), "cycles": cycles}


func _repeat(v: float, n: int) -> Array:
	var a: Array = []
	for i in n:
		a.append(v)
	return a


func _build(loads: Array, sus: Dictionary, crit: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	var c: Dictionary = PerfReport.DEFAULT_CRITERIA.duplicate()
	c.merge(crit, true)
	return PerfReport.build(loads, sus, c, extra)


func test_load_table_has_five_runs_and_averages() -> void:
	var r := _build(_loads(), _sustained())
	var md: String = r["markdown"]
	assert_str(md).contains("| Operação | Execução 1 | Execução 2 | Execução 3 | Execução 4 | Execução 5 | Média |")
	assert_str(md).contains("| Inicialização | 1000.0 | 1001.0 | 1002.0 | 1003.0 | 1004.0 | 1002.0 |")
	assert_str(md).contains("Carregamento da exploração")
	assert_str(md).contains("Carregamento do combate")
	assert_str(r["verdicts"]["Carregamento"]["status"]).is_equal(PerfReport.RECORDED)


func test_load_limit_and_outlier_detection() -> void:
	var r := _build(_loads(), _sustained(), {"load_max_ms": 1001.0})
	assert_str(r["verdicts"]["Carregamento"]["status"]).is_equal(PerfReport.FAIL)
	var loads := _loads()
	loads[4]["explore_ms"] = 5000.0
	r = _build(loads, _sustained())
	assert_str(r["verdicts"]["Carregamento"]["status"]).is_equal(PerfReport.WARN)


func test_fps_verdicts() -> void:
	assert_str(_build(_loads(), _sustained(60.0, 58.0))["verdicts"]["FPS"]["status"]).is_equal(PerfReport.PASS)
	assert_str(_build(_loads(), _sustained(60.0, 40.0))["verdicts"]["FPS"]["status"]).is_equal(PerfReport.FAIL)
	var sus := _sustained()
	sus["env"]["fps_valid"] = false
	assert_str(_build(_loads(), sus)["verdicts"]["FPS"]["status"]).is_equal(PerfReport.NA)


func test_sustained_drop_below_floor_fails_even_with_good_average() -> void:
	var sus := _sustained()
	var fps: Array = _repeat(70.0, 20)
	for i in range(5, 9):
		fps[i] = 10.0
	sus["explore"]["fps"] = fps
	assert_str(_build(_loads(), sus)["verdicts"]["FPS"]["status"]).is_equal(PerfReport.FAIL)


func test_memory_verdicts() -> void:
	assert_str(_build(_loads(), _sustained())["verdicts"]["Memória RAM"]["status"]).is_equal(PerfReport.PASS)
	var leak := _build(_loads(), _sustained(60.0, 60.0, [300.0, 330.0, 360.0, 390.0]))
	assert_str(leak["verdicts"]["Memória RAM"]["status"]).is_equal(PerfReport.FAIL)
	var slow := _build(_loads(), _sustained(60.0, 60.0, [300.0, 300.1, 300.2, 300.3]))
	assert_str(slow["verdicts"]["Memória RAM"]["status"]).is_equal(PerfReport.WARN)
	var few := _build(_loads(), _sustained(60.0, 60.0, [300.0, 301.0]))
	assert_str(few["verdicts"]["Memória RAM"]["status"]).is_equal(PerfReport.NA)


func test_orphan_growth_fails_memory_check() -> void:
	var sus := _sustained()
	sus["cycles"][2]["orphans"] = 4
	assert_str(_build(_loads(), sus)["verdicts"]["Memória RAM"]["status"]).is_equal(PerfReport.FAIL)


func test_stability_uses_exit_codes_and_engine_errors() -> void:
	assert_str(_build(_loads(), _sustained())["verdicts"]["Estabilidade"]["status"]).is_equal(PerfReport.PASS)
	var crashed := _build(_loads(), _sustained(), {}, {"exit_codes": {"load_3": 139}})
	assert_str(crashed["verdicts"]["Estabilidade"]["status"]).is_equal(PerfReport.FAIL)
	var noisy := _build(_loads(), _sustained(), {}, {"engine_errors": ["perf_load_1.log: ERROR: x"]})
	assert_str(noisy["verdicts"]["Estabilidade"]["status"]).is_equal(PerfReport.WARN)
	var unfinished := _loads()
	unfinished[1]["completed"] = false
	assert_str(_build(unfinished, _sustained())["verdicts"]["Estabilidade"]["status"]).is_equal(PerfReport.FAIL)


func test_overall_and_csv() -> void:
	var ok := _build(_loads(), _sustained())
	assert_str(ok["overall"]).is_equal(PerfReport.PASS)
	assert_str(_build(_loads(), _sustained(60.0, 20.0))["overall"]).is_equal(PerfReport.FAIL)
	var csv: String = ok["csv"]
	assert_str(csv).starts_with("secao,item,execucao,valor")
	assert_str(csv).contains("carregamento,init_ms,1,1000.000")
	assert_str(csv).contains("ram_mb,ciclo,3,300.200")


func test_missing_sections_do_not_crash() -> void:
	var r := PerfReport.build([], {}, PerfReport.DEFAULT_CRITERIA.duplicate(), {})
	assert_str(r["markdown"]).contains("Sem execuções do modo `load`")
	assert_str(r["verdicts"]["FPS"]["status"]).is_equal(PerfReport.NA)
