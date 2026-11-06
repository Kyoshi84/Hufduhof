extends SceneTree
## Ładuje wszystkie skrypty projektu (z autoloadami), żeby wypisać błędy składni z numerami linii.
func _initialize() -> void:
	var files: Array = []
	_scan("res://scripts", files)
	var bad := 0
	for f in files:
		var s = load(f)
		if s == null or not s.can_instantiate():
			print("BŁĄD: ", f)
			bad += 1
	print("skryptów: %d, z błędami: %d" % [files.size(), bad])
	quit(1 if bad > 0 else 0)

func _scan(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		_scan(dir + "/" + sub, out)
