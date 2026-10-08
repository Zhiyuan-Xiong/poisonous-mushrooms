extends SceneTree
var failures: Array[String] = []
var checks: int = 0
var game
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		push_error(text)
func _initialize() -> void:
	call_deferred("run")
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventKey.new()
	release.physical_keycode = code
	release.keycode = code
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
func inspect(node: Node) -> void:
	if node is Label or node is Button:
		check(node.get_theme_font("font").resource_path == game.FONT_PATH,"user font on "+str(node.get_path()))
		for i in node.text.length():
			var c: int = node.text.unicode_at(i)
			if c > 32:
				check(game.game_font.has_char(c),"font glyph "+node.text[i])
	for child in node.get_children():
		inspect(child)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.capture_mode = true
	check(game.model.state == "ready" and game.menu.visible,"start screen ready")
	check(game.result_art.size == Vector2(640,427),"badge respects layout rectangle")
	check(game.hud_coins.position == Vector2(237,9),"coin HUD label layout")
	check(game.get_node("World").textures.size() == game.assets["props"].size(),"all independent roadside props loaded")
	check(game.get_node("World").contact_variants.size() == 4,"four distinct base grass forms loaded")
	check(game.get_node("World").floating_frames.size()==12,"floating tooth mushroom has 12 frames")
	check(game.get_node("World").monster_frames.size() == 4,"four 12 frame monsters loaded")
	for frames in game.get_node("World").monster_frames:
		check(frames.size() == 12,"monster run has 12 frames")
	var frame: Control = game.frame_art
	check(frame.size == Vector2(720,1560),"fixed gold frame fits portrait viewport")
	game.menu.get_children()[4].pressed.emit()
	check(game.model.state == "playing","clicking start button begins run")
	await key(KEY_D)
	check(game.model.lane == 1,"actual D input routes to right lane")
	await key(KEY_LEFT)
	check(game.model.lane == 0,"actual left arrow routes to center")
	await key(KEY_A)
	check(game.model.lane == -1,"actual A input routes to left")
	await key(KEY_RIGHT)
	check(game.model.lane == 0,"actual right arrow routes to center")
	await key(KEY_SPACE)
	check(game.model.jump_velocity > 0,"actual Space input jumps")
	await key(KEY_ESCAPE)
	check(game.model.state == "paused" and game.pause_panel.visible,"Escape pauses with overlay")
	await key(KEY_ESCAPE)
	check(game.model.state == "playing" and not game.pause_panel.visible,"Escape resumes")
	game._mute()
	check(game.muted and AudioServer.is_bus_mute(0),"mute changes audio bus")
	game._mute()
	game.model.events.append({"type":"milestone","distance":250.0})
	game.capture_mode=false
	game._process(0.0)
	game.capture_mode=true
	check(game.get_node("World").omen_elapsed>=0.0,"milestone event triggers floating mushroom renderer")
	game.model.state = "failed"
	game._update_ui()
	check(game.dim.visible and game.result_words.text == "被蘑菇打倒了","failure darkens scene and correct phrase")
	inspect(game)
	await key(KEY_R)
	check(game.model.state == "playing" and game.model.distance == 0,"R restarts after failure")
	game.model.state = "won"
	game.model.distance = 1000
	game._update_ui()
	check(game.result_words.text == "蘑菇们都很佩服你" and game.result_panel.visible,"victory phrase")
	check(frame.position == Vector2.ZERO and frame.size == Vector2(720,1560),"gold frame stays fixed in results")
	inspect(game)
	game.effects.celebrate()
	check(game.effects.particles.size() >= 45,"victory sparkles created")
	game._back_to_menu()
	check(game.model.state == "ready" and game.menu.visible,"return to menu")
	var file := FileAccess.open("res://verification/integration-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"font":game.FONT_PATH,"engine":Engine.get_version_info()}, "\t"))
	file.close()
	print("INTEGRATION_TESTS checks=",checks," failures=",failures.size())
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
