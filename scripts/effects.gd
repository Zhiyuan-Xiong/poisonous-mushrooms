extends Node2D
var particles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var flash: float = 0.0

func clear() -> void:
	particles.clear()
	flash = 0
	queue_redraw()

func pickup(point: Vector2) -> void:
	for i in range(7):
		var angle: float = rng.randf()*TAU
		particles.append({"p":point,"v":Vector2(cos(angle),sin(angle))*rng.randf_range(35,90),"life":0.55,"max":0.55,"size":3.5})

func celebrate() -> void:
	flash = 0.48
	for i in range(45):
		var life: float = rng.randf_range(1.0,2.8)
		particles.append({"p":Vector2(rng.randf_range(80,640),rng.randf_range(345,1050)),
			"v":Vector2(rng.randf_range(-24,24),rng.randf_range(-55,-14)),"life":life,"max":life,"size":rng.randf_range(3,9)})

func _process(delta: float) -> void:
	flash = maxf(0,flash-delta)
	for p in particles:
		p["life"] = float(p["life"])-delta
		p["p"] = Vector2(p["p"])+Vector2(p["v"])*delta
	particles = particles.filter(func(p: Dictionary) -> bool: return float(p["life"])>0)
	queue_redraw()

func _draw() -> void:
	if flash>0:
		draw_rect(Rect2(0,0,720,1560),Color(0.95,0.86,0.53,flash*0.19))
	for p in particles:
		var center: Vector2 = p["p"]
		var s: float = float(p["size"])
		var alpha: float = clampf(float(p["life"])/0.5,0,1)
		var shape := PackedVector2Array([Vector2(0,-s*1.5),Vector2(s*0.3,-s*0.3),Vector2(s,0),
			Vector2(s*0.3,s*0.3),Vector2(0,s*1.5),Vector2(-s*0.3,s*0.3),Vector2(-s,0),Vector2(-s*0.3,-s*0.3)])
		for i in shape.size():
			shape[i] += center
		draw_colored_polygon(shape,Color(0.95,0.87,0.56,alpha))

