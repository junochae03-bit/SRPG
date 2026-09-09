extends Panel
const Keys=preload("res://scripts/key_bindings.gd")
const Art=preload("res://scripts/ui_art.gd")
const Icons=preload("res://scripts/icon_library.gd")
const ACTION_ICONS={"move_up":"agility","move_down":"agility","move_left":"agility","move_right":"agility","sprint":"agility","dodge":"dash","potion":"consumable","interact":"interact","return":"return_home","bag":"bag","skills":"skills","codex":"codex","card_next":"card_hand"}
var game
var draft:Dictionary={}
var selected_action=""
var action_buttons:Dictionary={}
var key_buttons:Dictionary={}
var status:Label
var choice:Label
var apply_button:Button
var title_button:Button
var was_paused=false
var changed=false

class ActionButton extends Button:
	var host
	var action=""
	func _get_drag_data(_at:Vector2):
		host.select_action(action)
		var preview=Label.new();preview.text=Keys.NAMES[action];preview.add_theme_font_size_override("font_size",22);set_drag_preview(preview)
		return {"kind":"key_action","action":action}
class KeyButton extends Button:
	var host
	var physical_key=0
	var assigned:Label
	func _can_drop_data(_at:Vector2,data:Variant)->bool:return data is Dictionary and data.get("kind","")=="key_action" and Keys.allowed(physical_key)
	func _drop_data(_at:Vector2,data:Variant):host.assign_key(physical_key,str(data.action))

func setup(owner_game):
	game=owner_game;position=Vector2(-60,24);size=Vector2(1560,852);mouse_filter=Control.MOUSE_FILTER_STOP;focus_mode=Control.FOCUS_ALL
	add_theme_stylebox_override("panel",StyleBoxEmpty.new());Art.decorate(self,"paper",6)
	game.label(self,"키 설정",Vector2(36,28),Vector2(630,46),32)
	game.label(self,"동작을 선택해 키를 누르거나, 동작을 키보드 위로 끌어 놓으세요.",Vector2(38,85),Vector2(1100,31),18)
	game.button(self,"닫기",Vector2(1368,30),Vector2(148,43),close)
	title_button=game.button(self,"저장하고 타이틀",Vector2(1136,30),Vector2(218,43),return_to_title)
	Art.panel(self,Vector2(28,130),Vector2(387,613),"paper",4)
	Art.panel(self,Vector2(428,130),Vector2(1098,613),"paper",4)
	var index=0
	for action in Keys.DEFAULTS:
		var b=ActionButton.new();b.host=self;b.action=action;b.position=Vector2(40+(index%2)*186,145+int(index/2)*58);b.size=Vector2(174,50);b.clip_text=true
		b.text=Keys.NAMES[action];b.add_theme_font_override("font",game.fonts);b.add_theme_font_size_override("font_size",17);b.add_theme_color_override("font_color",game.PALE)
		for state in ["normal","hover","pressed","focus"]:b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		b.pressed.connect(func():select_action(action));add_child(b);Art.decorate(b,"paper",3);Icons.attach(b,ACTION_ICONS.get(action,"skills"),20)
		action_buttons[action]=b;index+=1
	for row_index in range(Keys.KEY_ROWS.size()):
		var row=Keys.KEY_ROWS[row_index];var weights=[];var total=0.
		for physical_key in row:
			var weight=3.2 if physical_key==KEY_SPACE else 1.45 if physical_key in [KEY_TAB,KEY_CAPSLOCK,KEY_ENTER,KEY_BACKSPACE,KEY_SHIFT] else 1.
			weights.append(weight);total+=weight
		var unit=(1066.-5*(row.size()-1))/total;var x=444.
		for i in range(row.size()):
			var physical_key=row[i];var b=KeyButton.new();b.host=self;b.physical_key=physical_key;b.position=Vector2(x,155+row_index*90);b.size=Vector2(unit*weights[i],78);b.clip_text=true;b.text=Keys.key_name(physical_key);b.alignment=HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_override("font",game.bold_font);b.add_theme_font_size_override("font_size",15);b.add_theme_color_override("font_color",game.PALE)
			for state in ["normal","hover","pressed","focus"]:
				var style=StyleBoxEmpty.new();style.content_margin_left=8;style.content_margin_top=0;style.content_margin_bottom=34;b.add_theme_stylebox_override(state,style)
			b.pressed.connect(func():close() if physical_key==KEY_ESCAPE else assign_key(physical_key));add_child(b);Art.decorate(b,"paper",3)
			b.assigned=game.label(b,"",Vector2(5,39),Vector2(b.size.x-10,33),13);b.assigned.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;b.assigned.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;b.assigned.clip_text=true;b.assigned.mouse_filter=Control.MOUSE_FILTER_IGNORE
			b.tooltip_text="닫기 · 변경할 수 없음" if physical_key==KEY_ESCAPE else Keys.key_name(physical_key)
			key_buttons[physical_key]=b;x+=b.size.x+5
	choice=game.label(self,"",Vector2(455,700),Vector2(1034,32),18)
	status=game.label(self,"",Vector2(40,760),Vector2(966,54),18);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	game.button(self,"기본값",Vector2(1028,774),Vector2(142,43),reset_draft)
	game.button(self,"취소",Vector2(1186,774),Vector2(142,43),close)
	apply_button=game.button(self,"적용",Vector2(1344,774),Vector2(166,43),apply)
	hide()
