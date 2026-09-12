extends Control
const World=preload("res://scripts/world_catalog.gd")
const Art=preload("res://scripts/ui_art.gd")
const Gat=preload("res://scripts/gat_art.gd")
const STORIES={"smith":"던전에서 가져온 광석에는 마력이 남아 있어요. 좋은 장비를 오래 쓰고 싶다면 제게 맡겨 주세요.","shop":"깊은 층에 갈수록 돌아오는 모험가가 드물어요. 이 마을의 진열대도 여러분이 가져오는 보물로 채워지지요.","alchemy":"동굴 아래에 숲과 빙하가 함께 있다는 게 신기하지 않나요? 뒤틀린 마력이 서로 다른 생태계를 품고 있답니다.","guild":"우리 길드는 100층까지 이어지는 길을 기록하고 있어요. 당신의 모험도 이 기록의 한 페이지가 되겠지요.","inn":"늦게 돌아와도 불은 켜 둘게요. 이곳에선 무기를 내려놓고 잠시 쉬어도 괜찮아요."}
var game
var facility=""
var speaker:Label
var dialogue:Label
var portrait:TextureRect
var service_button:Button
var story_button:Button
var close_button:Button
func setup(owner_game):
	game=owner_game;position=Vector2(24,718);size=Vector2(1392,158);mouse_filter=Control.MOUSE_FILTER_STOP
	var background=Panel.new();background.size=size;background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var frame=StyleBoxFlat.new();frame.bg_color=Color("12130feb");frame.border_color=Color("887047");frame.set_border_width_all(1);frame.set_corner_radius_all(18);frame.shadow_color=Color("00000060");frame.shadow_size=8
	background.add_theme_stylebox_override("panel",frame);add_child(background)
	var portrait_frame=Panel.new();portrait_frame.position=Vector2(23,24);portrait_frame.size=Vector2(100,106);portrait_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var rim=StyleBoxFlat.new();rim.bg_color=Color("302921");rim.border_color=Color("d4ad55");rim.set_border_width_all(2);rim.set_corner_radius_all(12);portrait_frame.add_theme_stylebox_override("panel",rim);add_child(portrait_frame)
	portrait=Art.picture(self,null,Vector2(31,30),Vector2(80,90));portrait.material=Gat.material()
	speaker=game.label(self,"",Vector2(146,18),Vector2(1040,31),23,Color("edc982"))
	dialogue=game.label(self,"",Vector2(146,59),Vector2(984,73),20,Color("f3eee0"));dialogue.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	service_button=game.button(self,"",Vector2(1152,60),Vector2(212,37),open_service,true);service_button.add_theme_font_size_override("font_size",16)
	story_button=game.button(self,"마을 이야기",Vector2(1152,105),Vector2(212,33),tell_story);story_button.add_theme_font_size_override("font_size",15)
	close_button=Button.new();close_button.text="×";close_button.position=Vector2(1332,10);close_button.size=Vector2(39,36);close_button.add_theme_font_size_override("font_size",26)
	for state in ["normal","hover","pressed","focus"]:close_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	close_button.add_theme_color_override("font_color",Color("c9b689"));close_button.pressed.connect(close);add_child(close_button)
	for button in [service_button,story_button]:
		button.clip_text=true
		for state in ["normal","hover","pressed","disabled","focus"]:
			var safe=StyleBoxEmpty.new();safe.content_margin_left=18;safe.content_margin_right=18;safe.content_margin_top=5;safe.content_margin_bottom=5;button.add_theme_stylebox_override(state,safe)
	hide()
func open(key:String):
	if key not in World.RESIDENTS:
		game.town_panel.open(key);return
	if not game.session.connected or game.session.sim.map.zone!="town":return
	facility=key;var npc=World.RESIDENTS[key]
	game.bag.hide();game.skill_tree.hide();game.help_panel.hide();game.codex.hide();game.town_panel.hide()
	game.session.cancel_charge()
	game.session.send_input(Vector2.ZERO,game.session.sim.players[game.session.local_id].aim)
	speaker.text=npc.name;dialogue.text=npc.greeting
	portrait.texture=Gat.portrait({"avatar":npc.avatar,"class_id":"warrior"})
	service_button.text={"smith":"장비를 맡긴다","shop":"물건을 살펴본다","alchemy":"조합을 부탁한다","guild":"의뢰를 확인한다","inn":"쉬어 간다","costume":"코스튬을 살펴본다","training":"훈련 기록을 본다"}.get(key,"이용하기")
	story_button.disabled=false;game.session.paused=true;game.toast.hide();show()
func tell_story():
	dialogue.text=STORIES.get(facility,{"costume":"옷의 이름도 모험가님이 직접 정하실 수 있어요. 마음에 드는 모습으로 입어 보세요.","training":"허수아비는 언제든 다시 일어납니다. 피해와 타격 기록을 보며 기술을 바꿔 시험해 보세요."}.get(facility,"편하게 둘러보세요."));story_button.disabled=true
func open_service():
	if not visible:return
	hide();game.town_panel.open(facility)
func close():
	hide();game.session.paused=game.bag.visible or game.skill_tree.visible or game.help_panel.visible or game.codex.visible or game.town_panel.visible
