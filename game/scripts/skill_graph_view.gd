extends Control
const Art=preload("res://scripts/ui_art.gd")
const Icons=preload("res://scripts/icon_art.gd")
const Rules=preload("res://scripts/skill_build.gd")
const Presentation=preload("res://scripts/skill_presentation.gd")
var owner_tree
var definitions:Dictionary={}
var positions:Dictionary={}
var node_controls:Dictionary={}
var centers:Dictionary={}
var cluster_names:Dictionary={}
var states:Dictionary={}
var zoom=0.5
var offset=Vector2.ZERO
var bounds=Rect2()
var planned_ids:Array=[]
var dragging=false
var drag_start=Vector2.ZERO
var drag_offset=Vector2.ZERO
var hover_id=""
var class_id=""
var scope_cluster=0
var scope_extra:Dictionary={}
const BRANCH_COLUMNS=3
const NODE_GAP=Vector2(166,139)
var scroll_vertical:float:
	get:return -offset.y
	set(value):offset.y=-value;layout_controls()
class Medal extends Button:
	var graph
	var id=""
	var datum:Dictionary={}
	var status:Dictionary={}
	var name_label:Label
	func active_badge()->bool:return Presentation.active(datum)
	func shape()->String:
		return "crest" if datum.get("type","")=="keystone" else {"active":"active_square","active_module":"module_diamond","character_passive":"behavior_crest","stat_passive":"passive_round"}[Presentation.role(datum)]
	func role_badge_rect()->Rect2:
		if Presentation.role(datum)=="stat_passive":return Rect2()
		var width=graph.owner_tree.game.fonts.get_string_size(Presentation.role_caption(datum),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		return Rect2(Vector2((size.x-width)*.5-5,-13),Vector2(width+10,21))
	func icon_rect()->Rect2:
		var margin=size.x*(.21 if datum.get("type","")=="keystone" else .17)
		return Rect2(Vector2.ONE*margin,size-Vector2.ONE*margin*2)
	func _ready():
		mouse_filter=Control.MOUSE_FILTER_PASS;focus_mode=Control.FOCUS_NONE
		for state in ["normal","hover","pressed","disabled","focus"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	func _draw():
		if datum.is_empty():return
		var chosen=graph.owner_tree.choice==id;var learned=int(status.get("rank",0))>0;var blocked=str(status.get("reason","")).begins_with("배타");var kind=datum.get("type","original")
		var role=Presentation.role(datum)
		var frame="crest" if kind=="keystone" or role=="character_passive" else "magic" if role in ["active","active_module"] else "medallion"
		if role=="active_module":
			draw_set_transform(size*.5,PI*.25,Vector2.ONE*.76)
			draw_texture_rect(Art.texture(frame),Rect2(-size*.5,size),false)
			draw_set_transform(Vector2.ZERO)
		else:draw_texture_rect(Art.texture(frame),Rect2(Vector2.ZERO,size),false)
		var enabled=learned or bool(status.get("can_invest",false));draw_texture_rect(icon,icon_rect(),false,Color.WHITE if enabled else Color(.72,.76,.73,1.))
		if graph.scope_cluster>=0 and graph.scope_extra.is_empty() and Presentation.role(datum)!="stat_passive":
			var font=graph.owner_tree.game.fonts;var label=Presentation.role_caption(datum);var width=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
			draw_texture_rect(Art.plain_paper(),role_badge_rect(),false)
			draw_string(font,Vector2((size.x-width)*.5,3),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("284c56"))
		if chosen:draw_arc(size*.5,size.x*.49,0,TAU,40,Color("e6b848"),3,true)
		elif int(status.get("rank",0))>0:draw_arc(size*.5,size.x*.44,-PI*.5,TAU*float(status.rank)/maxi(1,int(datum.max_rank))-PI*.5,32,Color("70cbb5"),2,true)
		if blocked:
			draw_line(size*Vector2(.20,.78),size*Vector2(.80,.22),Color("ba775c"),3,true);draw_line(size*Vector2(.20,.22),size*Vector2(.80,.78),Color("ba775c"),3,true)
		elif bool(status.get("can_invest",false)):
			var point=Vector2(size.x*.85,size.y*.76);draw_circle(point,9,Color("735729"));draw_circle(point,7,Color("f8e3a6"));draw_line(point-Vector2(4,0),point+Vector2(4,0),Color("375c4e"),2,true);draw_line(point-Vector2(0,4),point+Vector2(0,4),Color("375c4e"),2,true)
		elif not learned and graph.scope_cluster>=0:
			var caption="LV.%d"%int(datum.get("level",1)) if str(status.get("reason","")).begins_with("LV.") else "선행" if str(status.get("reason","")).begins_with("선행") else ""
			if not caption.is_empty():
				var font=graph.owner_tree.game.fonts;var width=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
				draw_texture_rect(Art.plain_paper(),Rect2(Vector2(size.x*.5-width*.5-5,size.y-17),Vector2(width+10,17)),false);draw_string(font,Vector2(size.x*.5-width*.5,size.y-4),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("635a43"))
		if int(status.get("rank",0))>0 and graph.zoom>.55:
			var caption="%d/%d"%[int(status.rank),int(datum.max_rank)];var at=Vector2(size.x*.72,size.y-2)
			draw_texture_rect(Art.texture("scroll"),Rect2(at-Vector2(25,15),Vector2(50,22)),false)
			var font=graph.owner_tree.game.fonts;var width=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
			draw_string(font,at-Vector2(width*.5,0),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("34594e"))
	func _gui_input(event):
		if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			graph.zoom_at(graph.get_local_mouse_position(),1.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1./1.12);accept_event()
		elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			# A node click selects the node. Panning starts only on the map itself,
			# so its bubbled press cannot suppress the Button's release signal.
			graph.dragging=false

func setup(tree):
	owner_tree=tree;clip_contents=true;mouse_filter=Control.MOUSE_FILTER_STOP
	resized.connect(func():if not definitions.is_empty():fit_scope())

func rebuild(list:Array,p:Dictionary):
	var changed=class_id!=p.class_id or definitions.size()!=list.size()
	if changed:
		for child in get_children():remove_child(child);child.queue_free()
		class_id=p.class_id;definitions.clear();positions.clear();node_controls.clear();cluster_names.clear();planned_ids=[];scope_extra.clear();scope_cluster=0
		centers={0:Vector2(510,340),1:Vector2(1650,340),2:Vector2(2790,340),3:Vector2(1080,1080),4:Vector2(2220,1080)}
		var groups={}
		for node in list:
			definitions[node.id]=node;var cluster=clampi(int(node.get("cluster",0)),0,4)
			if not groups.has(cluster):groups[cluster]={"original":[],"special":[]}
			groups[cluster]["original" if node.get("type","original")=="original" else "special"].append(node)
			if node.has("cluster_name"):cluster_names[cluster]=str(node.cluster_name)
		for cluster in groups:
			for category in ["original","special"]:
				var records:Array=groups[cluster][category];var rows=ceili(records.size()/float(BRANCH_COLUMNS))
				for i in range(records.size()):
					var node=records[i];var origin_x=-2.5*NODE_GAP.x if category=="original" else .5*NODE_GAP.x
					if groups[cluster].original.is_empty():origin_x=-NODE_GAP.x
					if groups[cluster].original.size()>9:
						var at=i+(groups[cluster].original.size() if category=="special" else 0)
						if node.get("type","")=="keystone":at=19
						positions[node.id]=centers[cluster]+Vector2((at%5-2)*210,(int(at/5)-1.5)*150)
					else:positions[node.id]=centers[cluster]+Vector2(origin_x+(i%BRANCH_COLUMNS)*NODE_GAP.x,(int(i/BRANCH_COLUMNS)-(rows-1)*.5)*NODE_GAP.y)
					var b=Medal.new();b.graph=self;b.id=node.id;b.datum=node;b.icon=Icons.skill(node);b.material=Art.icon_material(b.icon);b.expand_icon=true;b.add_theme_constant_override("icon_max_width",1)
					for state_name in ["normal","hover","pressed","focus","disabled"]:b.add_theme_color_override("icon_"+state_name+"_color",Color.TRANSPARENT)
					b.pressed.connect(func():owner_tree.select_node(node.id))
					b.mouse_entered.connect(func():hover_id=node.id;queue_redraw());b.mouse_exited.connect(func():hover_id="";queue_redraw())
					add_child(b);node_controls[node.id]=b
					b.name_label=owner_tree.game.label(b,Presentation.short_label(node),Vector2.ZERO,Vector2(158,39),14)
					b.name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;b.name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;b.name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
					b.name_label.add_theme_color_override("font_outline_color",Color("fff5dc"));b.name_label.add_theme_constant_override("outline_size",4)
		bounds=Rect2(Vector2(0,0),Vector2(3320,1420));fit_scope()
	states.clear()
	for id in definitions:
		states[id]=Rules.node_state(p,id);var b=node_controls[id];b.status=states[id]
		b.modulate=Color.WHITE if owner_tree.matches(definitions[id],p) else Color(.60,.64,.62,.35)
		b.tooltip_text=definitions[id].name+"\n"+("액티브 · " if Presentation.active(definitions[id]) else "")+Presentation.short_label(definitions[id])+"\n"+str(definitions[id].get("description",""))+"\n"+str(states[id].get("reason",""));b.queue_redraw()
	if scope_cluster>=0 and definitions.has(owner_tree.choice) and not in_scope(owner_tree.choice):
		scope_cluster=int(definitions[owner_tree.choice].get("cluster",0));scope_extra.clear();fit_scope()
	layout_controls()

func fit_all():
	scope_cluster=-1;scope_extra.clear();fit_scope();owner_tree.refresh_branch_picker()
func set_scope(cluster:int):
	scope_cluster=clampi(cluster,-1,4);scope_extra.clear();planned_ids.clear();fit_scope();owner_tree.refresh_branch_picker()
func in_scope(id:String)->bool:
	return definitions.has(id) and (scope_cluster<0 or int(definitions[id].get("cluster",0))==scope_cluster or scope_extra.has(id))
func scope_bounds()->Rect2:
	if scope_cluster<0:return bounds
	var result=Rect2();var found=false
	for id in positions:
		if not in_scope(id):continue
		if not found:result=Rect2(positions[id],Vector2.ZERO);found=true
		else:result=result.expand(positions[id])
	return result.grow(76) if found else bounds
func fit_scope():
	var area=scope_bounds()
	if area.size==Vector2.ZERO:return
	zoom=minf((size.x-24)/area.size.x,(size.y-36)/area.size.y);offset=size*.5-area.get_center()*zoom;layout_controls()
	if scope_cluster>=0 and scope_extra.is_empty():offset.y-=12;layout_controls()
func reveal_plan():
	scope_extra.clear()
	for id in planned_ids:
		scope_extra[id]=true
		for parent in definitions.get(id,{}).get("parents",[]):
			if int(states.get(parent,{}).get("rank",0))>0:scope_extra[parent]=true
	fit_scope()

func world_to_view(point:Vector2)->Vector2:return point*zoom+offset
func view_to_world(point:Vector2)->Vector2:return (point-offset)/zoom
func zoom_at(point:Vector2,factor:float):
	var anchor=view_to_world(point);var fit=minf((size.x-44)/maxf(1,bounds.size.x),(size.y-44)/maxf(1,bounds.size.y))
	zoom=clampf(zoom*factor,minf(.35,fit),1.65);offset=point-anchor*zoom;clamp_pan();layout_controls()
func pan_by(delta:Vector2):offset+=delta;clamp_pan();layout_controls()
func clamp_pan():
	var margin=Vector2(180,130);var minimum=size-margin-bounds.end*zoom;var maximum=margin-bounds.position*zoom
	offset.x=clampf(offset.x,minf(minimum.x,maximum.x),maxf(minimum.x,maximum.x));offset.y=clampf(offset.y,minf(minimum.y,maximum.y),maxf(minimum.y,maximum.y))
func focus_node(id:String,near=true):
	if not positions.has(id):return
	if scope_cluster>=0 and not in_scope(id):scope_cluster=int(definitions[id].get("cluster",0));scope_extra.clear();owner_tree.refresh_branch_picker()
	if near:zoom=maxf(zoom,.80)
	offset=size*.5-positions[id]*zoom;layout_controls()
func layout_controls():
	for id in node_controls:
		# A sparse branch must not inflate its medals into the next row's text.
		# Manual zoom still enlarges both spacing and art; fit view keeps readable gaps.
		var b=node_controls[id];var type=definitions[id].get("type","original");var base=104. if type=="keystone" else 80. if type=="notable" else 84. if definitions[id].get("effect","")=="active" else 78.
		var readable=scope_cluster>=0 and scope_extra.is_empty()
		var minimum=84. if type=="keystone" else 80. if type=="notable" else 84. if definitions[id].get("effect","")=="active" else 78.
		var diameter=clampf(base*zoom,minimum if readable else 42. if type=="keystone" else 30.,base*1.24)
		b.size=Vector2.ONE*ceilf(diameter);b.position=(world_to_view(positions[id])-b.size*.5).round();b.visible=in_scope(id) and Rect2(-b.size,size+b.size*2).has_point(b.position);b.queue_redraw()
		b.name_label.visible=readable or id in [owner_tree.choice,hover_id] and zoom>.6
		b.name_label.position=Vector2((b.size.x-158)*.5,b.size.y+3);b.name_label.size=Vector2(158,39)
		b.name_label.add_theme_font_override("font",owner_tree.game.bold_font if Presentation.active(definitions[id]) else owner_tree.game.fonts)
	queue_redraw()
	if owner_tree!=null and owner_tree.zoom_label!=null:owner_tree.zoom_label.text="%d%%"%roundi(zoom*100)

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:zoom_at(event.position,1.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1./1.12);accept_event()
		elif event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE]:
			dragging=event.pressed;drag_start=event.position;drag_offset=offset;accept_event()
	elif event is InputEventMouseMotion and dragging:
		offset=drag_offset+event.position-drag_start;clamp_pan();layout_controls();accept_event()

func _draw():
	if owner_tree==null:return
	var p=owner_tree.player();var chosen=owner_tree.choice
	for cluster in centers:
		if scope_cluster>=0 and cluster!=scope_cluster:continue
		var center=world_to_view(centers[cluster])
		if not Rect2(-Vector2.ONE*100,size+Vector2.ONE*200).has_point(center):continue
		if scope_cluster<0:
			var heading=cluster_names.get(cluster,["전투의 근원","흐름의 전환","집중과 파괴","수호와 회복","기동과 제어"][cluster])
			var at=center-Vector2(0,260*zoom)
			Art.texture("scroll").draw_rect(get_canvas_item(),Rect2(at-Vector2(85,16),Vector2(170,36)),false)
			text_center(heading,at+Vector2(0,8),16,Color("28494d"))
	for id in definitions:
		if not in_scope(id):continue
		var node=definitions[id]
		for parent in node.get("parents",[]):
			if not positions.has(parent) or not in_scope(parent):continue
			var a=world_to_view(positions[parent]);var b=world_to_view(positions[id]);var direction=(b-a).normalized();a+=direction*(node_controls[parent].size.x*.52);b-=direction*(node_controls[id].size.x*.52)
			var learned=int(states.get(id,{}).get("rank",0))>0 and int(states.get(parent,{}).get("rank",0))>0
			var focus=id==chosen or parent==chosen;var planned=id in planned_ids and (parent in planned_ids or int(states.get(parent,{}).get("rank",0))>0)
			var frontier=bool(states.get(id,{}).get("can_invest",false)) and int(states.get(parent,{}).get("rank",0))>0
			var blocked=str(states.get(id,{}).get("reason","")).begins_with("배타")
			if planned or blocked:draw_dashed_line(a,b,Color("bd7e4d") if blocked else Color("ba8a26"),2 if planned else 1,7,true)
			else:
				draw_line(a,b,Color("338e7f") if learned else Color("b68c41") if focus or frontier else Color("89948225"),3.2 if learned or focus else 2. if frontier else 1.,true)
				if learned:
					var side=(b-a).orthogonal().normalized()*2;draw_line(a+side,b+side,Color("69b6a180"),1,true)
			if focus or planned or frontier:
				var tip=a.lerp(b,.70);draw_colored_polygon(PackedVector2Array([tip,tip-direction.rotated(.45)*8,tip-direction.rotated(-.45)*8]),Color("aa772c"))
	if definitions.has(chosen):
		var target=str(definitions[chosen].get("target_active_id",""))
		if definitions.has(target) and in_scope(target):
			var a=world_to_view(positions[chosen]);var b=world_to_view(positions[target]);var direction=(b-a).normalized()
			a+=direction*node_controls[chosen].size.x*.55;b-=direction*node_controls[target].size.x*.55
			draw_dashed_line(a,b,Color("416c9c"),3,9,true)
			draw_colored_polygon(PackedVector2Array([b,b-direction.rotated(.45)*13,b-direction.rotated(-.45)*13]),Color("416c9c"))
		var tags:Array=definitions[chosen].get("tags",[])
		for id in definitions:
			if id==chosen or not in_scope(id) or not definitions[id].get("tags",[]).any(func(tag):return tag in tags):continue
			if owner_tree.tag_filter!="" or id==hover_id:draw_dashed_line(world_to_view(positions[chosen]),world_to_view(positions[id]),Color("627faea0"),1,3,true)

func text_center(value:String,point:Vector2,font_size:int,color:Color):
	var font=owner_tree.game.fonts;point.x-=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*.5
	font.draw_string_outline(get_canvas_item(),point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color("fff4d9"));draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