func open():
	draft=game.keybindings.bindings.duplicate();selected_action="";changed=false;status.text="기본 공격 · 마우스 왼쪽    강공격 · 마우스 오른쪽"
	was_paused=game.session.paused if game.session.connected else false
	if game.session.connected:game.session.paused=true
	title_button.visible=game.session.connected
	show();refresh();grab_focus()
func return_to_title():
	game.session.disconnect_game();close()
func close():
	hide();selected_action=""
	if game.session.connected:game.session.paused=was_paused
func select_action(action:String):
	selected_action=action;status.text=Keys.NAMES[action]+"에 사용할 키를 선택하세요.";refresh()
func assign_key(physical_key:int,action:String=""):
	var target=selected_action if action.is_empty() else action
	if target.is_empty():
		for current in draft:
			if int(draft[current])==physical_key:select_action(current);return
		status.text="먼저 왼쪽에서 동작을 선택하세요.";return
	var result=game.keybindings.assign(draft,target,physical_key);status.text=result.reason
	if result.ok:selected_action=target;changed=draft!=game.keybindings.bindings
	refresh()
func reset_draft():
	draft=game.keybindings.defaults();changed=draft!=game.keybindings.bindings;status.text="기본 배치를 불러왔습니다. 적용하면 저장됩니다.";refresh()
func refresh():
	if draft.is_empty():return
	for action in action_buttons:
		var b=action_buttons[action];b.tooltip_text=Keys.NAMES[action]+" · "+Keys.key_name(int(draft[action]));b.modulate=Color(1,.9,.66) if selected_action==action else Color.WHITE
	for physical_key in key_buttons:
		var b=key_buttons[physical_key];var assigned=""
		for action in draft:
			if int(draft[action])==physical_key:assigned=action;break
		b.assigned.text=Keys.NAMES.get(assigned,"") if physical_key!=KEY_ESCAPE else "닫기"
		b.tooltip_text=Keys.key_name(physical_key)+( " · "+Keys.NAMES[assigned] if not assigned.is_empty() else "")
		b.modulate=Color(1,.89,.66) if not selected_action.is_empty() and int(draft[selected_action])==physical_key else Color.WHITE
	choice.text=(Keys.NAMES[selected_action]+"  →  "+Keys.key_name(int(draft[selected_action]))) if not selected_action.is_empty() else "같은 키를 선택하면 두 동작의 키가 서로 바뀝니다."
	apply_button.disabled=not changed
func apply():
	if not game.keybindings.valid(draft):status.text="키 배치를 확인하세요.";return
	var previous=game.keybindings.bindings.duplicate();game.keybindings.bindings=draft.duplicate()
	if not game.keybindings.save_file(game.keybindings_path):
		game.keybindings.bindings=previous;status.text="키 설정을 저장할 수 없습니다.";return
	game.on_keybindings_changed();close()
func _input(event:InputEvent):
	if not visible or not event is InputEventKey or not event.pressed or event.echo:return
	var physical_key=int(event.physical_keycode if event.physical_keycode!=0 else event.keycode)
	if physical_key==KEY_ESCAPE:close();get_viewport().set_input_as_handled();return
	if not selected_action.is_empty():assign_key(physical_key);get_viewport().set_input_as_handled()
