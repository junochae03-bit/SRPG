extends Control
## Temporary feedback driven by accepted actions and authoritative combat clocks.
const Content=preload("res://scripts/content.gd")
const Scaling=preload("res://scripts/skill_scaling.gd")
const Icons=preload("res://scripts/icon_art.gd")
const Library=preload("res://scripts/icon_library.gd")
const Art=preload("res://scripts/ui_art.gd")
const MOVEMENT=preload("res://scripts/constellation_effects.gd").MOVEMENT
const MAX_RECENT=3
const READY_HOLD=.5
const CHARGE_SIZE=Vector2(12,80)
var game
var recent:Array=[]
var slots:Array=[]
var current_class=""
var charge_ratio=0.0
var charge_rect=Rect2()
var charge_visible=false
var presentation_visible=false
var charge_frame:StyleBoxFlat
var rune_rects:Array=[]

func setup(owner_game):
	game=owner_game;mouse_filter=Control.MOUSE_FILTER_IGNORE
	charge_frame=charge_style(Color("172521e8"),Color("e7c489"))
	for _index in range(MAX_RECENT):
		var holder=Control.new();holder.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.size=Vector2(64,104);add_child(holder)
		Art.picture(holder,Art.texture("medallion"),Vector2(3,0),Vector2(58,58))
		var icon=Art.picture(holder,null,Vector2(10,7),Vector2(44,44))
		var count=game.label(holder,"",Vector2(-4,61),Vector2(72,maxf(38,game.fonts.get_height(24))),24,Color("fff3d2"));count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		count.add_theme_color_override("font_outline_color",Color("172724"));count.add_theme_constant_override("outline_size",5)
		var ready=Library.picture(holder,"selected",Vector2(43,37),Vector2(23,23))
		slots.append({"holder":holder,"icon":icon,"number":count,"ready":ready,"charges":-1,"maximum":1});holder.hide()
	game.session.action_performed.connect(on_action_performed)
	game.session.entered.connect(clear)
	hide()

func player()->Dictionary:
	if game==null or not game.session.connected or game.session.sim==null:return {}
	return game.session.sim.players.get(game.session.local_id,{})

static func mode(node:Dictionary)->String:
	return str(Scaling.LEGACY.get(node.get("id",""),node).get("mode",""))

static func mobility(node:Dictionary,p:Dictionary={},events:Array=[])->bool:
	if node.get("effect","")!="active":return false
	var kind=mode(node)
	if kind in MOVEMENT:return true
	# Pull chains become a player dash against immovable bosses. A pull on a
	# normal enemy is not advertised as a movement cooldown.
	if kind in ["chain_pull","chain_group"]:
		for event in events:
			if event.get("owner",-1)==p.get("id",-2) and event.get("skill_id","")==node.id and event.get("origin",Vector2.ZERO).distance_to(event.get("end",Vector2.ZERO))>.05 and event.get("end",Vector2.INF).is_equal_approx(p.get("pos",Vector2.ZERO)):return true
	return false

static func cooldown_info(p:Dictionary,id:String)->Dictionary:
	if id!="dodge":return {"remaining":maxf(0,float(p.get("skill_cooldowns",{}).get(id,0))),"charges":-1,"maximum":1}
	if Content.job(p):
		var state=p.get("job_state",{});var maximum=2 if p.class_id=="infighter" else 1
		var charges=clampi(int(state.get("dash_charges",maximum)),0,maximum)
		return {"remaining":maxf(0,float(state.get("dash_timer",0))) if charges<maximum else 0.,"charges":charges,"maximum":maximum}
	return {"remaining":maxf(0,float(p.get("dodge_cd",0))),"charges":-1,"maximum":1}

func on_action_performed(action:String):
	var p=player()
	if p.is_empty():return
	if current_class!=p.class_id:clear();current_class=p.class_id
	var node={};var id=action
	if action!="dodge":
		if action not in Content.ACTIONS:return
		node=Content.active_node(p,action)
		if not mobility(node,p,game.session.sim.events):return
		id=node.id
	recent=recent.filter(func(record):return record.id!=id)
	recent.append({"id":id,"node":node.duplicate(true),"ready_elapsed":0.,"remaining":0.,"total":cooldown_info(p,id).remaining})
	while recent.size()>MAX_RECENT:recent.pop_front()
	refresh(0.)

func clear():
	recent.clear();rune_rects.clear();current_class="";charge_visible=false;presentation_visible=false
	for slot in slots:slot.holder.hide()
	hide();queue_redraw()

