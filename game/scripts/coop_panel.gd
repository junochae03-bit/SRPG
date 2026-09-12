extends Panel
var game
var address:LineEdit
var port:SpinBox
var information:Label
var ready_button:Button
var host:Button
var join:Button
var leave:Button
var roster_labels=[]
func setup(owner_game):
	game=owner_game;position=Vector2(460,200);size=Vector2(560,490);mouse_filter=Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",StyleBoxEmpty.new());preload("res://scripts/ui_art.gd").decorate(self,"paper",6)
	game.label(self,"친구와 모험",Vector2(30,25),Vector2(360,45),30)
	game.button(self,"닫기",Vector2(428,25),Vector2(100,40),close)
	game.label(self,"방장 주소",Vector2(30,92),Vector2(140,30),20)
	address=game.line_edit(self,"127.0.0.1",Vector2(170,85),Vector2(358,44))
	game.label(self,"포트",Vector2(30,149),Vector2(140,30),20)
	port=SpinBox.new();port.position=Vector2(170,144);port.size=Vector2(180,40);port.min_value=1024;port.max_value=65535;port.value=24554;add_child(port)
	host=game.button(self,"방 열기",Vector2(30,208),Vector2(240,48),func():game.session.host_room(game.slot_picker.selected+1,int(port.value));update_controls())
	join=game.button(self,"주소로 참가",Vector2(288,208),Vector2(240,48),func():game.session.join_room(address.text,game.slot_picker.selected+1,int(port.value));update_controls())
	information=game.label(self,"",Vector2(30,367),Vector2(498,36),19);information.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for i in range(6):
		var label=game.label(self,"",Vector2(30+(i%2)*249,276+int(i/2)*28),Vector2(240,28),17);label.clip_text=true;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;roster_labels.append(label)
	ready_button=game.button(self,"준비",Vector2(30,410),Vector2(240,48),func():game.session.act("ready","false" if game.session.ready_players.get(game.session.local_id,false) else "true");update_controls())
	leave=game.button(self,"방 나가기",Vector2(288,410),Vector2(240,48),func():game.session.disconnect_game();update_controls())
	game.session.changed.connect(func():if visible:update_controls())
	game.session.status_changed.connect(func(_message):if visible:update_controls())
	hide()
func open():
	if game.session.connected:game.session.cancel_charge();game.session.paused=true
	show();update_controls()
func close():
	hide()
	if game.session.connected:game.session.paused=false
func update_controls():
	var session=game.session;var online=session.network_role!="offline"
	host.disabled=session.connected or online;join.disabled=session.connected or online;address.editable=not online;port.editable=not online
	ready_button.visible=online and session.connected;leave.visible=online
	ready_button.disabled=session.leaving;leave.disabled=session.leaving
	ready_button.text="준비 취소" if session.ready_players.get(session.local_id,false) else "출발 준비"
	var roster=[]
	for id in session.state.players:
		var p=session.state.players[id];roster.append(("● " if session.ready_players.get(id,false) else "○ ")+p.name)
	for i in range(6):
		roster_labels[i].text=roster[i] if i<roster.size() else "";roster_labels[i].tooltip_text=roster_labels[i].text
	information.text=session.room_status if online else "마을에 도착한 기록을 선택해 주세요. " +session.room_status
