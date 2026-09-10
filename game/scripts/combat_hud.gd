extends Control
const Content=preload("res://scripts/content.gd")
const Circle=preload("res://scripts/action_circle.gd")
const Icons=preload("res://scripts/icon_library.gd")
const Art=preload("res://scripts/ui_art.gd")
var game
var p:Dictionary={}
var circles={}
var name_label:Label
var class_label:Label
var hp_label:Label
var money_label:Label
var region:Label
var quest:Label
var quest_title:Label
var toast:Label
var charge_label:Label
var portrait:Texture2D
var bag_button:Button
var growth_button:Button
var codex_button:Button
var boss_hud:Control
var job_resource:Control
var quest_icon="quest"
var quest_emblem:TextureRect
var quest_panel:Control
var quest_toggle:Button
var quest_collapsed=false
var slot_context:Array=[]
var slot_metadata:Dictionary={}
var portrait_context:Array=[]
var portrait_source_rect=Rect2()
var portrait_frame_size=Vector2.ZERO
var metadata_rebuilds=0
var profile_evaluations=0
var chrome:Control
var chrome_hidden=false
func setup(owner_game):
	game=owner_game;mouse_filter=Control.MOUSE_FILTER_IGNORE
	material=preload("res://scripts/gat_art.gd").material()
	name_label=white_label("",Vector2(127,23),Vector2(290,34),24)
	name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter=Control.MOUSE_FILTER_PASS
	class_label=white_label("",Vector2(129,66),Vector2(286,25),16,Color("f3e5c5"))
	hp_label=white_label("",Vector2(133,94),Vector2(270,22),15);hp_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	money_label=white_label("",Vector2(153,136),Vector2(258,25),16)
	region=white_label("",Vector2(1079,196),Vector2(324,30),18)
	region.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;region.add_theme_font_override("font",game.serif)
	quest_panel=Art.panel(self,Vector2(1092,237),Vector2(312,112),"paper",15)
	quest_title=game.label(quest_panel,"",Vector2(48,11),Vector2(224,27),18,Color("29434a"))
	quest_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	quest=game.label(quest_panel,"",Vector2(22,49),Vector2(272,52),16,Color("29434a"))
	quest.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	quest_emblem=Icons.picture(quest_panel,"quest",Vector2(13,10),Vector2(28,28))
	quest_toggle=Button.new();quest_toggle.position=Vector2.ZERO;quest_toggle.size=Vector2(312,44);quest_toggle.focus_mode=Control.FOCUS_NONE
	for state in ["normal","hover","pressed","focus"]:
		var style=StyleBoxEmpty.new();style.content_margin_right=14;quest_toggle.add_theme_stylebox_override(state,style)
	quest_toggle.text="−";quest_toggle.alignment=HORIZONTAL_ALIGNMENT_RIGHT;quest_toggle.add_theme_font_override("font",game.fonts);quest_toggle.add_theme_font_size_override("font_size",22);quest_toggle.add_theme_color_override("font_color",Color("29434a"))
	quest_toggle.pressed.connect(toggle_quest);quest_panel.add_child(quest_toggle)
	quest_toggle.tooltip_text="목표 접기";quest_toggle.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	bag_button=preload("res://scripts/hud_sprite_button.gd").new()
	bag_button.setup(game,Icons.texture("bag"),"가방","I",game.toggle_bag);bag_button.position=Vector2(954,20);add_child(bag_button)
	var book=Icons.texture("skills")
	growth_button=preload("res://scripts/hud_sprite_button.gd").new()
	growth_button.setup(game,book,"성장","K",game.toggle_skills);growth_button.position=Vector2(1052,20);add_child(growth_button)
	codex_button=preload("res://scripts/hud_sprite_button.gd").new()
	codex_button.setup(game,Icons.texture("codex"),"도감","B",game.toggle_codex);codex_button.position=Vector2(1150,20);add_child(codex_button)
	var definitions=[
		["skill_q","기술","Q",Vector2(1028,618),96],
		["skill_f","기술","F",Vector2(1152,618),96],
		["skill_v","기술","V",Vector2(1276,618),96],
		["skill_c","기술","C",Vector2(1028,750),96],
		["skill_z","기술","Z",Vector2(1152,750),96],
		["skill_x","기술","X",Vector2(1276,750),96],
		["potion","물약","1",Vector2(596,788),76],
		["interact","상호작용","E",Vector2(698,780),84],
		["return","마을 귀환","R",Vector2(808,796),68]]
	for entry in definitions:
		var control=Circle.new();control.setup(game,entry[0],entry[1],entry[2]);control.position=entry[3];control.size=Vector2.ONE*entry[4]
		add_child(control);circles[entry[0]]=control
		var action=entry[0]
		if action=="heavy":
			control.button_down.connect(func():game.session.act("heavy_begin"))
			control.button_up.connect(func():game.session.act("heavy"))
		else:control.pressed.connect(func():game.session.act(action))
		game.action_buttons[action]=control
		var badge=Label.new();badge.hide();control.add_child(badge);game.action_badges[action]=badge
	charge_label=white_label("",Vector2(982,575),Vector2(416,30),19,Color("ffe09d"));charge_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;charge_label.hide()
	job_resource=preload("res://scripts/job_resource_hud.gd").new();job_resource.setup(game);job_resource.position=Vector2(28,675);add_child(job_resource)
	toast=white_label("",Vector2(427,173),Vector2(612,54),20,Color("fff5cd"));toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	game.region_label=region;game.quest_label=quest;game.hud_stats=money_label;game.health_label=hp_label;game.toast=toast
	game.connection_label=white_label("",Vector2(44,874),Vector2(660,20),12,Color("e6f0dc"))
	game.connection_label.hide()
	boss_hud=preload("res://scripts/boss_hud.gd").new();boss_hud.setup(game);add_child(boss_hud)
	# Main attaches full-screen panels after setup. Keep only HUD controls in
	# this layer so modal edges never expose half a caption or a resource bar.
	chrome=Control.new();chrome.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(chrome)
	for child in get_children():
		if child!=chrome and child is CanvasItem:child.reparent(chrome)
	refresh_key_labels()

