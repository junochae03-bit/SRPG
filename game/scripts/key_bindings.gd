extends RefCounted
## Keyboard preferences are global; player saves and mouse attacks stay separate.
const DEFAULTS={"move_up":KEY_W,"move_down":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"sprint":KEY_SHIFT,"dodge":KEY_SPACE,"skill_q":KEY_Q,"skill_f":KEY_F,"skill_v":KEY_V,"skill_c":KEY_C,"skill_z":KEY_Z,"skill_x":KEY_X,"potion":KEY_1,"consumable_2":KEY_2,"consumable_3":KEY_3,"consumable_4":KEY_4,"interact":KEY_E,"return":KEY_R,"bag":KEY_I,"skills":KEY_K,"codex":KEY_B,"card_next":KEY_TAB}
const NAMES={"move_up":"위로 이동","move_down":"아래로 이동","move_left":"왼쪽 이동","move_right":"오른쪽 이동","sprint":"달리기","dodge":"회피","skill_q":"기술 1","skill_f":"기술 2","skill_v":"기술 3","skill_c":"기술 4","skill_z":"기술 5","skill_x":"기술 6","potion":"소모품 1","consumable_2":"소모품 2","consumable_3":"소모품 3","consumable_4":"소모품 4","interact":"상호작용","return":"마을 귀환","bag":"가방","skills":"성장","codex":"도감","card_next":"카드 선택"}
const KEY_ROWS=[[KEY_ESCAPE,KEY_F1,KEY_F2,KEY_F3,KEY_F4,KEY_F5,KEY_F6,KEY_F7,KEY_F8,KEY_F9,KEY_F10,KEY_F11,KEY_F12],[KEY_QUOTELEFT,KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0,KEY_MINUS,KEY_EQUAL,KEY_BACKSPACE],[KEY_TAB,KEY_Q,KEY_W,KEY_E,KEY_R,KEY_T,KEY_Y,KEY_U,KEY_I,KEY_O,KEY_P,KEY_BRACKETLEFT,KEY_BRACKETRIGHT,KEY_BACKSLASH],[KEY_CAPSLOCK,KEY_A,KEY_S,KEY_D,KEY_F,KEY_G,KEY_H,KEY_J,KEY_K,KEY_L,KEY_SEMICOLON,KEY_APOSTROPHE,KEY_ENTER],[KEY_SHIFT,KEY_Z,KEY_X,KEY_C,KEY_V,KEY_B,KEY_N,KEY_M,KEY_COMMA,KEY_PERIOD,KEY_SLASH,KEY_UP],[KEY_CTRL,KEY_ALT,KEY_SPACE,KEY_LEFT,KEY_DOWN,KEY_RIGHT,KEY_INSERT,KEY_DELETE,KEY_HOME,KEY_END,KEY_PAGEUP,KEY_PAGEDOWN]]
var bindings:Dictionary=DEFAULTS.duplicate()
func defaults()->Dictionary:return DEFAULTS.duplicate()
func key_for(action:String)->int:return int(bindings.get(action,0))
static func key_name(key:int)->String:
	return {KEY_ESCAPE:"ESC",KEY_SHIFT:"SHIFT",KEY_CTRL:"CTRL",KEY_ALT:"ALT",KEY_SPACE:"SPACE",KEY_BACKSPACE:"BACK",KEY_CAPSLOCK:"CAPS",KEY_ENTER:"ENTER",KEY_PAGEUP:"PGUP",KEY_PAGEDOWN:"PGDN",KEY_INSERT:"INS",KEY_DELETE:"DEL",KEY_UP:"↑",KEY_DOWN:"↓",KEY_LEFT:"←",KEY_RIGHT:"→",KEY_QUOTELEFT:"`",KEY_MINUS:"-",KEY_EQUAL:"=",KEY_BRACKETLEFT:"[",KEY_BRACKETRIGHT:"]",KEY_BACKSLASH:"\\",KEY_SEMICOLON:";",KEY_APOSTROPHE:"'",KEY_COMMA:",",KEY_PERIOD:".",KEY_SLASH:"/"}.get(key,OS.get_keycode_string(key).to_upper())
func label(action:String)->String:return key_name(key_for(action))
static func allowed(key:int)->bool:
	if key==KEY_ESCAPE:return false
	for row in KEY_ROWS:
		if key in row:return true
	return false
func is_pressed(action:String)->bool:
	var key=key_for(action)
	return key!=0 and Input.is_physical_key_pressed(key)
func action_for_event(event:InputEvent)->String:
	if not event is InputEventKey or not event.pressed or event.echo:return ""
	var key=int(event.physical_keycode if event.physical_keycode!=0 else event.keycode)
	if key==KEY_ESCAPE:return ""
	for action in bindings:
		if int(bindings[action])==key:return action
	return ""
func assign(draft:Dictionary,action:String,key:int)->Dictionary:
	if not DEFAULTS.has(action):return {"ok":false,"reason":"알 수 없는 동작입니다.","swapped":""}
	if not allowed(key):return {"ok":false,"reason":"ESC는 닫기 키로 예약되어 있습니다." if key==KEY_ESCAPE else "화면에 표시된 키를 선택하세요.","swapped":""}
	if not valid(draft):return {"ok":false,"reason":"현재 키 배치가 올바르지 않습니다.","swapped":""}
	var swapped="";var previous=int(draft[action])
	for other in draft:
		if other!=action and int(draft[other])==key:swapped=other;break
	draft[action]=key
	if not swapped.is_empty():draft[swapped]=previous
	return {"ok":true,"reason":("%s ↔ %s"%[NAMES[action],NAMES[swapped]]) if not swapped.is_empty() else "%s · %s"%[NAMES[action],key_name(key)],"swapped":swapped}
func valid(value:Variant)->bool:
	if not value is Dictionary or value.size()!=DEFAULTS.size():return false
	var seen=[]
	for action in DEFAULTS:
		var key=value.get(action)
		if not (key is int or key is float) or float(key)!=floor(float(key)) or not allowed(int(key)) or int(key) in seen:return false
		seen.append(int(key))
	return true
func migrate(value:Variant)->Dictionary:
	if not value is Dictionary:return {}
	var result=value.duplicate()
	var added=["consumable_2","consumable_3","consumable_4"]
	for action in DEFAULTS:
		if not result.has(action) and action not in added:return {}
	for action in added:
		if result.has(action):continue
		var preferred=int(DEFAULTS[action])
		if preferred in result.values():
			for row in KEY_ROWS:
				for candidate in row:
					if allowed(candidate) and candidate not in result.values():preferred=candidate;break
				if preferred not in result.values():break
		result[action]=preferred
	return result if valid(result) else {}
func load_file(path:String)->bool:
	if not FileAccess.file_exists(path):return false
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or int(data.get("schema_version",0))!=1:return false
	var migrated=migrate(data.get("bindings"))
	if not valid(migrated):return false
	data.bindings=migrated
	var loaded={}
	for action in DEFAULTS:loaded[action]=int(data.bindings[action])
	bindings=loaded;return true
func save_file(path:String)->bool:
	if path.is_empty() or not valid(bindings):return false
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK:return false
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify({"schema_version":1,"bindings":bindings},"\t"));file.flush();file.close()
	return DirAccess.rename_absolute(path+".tmp",path)==OK
