extends Node2D
## Perspective is computed from world meters; the square road texture has no baked perspective.
const FOCAL := 1080.0
const CAMERA_DISTANCE := 5.0
const EYE_HEIGHT := 3.35
const HORIZON := 540.0
const FOG := Color(0.065,0.15,0.21,1.0)
var model: RefCounted
var manifest: Dictionary
var textures: Dictionary = {}
var props: Dictionary = {}
var player_frames: Array[Texture2D] = []
var monster_frames: Array = []
var background: Texture2D
var ground: Texture2D
var canopy: Texture2D
var coin: Texture2D
var idle: Texture2D
var meadow: Texture2D
var fog_texture: Texture2D
var contact_grass: Texture2D
var contact_variants: Array[Texture2D] = []
var floating_frames: Array[Texture2D] = []
var omen_elapsed: float = -1.0
var ambient: float = 0.0
var render_role: String = "root"

func setup(game_model: RefCounted, assets: Dictionary) -> void:
	model = game_model
	manifest = assets
	background = load(str(assets["scene"]["background"]["path"]))
	ground = load(str(assets["scene"]["ground"]["path"]))
	canopy = load(str(assets["scene"]["canopy"]["path"]))
	coin = load(str(assets["coin"]["path"]))
	idle = load(str(assets["player"]["idle"]["path"]))
	meadow = load("res://assets/scene/meadow_grass.png")
	if ResourceLoader.exists("res://assets/scene/distant_fog.png"):
		fog_texture = load("res://assets/scene/distant_fog.png")
	if ResourceLoader.exists("res://assets/scene/grass_contact.png"):
		contact_grass = load("res://assets/scene/grass_contact.png")
		contact_variants.append(contact_grass)
	for id in ["11_tall_reeds","13_fern_skirt","15_curved_verge"]:
		if ResourceLoader.exists("res://assets/props/"+id+".png"):
			contact_variants.append(load("res://assets/props/"+id+".png"))
	for f in assets["player"]["frames"]:
		player_frames.append(load(str(f["path"])))
	for m in assets["monsters"]:
		var frames: Array[Texture2D] = []
		for f in m["frames"]:
			frames.append(load(str(f["path"])))
		monster_frames.append(frames)
	if assets.has("floating_mushroom"):
		for f in assets["floating_mushroom"]["frames"]:
			floating_frames.append(load(str(f["path"])))
	for p in assets["props"]:
		props[str(p["id"])] = p
		textures[str(p["id"])] = load(str(p["path"]))
	for role in ["backdrop","terrain","distant","fog","near","omen"]:
		var layer = get_script().new()
		layer.name = role.capitalize()
		layer.render_role = role
		for field in ["model","manifest","textures","props","player_frames","monster_frames","floating_frames","background","ground","canopy","coin","idle","meadow","fog_texture","contact_grass","contact_variants"]:
			layer.set(field,get(field))
		if role in ["backdrop","distant"]:
			var soft := ShaderMaterial.new()
			soft.shader = load("res://shaders/distance_soften.gdshader")
			soft.set_shader_parameter("blur_radius",10.0 if role=="backdrop" else 6.0)
			soft.set_shader_parameter("fog_blend",0.27 if role=="backdrop" else 0.34)
			layer.material = soft
		add_child(layer)
	queue_redraw()

func project_point(x: float, z: float, height: float = 0.0) -> Vector2:
	var scale_factor: float = FOCAL/maxf(0.8,z+CAMERA_DISTANCE)
	return Vector2(360.0+x*scale_factor,HORIZON+(EYE_HEIGHT-height)*scale_factor)

func _process(delta: float) -> void:
	if model != null:
		if model.state in ["ready","playing"]:
			ambient += delta
		if render_role=="root" and omen_elapsed>=0.0 and model.state!="paused":
			omen_elapsed += delta
			if omen_elapsed > 5.4 or model.state=="ready":
				omen_elapsed = -1.0
		queue_redraw()

func reveal_mushroom() -> void:
	omen_elapsed = 0.0
	get_node("Omen").queue_redraw()