func refresh_chrome():
	var hidden=false
	for property in ["bag","skill_tree","town_panel","codex","help_panel","settings_panel","character_sheet"]:
		var panel=game.get(property)
		if panel!=null and panel.visible:hidden=true;break
	if hidden==chrome_hidden:return
	chrome_hidden=hidden;chrome.visible=not hidden;queue_redraw()

func _process(_delta):refresh_chrome()

func world_label_regions()->Array[Rect2]:
	var regions:Array[Rect2]=[]
	if not is_visible_in_tree() or chrome==null or not chrome.is_visible_in_tree():return regions
	var transform=get_global_transform_with_canvas()
	regions.append(transform*Rect2(19,20,400,145))
	for control in [bag_button,growth_button,codex_button,quest_panel,job_resource]:
		if control.is_visible_in_tree():regions.append(control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size).grow(4))
	for label in [name_label,class_label,hp_label,money_label,region,toast]:
		if label.is_visible_in_tree() and not label.text.is_empty():regions.append(label.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,label.size).grow(3))
	for control in circles.values():
		if not control.is_visible_in_tree():continue
		# 액션 버튼 바깥에 그리는 기술명과 키 글자도 점유 영역에 포함합니다.
		var text=control.caption_text();var pixels=15;var dimensions=game.fonts.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels)
		var baseline=Vector2(control.size.x*.5,control.size.y+21)
		var caption=Rect2(baseline-Vector2(dimensions.x*.5,game.fonts.get_ascent(pixels)),Vector2(dimensions.x,game.fonts.get_height(pixels)))
		var bounds=Rect2(Vector2.ZERO,control.size).merge(caption).merge(control.hotkey_layout().rect).grow(4)
		regions.append(control.get_global_transform_with_canvas()*bounds)
	if boss_hud.is_visible_in_tree() and not boss_hud.boss.is_empty():
		var boss=boss_hud.boss;var boss_transform=boss_hud.get_global_transform_with_canvas()
		if boss.get("training",false):regions.append(boss_transform*Rect2(481,0,480,92))
		else:
			var frame=preload("res://scripts/world_art.gd").frame("boss_bars",["warden","golem","sentinel"].find(boss.kind))
			regions.append(boss_transform*Rect2(Vector2(461,32),frame.texture.get_size()*(520./frame.texture.get_width())))
			regions.append(boss_transform*Rect2(461,0,520,32))
		if not boss.get("stagger",{}).is_empty():regions.append(boss_transform*Rect2(481,102 if boss.get("training",false) else 146,480,82))
	if game.map_overlay!=null and game.map_overlay.can_show():regions.append(game.map_overlay.get_global_transform_with_canvas()*Rect2(1244,26,160,160))
	var feedback=game.get("combat_feedback")
	if feedback!=null and feedback.is_visible_in_tree():
		for slot in feedback.slots:
			if slot.holder.is_visible_in_tree():regions.append(slot.holder.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,slot.holder.size).grow(4))
		if feedback.charge_visible:regions.append(feedback.get_global_transform_with_canvas()*feedback.charge_rect.grow(3))
	return regions

