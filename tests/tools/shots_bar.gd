extends SceneTree
## Zrzuty paska umiejętności: PC (pełny pasek) i tryb dotykowy (zwinięty pod "..."), przy różnych szerokościach.
var out := "user://shots"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run()

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await _wait(3)
	root.get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("zrzut: ", name)

func _run() -> void:
	var save = root.get_node("Save")
	var game = root.get_node("Game")
	save.save_path = "user://test_bar.json"
	for mode in [2, 1]:
		save.touch_mode = mode
		for hid in ["ivo", "ursa", "modraszka"]:
			game.new_game(hid)
			game.level_id = "wioska"
			var lvl = load("res://scripts/levels/level.gd").new("wioska")
			root.add_child(lvl)
			await _wait(20)
			lvl.hero.position = Iso.cell_center(Vector2i(33, 34))
			lvl.cam.reset_smoothing()
			game.hero.mana = game.hero.max_mana() * 0.6
			game.hero.hp = game.hero.max_hp() * 0.8
			await _wait(10)
			lvl.hero.cooldowns[lvl.hero.bar[1]] = float(lvl.hero.skills[lvl.hero.bar[1]]["odnowienie"]) * 0.99
			lvl.hero.cooldowns[lvl.hero.bar[2]] = float(lvl.hero.skills[lvl.hero.bar[2]]["odnowienie"]) * 0.99
			await _shot("bar_%s_%s" % ["dotyk" if mode == 1 else "pc", hid])
			if mode == 1 and hid == "ivo":
				lvl.hud.skill_bar.expanded = true
				lvl.hud.skill_bar.layout()
				await _shot("bar_dotyk_rozwiniety")
			lvl.queue_free()
			await _wait(3)
	quit(0)
