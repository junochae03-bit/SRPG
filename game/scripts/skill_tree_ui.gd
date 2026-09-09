extends Panel
const Content=preload("res://scripts/content.gd")
const Progression=preload("res://scripts/progression.gd")
var game
var choice=""
var mode="skills"
var signature=""
var class_picker:OptionButton
var title_label:Label
var detail:Label
var points:Label
var list:VBoxContainer
var scroll:ScrollContainer
var filter_index=0
var invest:Button
var bind_buttons=[]
var stat_buttons=[]
var search:LineEdit
var nodes={}
var comparison_rows=[]
func setup(owner_game):
	game=owner_game;Content.initialize_jobs();position=Vector2(24,24);size=Vector2(1392,852)
	add_theme_stylebox_override("panel",game.style(Color("162b39"),Color("c5ad76"),12))
	title_label=game.label(self,"직업과 스킬 · 6칸 조합",Vector2(220,20),Vector2(800,45),28,Color("25454b"))
	game.button(self,"닫기 K",Vector2(1220,20),Vector2(145,42),game.toggle_skills)
	points=game.label(self,"",Vector2(220,65),Vector2(800,35),20,Color("25454b"))
	class_picker=OptionButton.new();class_picker.add_theme_font_override("font",game.fonts);class_picker.get_popup().add_theme_font_override("font",game.fonts);class_picker.add_theme_font_size_override("font_size",20);class_picker.position=Vector2(28,111);class_picker.size=Vector2(420,42);add_child(class_picker)
	for key in Content.CLASSES:
		var c=Content.CLASSES[key];class_picker.add_item(c.name+(" · 30레벨 전직" if c.has("base") and not c.get("starter",false) else " · 기본 직업"));class_picker.set_item_metadata(class_picker.item_count-1,key)
	class_picker.item_selected.connect(func(i):game.session.act("class",class_picker.get_item_metadata(i));choice="";refresh(true))
	game.button(self,"스킬 초기화",Vector2(470,111),Vector2(180,42),func():game.session.act("reset_skills");refresh(true))
	game.button(self,"능력치 초기화",Vector2(675,111),Vector2(200,42),func():game.session.act("reset_stats");refresh(true))
	search=game.line_edit(self,"",Vector2(28,170),Vector2(625,40));search.placeholder_text="스킬 이름 · 효과 검색";search.text_changed.connect(func(_v):choice="";refresh(true))
	var filters=OptionButton.new();filters.add_theme_font_override("font",game.fonts);filters.get_popup().add_theme_font_override("font",game.fonts);filters.position=Vector2(1010,111);filters.size=Vector2(180,32);filters.add_item("전체 스킬");filters.add_item("액티브만");filters.add_item("투자 가능");add_child(filters);filters.item_selected.connect(func(i):filter_index=i;refresh(true))
	scroll=ScrollContainer.new();scroll.position=Vector2(28,225);scroll.size=Vector2(630,555);add_child(scroll)
	list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	detail=game.label(self,"",Vector2(700,175),Vector2(650,350),20,Color("25454b"));detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	invest=game.button(self,"배우기",Vector2(700,540),Vector2(640,45),invest_selected)
	for i in range(6):
		var slot=Content.ACTIONS[i]
		bind_buttons.append(game.button(self,"QFVCZX"[i]+" 배치",Vector2(700+(i%3)*215,605+(i/3)*50),Vector2(205,43),func():game.session.act("bind_skill",slot+":"+choice);refresh(true)))
	for i in range(4):
		var stat=Progression.NAMES.keys()[i]
		stat_buttons.append(game.button(self,Progression.NAMES[stat]+" +1",Vector2(700+i*162,745),Vector2(152,42),func():game.session.act("stat",stat);refresh(true)))
	game.label(self,"전직·장착 변경·초기화는 마을에서 · 60레벨부터 기존 직업 강화 · 최대 100레벨",Vector2(70,790),Vector2(1330,27),17,Color("25454b"))
	hide()
