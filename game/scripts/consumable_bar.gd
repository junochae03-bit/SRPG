extends Control
## Client preferences select an existing item; the session owns cost and effects.
const Art=preload("res://scripts/ui_art.gd")
const Icons=preload("res://scripts/icon_library.gd")
const ACTIONS=["potion","consumable_2","consumable_3","consumable_4"]
const Consumables=preload("res://scripts/consumables.gd")
const ITEMS=Consumables.ITEMS
var game
var assignments=["potion","","",""]
var slots=[]
var picker:Control
var assign_button:Button
var assign_buttons:Dictionary={}
var selected=0
var loaded_path=""
class Slot extends Button:
	var bar
	var index=0
	func _gui_input(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			bar.open_picker(index);accept_event()
	func _make_custom_tooltip(value:String)->Object:
		var item=bar.assignments[index]
		if item.is_empty():return Art.tooltip(bar.game,value)
		var p=bar.player();var reason=Consumables.unavailable(p,item)
		return Art.tooltip(bar.game,value+"\n"+Consumables.description(p,item)+("\n"+reason if not reason.is_empty() else "")+"\n우클릭으로 변경")
	func _draw():
		draw_texture_rect(Art.plain_paper(),Rect2(Vector2.ZERO,size),false,Color("303842"))
		draw_rect(Rect2(Vector2.ZERO,size),Color("e1c396") if is_hovered() else Color("967b58"),false,1)
		var item=bar.assignments[index];var p=bar.player()
		if item.is_empty():write(size*.5+Vector2(-5,7),"+",20,Color("b7b7a8"))
		else:
			Icons.draw(self,ITEMS[item].icon,Rect2(5,5,34,34),Color.WHITE if Consumables.count(p,item)>0 else Color(.45,.45,.45))
			var cd=float(p.get("potion_cd",0))
			if cd>0:
				draw_rect(Rect2(1,1,42,42),Color("17252bb0"));write(Vector2(14,30),str(ceili(cd)),21,Color("fff4d5"))
			else:write(Vector2(27,40),str(Consumables.count(p,item)),12,Color("fff4d5"))
		var key=bar.game.keybindings.label(ACTIONS[index]);var pixels=12
		while pixels>7 and bar.game.fonts.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x>36:pixels-=1
		write(Vector2(4,15),key,pixels,Color("fff4d5"))
	func write(at:Vector2,value:String,pixels:int,color:Color):
		draw_string_outline(bar.game.fonts,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,3,Color("18292d"))
		draw_string(bar.game.fonts,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)
func setup(owner_game):
	game=owner_game;position=Vector2(665,744);size=Vector2(194,44);mouse_filter=Control.MOUSE_FILTER_IGNORE
	for i in range(4):
		var button=Slot.new();button.bar=self;button.index=i;button.position=Vector2(i*50,0);button.size=Vector2(44,44);button.focus_mode=Control.FOCUS_NONE;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for state in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		add_child(button);slots.append(button);button.pressed.connect(func():open_picker(i) if assignments[i].is_empty() else use_slot(i));button.mouse_entered.connect(button.queue_redraw);button.mouse_exited.connect(button.queue_redraw)
	picker=Art.panel(self,Vector2(-50,-239),Vector2(296,227),"paper",4);picker.mouse_filter=Control.MOUSE_FILTER_STOP
	game.label(picker,"소모품 등록",Vector2(16,9),Vector2(220,25),18)
	game.button(picker,"×",Vector2(251,8),Vector2(30,27),func():picker.hide())
	for key in ITEMS:
		var control=game.button(picker,ITEMS[key].name,Vector2(14,44+assign_buttons.size()*44),Vector2(268,38),func():assign(selected,key))
		assign_buttons[key]=control
	assign_button=assign_buttons.potion
	game.button(picker,"등록 해제",Vector2(14,181),Vector2(268,34),func():assign(selected,""))
	picker.hide();load_preferences();refresh()
func player()->Dictionary:return game.session.state.get("players",{}).get(game.session.local_id,{})
func path()->String:return game.session.save_directory.path_join("consumable-slots.json")
func load_preferences():
	if loaded_path==path():return
	loaded_path=path();assignments=["potion","","",""]
	if not FileAccess.file_exists(loaded_path):return
	var value=JSON.parse_string(FileAccess.get_file_as_string(loaded_path))
	if value is Dictionary and value.get("schema_version",0)==1 and valid(value.get("slots")):assignments=value.slots.duplicate()
static func valid(value:Variant)->bool:
	return value is Array and value.size()==4 and value.all(func(item):return item is String and (item.is_empty() or ITEMS.has(item)))
func assign(index:int,item:String)->bool:
	if index<0 or index>=4 or (not item.is_empty() and not ITEMS.has(item)):return false
	if not item.is_empty() and Consumables.count(player(),item)<=0:return false
	var next=assignments.duplicate();next[index]=item
	var target=path();var ok=DirAccess.make_dir_recursive_absolute(target.get_base_dir())==OK
	var file=FileAccess.open(target+".tmp",FileAccess.WRITE) if ok else null
	if file==null:game.show_toast("소모품 등록을 저장할 수 없습니다.");return false
	file.store_string(JSON.stringify({"schema_version":1,"slots":next},"\t"));file.flush();var error=file.get_error();file.close()
	if error!=OK or DirAccess.rename_absolute(target+".tmp",target)!=OK:game.show_toast("소모품 등록을 저장할 수 없습니다.");return false
	assignments=next;picker.hide();refresh();return true
func use_slot(index:int)->bool:
	if index<0 or index>=4 or assignments[index].is_empty() or not is_visible_in_tree() or game.hud.chrome_hidden or picker.visible:return false
	return game.session.act(ITEMS[assignments[index]].action)
func open_picker(index:int):
	if index<0 or index>=4:return
	selected=index
	for key in assign_buttons:
		var control=assign_buttons[key];control.text=ITEMS[key].name+" · %d개"%Consumables.count(player(),key);control.disabled=Consumables.count(player(),key)<=0;control.tooltip_text=Consumables.description(player(),key)
	picker.show()
func _input(event):
	if picker!=null and picker.is_visible_in_tree() and event is InputEventKey and event.pressed and (event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE):
		picker.hide();get_viewport().set_input_as_handled()
func refresh():
	load_preferences()
	for i in range(slots.size()):
		var item=assignments[i];slots[i].tooltip_text=("빈 소모품 슬롯 · 클릭하여 등록" if item.is_empty() else ITEMS[item].name+" · "+game.keybindings.label(ACTIONS[i]));slots[i].queue_redraw()
