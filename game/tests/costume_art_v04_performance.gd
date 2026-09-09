extends SceneTree
const Art = preload("res://scripts/costume_art_v04.gd")

func _initialize(): run.call_deferred()

func elapsed_ms(start: int) -> float:
	return float(Time.get_ticks_usec()-start)/1000.0

func scenario(id: String, index: int) -> Dictionary:
	var p = {"costume_id":id}
	var time = 0.0
	if index<4:
		p.dir=Vector2.RIGHT
		time=float(index)/8.0
	elif index<12:
		p.motion="cleave" if index<8 else "slam"
		p.motion_duration=1.0
		p.motion_time=1.0-(float((index-4)%4)+0.1)/4.0
	elif index<14:
		p.dodge_time=0.2 if index==12 else 0.1
	elif index==14:
		p.hurt_time=0.1
	return {"p":p,"time":time}

func frame_pass(scenarios: Array, iterations: int) -> Dictionary:
	var invalid=0
	var start=Time.get_ticks_usec()
	for i in iterations:
		var item: Dictionary=scenarios[i%scenarios.size()]
		if Art.frame(item.p,item.time).is_empty(): invalid+=1
	return {"calls":iterations,"elapsed_ms":elapsed_ms(start),"empty_frames":invalid}

func run():
	Art.reset_cache(true)
	var total_start=Time.get_ticks_usec()
	var start=Time.get_ticks_usec()
	var ids=Art.ids()
	var catalog_ms=elapsed_ms(start)
	if ids.size()!=33:
		push_error("Performance test requires the complete 33-costume catalog")
		quit(1)
		return
	start=Time.get_ticks_usec()
	var cold_frame=Art.frame({"costume_id":ids[0]},0.0)
	var cold_frame_ms=elapsed_ms(start)
	var cold_total_ms=elapsed_ms(total_start)
	if cold_frame.is_empty():
		push_error("Cold costume frame failed")
		quit(1)
		return
	start=Time.get_ticks_usec()
	var missing_portraits=0
	for id in ids:
		if Art.portrait({"costume_id":id})==null: missing_portraits+=1
	var populate_portraits_ms=elapsed_ms(start)
	var populated_sheets=Art._sheet_textures.size()
	start=Time.get_ticks_usec()
	for id in ids:
		if Art.portrait({"costume_id":id})==null: missing_portraits+=1
	var cached_portraits_ms=elapsed_ms(start)
	var scenarios: Array=[]
	for index in 16:
		for id in ids:
			scenarios.append(scenario(id,index))
	var first_pass=frame_pass(scenarios,1000)
	var repeated=[]
	for i in 3: repeated.append(frame_pass(scenarios,1000))
	var bytes=0
	for texture in Art._sheet_textures.values():
		bytes+=texture.get_width()*texture.get_height()*4
	var result={"method":"Fresh reader caches in a new Godot process; OS filesystem cache state is not controlled. Timed frame calls include normal public frame() dispatch. No image file is modified.",
		"display_server":DisplayServer.get_name(),"godot_version":Engine.get_version_info().string,
		"catalog_count":ids.size(),"cold_costume_id":ids[0],"catalog_load_ms":catalog_ms,
		"cold_first_costume_frame_ms":cold_frame_ms,"cold_catalog_plus_first_costume_ms":cold_total_ms,
		"populate_all_33_portraits_ms":populate_portraits_ms,
		"portrait_population_initial_state":"one source sheet already loaded by cold frame; the other 32 original sheets are cold",
		"sheets_after_portraits":populated_sheets,"all_33_cached_portraits_ms":cached_portraits_ms,
		"first_1000_frame_calls_after_portraits":first_pass,
		"first_frame_pass_note":"This pass also loads the two mint patch sheets when frame 6/7 are first requested; later passes use all 35 cached sheets and all 528 cached frame atlases.",
		"fully_cached_1000_frame_calls_runs":repeated,
		"cached_sheet_count":Art._sheet_textures.size(),"cached_frame_count":Art._frame_textures.size(),
		"cached_portrait_count":Art._portraits.size(),"rgba_texel_bytes_without_engine_overhead":bytes,
		"missing_portraits":missing_portraits,"source_pixels_changed":false}
	var output=ProjectSettings.globalize_path("res://../runtime/costume-art-v04-performance.json")
	var file=FileAccess.open(output,FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify(result,"  "))
		file.close()
	print("COSTUME_ART_V04_PERFORMANCE ",JSON.stringify(result))
	var invalid=missing_portraits+int(first_pass.empty_frames)
	for run in repeated: invalid+=int(run.empty_frames)
	Art.reset_cache(true)
	quit(0 if invalid==0 and file!=null else 1)
