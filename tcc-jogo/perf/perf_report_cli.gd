extends SceneTree

# godot --headless --path . -s res://perf/perf_report_cli.gd -- --dir=PASTA [--strict]


func _init() -> void:
	var dir := ""
	var strict := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			dir = a.trim_prefix("--dir=")
		elif a == "--strict":
			strict = true
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		push_error("perf_report_cli: informe --dir=PASTA com os resultados.")
		quit(2)
		return

	var loads: Array = []
	var sustained := {}
	var exit_codes := {}
	var errors: Array = []
	var names := DirAccess.get_files_at(dir)
	names.sort()
	for f in names:
		var path := dir.path_join(f)
		if f.begins_with("perf_load_") and f.ends_with(".json"):
			var d = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary:
				loads.append(d)
		elif f == "perf_sustained.json":
			var d = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary:
				sustained = d
		elif f.begins_with("exit_") and f.ends_with(".txt"):
			exit_codes[f.trim_prefix("exit_").trim_suffix(".txt")] = int(FileAccess.get_file_as_string(path).strip_edges())
		elif f.ends_with(".log"):
			for line in FileAccess.get_file_as_string(path).split("\n"):
				if line.begins_with("ERROR:") or line.begins_with("SCRIPT ERROR:"):
					errors.append("%s: %s" % [f, line.strip_edges()])
	loads.sort_custom(func(a, b): return int(a.get("run", 0)) < int(b.get("run", 0)))

	var report := PerfReport.build(loads, sustained, PerfReport.load_criteria(), {"exit_codes": exit_codes, "engine_errors": errors})
	FileAccess.open(dir.path_join("relatorio.md"), FileAccess.WRITE).store_string(report["markdown"])
	FileAccess.open(dir.path_join("resultados.csv"), FileAccess.WRITE).store_string(report["csv"])
	print(report["markdown"])
	print("Relatório salvo em: ", dir.path_join("relatorio.md"))
	quit(1 if strict and report["overall"] == PerfReport.FAIL else 0)