func player()->Dictionary:return game.session.state.players.get(game.session.local_id,{})
func _process(_delta):
	if visible:refresh()
func invest_selected():
	game.session.act("invest",choice);refresh(true)
func refresh(force=false):
	var p=player()
	if p.is_empty():return
	var next=JSON.stringify([p.class_id,p.skill_ranks,p.level,p.skill_loadout,p.stats,choice,search.text])
	if signature==next and not force:return
	signature=next
	points.text="Lv.%d · SP %d · 능력치 %d · %s"%[p.level,Content.available_points(p),Progression.available(p),"마스터" if p.level>=100 else "3차 강화" if p.level>=60 else "2차 전직" if p.level>=30 else "기초 성장"]
	for i in range(class_picker.item_count):
		var key=class_picker.get_item_metadata(i);var c=Content.CLASSES[key]
		class_picker.set_item_disabled(i,not game.dungeon.in_town(p.pos) or (c.has("base") and not c.get("starter",false) and (p.level<30 or Content.base_class(p.class_id)!=c.base)))
		if key==p.class_id:class_picker.select(i)
	for child in list.get_children():list.remove_child(child);child.queue_free()
	nodes.clear()
	var all=Content.SKILLS[p.class_id]
	var filtered=all.filter(func(n):return matches(n,p))
	if not filtered.is_empty() and not filtered.any(func(n):return n.id==choice):choice=filtered[0].id
	for n in all:
		var rank=int(p.skill_ranks.get(n.id,0));var maximum=Content.max_rank(n)
		if matches(n,p):
			var b=Button.new();b.add_theme_font_override("font",game.fonts);b.add_theme_font_size_override("font_size",19);b.icon=preload("res://scripts/icon_art.gd").skill(n);b.expand_icon=true;b.add_theme_constant_override("icon_max_width",36);b.text="%s  ·  %s  ·  Lv.%d  ·  %d/%d"%[n.name,{"active":"액티브","upgrade":"3차 강화","passive":"패시브"}.get(n.effect,"패시브"),n.get("level",1),rank,maximum];b.custom_minimum_size=Vector2(600,45);b.pressed.connect(func():choice=n.id;refresh(true));list.add_child(b);nodes[n.id]=b
		if n.id!=choice:continue
		var prereq=[]
		for parent in n.parents:
			for other in all:
				if other.id==parent:prereq.append(other.name+" "+str(n.get("required_rank",1))+"랭크")
		comparison_rows=[rank,mini(maximum,rank+1)]
		detail.text=n.name+"\n\n"+n.description+"\n\n해금: "+str(n.get("level",1))+"레벨 · "+str(rank)+"/"+str(maximum)+"랭크\n선행: "+("없음" if prereq.is_empty() else " 또는 ".join(prereq))
		if n.effect=="active":detail.text+="\n기력 %d · 재사용 %.1f초"%[n.get("cost",20),n.get("cooldown",7)*(1-.04*maxi(0,rank-1))]+"\n\n3차: "+n.get("upgrade_text","기존 성장 적용")
		if n.effect=="active" and Content.job(p):detail.text+="\n투자: 피해 ×%.2f → ×%.2f"%[1+.2*maxi(0,rank-1),1+.2*mini(4,rank)]
		invest.disabled=not Content.can_invest(p,n.id);invest.text="최대 랭크" if rank>=maximum else "배우기 · 1 SP" if rank==0 else "강화 · 1 SP"
		for i in range(6):
			bind_buttons[i].disabled=n.effect!="active" or rank<=0 or not game.dungeon.in_town(p.pos)
			bind_buttons[i].text="QFVCZX"[i]+(" 사용 중" if p.skill_loadout.get(Content.ACTIONS[i],"")==n.id else " 배치")
	for b in stat_buttons:b.disabled=Progression.available(p)<=0

func matches(n:Dictionary,p:Dictionary)->bool:
	return (search.text.is_empty() or (n.name+" "+n.description).contains(search.text)) and (filter_index==0 or (filter_index==1 and n.effect=="active") or (filter_index==2 and Content.can_invest(p,n.id)))
