extends Control
const Presets=preload("res://scripts/build_presets.gd")
const Rules=preload("res://scripts/skill_build.gd")
const Art=preload("res://scripts/ui_art.gd")
const Icons=preload("res://scripts/icon_art.gd")
const Presentation=preload("res://scripts/skill_presentation.gd")
var tree
var body:Control
var picker:OptionButton
var quote={}
var target=""
var serial=-1
var commit:Button
var feedback:Label

func setup(owner_tree):
	tree=owner_tree;size=tree.size;mouse_filter=MOUSE_FILTER_STOP
	var surface=ColorRect.new();surface.color=Color(0,0,0,.68);surface.size=size;add_child(surface)
	var panel=Art.panel(self,Vector2(300,105),Vector2(950,650),"paper",24)
	tree.game.label(panel,"직업 빌드",Vector2(34,28),Vector2(610,42),29)
	tree.game.button(panel,"닫기",Vector2(804,28),Vector2(110,39),close)
	picker=tree.picker(panel,Vector2(35,90),Vector2(877,46))
	for key in Presets.choices(tree.player()):
		picker.add_item(str(key.name)+" · "+str(Presentation.branch(key)[0]));picker.set_item_metadata(picker.item_count-1,key.id)
	picker.item_selected.connect(func(i):target=str(picker.get_item_metadata(i));refresh())
	body=Control.new();body.position=Vector2(35,155);body.size=Vector2(877,387);panel.add_child(body)
	feedback=tree.game.label(panel,"",Vector2(35,555),Vector2(555,61),18);feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	commit=tree.game.button(panel,"미리 본 빌드 적용",Vector2(615,554),Vector2(297,49),apply_build)
	if tree.game.session.has_signal("request_completed"):tree.game.session.request_completed.connect(received)
	tree.game.session.status_changed.connect(func(_message):
		if not tree.game.session.connected:serial=-1;queue_free())
	target=str(picker.get_item_metadata(0));refresh();tree.style_tree(panel)

func refresh():
	tree.clear(body);quote=Presets.preview(tree.player(),target)
	var node=Rules.definition(target)
	var effects=tree.game.label(body,str(node.effects_text),Vector2.ZERO,Vector2(875,65),22);effects.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var tradeoff=tree.game.label(body,str(node.tradeoff),Vector2(0,69),Vector2(875,49),17);tradeoff.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	draw_loadout("현재",tree.player(),128)
	if quote.ok:
		draw_loadout("적용 후",quote.player,234)
		feedback.text="%d → %d SP · 남는 포인트 %d"%[Rules.spent_points(tree.player()),quote.spent,Rules.available_points(quote.player)]
	else:feedback.text=quote.reason
	commit.disabled=not quote.ok or tree.game.dungeon.zone!="town" or serial>=0
	if tree.game.dungeon.zone!="town":feedback.text="마을에서 빌드를 변경할 수 있습니다."
	tree.style_tree(body)

func draw_loadout(title:String,p:Dictionary,y:float):
	tree.game.label(body,title,Vector2(0,y+15),Vector2(95,31),20)
	for i in range(6):
		var id=str(p.skill_loadout.get(Presets.ACTIONS[i],""));var node=Rules.definition(id)
		var x=101+i*129
		var slot=tree.game.button(body,"",Vector2(x,y),Vector2(117,95),func():pass)
		slot.mouse_default_cursor_shape=Control.CURSOR_ARROW
		if node.is_empty():tree.game.label(slot,"—",Vector2(20,24),Vector2(77,31),24);continue
		Art.picture(slot,Icons.skill(node),Vector2(34,6),Vector2(48,48))
		var label=tree.game.label(slot,str(node.name),Vector2(5,59),Vector2(107,30),14);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		slot.tooltip_text=str(node.name)+" · 랭크 %d"%Rules.rank(p,node)

func apply_build():
	if serial>=0 or not quote.get("ok",false):return
	var success=tree.game.session.act("apply_build",JSON.stringify({"target":target,"signature":quote.signature}))
	if success and tree.game.session.get("network_role")=="client":serial=tree.game.session.sequence;commit.disabled=true;picker.disabled=true;feedback.text="빌드 적용 확인 중…";return
	if success:tree.choice="";tree.refresh(true);close()
	else:refresh();feedback.text="투자 상태가 바뀌었습니다. 새 미리보기를 확인하세요."

func received(kind:String,success:bool):
	if kind!="apply_build" or tree.game.session.completed_sequence!=serial:return
	serial=-1;picker.disabled=false
	if success:tree.choice="";tree.refresh(true);close()
	else:refresh();feedback.text="빌드를 적용하지 못했습니다. 현재 상태를 다시 확인하세요."

func close():
	queue_free()

func _notification(what):
	if what==NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree() and not is_visible_in_tree():queue_free()
