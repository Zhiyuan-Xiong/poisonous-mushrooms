extends Control
const Model = preload("res://scripts/runner_model.gd")
const Effects = preload("res://scripts/effects.gd")
const FONT_PATH := "res://assets/fonts/WenCangShuFang-2.ttf"
var model = Model.new()
var assets: Dictionary
var game_font: Font
var hud_distance: Label
var hud_coins: Label
var progress: ProgressBar
var menu: Control
var result_panel: Control
var result_art: TextureRect
var result_words: Label
var result_stats: Label
var pause_panel: Control
var dim: ColorRect
var pause_button: Button
var mute_button: Button
var control_hint: Label
var frame_art: TextureRect
var music: AudioStreamPlayer
var sfx: AudioStreamPlayer
var effects: Node2D
var last_state: String = ""
var muted: bool = false
var capture_mode: bool = false

func _ready() -> void:
	assets = JSON.parse_string(FileAccess.get_file_as_string("res://assets/asset_manifest.json"))
	game_font = load(FONT_PATH)
	var game_theme := Theme.new()
	game_theme.default_font = game_font
	game_theme.default_font_size = 30
	theme = game_theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	model.scenery_catalog = assets["props"]
	model.reset()
	$World.setup(model,assets)
	$World.modulate = Color(0.79,0.81,0.85,1.0)
	_build_interface()
	_setup_audio()
	_update_ui()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_mode = true
			call_deferred("_capture",arg.trim_prefix("--capture="))
	if not capture_mode and DisplayServer.get_name() != "headless":
		music.play()

