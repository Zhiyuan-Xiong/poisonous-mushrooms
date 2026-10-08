extends SceneTree
var game
var shots: String
var clip: String
var frame_times: Array[float] = []
func _initialize() -> void:
	call_deferred("run")
func press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventKey.new()
	release.physical_keycode=code
	release.keycode=code
	Input.parse_input_event(release)
func avoid() -> void:
	var m=game.model
	var nearest: float = 1000.0
	var blocked: Array[int]=[]
	for e in m.entities:
		if e["kind"] in ["rock","monster"] and float(e["z"])>0.0 and not e["handled"]:
			nearest=minf(nearest,float(e["z"])/(m.speed+float(e.get("extra_speed",0))))
	for e in m.entities:
		if e["kind"] in ["rock","monster"] and float(e["z"])>0.0 and not e["handled"]:
			var arrival: float = float(e["z"])/(m.speed+float(e.get("extra_speed",0)))
			if arrival<minf(1.1,nearest+0.45):
				blocked.append(int(e["lane"]))
	if m.lane in blocked:
		for target in [-1,0,1]:
			if not target in blocked:
				m.shift_lane(signi(target-m.lane))
				break
func screenshot(file: String) -> void:
	game._update_ui()
	for layer in game.get_node("World").get_children():
		layer.queue_redraw()
	game.get_node("World").queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error=root.get_texture().get_image().save_png(file)
	if error!=OK:
		push_error("Capture failed: "+file)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--clip="):
			clip=arg.trim_prefix("--clip=")
		if arg.begins_with("--shots="):
			shots=arg.trim_prefix("--shots=")
	if clip.is_empty() or shots.is_empty():
		push_error("Pass absolute --clip and --shots output directories")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(clip)
	DirAccess.make_dir_recursive_absolute(shots)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.music.stop()
	AudioServer.set_bus_mute(0,true)
	game.model.start(7321)
	for frame in range(72):
		if frame==12:
			await press_key(KEY_SPACE)
		if frame==25:
			await press_key(KEY_D)
		if frame==48:
			await press_key(KEY_A)
		for step in range(6):
			avoid()
			game._process(1.0/60.0)
		await screenshot(clip.path_join("frame-%03d.png"%frame))
		if frame%12==0:
			await screenshot(shots.path_join("motion-%03d.png"%frame))
		frame_times.append(float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.0)
	var captures: Array[Dictionary]=[]
	for target_distance in [100.0,350.0,650.0,970.0]:
		while game.model.distance<target_distance and game.model.state=="playing":
			avoid()
			game.model.step(1.0/60.0)
			game.model.events.clear()
		var name: String="course-%04d.png"%int(game.model.distance)
		await screenshot(shots.path_join(name))
		captures.append({"distance":game.model.distance,"state":game.model.state,"file":name})
	var file=FileAccess.open("res://verification/motion-capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"mode":"native Godot viewport; actual model progression; deterministic seed 7321; automated avoidance for visual review","frames":72,"frame_delay_ms":100,"input":"Space, D, A events","course_captures":captures,"process_frame_ms_samples":frame_times},"\t"))
	file.close()
	print("MOTION_CAPTURE frames=72 final_distance=",game.model.distance," state=",game.model.state)
	game.queue_free()
	await process_frame
	quit(0 if captures.size()==4 and captures[-1]["state"]=="playing" else 1)
