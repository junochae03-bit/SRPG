extends Control
const Inspect=preload("res://scripts/enemy_inspection.gd")
const Icons=preload("res://scripts/icon_library.gd")
const Art=preload("res://scripts/ui_art.gd")
const Aim=preload("res://scripts/monster_aim.gd")
var game
var card:Control
var heading:Label
var subtitle:Label
var health:Label
var shapes:Label
var defense:Label
var status_row:Control
var target={}
var target_id=0
var target_is_corpse=false
var map_instance=0
var grace=0.0
var context=[]
var corpse_frames={}
var codex_button:Button
var drops_button:Button
func setup(owner_game):
	game=owner_game;mouse_filter=Control.MOUSE_FILTER_IGNORE
	card=Art.panel(self,Vector2(1079,403),Vector2(324,272),"paper",12)
	card.mouse_filter=Control.MOUSE_FILTER_STOP
	heading=game.label(card,"",Vector2(20,14),Vector2(284,33),22)
	subtitle=game.label(card,"",Vector2(20,50),Vector2(284,29),16)
	health=game.label(card,"",Vector2(52,83),Vector2(248,29),17)
	Icons.picture(card,"health",Vector2(20,84),Vector2(24,24))
	shapes=game.label(card,"",Vector2(20,115),Vector2(284,31),17)
	defense=game.label(card,"",Vector2(20,147),Vector2(284,31),16)
	status_row=Control.new();status_row.position=Vector2(20,182);status_row.size=Vector2(284,28);status_row.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(status_row)
	for label in [heading,subtitle,health,shapes,defense]:
		label.clip_text=true;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;label.mouse_filter=Control.MOUSE_FILTER_PASS
	codex_button=game.button(card,"도감",Vector2(18,220),Vector2(140,36),func():open_codex(false));Icons.attach(codex_button,"codex",22)
	drops_button=game.button(card,"드랍",Vector2(166,220),Vector2(140,36),func():open_codex(true));Icons.attach(drops_button,"pickup",22)
	hide()
func reset():
	target={};target_id=0;grace=0.;context=[];corpse_frames.clear();hide()
func _process(delta:float):
	if game.session==null or not game.session.connected or game.session.paused or not game.hud.visible:reset();return
	if map_instance!=game.dungeon.get_instance_id():reset();map_instance=game.dungeon.get_instance_id()
	var player:Dictionary=game.session.state.players.get(game.session.local_id,{})
	if player.is_empty() or player.hp<=0:reset();return
	var records=game.session.state.get("corpses",[])
	var point=game.aim_mouse_position()
	var hovered=game.get_viewport().gui_get_hovered_control()
	var own_hover=hovered!=null and (hovered==card or card.is_ancestor_of(hovered))
	var next={};var corpse=false
	if hovered==null:
		next=Aim.target_at(point,game.session.state.enemies,game.monster_aim_frames,player.pos,game.dungeon)
		if next.get("training",false):next={}
		if next.is_empty():
			for entry in Inspect.nearby(records,player.pos,game.vision):
				if corpse_frames.has(entry.record_id) and corpse_frames[entry.record_id].has_point(point):next=entry;corpse=true;break
	if not next.is_empty() and game.vision.sees(next.pos):
		target_id=int(next.record_id if corpse else next.id);target_is_corpse=corpse;target=next;grace=1.4
	else:
		if own_hover:grace=1.4
		else:grace-=delta
		if target_id>0:
			if target_is_corpse:
				var found=Inspect.nearby(records,player.pos,game.vision).filter(func(c):return int(c.record_id)==target_id)
				target=found[0] if not found.is_empty() else {}
			else:target=game.session.state.enemies.get(target_id,{})
	if target.is_empty() or not game.vision.sees(target.pos) or (not target_is_corpse and target.hp<=0) or grace<=0:reset();return
	show();present(target)
func present(enemy:Dictionary):
	var info=Inspect.description(enemy)
	var next=[target_is_corpse,info]
	if context==next:return
	context=next
	heading.text=info.name;heading.tooltip_text=info.name
	subtitle.text=info.subtitle;subtitle.tooltip_text=info.subtitle
	health.text=info.health
	defense.text=("방어 노출" if info.defense.get("exposed",false) else info.defense.get("name",""))+" · "+info.defense.get("counter","") if not info.defense.is_empty() else ""
	defense.tooltip_text=defense.text
	shapes.text="공격 · "+info.shapes;shapes.tooltip_text=shapes.text
	for child in status_row.get_children():status_row.remove_child(child);child.queue_free()
	for i in range(mini(8,info.statuses.size())):
		var icon=Icons.picture(status_row,info.statuses[i],Vector2(i*31,0),Vector2(25,25))
		icon.mouse_filter=Control.MOUSE_FILTER_PASS;icon.tooltip_text=Inspect.STATUS_NAMES.get(info.statuses[i],info.statuses[i])
	if info.statuses.size()>8:
		var more=game.label(status_row,"+%d"%(info.statuses.size()-8),Vector2(248,0),Vector2(36,28),16)
		more.mouse_filter=Control.MOUSE_FILTER_PASS;more.tooltip_text=" · ".join(info.statuses.slice(8).map(func(key):return Inspect.STATUS_NAMES.get(key,key)))
func open_codex(drops:bool):
	if target.is_empty() or not game.vision.sees(target.pos):return
	var id=Inspect.codex_id(target);var floor_number=int(target.get("floor",0))
	game.toggle_codex("drops" if drops else "monsters")
	var filters={"floor":floor_number} if floor_number>0 else {}
	if drops:filters["monster_id"]=id
	game.codex.open("drops" if drops else "monsters",filters)
	if not drops:game.codex.select_record(id)
	reset()
func draw_corpses():
	corpse_frames.clear()
	if game.session.paused:return
	var player:Dictionary=game.session.state.players.get(game.session.local_id,{})
	if player.is_empty():return
	for corpse in Inspect.nearby(game.session.state.get("corpses",[]),player.pos,game.vision):
		var point=game.world_point(corpse.pos);var rect=Rect2(point-Vector2(15,16),Vector2(30,30))
		game.draw_circle(point-Vector2(0,1),18,Color("202527ae"))
		Icons.draw(game,"monster",rect)
		corpse_frames[corpse.record_id]=rect.grow(5)