func _label(parent: Node, text: String, rect: Rect2, font_size: int, color: Color = Color("eee8c4")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",game_font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _box(color: Color, border: Color, radius: int = 14) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	return box

func _button(parent: Node, text: String, rect: Rect2, action: Callable, small: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font",game_font)
	button.add_theme_font_size_override("font_size",24 if small else 34)
	button.add_theme_color_override("font_color",Color("eee8c4"))
	button.add_theme_stylebox_override("normal",_box(Color("193d43"),Color("a99b66")))
	button.add_theme_stylebox_override("hover",_box(Color("27535b"),Color("e5d28e")))
	button.add_theme_stylebox_override("pressed",_box(Color("326470"),Color("e5d28e")))
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func _image(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.texture = load(path)
	sprite.position = rect.position
	sprite.size = rect.size
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sprite)
	return sprite

func _layer() -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	return layer

func _build_interface() -> void:
	var vignette := ColorRect.new()
	vignette.size = Vector2(720,1560)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = load("res://shaders/vignette.gdshader")
	vignette.material = vignette_material
	add_child(vignette)
	var mist := ColorRect.new()
	mist.size = Vector2(720,1560)
	mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/mist.gdshader")
	mist.material = material
	add_child(mist)
	effects = Effects.new()
	add_child(effects)
	var interface := _layer()
	interface.modulate = Color(0.93,0.93,0.90,1.0)
	var hud := Panel.new()
	hud.position = Vector2(158,179)
	hud.size = Vector2(404,151)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_theme_stylebox_override("panel",_box(Color(0.035,0.10,0.14,0.88),Color("887f58"),12))
	interface.add_child(hud)
	hud_distance = _label(hud,"0 米",Rect2(4,9,208,49),39)
	hud_coins = _label(hud,"0 枚",Rect2(237,9,153,49),36,Color("e3cc83"))
	_image(hud,str(assets["coin"]["path"]),Rect2(210,16,36,36))
	_label(hud,"穿过蘑菇森林 · 目标 1000 米",Rect2(10,62,384,33),23,Color("a3c4c4"))
	progress = ProgressBar.new()
	progress.position = Vector2(108,113)
	progress.size = Vector2(188,9)
	progress.max_value = 1000
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_theme_stylebox_override("background",_box(Color("183039"),Color.TRANSPARENT,4))
	progress.add_theme_stylebox_override("fill",_box(Color("b6ae75"),Color.TRANSPARENT,4))
	hud.add_child(progress)
	pause_button = _button(interface,"暂停",Rect2(175,282,72,37),_pause,true)
	mute_button = _button(interface,"声音",Rect2(475,282,72,37),_mute,true)
	menu = _layer()
	_label(menu,"毒蘑菇",Rect2(130,363,460,87),67,Color("e8d99b"))
	_label(menu,"向森林深处奔跑",Rect2(130,451,460,45),28,Color("a9cece"))
	_image(menu,str(assets["ui"]["start"]["path"]),Rect2(68,509,584,389))
	_label(menu,"游戏开始",Rect2(203,742,314,75),48,Color("446b6b"))
	var hit := Button.new()
	hit.position = Vector2(165,717)
	hit.size = Vector2(390,116)
	hit.focus_mode = Control.FOCUS_NONE
	for style in ["normal","hover","pressed","focus"]:
		hit.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.pressed.connect(_start)
	menu.add_child(hit)
	_label(menu,"点击横幅 / 回车开始",Rect2(120,905,480,48),27,Color("c5d7cc"))
	_label(menu,"A / D 或左右键   切换道路\n空格跳跃   ·   低岩石可跳过\n蘑菇怪兽与高石柱需要绕开",Rect2(88,1241,544,127),27,Color("c0d4d1"))
	control_hint = _label(interface,"A / D  左右移动       空格  跳跃",Rect2(100,1407,520,45),25,Color("b4c9c6"))
	dim = ColorRect.new()
	dim.size = Vector2(720,1560)
	dim.color = Color(0.015,0.025,0.06,0.74)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	result_panel = _layer()
	result_art = _image(result_panel,str(assets["ui"]["victory"]["path"]),Rect2(40,521,640,427))
	result_words = _label(result_panel,"",Rect2(159,778,402,88),38,Color("806c39"))
	result_stats = _label(result_panel,"",Rect2(97,977,526,66),33)
	_button(result_panel,"再跑一次",Rect2(131,1092,458,77),_start)
	_button(result_panel,"回到开始",Rect2(188,1193,344,66),_back_to_menu)
	pause_panel = _layer()
	_label(pause_panel,"森林在等你",Rect2(130,605,460,97),58)
	_label(pause_panel,"游戏已暂停",Rect2(130,712,460,57),32,Color("b3ccca"))
	_button(pause_panel,"继续奔跑",Rect2(151,831,418,79),_pause)
	_button(pause_panel,"回到开始",Rect2(188,943,344,66),_back_to_menu)
	move_child(effects,get_child_count()-1)
	# The ornamental frame remains stationary over every game state.
	frame_art = _image(_layer(),str(assets["ui"]["frame"]["path"]),Rect2(0,0,720,1560))
	frame_art.modulate = Color(0.83,0.83,0.76,1.0)

func _setup_audio() -> void:
	music = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load("res://audio/forest_run.wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size()/2
	music.stream = stream
	music.volume_db = -14.0
	add_child(music)
	sfx = AudioStreamPlayer.new()
	sfx.volume_db = -10.0
	add_child(sfx)

func _sound(name: String) -> void:
	if not muted and not capture_mode and DisplayServer.get_name() != "headless":
		sfx.stream = load("res://audio/"+name+".wav")
		sfx.play()

func _start() -> void:
	$World.omen_elapsed = -1.0
	music.stream_paused = false
	model.start()
	effects.clear()
	if not music.playing and not capture_mode and DisplayServer.get_name() != "headless":
		music.play()
	_update_ui()

func _back_to_menu() -> void:
	$World.omen_elapsed = -1.0
	music.stream_paused = false
	model.reset()
	effects.clear()
	if not music.playing and not capture_mode and DisplayServer.get_name() != "headless":
		music.play()
	_update_ui()

func _pause() -> void:
	model.toggle_pause()
	music.stream_paused = model.state == "paused"
	_update_ui()

func _mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0,muted)
	mute_button.text = "静音" if muted else "声音"

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode
	if key in [KEY_A,KEY_LEFT]:
		model.shift_lane(-1)
	elif key in [KEY_D,KEY_RIGHT]:
		model.shift_lane(1)
	elif key == KEY_SPACE:
		model.jump()
	elif key in [KEY_ESCAPE,KEY_P]:
		_pause()
	elif key == KEY_ENTER:
		if model.state in ["ready","failed","won"]:
			_start()
		elif model.state == "paused":
			_pause()
	elif key == KEY_R and model.state in ["failed","won"]:
		_start()
	_update_ui()

func _process(delta: float) -> void:
	if capture_mode:
		return
	model.step(delta)
	for event in model.events:
		match str(event["type"]):
			"coin":
				_sound("coin")
				effects.pickup($World.project_point(float(event["x"]),0,float(event["height"])))
			"jump":
				_sound("jump")
			"milestone":
				$World.reveal_mushroom()
			"failed":
				music.stop()
				_sound("failure")
			"won":
				music.stop()
				_sound("victory")
				effects.celebrate()
	model.events.clear()
	_update_ui()

func _update_ui() -> void:
	hud_distance.text = str(int(model.distance))+" 米"
	hud_coins.text = str(model.coins)+" 枚"
	progress.value = model.distance
	menu.visible = model.state == "ready"
	control_hint.visible = model.state == "playing"
	result_panel.visible = model.state in ["failed","won"]
	pause_panel.visible = model.state == "paused"
	dim.visible = result_panel.visible or pause_panel.visible
	pause_button.visible = model.state in ["playing","paused"]
	pause_button.text = "继续" if model.state == "paused" else "暂停"
	if model.state != last_state:
		if model.state in ["failed","won"]:
			var won: bool = model.state == "won"
			result_art.texture = load(str(assets["ui"]["victory" if won else "failure"]["path"]))
			result_words.text = "蘑菇们都很佩服你" if won else "被蘑菇打倒了"
			result_words.add_theme_font_size_override("font_size",35 if won else 42)
			result_words.add_theme_color_override("font_color",Color("806c39") if won else Color("626c9b"))
			result_stats.text = "%d 米     蘑菇金币 %d 枚" % [int(model.distance),model.coins]
		last_state = model.state

func _capture(mode: String) -> void:
	model.reset(7321)
	if mode != "ready":
		model.start(7321)
		model.distance = 184.0
		model.speed = 8.84
		model.coins = 27
		model.elapsed = 6.21
		model.entities = model.entities.filter(func(e: Dictionary) -> bool: return e["kind"] == "decor")
		model.add_hazard("monster",-1,12,2.2,0)
		model.add_hazard("monster",1,22,2.2,2)
		model.add_hazard("rock",1,5,model.LOW_ROCK_CLEARANCE,0)
		for z in [2.0,4.0,6.0,8.0,10.0]:
			model.add_coin(0,z)
		if mode == "won":
			model.state = "won"
			model.distance = 1000
			model.coins = 183
			effects.celebrate()
		elif mode == "failed":
			model.state = "failed"
		elif mode == "paused":
			model.state = "paused"
		elif mode == "milestone":
			model.distance = 250.0
			$World.reveal_mushroom()
			$World.omen_elapsed = 1.75
	_update_ui()
	var screenshot: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			screenshot = arg.trim_prefix("--screenshot=")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().create_timer(0.20).timeout
	await RenderingServer.frame_post_draw
	if not screenshot.is_empty():
		var error: Error = get_viewport().get_texture().get_image().save_png(screenshot)
		print("CAPTURE ",mode," ",screenshot," error=",error)
	get_tree().quit()