func _draw() -> void:
	if model == null or background == null:
		return
	if render_role == "root":
		draw_texture_rect(background,Rect2(-4.0,0.0,728.0,1560.0),false)
		return
	if render_role == "omen":
		var t: float = float(get_parent().omen_elapsed)
		if t>=0.0 and not floating_frames.is_empty():
			var opacity: float = smoothstep(0.0,0.65,t)*(1.0-smoothstep(4.4,5.4,t))*0.92
			var frame: int = int(t*10.0)%12
			var bob: float = sin(t*2.1)*5.0
			draw_texture_rect(floating_frames[frame],Rect2(235.0,306.0+bob,250.0,250.0),false,Color(0.89,0.94,1.0,opacity))
		return
	if render_role == "backdrop":
		_draw_distant_groves()
		return
	if render_role == "terrain":
		_draw_meadow()
		_draw_road()
		return
	if render_role == "fog":
		_draw_horizon_haze()
		if fog_texture != null:
			_draw_entity({"kind":"fog","z":15.0})
		return
	var order: Array[Dictionary] = []
	for e in model.entities:
		var z: float = float(e["z"])
		if (render_role=="distant" and z>12.0 and z<82.0) or (render_role=="near" and z>-3.4 and z<=20.0):
			order.append(e)
	if render_role == "near":
		order.append({"kind":"player","z":0.0})
	order.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a["z"])>float(b["z"]))
	for e in order:
		_draw_entity(e)
	# Hanging branches stay at the top of the scene; their bottom tips are complete in the source.
	if render_role == "near":
		draw_texture_rect(canopy,Rect2(-95.0,-190.0,910.0,606.0),false,Color(0.67,0.75,0.82,0.64))

func _depth_color(z: float) -> Color:
	var mist: float = smoothstep(8.0,55.0,z)
	var fade: float = 1.0-smoothstep(35.0,75.0,z)
	return Color(lerpf(1.0,0.40,mist),lerpf(1.0,0.70,mist),lerpf(1.0,0.87,mist),fade)

func _draw_distant_groves() -> void:
	# Independent regions of the same painted forest crossfade and drift more slowly than the road.
	var groves: Array[Rect2] = [Rect2(0,970,1080,950),Rect2(100,1210,880,840),Rect2(0,1430,1080,750)]
	var section: int = int(floor(model.distance/90.0))%3
	var fraction: float = smoothstep(0.0,1.0,fmod(model.distance,90.0)/90.0)
	var drift: float = sin(ambient*0.08+model.distance*0.003)*20.0
	var target := Rect2(-40.0+drift,309.0,800.0,362.0)
	_forest_region(groves[section],target,0.82*(1.0-fraction))
	_forest_region(groves[(section+1)%3],target,0.82*fraction)
	for i in range(4):
		var id: String = "05_round_crown_tree" if i%2==0 else "04_twisted_tree"
		var z: float = 62.0+float(i%2)*16.0
		var x: float = (-4.3 if i<2 else 4.3)+sin(model.distance*0.006+float(i))*0.8
		_sprite(textures[id],x,z,0.0,26.0-float(i%2)*4.0,Vector2(0.5,0.985),Color(0.26,0.44,0.47,0.50))
	# Soft blue rock silhouettes form a second, slightly closer layer behind the broad turf banks.
	for i in range(3):
		var x: float = -4.8+float(i)*4.8+sin(model.distance*0.008+float(i))*0.5
		var z: float = 80.0+float(i%2)*18.0
		var height: float = 13.0+float(i%2)*5.0
		_sprite(textures["08_upright_stone"],x,z,0.0,height,Vector2(0.5,0.985),Color(0.17,0.31,0.35,0.27))

func _forest_region(source: Rect2,target: Rect2,opacity: float) -> void:
	var texture_size: Vector2 = background.get_size()
	var resource_scale := texture_size/Vector2(1080.0,2340.0)
	source = Rect2(source.position*resource_scale,source.size*resource_scale)
	for i in range(24):
		var v0: float = float(i)/24.0
		var v1: float = float(i+1)/24.0
		var a0: float = opacity*smoothstep(0.0,0.23,v0)*(1.0-smoothstep(0.86,1.0,v0))
		var a1: float = opacity*smoothstep(0.0,0.23,v1)*(1.0-smoothstep(0.86,1.0,v1))
		var points := PackedVector2Array([target.position+Vector2(0,v0*target.size.y),target.position+Vector2(target.size.x,v0*target.size.y),target.position+Vector2(target.size.x,v1*target.size.y),target.position+Vector2(0,v1*target.size.y)])
		var u0: float = source.position.x/texture_size.x
		var u1: float = source.end.x/texture_size.x
		var y0: float = (source.position.y+v0*source.size.y)/texture_size.y
		var y1: float = (source.position.y+v1*source.size.y)/texture_size.y
		var uv := PackedVector2Array([Vector2(u0,y0),Vector2(u1,y0),Vector2(u1,y1),Vector2(u0,y1)])
		draw_polygon(points,PackedColorArray([Color(0.72,0.91,0.92,a0),Color(0.72,0.91,0.92,a0),Color(0.72,0.91,0.92,a1),Color(0.72,0.91,0.92,a1)]),uv,background)

