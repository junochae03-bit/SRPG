extends Panel
const Art=preload("res://scripts/ui_art.gd")
const Model=preload("res://scripts/game_options.gd")
var game
var draft={}
var controls={}
var pages={}
var tabs={}
var status:Label
var key_button:Button
var apply_button:Button
var title_button:Button
var was_paused=false
var selected_page="sound"
var syncing=false

func setup(owner_game):
	game=owner_game;position=Vector2(176,64);size=Vector2(1088,764);mouse_filter=Control.MOUSE_FILTER_STOP
	var backdrop=ColorRect.new();backdrop.name="ModalBackdrop";backdrop.color=Color(.035,.075,.06,.36)
	backdrop.position=-position-game.ui_offset();backdrop.size=Vector2(1600,900);backdrop.mouse_filter=Control.MOUSE_FILTER_STOP;backdrop.show_behind_parent=true;add_child(backdrop)
	add_theme_stylebox_override("panel",StyleBoxEmpty.new());Art.decorate(self,"paper",6)
	game.label(self,"설정",Vector2(38,28),Vector2(720,48),34)
	game.button(self,"닫기",Vector2(892,30),Vector2(150,44),close)
	var definitions=[["sound","소리"],["display","화면"],["combat","전투 표시"]]
	for i in range(definitions.size()):
		var id=definitions[i][0]
		tabs[id]=game.button(self,definitions[i][1],Vector2(36,118+i*70),Vector2(216,55),func():select_page(id))
		var page=Control.new();page.position=Vector2(292,115);page.size=Vector2(744,477);add_child(page);pages[id]=page
	key_button=game.button(self,"키 변경  →",Vector2(36,356),Vector2(216,58),open_keys)
	game.label(pages.sound,"소리",Vector2.ZERO,Vector2(700,42),28)
	slider(pages.sound,"music","배경 음악",88)
	slider(pages.sound,"effects","효과음",198)
	game.label(pages.display,"화면",Vector2.ZERO,Vector2(700,42),28)
	choice(pages.display,"window_mode","화면 모드",72,["창 모드","전체 화면"])
	choice(pages.display,"resolution","창 해상도",158,["1920 × 1080","1600 × 900","1280 × 720"])
	choice(pages.display,"fps","최대 프레임",244,["30","60","120","144","제한 없음"])
	checkbox(pages.display,"vsync","수직 동기화",337)
	game.label(pages.combat,"전투 표시",Vector2.ZERO,Vector2(700,42),28)
	checkbox(pages.combat,"damage_numbers","피해량 숫자",92)
	checkbox(pages.combat,"enemy_names","몬스터 이름",186)
	status=game.label(self,"",Vector2(295,603),Vector2(720,42),18)
	title_button=game.button(self,"저장 후 타이틀",Vector2(36,654),Vector2(245,51),return_to_title)
	game.button(self,"기본값",Vector2(493,654),Vector2(165,51),reset_draft)
	game.button(self,"취소",Vector2(677,654),Vector2(165,51),close)
	apply_button=game.button(self,"적용",Vector2(861,654),Vector2(180,51),apply)
	hide()
func slider(parent:Control,id:String,caption:String,y:float):
	game.label(parent,caption,Vector2(0,y),Vector2(260,32),22)
	var bar=HSlider.new();bar.position=Vector2(0,y+48);bar.size=Vector2(580,35);bar.min_value=0;bar.max_value=100;bar.step=1;parent.add_child(bar)
	var value=game.label(parent,"",Vector2(604,y+47),Vector2(95,33),23)
	controls[id]=bar;controls[id+"_value"]=value
	bar.value_changed.connect(func(number):value.text="%d%%"%number;if not syncing:draft[id]=number/100.0;mark_changed())
func choice(parent:Control,id:String,caption:String,y:float,items:Array):
	game.label(parent,caption,Vector2(0,y+7),Vector2(242,35),22)
	var picker=OptionButton.new();picker.position=Vector2(270,y);picker.size=Vector2(440,52);picker.add_theme_font_override("font",game.fonts);picker.add_theme_font_size_override("font_size",22);picker.add_theme_color_override("font_color",game.PALE)
	for state in ["normal","hover","pressed","focus"]:
		var style=StyleBoxEmpty.new();style.content_margin_left=18;style.content_margin_right=32;picker.add_theme_stylebox_override(state,style)
	for item in items:picker.add_item(item)
	parent.add_child(picker);Art.decorate(picker,"paper",4);controls[id]=picker
	picker.item_selected.connect(func(index):draft[id]=(["windowed","fullscreen"][index] if id=="window_mode" else [30,60,120,144,0][index] if id=="fps" else index);mark_changed();controls.resolution.disabled=draft.window_mode=="fullscreen")
func checkbox(parent:Control,id:String,caption:String,y:float):
	var button=CheckButton.new();button.text=caption;button.position=Vector2(0,y);button.size=Vector2(710,55);button.add_theme_font_override("font",game.fonts);button.add_theme_font_size_override("font_size",22);button.add_theme_color_override("font_color",game.PALE);parent.add_child(button);controls[id]=button
	for state in ["font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:button.add_theme_color_override(state,game.PALE)
	button.set_meta("caption",caption)
	button.toggled.connect(func(value):button.text=caption+"   ·   "+("켜짐" if value else "꺼짐"))
	button.toggled.connect(func(value):if not syncing:draft[id]=value;mark_changed())
func open():
	was_paused=game.session.paused if game.session.connected else false
	if game.session.connected:game.session.paused=true;game.session.sim.combat.act(game.session.sim.players[game.session.local_id],"cancel_charge")
	draft=game.preferences.values.duplicate();status.text="";sync_controls();title_button.visible=game.session.connected;show()
func select_page(id:String):
	selected_page=id
	for key in pages:pages[key].visible=key==id;tabs[key].text=("◆ " if key==id else "")+{"sound":"소리","display":"화면","combat":"전투 표시"}[key]
func sync_controls():
	syncing=true
	for key in ["music","effects"]:controls[key].value=float(draft[key])*100;controls[key+"_value"].text="%d%%"%(float(draft[key])*100)
	controls.window_mode.select(0 if draft.window_mode=="windowed" else 1);controls.resolution.select(int(draft.resolution));controls.fps.select([30,60,120,144,0].find(int(draft.fps)))
	controls.resolution.disabled=draft.window_mode=="fullscreen"
	for key in ["vsync","damage_numbers","enemy_names"]:controls[key].button_pressed=draft[key];controls[key].text=controls[key].get_meta("caption")+"   ·   "+("켜짐" if draft[key] else "꺼짐")
	syncing=false;select_page(selected_page);mark_changed()
func mark_changed():
	if apply_button!=null:apply_button.disabled=draft==game.preferences.values
func reset_draft():draft=Model.DEFAULTS.duplicate();sync_controls();status.text="기본값 선택 · 적용하면 저장됩니다."
func apply():
	if not game.preferences.save_file(game.session.save_directory.path_join("game-options.json"),draft):status.text="설정을 저장할 수 없습니다.";return
	game.preferences.apply(game);status.text="설정을 저장했습니다.";mark_changed()
func close():
	hide()
	if game.session.connected:game.session.paused=was_paused
func open_keys():
	hide();game.help_panel.open();game.help_panel.return_panel=self;game.help_panel.title_button.hide()
func return_from_keys():
	show()
	if game.session.connected:game.session.paused=true
func return_to_title():
	if game.session.disconnect_game():hide()
	else:status.text="저장 실패 · 기록은 유지됩니다. 다시 시도하세요."
