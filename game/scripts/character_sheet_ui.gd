extends Control
const Creation=preload("res://scripts/character_creation.gd")
const Content=preload("res://scripts/content.gd")
const Stats=preload("res://scripts/progression.gd")
const Art=preload("res://scripts/ui_art.gd")
const Gat=preload("res://scripts/gat_art.gd")
const Costumes=preload("res://scripts/costume_art_v04.gd")
var game
var sheet={}
var selected_slot=1
var name_field:LineEdit
var portrait:Control
var stat_labels={}
var stat_minus={}
var stat_plus={}
var job_buttons={}
var class_description:Label
var balance_label:Label
var error_label:Label
var derived_label:Label
var create_button:Button
var appearance_label:Label
var avatar_buttons=[]
var page_label:Label
var previous_button:Button
var next_button:Button
var avatar_page=0
var avatar_keys=[]
var avatar_grid:Control
func setup(owner_game):
	game=owner_game;position=Vector2(24,24);size=Vector2(1392,852);mouse_filter=Control.MOUSE_FILTER_STOP
	Art.decorate(self,"paper",36)
	Art.picture(self,Art.texture("crest"),Vector2(30,24),Vector2(64,64))
	game.label(self,"모험가 등록",Vector2(112,24),Vector2(640,46),32)
	game.button(self,"돌아가기",Vector2(1210,31),Vector2(146,45),cancel)
	Art.panel(self,Vector2(28,124),Vector2(444,633),"paper",24)
	Art.panel(self,Vector2(483,124),Vector2(372,633),"paper",24)
	Art.panel(self,Vector2(865,124),Vector2(499,633),"paper",24)
	game.label(self,"외형",Vector2(76,162),Vector2(190,30),22)
	appearance_label=game.label(self,"",Vector2(76,202),Vector2(350,48),17)
	appearance_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	portrait=preload("res://scripts/character_preview.gd").new();portrait.position=Vector2(76,260);portrait.size=Vector2(343,410);add_child(portrait)
	avatar_grid=Control.new();avatar_grid.position=Vector2(53,495);avatar_grid.size=Vector2(390,171);add_child(avatar_grid)
	previous_button=game.button(self,"‹",Vector2(63,694),Vector2(54,36),func():avatar_page-=1;refresh_avatars())
	page_label=game.label(self,"",Vector2(124,702),Vector2(229,23),16);page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	next_button=game.button(self,"›",Vector2(363,694),Vector2(54,36),func():avatar_page+=1;refresh_avatars())
	game.label(self,"이름",Vector2(527,162),Vector2(284,31),22)
	name_field=game.line_edit(self,"",Vector2(516,209),Vector2(305,49));name_field.max_length=16;name_field.placeholder_text="모험가의 이름"
	name_field.text_changed.connect(func(value):sheet.name=value;refresh())
	game.label(self,"직업",Vector2(527,282),Vector2(284,31),22)
	Content.initialize_jobs()
	for i in range(Creation.CLASSES.size()):
		var id=Creation.CLASSES[i]
		job_buttons[id]=game.button(self,Content.CLASSES[id].name,Vector2(516,325+i*53),Vector2(305,44),func():select_class(id))
	class_description=game.label(self,"",Vector2(527,613),Vector2(284,101),19);class_description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	game.label(self,"초기 능력치",Vector2(909,162),Vector2(224,31),22)
	balance_label=game.label(self,"",Vector2(1143,168),Vector2(170,24),18);balance_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	for i in range(Stats.NAMES.size()):
		var key=Stats.NAMES.keys()[i];var y=224+i*62
		game.label(self,Stats.NAMES[key],Vector2(896,y),Vector2(81,28),21)
		var note=game.label(self,{"strength":"물리 공격","endurance":"물리 · 마법 방어","technique":"재사용 · 무력화","agility":"이동 · 공격 속도","magic":"마법 공격"}[key],Vector2(896,y+28),Vector2(229,23),14,game.MUTED)
		note.tooltip_text=Stats.HELP[key];note.mouse_filter=Control.MOUSE_FILTER_PASS
		stat_minus[key]=game.button(self,"−",Vector2(1147,y),Vector2(42,39),func():change_stat(key,-1))
		stat_labels[key]=game.label(self,"0",Vector2(1197,y+4),Vector2(67,30),22);stat_labels[key].horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		stat_plus[key]=game.button(self,"+",Vector2(1271,y),Vector2(42,39),func():change_stat(key,1))
	game.button(self,"직업 추천",Vector2(909,554),Vector2(190,40),func():sheet.stats=Creation.suggested(sheet.class_id);refresh())
	game.button(self,"초기화",Vector2(1120,554),Vector2(190,40),func():sheet.stats={};refresh())
	derived_label=game.label(self,"",Vector2(909,615),Vector2(400,113),18);derived_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	error_label=game.label(self,"",Vector2(52,784),Vector2(1041,32),18,Color("8c4239"))
	create_button=game.button(self,"모험 시작",Vector2(1147,779),Vector2(209,47),submit,true)
	avatar_keys=Content.avatar_options("warrior")
	hide()