func _contact_patch(x: float,z: float,width: float,color: Color,front: bool = false,style: int = 0) -> void:
	if contact_grass == null:
		return
	var tex: Texture2D = contact_grass if front else contact_variants[posmod(style,contact_variants.size())]
	var point: Vector2 = project_point(x,z)
	var pixels: float = clampf(width,0.72,6.5)*FOCAL/maxf(0.8,z+CAMERA_DISTANCE)
	var ratio: float = float(tex.get_height())/float(tex.get_width())
	var size := Vector2(pixels,pixels*ratio*(0.32 if front else (0.70 if style==0 else 0.46)))
	var tint: Color = color
	tint.a *= 0.38 if front else 0.76
	draw_texture_rect(tex,Rect2(point-size*Vector2(0.5,0.55 if front else 0.72),size),false,tint)

func _bank_crest(x: float) -> float:
	return 445.0+86.0*exp(-pow((x-360.0)/179.0,2.0))+12.0*sin(x/95.0)

func _draw_horizon_haze() -> void:
	# Soft haze crosses the curved turf crest, not just a straight horizontal strip.
	for i in range(24):
		var x0: float = float(i)*30.0
		var x1: float = x0+30.0
		for j in range(12):
			var t0: float = float(j)/12.0
			var t1: float = float(j+1)/12.0
			var y0: float = lerpf(-115.0,145.0,t0)
			var y1: float = lerpf(-115.0,145.0,t1)
			var a0: float = 0.43*pow(sin(PI*t0),2.0)
			var a1: float = 0.43*pow(sin(PI*t1),2.0)
			var points := PackedVector2Array([Vector2(x0,_bank_crest(x0)+y0),Vector2(x1,_bank_crest(x1)+y0),Vector2(x1,_bank_crest(x1)+y1),Vector2(x0,_bank_crest(x0)+y1)])
			draw_polygon(points,PackedColorArray([Color(0.29,0.42,0.46,a0),Color(0.29,0.42,0.46,a0),Color(0.29,0.42,0.46,a1),Color(0.29,0.42,0.46,a1)]))

func _draw_meadow() -> void:
	# Broad connected banks cover the distant ground instead of isolated small cutouts.
	var bank := PackedVector2Array()
	var uv := PackedVector2Array()
	for i in range(25):
		var x: float = float(i)*30.0
		var crest: float = _bank_crest(x)+52.0
		bank.append(Vector2(x,crest))
		uv.append(Vector2(x/720.0,0.05))
	bank.append(Vector2(720,1560))
	bank.append(Vector2(0,1560))
	uv.append(Vector2(1.0,1.0))
	uv.append(Vector2(0.0,1.0))
	if meadow != null:
		draw_polygon(bank,PackedColorArray([Color(0.62,0.78,0.79)]),uv,meadow)
		# Feather the broad grassy horizon over 104 pixels to remove a hard bank silhouette.
		for i in range(24):
			var x0: float = float(i)*30.0
			var x1: float = x0+30.0
			for j in range(8):
				var t0: float = float(j)/8.0
				var t1: float = float(j+1)/8.0
				var p := PackedVector2Array([Vector2(x0,_bank_crest(x0)-52.0+104.0*t0),Vector2(x1,_bank_crest(x1)-52.0+104.0*t0),Vector2(x1,_bank_crest(x1)-52.0+104.0*t1),Vector2(x0,_bank_crest(x0)-52.0+104.0*t1)])
				var tex_uv := PackedVector2Array([Vector2(x0/720.0,0.05),Vector2(x1/720.0,0.05),Vector2(x1/720.0,0.05),Vector2(x0/720.0,0.05)])
				draw_polygon(p,PackedColorArray([Color(0.62,0.78,0.79,smoothstep(0.0,1.0,t0)),Color(0.62,0.78,0.79,smoothstep(0.0,1.0,t0)),Color(0.62,0.78,0.79,smoothstep(0.0,1.0,t1)),Color(0.62,0.78,0.79,smoothstep(0.0,1.0,t1))]),tex_uv,meadow)
	else:
		draw_colored_polygon(bank,Color("24514c"))
	var first: int = int(floor(model.distance/8.0))-1
	for tile in range(first+11,first-1,-1):
		var z0: float = maxf(-2.4,float(tile)*8.0-model.distance)
		var z1: float = float(tile+1)*8.0-model.distance
		if z1<=-2.4 or z0>=82.0:
			continue
		for side in [-1,1]:
			var x0: float = 1.5*float(side)
			var x1: float = 12.0*float(side)
			var points := PackedVector2Array([project_point(x0,z0),project_point(x1,z0),project_point(x1,z1),project_point(x0,z1)])
			var tex_uv := PackedVector2Array([Vector2(0,clampf((z1-z0)/8.0,0,1)),Vector2(1,clampf((z1-z0)/8.0,0,1)),Vector2(1,0),Vector2(0,0)])
			var near_color: Color = _depth_color(z0)
			var far_color: Color = _depth_color(z1)
			near_color.a = 1.0
			far_color.a = 1.0
			draw_polygon(points,PackedColorArray([near_color,near_color,far_color,far_color]),tex_uv,meadow)

