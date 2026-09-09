extends Node2D
## Standalone, deterministic preview. No save data or combat scene is loaded.

const VFX = preload("res://scripts/skill_vfx.gd")
const FONT = preload("res://assets/fonts/dnf_forged_blade_medium.ttf")
const FAMILIES = [
	["slash", "섬광 검격", "ffd18d"],
	["spin", "회전 참격", "ffb276"],
	["fire", "화염 폭발", "ff8768"],
	["frost", "빙결 결정", "8ae5ff"],
	["thunder", "천둥 낙뢰", "bea4ff"],
	["impact", "대지 충격", "edbb8d"],
	["rain", "화살 폭우", "c8e7a0"],
	["shot", "관통 사격", "abeecb"],
	["poison", "맹독 지대", "b4e78b"],
	["heal", "회복의 빛", "91f1be"],
	["barrier", "수호 장벽", "96caff"],
	["haste", "가속의 바람", "9fe9e0"],
	["summon", "소환 의식", "deb0ff"],
	["cards", "마력 카드", "ffacda"],
	["chain", "마력 사슬", "b3bcff"],
	["vortex", "차원 소용돌이", "c5a0ff"],
	["blink", "순간 이동", "8be6ec"],
	["rune", "룬 마법진", "e6c7ff"],
]
const GRID_ORIGIN = Vector2(48, 204)
const TILE_SIZE = Vector2(210.666667, 196)
const GAP = 16.0
const CYCLE = 2.2

var visual_time = 0.0
var rank = 2
var playing = true
var _elapsed = 0.0
var _duration = 0.0
var _capture_at = 0.4
var _capture_path = ""
var _capture_started = false
var _capture_finished = false
var _canvases: Array[Node2D] = []
var _play_button: Button
var _rank_buttons: Array[Button] = []


class EffectCanvas extends Node2D:
	var studio: Node2D
	var family: String
	var index: int
	var accent: Color
	var visual_time = 0.0

	func world_point(pos: Vector2) -> Vector2:
		return pos

	func _draw() -> void:
		var at = Vector2(97.33333, 107)
		# Quiet perspective guides help compare the footprint of every effect.
		for offset in [-28.0, 0.0, 28.0]:
			draw_line(at + Vector2(-70, -35 + offset * 0.5), at + Vector2(70, 35 + offset * 0.5), Color(0.38, 0.5, 0.67, 0.07), 1, true)
			draw_line(at + Vector2(-70, 35 + offset * 0.5), at + Vector2(70, -35 + offset * 0.5), Color(0.38, 0.5, 0.67, 0.07), 1, true)
		draw_set_transform(at, 0, Vector2(1, 0.5))
		draw_arc(Vector2.ZERO, 39, 0, TAU, 48, Color(accent, 0.14), 1, true)
		draw_set_transform(Vector2.ZERO)
		var phase = fposmod(studio.visual_time + index * 0.029, CYCLE)
		if phase > 1.8:
			return
		var start = at
		var end = at
		if family in ["shot", "chain", "blink"]:
			start = at + Vector2(-51, 0)
			end = at + Vector2(53, 0)
		var event = {
			"vfx": family, "fx": family, "pos": start, "end": end,
			"dir": Vector2.RIGHT, "rank": studio.rank,
			"radius": 1.1, "max_life": 1.8, "life": 1.8 - phase,
		}
		VFX.render(self, event)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0b0f18"))
	DisplayServer.window_set_title("스텔알피지 · 스킬 이펙트 스튜디오")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			_capture_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--capture-at="):
			_capture_at = maxf(0.0, argument.trim_prefix("--capture-at=").to_float())
		elif argument.begins_with("--duration="):
			_duration = maxf(0.0, argument.trim_prefix("--duration=").to_float())
		elif argument.begins_with("--rank="):
			rank = clampi(argument.trim_prefix("--rank=").to_int(), 1, 3)
	for i in range(FAMILIES.size()):
		var clip = Control.new()
		clip.position = _tile_origin(i) + Vector2(8, 29)
		clip.size = TILE_SIZE - Vector2(16, 56)
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(clip)
		var canvas = EffectCanvas.new()
		canvas.studio = self
		canvas.family = FAMILIES[i][0]
		canvas.index = i
		canvas.accent = Color(FAMILIES[i][2])
		clip.add_child(canvas)
		_canvases.append(canvas)
	_play_button = _button(Vector2(48, 141), Vector2(142, 37), "Ⅱ  일시정지", _toggle_playback)
	_button(Vector2(200, 141), Vector2(112, 37), "↺  다시 재생", _restart)
	for level in range(1, 4):
		var button = _button(Vector2(1101 + (level - 1) * 98, 141), Vector2(91, 37), "랭크 %d" % level, _set_rank.bind(level))
		_rank_buttons.append(button)
	_update_controls()
	queue_redraw()


