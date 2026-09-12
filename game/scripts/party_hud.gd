extends Control
const Status=preload("res://scripts/status_markers.gd")
const Icons=preload("res://scripts/icon_library.gd")
const Art=preload("res://scripts/ui_art.gd")
var game
var rows=[]
class Member extends Control:
	var game
	var actor={}
	var buffs=[]
	func _make_custom_tooltip(value:String)->Object:return Art.tooltip(game,value)
	func _draw():
		var label=str(actor.get("name",""));var font=game.fonts
		while label.length()>1 and font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x>132:label=label.left(label.length()-2)+"…"
		draw_string_outline(font,Vector2(0,12),label,HORIZONTAL_ALIGNMENT_LEFT,132,12,3,Color("17272d"))
		draw_string(font,Vector2(0,12),label,HORIZONTAL_ALIGNMENT_LEFT,132,12,Color("fff0d0"))
		meter(Rect2(0,17,132,8),float(actor.get("hp",0))/maxf(1,actor.get("max_hp",1)),Color("59ca85"))
		meter(Rect2(0,28,132,4),get_parent().resource(actor)/maxf(1,get_parent().resource_max(actor)),Color("64cbe4"))
		for i in range(buffs.size()):Icons.draw(self,buffs[i].icon,Rect2(142+(i%8)*19,int(i/8)*19,17,17))
	func meter(rect:Rect2,ratio:float,color:Color):
		draw_rect(rect.grow(1),Color("142329dd"));draw_rect(rect,Color("283e48"));draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(ratio,0,1),rect.size.y)),color)
static func resource(p:Dictionary)->float:return float(p.get("mana",p.get("stamina",0)))
static func resource_max(p:Dictionary)->float:return float(p.get("max_mana",p.get("max_stamina",1)))
static func buffs_for(p:Dictionary)->Array:
	return Status.timed_for(p).filter(func(entry):return entry.key!="enemy_slow_time")
func setup(owner_game):
	game=owner_game;mouse_filter=Control.MOUSE_FILTER_IGNORE
	for i in range(5):
		var row=Member.new();row.game=game;row.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(row);row.hide();rows.append(row)
func refresh():
	var players=game.session.state.get("players",{});var ids=players.keys();ids.sort();ids.erase(game.session.local_id)
	var y=0.
	for i in range(rows.size()):
		var row=rows[i];row.visible=i<ids.size()
		if not row.visible:continue
		row.actor=players[ids[i]];row.buffs=buffs_for(row.actor)
		row.position=Vector2(0,y);row.size=Vector2(294,maxf(34,ceilf(row.buffs.size()/8.)*19));y+=row.size.y+4
		row.tooltip_text="%s\n생명력 %d / %d\n%s %d / %d"%[row.actor.name,row.actor.hp,row.actor.max_hp,"마나" if row.actor.has("mana") else "기력",resource(row.actor),resource_max(row.actor)]
		for buff in row.buffs:row.tooltip_text+="\n%s · %d초"%[buff.name,ceili(buff.remaining)]
		row.queue_redraw()
	size=Vector2(294,y);visible=not ids.is_empty()
func world_regions()->Array[Rect2]:
	var result:Array[Rect2]=[]
	if not is_visible_in_tree():return result
	for row in rows:
		if not row.visible:continue
		var transform=row.get_global_transform_with_canvas();result.append(transform*Rect2(0,0,134,34))
		for i in range(row.buffs.size()):result.append(transform*Rect2(142+(i%8)*19,int(i/8)*19,17,17))
	return result
