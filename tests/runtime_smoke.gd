extends SceneTree
var game
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._start()
	AudioServer.set_bus_mute(0,true)
	var start: int=Time.get_ticks_msec()
	var frames: int=0
	var frame_ms: Array[float]=[]
	while Time.get_ticks_msec()-start<8000:
		var m=game.model
		var blocked: Array[int]=[]
		for e in m.entities:
			if e["kind"] in ["rock","monster"] and not e["handled"] and float(e["z"])>0.0 and float(e["z"])/(m.speed+float(e.get("extra_speed",0)))<1.2:
				blocked.append(int(e["lane"]))
		if m.lane in blocked:
			for candidate in [-1,0,1]:
				if not candidate in blocked:
					m.shift_lane(signi(candidate-m.lane))
					break
		await process_frame
		if Time.get_ticks_msec()-start>1500:
			frames+=1
			frame_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.0)
	var mean: float=0.0
	for ms in frame_ms:
		mean+=ms/maxi(1,frame_ms.size())
	var file=FileAccess.open("res://verification/runtime-smoke.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"duration_ms":Time.get_ticks_msec()-start,"warmup_ms":1500,"rendered_frames_after_warmup":frames,"approx_fps":frames/6.5,"mean_process_ms":mean,"distance":game.model.distance,"coins":game.model.coins,"state":game.model.state,"note":"Native real-time game; no image readback or PNG saving during measurement; automated lane avoidance."},"\t"))
	file.close()
	print("RUNTIME_SMOKE fps=",frames/6.5," mean_process_ms=",mean," distance=",game.model.distance," state=",game.model.state)
	var ok: bool=game.model.state=="playing" and game.model.distance>40.0
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