func _button(at: Vector2, dimensions: Vector2, caption: String, callback: Callable) -> Button:
	var button = Button.new()
	button.position = at
	button.size = dimensions
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("dae4f2"))
	for state in ["normal", "hover", "pressed"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("1b263a") if state == "normal" else Color("304660")
		style.border_color = Color("35465f")
		style.set_border_width_all(1)
		style.set_corner_radius_all(7)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	add_child(button)
	return button


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			_toggle_playback()
		KEY_R:
			_restart()
		KEY_1, KEY_KP_1:
			_set_rank(1)
		KEY_2, KEY_KP_2:
			_set_rank(2)
		KEY_3, KEY_KP_3:
			_set_rank(3)


func _toggle_playback() -> void:
	playing = not playing
	_update_controls()


func _restart() -> void:
	visual_time = 0.0
	playing = true
	_update_controls()


func _set_rank(value: int) -> void:
	rank = clampi(value, 1, 3)
	_update_controls()


func _update_controls() -> void:
	_play_button.text = "Ⅱ  일시정지" if playing else "▶  계속 재생"
	for i in range(_rank_buttons.size()):
		_rank_buttons[i].add_theme_color_override("font_color", Color("9de8ef") if rank == i + 1 else Color("91a0b7"))
		var style = _rank_buttons[i].get_theme_stylebox("normal").duplicate()
		style.bg_color = Color("24434e") if rank == i + 1 else Color("1b263a")
		style.border_color = Color("609ba7") if rank == i + 1 else Color("35465f")
		_rank_buttons[i].add_theme_stylebox_override("normal", style)
	queue_redraw()
	for canvas in _canvases:
		canvas.queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if playing:
		visual_time += delta
		for canvas in _canvases:
			canvas.visual_time = visual_time
			canvas.queue_redraw()
		queue_redraw()
	if not _capture_path.is_empty() and not _capture_started and _elapsed >= _capture_at:
		_capture_started = true
		_capture.call_deferred()
	if _duration > 0.0 and _elapsed >= _duration:
		if _capture_path.is_empty() or _capture_finished:
			get_tree().quit()


func _capture() -> void:
	# Freeze at the requested timestamp so captures are independent of frame rate.
	var was_playing = playing
	playing = false
	visual_time = _capture_at
	_update_controls()
	for canvas in _canvases:
		canvas.visual_time = visual_time
		canvas.queue_redraw()
	queue_redraw()
	await RenderingServer.frame_post_draw
	var destination = _capture_path
	if not destination.is_absolute_path():
		destination = ProjectSettings.globalize_path(destination)
	var directory_error = DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if directory_error != OK:
		push_error("Cannot create capture directory: %s (error %d)" % [destination, directory_error])
		get_tree().quit(1)
		return
	var capture = get_viewport().get_texture().get_image()
	var result = capture.save_png(destination)
	if result != OK:
		push_error("Cannot save gallery capture: %s (error %d)" % [destination, result])
		get_tree().quit(1)
		return
	print("VFX_GALLERY_CAPTURE_OK ", destination)
	_capture_finished = true
	playing = was_playing
	_update_controls()


func _tile_origin(index: int) -> Vector2:
	return GRID_ORIGIN + Vector2(index % 6, index / 6) * (TILE_SIZE + Vector2(GAP, GAP))


func _panel(rect: Rect2, fill: Color, border: Color, radius: int = 10) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)


func _text(at: Vector2, caption: String, size: int, color: Color) -> void:
	draw_string(FONT, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1440, 900), Color("0b0f18"))
	draw_rect(Rect2(0, 0, 1440, 117), Color("101725"))
	draw_line(Vector2(48, 118), Vector2(1392, 118), Color("263247"), 1)
	_text(Vector2(48, 35), "STELLAR RPG  /  EFFECT LIBRARY", 13, Color("8acbd4"))
	_text(Vector2(46, 78), "스킬 이펙트 스튜디오", 33, Color("eff5ff"))
	_text(Vector2(49, 103), "검격부터 차원 마법까지, 전투에 적용되는 18가지 이펙트", 15, Color("98a7bf"))
	_panel(Rect2(1247, 39, 145, 39), Color("182b32"), Color("35535c"), 8)
	draw_circle(Vector2(1265, 58), 3, Color("97ebcc") if playing else Color("eac989"))
	_text(Vector2(1277, 63), "반복 재생 중" if playing else "일시정지됨", 15, Color("bee2df"))
	_text(Vector2(332, 165), "SPACE  일시정지     R  다시 재생", 14, Color("91a0b8"))
	_text(Vector2(980, 165), "효과 강도", 15, Color("abbad0"))
	for i in range(FAMILIES.size()):
		var origin = _tile_origin(i)
		var accent = Color(FAMILIES[i][2])
		_panel(Rect2(origin, TILE_SIZE), Color("121b2b"), Color("2a364c"), 10)
		draw_line(origin + Vector2(14, 1), origin + Vector2(TILE_SIZE.x - 14, 1), Color(accent, 0.7), 2, true)
		_text(origin + Vector2(14, 24), FAMILIES[i][1], 17, Color("dce7f6"))
		_text(origin + Vector2(TILE_SIZE.x - 32, 23), "%02d" % (i + 1), 12, Color("7286a1"))
		draw_line(origin + Vector2(14, 167), origin + Vector2(TILE_SIZE.x - 14, 167), Color("253147"), 1)
		_text(origin + Vector2(14, 185), str(FAMILIES[i][0]).to_upper(), 11, Color(accent, 0.84))
		for level in range(3):
			draw_rect(Rect2(origin + Vector2(TILE_SIZE.x - 44 + level * 9, 178), Vector2(5, 5)), accent if level < rank else Color("314057"))
	draw_line(Vector2(48, 846), Vector2(1392, 846), Color("263247"), 1)
	_text(Vector2(48, 872), "18 EFFECTS   ·   실시간 절차형 렌더링   ·   1 / 2 / 3 키로 랭크 비교", 13, Color("8c9db5"))
	_text(Vector2(1162, 872), "스텔알피지  /  VFX STUDIO", 12, Color("6f859f"))