func key_label(action:String)->String:
	return game.keybindings.label(action) if game.get("keybindings")!=null else preload("res://scripts/key_bindings.gd").key_name(preload("res://scripts/key_bindings.gd").DEFAULTS[action])

func refresh_key_labels():
	for action in circles:
		circles[action].hotkey=key_label(action);circles[action].queue_redraw()
	for pair in [[bag_button,"bag"],[growth_button,"skills"],[codex_button,"codex"]]:
		if pair[0]!=null:pair[0].hotkey=key_label(pair[1]);pair[0].tooltip_text=pair[0].caption+" ("+pair[0].hotkey+")";pair[0].queue_redraw()

func refresh_portrait():
	var still={"class_id":p.class_id,"avatar":p.get("avatar","auto"),"costume":p.costume}
	var source:Texture2D=preload("res://scripts/gat_art.gd").frame(still,0.).texture
	portrait_frame_size=source.get_size()
	var bounds=Rect2(source.get_image().get_used_rect())
	if not bounds.has_area():bounds=Rect2(Vector2.ZERO,portrait_frame_size)
	# Retain the entire authored width and top: wide hats/ears cannot be cut by
	# the old fixed square around the foot. Only the lower body is cropped.
	portrait_source_rect=Rect2(bounds.position,Vector2(bounds.size.x,ceilf(bounds.size.y*.62)))
	var cropped=AtlasTexture.new();cropped.filter_clip=true
	if source is AtlasTexture:
		cropped.atlas=source.atlas;cropped.region=Rect2(source.region.position+portrait_source_rect.position,portrait_source_rect.size)
	else:cropped.atlas=source;cropped.region=portrait_source_rect
	portrait=cropped

func portrait_rect()->Rect2:
	if portrait==null:return Rect2()
	var dimensions=portrait.get_size();dimensions*=minf(72./dimensions.x,72./dimensions.y)
	dimensions.x=minf(72.,dimensions.x);dimensions.y=minf(72.,dimensions.y)
	return Rect2(Vector2(72,73)-dimensions*.5,dimensions)

func toggle_quest():
	quest_collapsed=not quest_collapsed
	quest.visible=not quest_collapsed;quest_panel.size.y=44 if quest_collapsed else 112
	quest_toggle.tooltip_text="목표 펼치기" if quest_collapsed else "목표 접기"
	quest_toggle.text="+" if quest_collapsed else "−"
	queue_redraw()

