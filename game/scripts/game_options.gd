extends RefCounted

const DEFAULTS={"music":0.45,"effects":0.7,"window_mode":"windowed","resolution":0,"fps":60,"vsync":true,"damage_numbers":true,"enemy_names":true}
const RESOLUTIONS=[Vector2i(1920,1080),Vector2i(1600,900),Vector2i(1280,720)]
var values=DEFAULTS.duplicate()
func valid(data:Variant)->bool:
	if not data is Dictionary or data.size()!=DEFAULTS.size():return false
	for key in ["music","effects"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])) or float(data[key])<0 or float(data[key])>1:return false
	if data.get("window_mode") not in ["windowed","fullscreen"]:return false
	for key in ["resolution","fps"]:
		if not (data.get(key) is int or data.get(key) is float) or not is_finite(float(data[key])) or float(data[key])!=floor(float(data[key])):return false
	if int(data.resolution) not in [0,1,2] or int(data.fps) not in [30,60,120,144,0]:return false
	for key in ["vsync","damage_numbers","enemy_names"]:
		if not data.get(key) is bool:return false
	return true
func load_file(path:String)->bool:
	if not FileAccess.file_exists(path):return false
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version")!=1 or not valid(data.get("values")):return false
	values=data["values"].duplicate();values.resolution=int(values.resolution);values.fps=int(values.fps);return true
func save_file(path:String,data:Dictionary)->bool:
	if not valid(data) or path.is_empty():return false
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK:return false
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify({"version":1,"values":data},"\t"));file.flush();file.close()
	if DirAccess.rename_absolute(path+".tmp",path)!=OK:return false
	values=data.duplicate();return true
func apply(game):
	game.audio_director.set_gain("music",float(values.music))
	game.audio_director.set_gain("effects",float(values.effects))
	Engine.max_fps=int(values.fps)
	# Automated capture dimensions are controlled by the verification runner.
	if DisplayServer.get_name()=="headless" or game.options.has("capture"):return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	var window=game.get_window()
	window.mode=Window.MODE_FULLSCREEN if values.window_mode=="fullscreen" else Window.MODE_WINDOWED
	if values.window_mode=="windowed":window.size=RESOLUTIONS[int(values.resolution)];window.move_to_center()
