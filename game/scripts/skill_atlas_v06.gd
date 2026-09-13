extends Node2D
## Dedicated additive draw layer. Parent must share game's screen-space transform.
## Main calls begin_frame(), then render() during its draw, once per event/shot.
const Dungeon = preload("res://scripts/dungeon.gd")
const Presentation = preload("res://scripts/character_presentation.gd")
const MAX_EXTENT = 224.0
static var catalog: Dictionary = {}
var commands: Array = []
var textures: Dictionary = {}

static func data() -> Dictionary:
	if catalog.is_empty():
		catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/attacks/catalog.json"))
	return catalog

static func binding(event: Dictionary, channel: String = "event") -> Dictionary:
	var b: Dictionary = data().bindings.get(str(event.get("skill_id", "")), {})
	if b.is_empty() or b.channel != channel: return {}
	if str(event.get("class_id", "")) != b.class_id: return {}
	if str(event.get("skill_mode", "")) != b.mode: return {}
	if event.get("skill_phase", "") == "windup": return {}
	if event.get("cancelled", false): return {}
	return b

## Pure sampling. t is elapsed seconds, not normalized progress or simulation time.
## Pulse samples replay at actual provided offsets; no damage or new pulse schedule.
static func sample(event: Dictionary, t: float, duration: float, channel: String = "event") -> Dictionary:
	var b = binding(event, channel)
	if b.is_empty() or not is_finite(t) or not is_finite(duration) or duration <= 0 or t < 0 or t >= duration: return {}
	var a: Dictionary = data().animations[b.effect_id]
	var age = t
	var span = duration
	var pulses = event.get("pulse_times", [])
	if channel == "event" and not pulses.is_empty():
		var last = -1.0
		for value in pulses:
			var pulse = float(value)
			if is_finite(pulse) and pulse >= 0 and pulse <= t: last = maxf(last, pulse)
		if last < 0: return {}
		age = t - last
		span = minf(float(a.duration), duration - last)
		if age >= span: return {}
	var progress = clampf(age / span, 0, 1)
	var index = mini(5, int(progress * 6.0))
	var frame: Dictionary = a.frames[index]
	# Bound every frame, not just frame 3. Never multiply by rank/visual_scale.
	var scale = float(a.runtime_scale)
	var alpha = .55 * minf(1.0, progress / .08) * minf(1.0, (1.0-progress) / .20)
	return {"effect_id": b.effect_id, "sheet": a.sheet, "frame": index, "rect": frame.rect,
		"pivot": frame.pivot, "scale": scale, "alpha": alpha,
		"directional": b.directional, "keep_procedural_link": b.keep_procedural_link}

func _ready():
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/skill_atlas_v06.gdshader")
	material = mat
	set_process_input(false)

func begin_frame():
	commands.clear()
	queue_redraw()

func sync_vision(game):
	if material == null: return
	material.set_shader_parameter("enabled", game.vision.active)
	material.set_shader_parameter("sight_mask", game.vision.texture)
	material.set_shader_parameter("mask_size", float(game.vision.extent))
	material.set_shader_parameter("camera", game.camera_pos)
	material.set_shader_parameter("screen_anchor", game.screen_center())

func render(game, event: Dictionary, t: float, duration: float, channel: String = "event") -> bool:
	sync_vision(game)
	var s = sample(event, t, duration, channel)
	if s.is_empty(): return not binding(event, channel).is_empty()
	var pos: Vector2 = event.get("pos", Vector2.ZERO)
	var direction: Vector2 = event.get("dir", Vector2.RIGHT)
	if channel == "event" and event.get("follow_owner", false):
		if game.get("session") == null: return false
		var owner: Dictionary = game.session.state.get("players", {}).get(event.get("owner", -1), {})
		if owner.is_empty() or float(owner.get("hp", 0)) <= 0: return false
		direction = owner.aim
		pos = owner.pos + direction * float(event.get("follow_offset", 0))
	elif s.keep_procedural_link:
		pos = event.get("end", pos)
	var at: Vector2 = game.world_point(pos)
	var height_offset = Presentation.projectile_offset(event) if channel == "projectile" else Vector2.ZERO
	at += height_offset
	s["height_offset"] = height_offset
	var angle = Dungeon.iso(direction).angle() if s.directional else 0.0
	s["at"] = at
	s["angle"] = angle
	commands.append(s)
	queue_redraw()
	return true

func _draw():
	for s in commands:
		if not textures.has(s.sheet): textures[s.sheet] = load(s.sheet)
		var texture: Texture2D = textures[s.sheet]
		var r = s.rect
		var pivot = Vector2(s.pivot[0], s.pivot[1])
		var corners = [Vector2.ZERO, Vector2(r[2],0), Vector2(r[2],r[3]), Vector2(0,r[3])]
		var vertices = PackedVector2Array()
		var uvs = PackedVector2Array()
		for corner in corners:
			vertices.append(s.at + ((corner-pivot)*float(s.scale)).rotated(float(s.angle)))
			# Half-texel inset avoids neighboring atlas frames during filtering.
			var source = Vector2(r[0],r[1]) + corner.clamp(Vector2(.5,.5),Vector2(r[2]-.5,r[3]-.5))
			uvs.append(source / texture.get_size())
		# Per-vertex channels carry visual elevation, not a shared per-draw uniform.
		# The shader restores white modulation and samples sight on the ground plane.
		var offset: Vector2 = s.height_offset
		var encoded = Color(.5+offset.x/2048., .5+offset.y/2048., 1., s.alpha)
		draw_polygon(vertices, PackedColorArray([encoded]), uvs, texture)
