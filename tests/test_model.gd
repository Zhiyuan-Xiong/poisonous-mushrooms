extends SceneTree
const Model = preload("res://scripts/runner_model.gd")
var failures: Array[String] = []
var checks: int = 0
var bot_results: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func isolated():
	var m = Model.new()
	m.start(42)
	m.entities.clear()
	m._next_wave = 10000
	return m

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var m = Model.new()
	m.reset(42)
	check(m.state == "ready" and m.distance == 0 and m.coins == 0,"fresh title state")
	m.step(1)
	check(m.distance == 0,"ready does not move")
	m.shift_lane(1)
	check(m.lane == 0,"ready ignores movement")
	m.start(42)
	m.shift_lane(1)
	m.shift_lane(1)
	check(m.lane == 1,"right clamps to lane 1")
	m.shift_lane(-1)
	m.shift_lane(-1)
	m.shift_lane(-1)
	check(m.lane == -1,"left clamps to lane -1")
	m.step(0.2)
	check(is_equal_approx(m.player_x,-1),"lane transition reaches target")
	var d: float = m.distance
	m.toggle_pause()
	m.step(0.25)
	check(m.distance == d and m.state == "paused","paused world freezes")
	m.toggle_pause()
	m.step(.1)
	check(m.distance > d,"resume advances")
	m = isolated()
	m.add_coin(0,0.1)
	m.add_coin(1,0.1)
	m.step(.25)
	check(m.coins == 1,"swept coin crossing and wrong lane exclusion")
	m = isolated()
	m.add_hazard("rock",0,.1)
	m.step(.25)
	check(m.state == "failed","low rock collision fails")
	d = m.distance
	m.step(.25)
	check(m.distance == d,"failure freezes distance")
	m = isolated()
	check(m.jump(),"ground jump accepted")
	m.step(.14)
	check(m.jump_height > .65 and not m.jump(),"jump rises and blocks double jump")
	m.add_hazard("rock",0,.1,.65)
	m.step(.1)
	check(m.state == "playing","jump clears low rock")
	m.add_hazard("monster",0,.1,2.2)
	m.step(.1)
	check(m.state == "failed","mushroom monster requires lane avoidance")
	m = isolated()
	m.shift_lane(1)
	m.add_hazard("monster",0,3.0,2.2)
	m.step(.25)
	m.step(.25)
	check(m.state == "playing" and m.player_x == 1,"lane change avoids monster")
	m = isolated()
	m.distance = 999.9
	m.step(.25)
	check(m.state == "won" and m.distance == 1000.0,"exact 1000 meter win")
	check(m.speed == 15.0,"speed caps at 15 meters/sec")
	m = isolated()
	m.distance = 249.95
	m.step(0.05)
	check(m.events.filter(func(e: Dictionary) -> bool: return e["type"]=="milestone" and e["distance"]==250.0).size()==1,"250 meter floating mushroom fires once")
	m.events.clear()
	m.step(0.1)
	check(m.events.filter(func(e: Dictionary) -> bool: return e["type"]=="milestone").is_empty(),"milestone does not repeat each frame")
	m.distance = 499.95
	m.step(0.05)
	check(m.events.filter(func(e: Dictionary) -> bool: return e["type"]=="milestone" and e["distance"]==500.0).size()==1,"500 meter floating mushroom")
	m.events.clear()
	m.distance=749.95
	m.step(0.05)
	check(m.events.filter(func(e: Dictionary) -> bool: return e["type"]=="milestone" and e["distance"]==750.0).size()==1,"750 meter floating mushroom")
	m.events.clear()
	m.distance=999.95
	m.step(0.05)
	check(m.state=="won" and m.events.filter(func(e: Dictionary) -> bool: return e["type"]=="milestone" and e["distance"]==1000.0).size()==1,"1000 meter floating mushroom coexists with victory")
	m.start(42)
	check(m.coins == 0 and m.distance == 0 and m.lane == 0 and m.jump_height == 0,"retry resets full state")
	var a = Model.new()
	var b = Model.new()
	a.start(823)
	b.start(823)
	check(JSON.stringify(a.entities) == JSON.stringify(b.entities),"seed reproduces complete entity layout")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/asset_manifest.json"))
	for layout_seed in range(1,11):
		var layout = Model.new()
		layout.scenery_catalog = manifest["props"]
		layout.reset(layout_seed)
		for e in layout.entities:
			if e["kind"] == "decor" and str(e["prop"]).begins_with("mushroom_"):
				check(float(e["stretch_x"]) == 1.0 and float(e["stretch_y"]) == 1.0,"mushroom proportions stay uniform")
		for side in [-1,1]:
			var low_z: Array[float] = []
			for e in layout.entities:
				if e["kind"] != "decor" or int(e["side"]) != side:
					continue
				for p in manifest["props"]:
					if e["prop"] == p["id"] and p["group"] in ["low","bank"]:
						low_z.append(float(e["z"]))
			low_z.sort()
			for i in range(1,low_z.size()):
				check(low_z[i]-low_z[i-1] < 8.0,"roadside ground has continuous connecting groups")
	for seed_value in range(1,101):
		_run_bot(seed_value)
	check(bot_results.size() == 100,"100 seeded complete playthroughs")
	var file := FileAccess.open("res://verification/model-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"playthroughs":bot_results}, "\t"))
	file.close()
	print("MODEL_TESTS checks=",checks," failures=",failures.size()," playthroughs=",bot_results.size())
	quit(0 if failures.is_empty() else 1)

func _run_bot(seed_value: int) -> void:
	var m = Model.new()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/asset_manifest.json"))
	m.scenery_catalog = catalog["props"]
	m.start(seed_value)
	var frames: int = 0
	while m.state == "playing" and frames < 15000:
		var blocked: Array[int] = []
		var nearest: float = 1000
		for e in m.entities:
			if e["kind"] in ["rock","monster"] and float(e["z"]) > 0 and not e["handled"]:
				nearest = minf(nearest,float(e["z"])/(m.speed+float(e.get("extra_speed",0))))
		for e in m.entities:
			if e["kind"] in ["rock","monster"] and float(e["z"]) > 0 and not e["handled"]:
				var arrival: float = float(e["z"])/(m.speed+float(e.get("extra_speed",0)))
				if arrival < minf(1.1,nearest+.45):
					blocked.append(int(e["lane"]))
		if m.lane in blocked:
			var candidates: Array[int] = []
			for l in [-1,0,1]:
				if not int(l) in blocked:
					candidates.append(int(l))
			if not candidates.is_empty():
				candidates.sort_custom(func(x: int,y: int) -> bool: return absi(x-m.lane)<absi(y-m.lane))
				m.shift_lane(signi(candidates[0]-m.lane))
			else:
				m.jump()
		m.step(1.0/60.0)
		m.events.clear()
		frames += 1
	check(m.state == "won","reachable full course seed "+str(seed_value)+" ended "+m.state+" at "+str(m.distance))
	var previous_safe: int = 0
	for wave in m.wave_log:
		check(wave["blocked"].size() <= 2 and not wave["safe"] in wave["blocked"],"wave always has an open lane seed "+str(seed_value))
		check(absi(int(wave["safe"])-previous_safe)<=1,"safe lane never jumps across two lanes seed "+str(seed_value))
		previous_safe = int(wave["safe"])
	bot_results.append({"seed":seed_value,"state":m.state,"distance":m.distance,"coins":m.coins,"waves":m.wave_log.size(),"seconds":m.elapsed,"frames":frames})
