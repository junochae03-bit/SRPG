extends "res://scripts/main.gd"

var timings:Dictionary={}
var frame_marks:Array=[]
var previous_frame:int=0
var probe_start:int=Time.get_ticks_usec()
var reported:bool=false

func mark(key:String,begin:int):
	if not timings.has(key):timings[key]=[]
	timings[key].append(float(Time.get_ticks_usec()-begin)/1000.)

func _ready():
	var begin=Time.get_ticks_usec()
	super._ready()
	# Real keyboard input must not change an isolated profiling scenario.
	get_window().unfocusable=true
	get_viewport().gui_disable_input=true
	set_process_input(false);set_process_unhandled_input(false);set_process_unhandled_key_input(false)
	mark("ready_ms",begin)
	if options.get("probe-mode","")=="no_hud":session.changed.disconnect(update_hud)
	if options.has("probe-floor") and session.connected:session.change_map("forest",int(options["probe-floor"]))
	if options.get("probe-menu","")=="bag":toggle_bag()
	if options.get("probe-menu","")=="skills":toggle_skills()
	if options.get("probe-menu","")=="codex":toggle_codex("equipment")

func update_hud():
	var begin=Time.get_ticks_usec()
	super.update_hud()
	mark("hud_ms",begin)

func load_art():
	var begin=Time.get_ticks_usec()
	super.load_art()
	mark("load_art_ms",begin)

func build_interface():
	var begin=Time.get_ticks_usec()
	super.build_interface()
	mark("build_interface_ms",begin)

func refresh_slot_summary():
	var begin=Time.get_ticks_usec()
	super.refresh_slot_summary()
	mark("slot_summary_ms",begin)

func on_entered():
	var begin=Time.get_ticks_usec()
	super.on_entered()
	mark("enter_map_ms",begin)

func join_game():
	var begin=Time.get_ticks_usec()
	super.join_game()
	mark("join_game_ms",begin)

func toggle_bag():
	var begin=Time.get_ticks_usec();super.toggle_bag();mark("bag_toggle_ms",begin)

func toggle_skills():
	var begin=Time.get_ticks_usec();super.toggle_skills();mark("skills_toggle_ms",begin)

func toggle_codex(tab:String=""):
	var begin=Time.get_ticks_usec();super.toggle_codex(tab);mark("codex_toggle_ms",begin)

func _process(delta:float):
	var begin=Time.get_ticks_usec()
	if previous_frame>0:frame_marks.append({"at_ms":float(begin-probe_start)/1000.,"ms":float(begin-previous_frame)/1000.})
	previous_frame=begin
	super._process(delta)
	if options.get("probe-mode","")=="no_world":forest.terrain.visible=false
	mark("main_process_ms",begin)

func _physics_process(delta:float):
	var begin=Time.get_ticks_usec()
	if options.has("bot"):super._physics_process(delta)
	elif session.connected and not session.paused:session.send_input(Vector2.ZERO,Vector2.RIGHT)
	mark("main_physics_ms",begin)

func _draw():
	var begin=Time.get_ticks_usec()
	if options.get("probe-mode","")!="no_world":super._draw()
	mark("world_draw_ms",begin)

func finish_run():
	if reported:return
	reported=true
	var result={"timings":timings,"frames":frame_marks,"total_ms":float(Time.get_ticks_usec()-probe_start)/1000.,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"video_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"options":options}
	var file=FileAccess.open(str(options.get("probe-output","res://../runtime/performance-v05.json")),FileAccess.WRITE)
	result["window_size"]=[get_window().size.x,get_window().size.y]
	result["viewport_size"]=[get_viewport_rect().size.x,get_viewport_rect().size.y]
	file.store_string(JSON.stringify(result));file.close()
	await super.finish_run()