func _draw_road() -> void:
	var near_z: float = -2.4
	var far_z: float = 82.0
	var first: int = int(floor(model.distance))-3
	for cell in range(first+84,first-1,-1):
		var z0: float = maxf(near_z,float(cell)-model.distance)
		var z1: float = float(cell+1)-model.distance
		if z1 <= near_z or z0 >= far_z:
			continue
		var v0: float = float(posmod(cell,8))/8.0
		var v1: float = v0+1.0/8.0
		var near_color: Color = _depth_color(z0)
		var far_color: Color = _depth_color(z1)
		near_color.r *= 0.86
		near_color.g *= 0.90
		near_color.b *= 0.94
		far_color.r *= 0.86
		far_color.g *= 0.90
		far_color.b *= 0.94
		for column in range(3):
			var x0: float = float(column)-1.5
			var x1: float = x0+1.0
			var points := PackedVector2Array([project_point(x0,z0),project_point(x1,z0),project_point(x1,z1),project_point(x0,z1)])
			var u0: float = float(column)/8.0
			var u1: float = u0+1.0/8.0
			var clipped_v: float = lerpf(v0,v1,clampf(z1-z0,0.0,1.0))
			var uv := PackedVector2Array([Vector2(u0,clipped_v),Vector2(u1,clipped_v),Vector2(u1,v0),Vector2(u0,v0)])
			draw_polygon(points,PackedColorArray([near_color,near_color,far_color,far_color]),uv,ground)
			var mist: float = smoothstep(18.0,80.0,(z0+z1)*0.5)*0.63
			draw_colored_polygon(points,Color(FOG.r,FOG.g,FOG.b,mist*far_color.a))
	for edge in [-1.5,1.5]:
		draw_line(project_point(float(edge),near_z),project_point(float(edge),far_z),Color(0.20,0.42,0.40,0.32),1.5,true)

func _sprite(tex: Texture2D, x: float, z: float, height: float, world_height: float, pivot: Vector2, color: Color, flip: bool = false, squash: float = 1.0) -> void:
	var point: Vector2 = project_point(x,z,height)
	var pixels: float = world_height*FOCAL/maxf(0.8,z+CAMERA_DISTANCE)
	var size: Vector2 = tex.get_size()*(pixels/tex.get_height())
	size.x *= squash
	var rect := Rect2(point-size*pivot,size)
	if flip:
		draw_set_transform(point,0.0,Vector2(-1.0,1.0))
		draw_texture_rect(tex,Rect2(-size*pivot,size),false,color)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect(tex,rect,false,color)

func _shadow(x: float, z: float, alpha: float, width: float = 0.35) -> void:
	var p: Vector2 = project_point(x,z)
	var radius: float = width*FOCAL/maxf(0.8,z+CAMERA_DISTANCE)
	draw_set_transform(p,0.0,Vector2(1.0,0.25))
	for ring in range(12):
		var t: float = float(ring)/12.0
		draw_circle(Vector2.ZERO,radius*(1.0-t*0.73),Color(0.023,0.067,0.078,alpha*(0.04+t*0.085)),true,-1.0,true)
	draw_set_transform(Vector2.ZERO)