func open(slot_number:int):
	selected_slot=slot_number;sheet={"name":"","class_id":"warrior","avatar":"auto","costume":"none","stats":Creation.suggested("warrior")};avatar_page=0
	name_field.text="";error_label.text="";show();refresh_avatars();refresh();name_field.grab_focus()
func select_class(key:String):
	sheet.class_id=key
	sheet.avatar="auto";sheet.costume="none";avatar_page=0;refresh_avatars()
	refresh()
func spent()->int:
	var result=0
	for value in sheet.get("stats",{}).values():result+=int(value)
	return result
func change_stat(key:String,amount:int):
	if key not in Stats.NAMES or (amount>0 and spent()>=Creation.POINTS) or (amount<0 and int(sheet.stats.get(key,0))<=0):return
	sheet.stats[key]=int(sheet.stats.get(key,0))+amount;refresh()
func refresh():
	if sheet.is_empty():return
	portrait.sheet=sheet
	appearance_label.text=preload("res://scripts/wardrobe.gd").label("base:"+sheet.class_id)
	appearance_label.tooltip_text=appearance_label.text
	balance_label.text="남은 점수  %d"%(Creation.POINTS-spent())
	for key in Stats.NAMES:
		stat_labels[key].text=str(sheet.stats.get(key,0));stat_minus[key].disabled=int(sheet.stats.get(key,0))<=0;stat_plus[key].disabled=spent()>=Creation.POINTS
	for key in job_buttons:job_buttons[key].text=("◆  " if sheet.class_id==key else "")+Content.CLASSES[key].name
	class_description.text=Creation.DESCRIPTIONS[sheet.class_id]
	var p={"class_id":sheet.class_id,"stats":sheet.stats,"level":1}
	derived_label.text="물리 공격력 %d    마법 공격력 %d\n물리 · 마법 방어력 %d\n공격 속도 +%.1f%%    이동 속도 +%.1f%%\n재사용 시간 −%.1f%%"%[22+Stats.damage(p,"sword"),22+Stats.damage(p,"staff"),Stats.bonus(p,"endurance")*2+6,(Stats.attack_speed(p)-1)*100,(Stats.move_speed(p)-1)*100,(1-Stats.cooldown_factor(p))*100]
	create_button.disabled=not Creation.reason(sheet).is_empty()
	error_label.text=Creation.reason(sheet) if not sheet.name.is_empty() or spent()!=Creation.POINTS else ""
func refresh_avatars():
	avatar_keys=["auto"];avatar_page=0
	sheet.avatar="auto";sheet.costume="none"
	for child in avatar_grid.get_children():avatar_grid.remove_child(child);child.queue_free()
	avatar_buttons.clear();avatar_grid.hide();previous_button.hide();next_button.hide();page_label.hide()
func submit():
	error_label.text=Creation.reason(sheet)
	if not error_label.text.is_empty():return
	if game.session.create_character(sheet,selected_slot):hide()
	else:error_label.text="이 기록에는 이미 모험가가 있거나 저장할 수 없습니다."
func cancel():
	hide();game.menu.show();name_field.release_focus()