func white_label(value:String,at:Vector2,dimensions:Vector2,font_size:int,color:Color=Color("f3f7ee"))->Label:
	var label=game.label(self,value,at,dimensions,font_size,color)
	label.add_theme_color_override("font_outline_color",Color("203e45b0"));label.add_theme_constant_override("outline_size",4)
	return label

func refresh_slot_metadata():
	# Only presentation metadata is retained. Combat still resolves every cast,
	# including temporary resource, movement, follow-up and support effects.
	var weapon=game.session.sim.combat.weapon_type(p)
	var context=[p.class_id,p.skill_ranks,p.skill_loadout,p.stats,p.get("gear_stats",{}),p.equipment,p.get("equipped",""),p.inventory,p.level,p.max_hp,p.get("constellation_allocations",{}),weapon]
	if context==slot_context and not slot_metadata.is_empty():return
	slot_context=context.duplicate(true);slot_metadata.clear();metadata_rebuilds+=1
	var advanced=Content.job(p)
	var damage=game.session.sim.damage_for(p) if advanced else 0
	var bonuses={} if advanced else preload("res://scripts/active_skills.gd").bonuses(p)
	for key in circles:
		var node=Content.active_node(p,key) if key in Content.ACTIONS else {}
		var rank=int(p.skill_ranks.get(node.get("id",""),0));var trained=rank>0
		var maximum={"nova":4.0,"dodge":0.8,"potion":2.0,"return":8.0}.get(key,0.8)
		if key in Content.ACTIONS and trained:
			var profile=preload("res://scripts/job_balance.gd").profile(p,node,rank,damage,p.max_hp,p.skill_ranks.get(node.id+"_upgrade",0)>0) if advanced else preload("res://scripts/skill_scaling.gd").profile(node,rank,bonuses)
			maximum=profile.cooldown;profile_evaluations+=1
		var picture=Icons.texture("skill_empty" if node.is_empty() else "skill_locked") if key in Content.ACTIONS and not trained else preload("res://scripts/icon_art.gd").action(p,key,weapon)
		slot_metadata[key]={"node":node,"rank":rank,"trained":trained,"max_cooldown":maximum,"picture":picture}

