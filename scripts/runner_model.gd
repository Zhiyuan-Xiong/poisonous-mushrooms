extends RefCounted
## Gameplay uses world meters. Rendering does not influence pickup or collision tests.

const GOAL := 1000.0
const START_SPEED := 7.0
const MAX_SPEED := 15.0
const GRAVITY := 20.0
const JUMP_VELOCITY := 7.8
const FRONTIER := 74.0
const MONSTER_APPROACH := 1.2
const LOW_ROCK_CLEARANCE := 0.82

var state: String = "ready"
var distance: float = 0.0
var speed: float = START_SPEED
var coins: int = 0
var lane: int = 0
var player_x: float = 0.0
var jump_height: float = 0.0
var jump_velocity: float = 0.0
var elapsed: float = 0.0
var entities: Array[Dictionary] = []
var events: Array[Dictionary] = []
var wave_log: Array[Dictionary] = []
var scenery_catalog: Array = []
var rng := RandomNumberGenerator.new()
var _next_wave: float = 15.0
var _next_decor: float = 0.0
var _last_safe: int = 0
var _decor_count: int = 0
var _next_milestone: float = 250.0

func reset(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	state = "ready"
	distance = 0.0
	speed = START_SPEED
	coins = 0
	lane = 0
	player_x = 0.0
	jump_height = 0.0
	jump_velocity = 0.0
	elapsed = 0.0
	entities.clear()
	events.clear()
	wave_log.clear()
	_next_wave = 15.0
	_next_decor = 3.0
	_last_safe = 0
	_decor_count = 0
	_next_milestone = 250.0
	_fill_scenery()
	for z in [7.0, 9.0, 11.0, 13.0, 15.0, 17.0]:
		add_coin(0, float(z))

func start(seed_value: int = 0) -> void:
	reset(seed_value)
	state = "playing"
	_spawn_wave(32.0)
	_spawn_wave(55.0)
	events.append({"type":"started"})

func shift_lane(direction: int) -> void:
	if state == "playing":
		lane = clampi(lane + direction, -1, 1)

func jump() -> bool:
	if state == "playing" and jump_height <= 0.001:
		jump_velocity = JUMP_VELOCITY
		events.append({"type":"jump"})
		return true
	return false

func toggle_pause() -> void:
	if state == "playing":
		state = "paused"
	elif state == "paused":
		state = "playing"

func add_coin(at_lane: int, z: float, height: float = 0.65) -> void:
	entities.append({"kind":"coin", "lane":at_lane, "x":float(at_lane), "z":z,
		"height":height, "phase":rng.randf_range(0.0,TAU), "handled":false})

func add_hazard(kind: String, at_lane: int, z: float, clearance: float = LOW_ROCK_CLEARANCE, variant: int = 0) -> void:
	entities.append({"kind":kind,"lane":at_lane,"x":float(at_lane),"z":z,
		"height":0.0,"clearance":clearance,"variant":variant,"phase":rng.randf()*12.0,
		"extra_speed":MONSTER_APPROACH if kind == "monster" else 0.0,"handled":false})

func step(delta: float) -> void:
	if state != "playing" or delta <= 0.0:
		return
	# Substeps also keep a short keyframe stall from tunnelling through a hazard.
	var remaining: float = minf(delta, 0.25)
	while remaining > 0.00001 and state == "playing":
		var dt: float = minf(remaining, 1.0/60.0)
		_step_fixed(dt)
		remaining -= dt

func _step_fixed(delta: float) -> void:
	speed = minf(MAX_SPEED, START_SPEED + distance*0.01)
	var dt: float = minf(delta, (GOAL-distance)/speed)
	var old_x: float = player_x
	var old_height: float = jump_height
	player_x = move_toward(player_x, float(lane), 7.5*dt)
	if jump_height > 0.0 or jump_velocity > 0.0:
		jump_velocity -= GRAVITY*dt
		jump_height = maxf(0.0, jump_height + jump_velocity*dt)
		if jump_height == 0.0:
			jump_velocity = 0.0
	elapsed += dt
	distance = minf(GOAL, distance+speed*dt)
	for e in entities:
		var old_z: float = float(e["z"])
		var extra: float = float(e.get("extra_speed",0.0))
		e["z"] = old_z-(speed+extra)*dt
		if e["kind"] == "decor" or bool(e["handled"]):
			continue
		# One swept crossing of the player's z-plane, using the interpolated lateral position.
		if old_z >= 0.0 and float(e["z"]) < 0.0:
			e["handled"] = true
			var fraction: float = clampf(old_z/maxf(0.00001,old_z-float(e["z"])),0.0,1.0)
			var hit_x: float = lerpf(old_x,player_x,fraction)
			var hit_height: float = lerpf(old_height,jump_height,fraction)
			var width: float = 0.46 if e["kind"] == "coin" else 0.52
			if absf(hit_x-float(e["x"])) < width:
				if e["kind"] == "coin":
					var ch: float = float(e["height"])
					if ch >= hit_height-0.12 and ch <= hit_height+1.65:
						coins += 1
						e["collected"] = true
						events.append({"type":"coin","x":hit_x,"height":ch})
				elif hit_height < float(e["clearance"]):
					state = "failed"
					events.append({"type":"failed","hazard":e["kind"]})
					break
	entities = entities.filter(func(e: Dictionary) -> bool: return float(e["z"]) > -7.0 and not bool(e.get("collected",false)))
	if state == "failed":
		return
	while distance >= _next_milestone:
		events.append({"type":"milestone","distance":_next_milestone})
		_next_milestone += 250.0
	if distance >= GOAL:
		state = "won"
		events.append({"type":"won"})
		return
	while distance >= _next_wave:
		_spawn_wave(FRONTIER)
		_next_wave += maxf(15.5,speed*1.7)
	_fill_scenery()

func _spawn_wave(z: float) -> void:
	var monster_wave: bool = distance > 55.0 and rng.randf() < lerpf(0.22,0.60,distance/GOAL)
	var extra: float = MONSTER_APPROACH if monster_wave else 0.0
	var arrival: float = z/(speed+extra)
	var available: Array[int] = []
	for candidate in [-1,0,1]:
		if absi(int(candidate)-_last_safe) > 1:
			continue
		var clear: bool = true
		for e in entities:
			if e["kind"] in ["rock","monster"] and not bool(e["handled"]):
				var other_arrival: float = float(e["z"])/(speed+float(e.get("extra_speed",0.0)))
				if absf(other_arrival-arrival) < 1.75 and int(e["lane"]) == int(candidate):
					clear = false
		if clear:
			available.append(int(candidate))
	# If adjacent approach times disagree, leave a coin-only breathing space.
	var empty_wave: bool = available.is_empty()
	var safe: int = _last_safe if empty_wave else available[rng.randi_range(0,available.size()-1)]
	var blocked: Array[int] = []
	if not empty_wave:
		var options: Array[int] = []
		for l in [-1,0,1]:
			if int(l) != safe:
				options.append(int(l))
		if rng.randf() < 0.5:
			options.reverse()
		var count: int = 2 if distance > 160.0 and rng.randf() < lerpf(0.25,0.72,distance/GOAL) else 1
		for i in range(count):
			var l: int = options[i]
			blocked.append(l)
			if monster_wave:
				add_hazard("monster",l,z,2.2,rng.randi_range(0,3))
			else:
				var tall: bool = distance > 240.0 and rng.randf() < 0.25
				add_hazard("rock",l,z,1.9 if tall else LOW_ROCK_CLEARANCE,1 if tall else 0)
	for i in range(5):
		add_coin(safe,z-6.0+float(i)*1.3)
	_last_safe = safe
	wave_log.append({"distance":distance,"safe":safe,"blocked":blocked,"monster":monster_wave,"empty":empty_wave})

func _decor(id: String,side: int,z: float,scale_value: float,offset: float) -> void:
	var sx: float = 1.0
	var sy: float = 1.0
	if not id.begins_with("mushroom_"):
		sx = rng.randf_range(0.78,1.35)
		sy = rng.randf_range(0.78,1.25)
	entities.append({"kind":"decor","prop":id,"side":side,"offset":offset,"z":z-distance,
		"scale":scale_value,"stretch_x":sx,"stretch_y":sy,"ground_style":rng.randi_range(0,3),"flip":rng.randf()<0.5,"handled":false})

func _choose(group: String,compact: bool = false) -> String:
	var choices: Array = scenery_catalog.filter(func(p: Dictionary) -> bool:
		return p["group"] == group and str(p["id"])!="mushroom_11" and (not compact or str(p["id"]) in ["mushroom_0","mushroom_1","mushroom_3","mushroom_5","mushroom_6","mushroom_7","mushroom_8"]))
	if choices.is_empty():
		return ""
	return str(choices[rng.randi_range(0,choices.size()-1)]["id"])

func _fill_scenery() -> void:
	# Outer tree/vine - inner mushroom - road - inner mushroom - outer tree/vine.
	while _next_decor < distance+FRONTIER+12.0:
		for side in [-1,1]:
			var pocket: int = (_decor_count+int(side==1)*2)%4
			var z: float = _next_decor+(rng.randf_range(2.5,4.0) if side==1 else 0.0)
			var anchor: String = _choose("mushroom",pocket==2)
			if not anchor.is_empty():
				_decor(anchor,side,z,rng.randf_range(0.63,0.82) if pocket==2 else rng.randf_range(0.95,1.24),rng.randf_range(0.08,0.28))
				var plant: String = _choose("low")
				if not plant.is_empty():
					_decor(plant,side,z-0.3,rng.randf_range(1.1,1.45),0.08)
			var outer: Array[String] = ["04_twisted_tree","05_round_crown_tree","mushroom_11"]
			if not scenery_catalog.is_empty() and pocket!=2:
				_decor(outer[rng.randi_range(0,outer.size()-1)],side,z+rng.randf_range(4.6,6.4),rng.randf_range(1.3,1.8),rng.randf_range(0.75,1.20))
			var bank: String = _choose("bank")
			if not bank.is_empty():
				_decor(bank,side,z+1.0,rng.randf_range(1.2,1.65),0.03)
			var terrain: Array = scenery_catalog.filter(func(p: Dictionary) -> bool: return p["group"] in ["rock","wood"] and float(p["world_height"]) <= 1.7)
			if not terrain.is_empty():
				_decor(str(terrain[rng.randi_range(0,terrain.size()-1)]["id"]),side,z+(0.5 if pocket==2 else 5.5),rng.randf_range(1.45,1.95),rng.randf_range(0.03,0.32))
				# A rock is dressed as a group with plants and wood, rather than sitting alone.
				var low: String = _choose("low")
				if not low.is_empty():
					_decor(low,side,z+4.7,rng.randf_range(1.1,1.5),0.04)
				_decor("09_hollow_stump",side,z+6.7,rng.randf_range(0.9,1.3),0.55)
			# A compact mushroom and low verge connect the spaces between the tall anchors.
			var connector: String = _choose("mushroom",true)
			if not connector.is_empty():
				_decor(connector,side,z+8.0,rng.randf_range(0.53,0.78),0.10)
			var verge: String = _choose("low")
			if not verge.is_empty():
				_decor(verge,side,z+8.8,rng.randf_range(1.3,1.75),0.03)
		_decor_count += 1
		_next_decor += rng.randf_range(11.5,15.0)