func _cast_shadow(x: float,z: float,width: float,height: float,alpha: float) -> void:
	# A compact feathered footprint avoids detached shadow wedges from offscreen trees.
	var reach: float = minf(height*0.14,0.50)
	_shadow(x+reach*0.25,z-reach*0.16,alpha*0.65,minf(width*0.36,1.25))
	_shadow(x,z,alpha,minf(width*0.28,1.0))

func _draw_entity(e: Dictionary) -> void:
	var kind: String = str(e["kind"])
	var z: float = float(e["z"])
	if kind == "fog":
		draw_texture_rect(fog_texture,Rect2(-50.0+sin(ambient*0.09)*12.0,360.0,820.0,590.0),false,Color(0.90,0.98,1.0,0.94))
		draw_texture_rect(fog_texture,Rect2(-80.0-sin(ambient*0.07)*14.0,387.0,880.0,300.0),false,Color(0.87,0.95,0.99,1.0))
		return
	if kind == "player":
		_shadow(model.player_x,0.0,0.49/(1.0+model.jump_height),0.41)
		var tex: Texture2D = idle
		if model.state != "ready":
			var frame: int = int(model.elapsed*(12.5+model.speed*0.18))%8
			if model.jump_height > 0.04:
				frame = 3 if model.jump_velocity > 0.0 else 7
			tex = player_frames[frame]
		_sprite(tex,model.player_x,0.0,model.jump_height,2.75,Vector2(0.5,728.0/768.0),Color.WHITE)
		return
	var color: Color = _depth_color(z)
	var blend: float = smoothstep(12.0,20.0,z)
	color.a *= blend if render_role=="distant" else 1.0-blend
	if kind == "decor":
		var p: Dictionary = props[str(e["prop"])]
		var sx: float = float(e.get("stretch_x",1.0))
		var sy: float = float(e.get("stretch_y",1.0))
		var wh: float = float(p["world_height"])*float(e["scale"])*sy*(1.5 if p["group"] in ["mushroom","tree"] else 1.2)
		if p["group"] in ["mushroom","tree"]:
			# Preserve proportions while stopping close sprites from filling the entire portrait.
			var max_pixels: float = 620.0 if p["group"]=="tree" else 460.0
			wh = minf(wh,max_pixels*maxf(0.8,z+CAMERA_DISTANCE)/FOCAL)
		var ww: float = wh*float(p["width"])/float(p["height"])*sx/sy
		var x: float = float(e["side"])*(1.63+ww*0.5+float(e["offset"]))
		var blends_own_base: bool = p["group"] in ["low","bank"]
		if not blends_own_base:
			_contact_patch(x,z,ww+0.35,color,false,int(e.get("ground_style",0)))
		_sprite(textures[str(e["prop"])],x,z,0.0,wh,Vector2(0.5,0.985),color,bool(e["flip"]),sx/sy)
		if not blends_own_base:
			_contact_patch(x,z,ww+0.10,color,true)
	elif kind == "coin":
		var phase: float = ambient*3.0+float(e["phase"])
		var y: float = float(e["height"])+sin(phase)*0.045
		_shadow(float(e["x"])+0.08,z,0.19*color.a,0.13)
		_sprite(coin,float(e["x"]),z,y,0.50,Vector2(0.5,0.5),color,false,0.84+absf(cos(phase*0.65))*0.16)
	elif kind == "monster":
		var frames: Array = monster_frames[int(e["variant"])]
		var frame: int = int(model.elapsed*12.0+float(e["phase"]))%12
		_cast_shadow(float(e["x"]),z,0.68,2.3,0.40*color.a)
		_sprite(frames[frame],float(e["x"]),z,0.0,2.5,Vector2(0.5,480.0/512.0),color)
	elif kind == "rock":
		var tall: bool = int(e["variant"]) == 1
		var id: String = "08_upright_stone" if tall else "06_moss_boulder"
		_contact_patch(float(e["x"]),z,1.06,color)
		_sprite(textures[id],float(e["x"]),z,0.0,1.95 if tall else 1.05,Vector2(0.5,0.985),color)
		_contact_patch(float(e["x"]),z,1.06,color,true)