func refresh():
	refresh_chrome()
	p=game.session.state.players.get(game.session.local_id,{})
	if p.is_empty():return
	name_label.text=p.name;name_label.tooltip_text=p.name
	class_label.text=Content.CLASSES[p.class_id].name
	hp_label.text="%d / %d" % [p.hp,p.max_hp]
	money_label.text="%s 금화" % str(p.gold)
	var floor_number=game.dungeon.floor_number
	region.text="햇살 마을" if game.dungeon.zone=="town" else preload("res://scripts/abyss_catalog.gd").config(floor_number).name if floor_number>0 else "꽃바람 숲 · 튜토리얼"
	quest_title.text="100층으로 향하는 길";quest_icon="quest"
	if not p.tutorial_done:
		quest_title.text="첫 모험 · 꽃바람 숲";quest_icon="quest_complete" if p.tutorial_kills>=5 else "quest";quest.text="숲의 적 처치   %d / 5\n%s"%[mini(5,p.tutorial_kills),"햇살 마을로 향하기" if p.tutorial_kills>=5 else "보상 · 금화 100"]
	elif game.dungeon.zone=="town":quest.text="최고 돌파   B%d / B100\n다음 목적지 · 원정의 문"%p.cleared_floor
	else:
		var clear=not game.session.state.enemies.values().any(func(e):return e.get("guardian",false) and e.hp>0)
		quest_title.text="B%d · %s"%[floor_number,"레이드" if floor_number%10==0 else "던전 탐사"]
		quest_icon="trophy" if floor_number==100 and clear else "quest_complete" if clear else "boss" if floor_number%10==0 else "quest"
		quest.text="100층 레이드 완료\n마력핵을 잠재웠습니다." if floor_number==100 and clear else "다음 층으로 향하는 길이\n열렸습니다." if clear else "최종 보스 격파" if floor_number==100 else "보스 격파 · 다음 층 해금" if floor_number%10==0 else "최심부 수문장 격파"
	game.connection_label.text=""
	quest_title.tooltip_text=quest_title.text
	quest_emblem.texture=Icons.texture(quest_icon)
	var appearance=[p.class_id,p.get("avatar","auto"),p.costume,p.get("legacy_costume","")]
	if appearance!=portrait_context:
		portrait_context=appearance
		refresh_portrait()
	refresh_slot_metadata()
	for key in circles:
		var control=circles[key];var metadata=slot_metadata[key]
		control.cooldown=p.get(key+"_cd",0.0);control.max_cooldown=metadata.max_cooldown
		if key=="heavy":control.cooldown=p.attack_cd
		if key=="potion":control.count=str(p.potions)
		if key=="nova":control.caption=Content.CLASSES[p.class_id].skill
		if key in Content.ACTIONS:
			var node=metadata.node;var trained=metadata.trained
			control.caption=node.get("name","미장착") if trained else "미장착" if node.is_empty() else "미습득"
			control.locked=not trained
			control.cooldown=p.skill_cooldowns.get(node.get("id",""),0.)
			control.rank_text=str(metadata.rank)+"/"+str(Content.max_rank(node)) if trained else ""
		control.picture=metadata.picture
		control.tooltip_text=control.caption+" ("+control.hotkey+")"
		if key in Content.ACTIONS and control.locked:control.tooltip_text=key_label("skills")+" · 성장에서 기술을 배우고 배치하세요." if metadata.node.is_empty() else metadata.node.name+" · 아직 배우지 않은 기술"
		control.queue_redraw()
		game.action_badges[key].text="%.1fs" % control.cooldown if control.cooldown>0 else ""
	var interact=circles.interact;interact.caption="상호작용"
	if game.dungeon.zone=="town":
		if not preload("res://scripts/world_catalog.gd").nearest(p.pos).is_empty():interact.caption="대화"
	elif game.session.state.drops.values().any(func(drop):return drop.owner==p.id and drop.pos.distance_to(p.pos)<=1.8):interact.caption="줍기"
	elif game.dungeon.floor_number>0 and p.pos.distance_to(game.dungeon.exit_position)<2.8:interact.caption="출구"
	elif game.dungeon.in_town(p.pos):interact.caption="회복 · 보급"
	interact.tooltip_text=interact.caption+" ("+interact.hotkey+")"
	charge_label.text="";charge_label.hide()
	job_resource.refresh(p)
	queue_redraw()

func _draw():
	if p.is_empty() or chrome_hidden:return
	Icons.draw(self,"gold",Rect2(126,136,22,22))
	var center=Vector2(72,73)
	draw_texture_rect(Art.texture("medallion"),Rect2(center-Vector2(53,53),Vector2(106,106)),false)
	if portrait:draw_texture_rect(portrait,portrait_rect(),false)
	draw_string_outline(game.bold_font,Vector2(46,139),"LV."+str(p.level),HORIZONTAL_ALIGNMENT_CENTER,70,16,4,Color("263b35"))
	draw_string(game.bold_font,Vector2(46,139),"LV."+str(p.level),HORIZONTAL_ALIGNMENT_CENTER,70,16,Color("fff0b9"))
	bar(Rect2(130,95,278,23),float(p.hp)/p.max_hp,Color("5ad18c"),0)
	bar(Rect2(130,123,278,7),p.stamina/p.max_stamina,Color("67cde2"),0)
	bar(Rect2(46,897,1350,3),float(p.xp)/preload("res://scripts/progression.gd").xp_required(p.level),Color("efd45c"),0)

func bar(rect:Rect2,ratio:float,color:Color,segments:int):
	draw_rect(rect,Color("1b3543cf"));draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(ratio,0,1),rect.size.y)),color)
	for i in range(1,segments):
		var at=rect.position+Vector2(rect.size.x*i/segments,0);draw_line(at,at+Vector2(0,rect.size.y),Color("20454c90"),2)