func modal_open()->bool:
	if game.session.paused:return true
	for property in ["menu","bag","skill_tree","town_panel","codex","help_panel","settings_panel","character_sheet","npc_dialogue"]:
		var panel=game.get(property)
		if panel!=null and panel.visible:return true
	return false

func screen_to_local(point:Vector2)->Vector2:
	return get_global_transform_with_canvas().affine_inverse()*point

func refresh(delta:float=0.):
	var p=player()
	if p.is_empty():clear();return
	if current_class!="" and current_class!=p.class_id:clear()
	current_class=p.class_id
	presentation_visible=not modal_open() and p.get("hp",0)>0
	visible=presentation_visible
	# Paused windows do not consume the brief ready flash or expose combat UI.
	if not presentation_visible:charge_visible=false;rune_rects.clear();return
	for record in recent:
		var info=cooldown_info(p,record.id);record.remaining=info.remaining;record.charges=info.charges;record.maximum=info.maximum
		record.total=maxf(record.total,record.remaining)
		record.ready_elapsed=record.ready_elapsed+delta if record.remaining<=0 else 0.
	recent=recent.filter(func(record):return record.ready_elapsed<READY_HOLD)
	var center=screen_to_local(Vector2(get_viewport().get_visible_rect().size.x*.5,570))
	for index in range(slots.size()):
		var slot=slots[index];slot.holder.visible=index<recent.size()
		if index>=recent.size():continue
		var record=recent[index];slot.holder.position=center+Vector2((index-(recent.size()-1)*.5)*78-32,0)
		var picture=Library.texture("dash") if record.id=="dodge" else Icons.skill(record.node)
		if slot.icon.texture!=picture:slot.icon.texture=picture;slot.icon.material=Art.icon_material(picture)
		slot.number.text=(str(ceili(record.remaining)) if record.remaining>=10 else "%.1f"%(ceilf(record.remaining*10)/10.)) if record.remaining>0 else ""
		slot.ready.visible=record.remaining<=0;slot.charges=record.charges;slot.maximum=record.maximum
	charge_visible=float(p.get("charge_time",-1))>=0
	charge_ratio=clampf(float(p.get("charge_time",0))/.9,0.,1.)
	# The world camera scales about a moving anchor. Convert that exact point
	# into this CanvasLayer's coordinates; do not assume a fixed screen center.
	var foot=get_viewport().canvas_transform*game.world_point(p.pos)
	charge_rect=Rect2(screen_to_local(foot+Vector2(52,-98)),CHARGE_SIZE)
	rune_rects.clear()
	if p.class_id=="runesword":
		var count=clampi(int(p.job_state.get("runes",0)),0,16)
		for i in range(count):
			var angle=TAU*i/maxi(1,count)+game.session.sim.clock*.35
			var rune_center=screen_to_local(foot+Vector2(cos(angle)*64,32+sin(angle)*24))
			rune_rects.append(Rect2(rune_center-Vector2(8,8),Vector2(16,16)))
	queue_redraw()

func _process(delta:float):refresh(delta)

func _draw():
	if not presentation_visible:return
	for rect in rune_rects:Library.draw(self,"rune",rect)
	for index in range(recent.size()):
		var record=recent[index];var slot=slots[index];var center=slot.holder.position+Vector2(32,29)
		if record.remaining>0 and record.total>0:draw_arc(center,30,-PI*.5,-PI*.5+TAU*record.remaining/record.total,40,Color("ead394"),2,true)
		if slot.maximum>1:
			for pip in range(slot.maximum):
				var point=slot.holder.position+Vector2(25+pip*14,57)
				draw_circle(point,4,Color("ffc875") if pip<slot.charges else Color("243834"));draw_arc(point,4,0,TAU,14,Color("f8e6b4"),1,true)
	if charge_visible:
		draw_style_box(charge_frame,charge_rect.grow(2))
		var fill=Rect2(charge_rect.position+Vector2(0,charge_rect.size.y*(1.-charge_ratio)),Vector2(charge_rect.size.x,charge_rect.size.y*charge_ratio))
		if fill.size.y>0:draw_rect(fill,Color("ff9d3b") if charge_ratio<1 else Color("ffd078"));draw_rect(Rect2(fill.position,Vector2(3,fill.size.y)),Color("ffe3a866"))
		if charge_ratio>=1:draw_line(charge_rect.position-Vector2(3,0),charge_rect.position+Vector2(15,0),Color("fff0b8"),3)

static func charge_style(background:Color,border:Color)->StyleBoxFlat:
	var style=StyleBoxFlat.new();style.bg_color=background;style.border_color=border;style.set_border_width_all(1);style.set_corner_radius_all(3);return style
