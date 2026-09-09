extends Button

const Content = preload("res://scripts/content.gd")
var panel
var item: Dictionary = {}
var equip_slot = ""
var preview_only = false
var selected = false
var faded = false
var font: Font
var picture: Texture2D

func configure(owner_panel, value: Dictionary, slot: String = ""):
	panel=owner_panel
	item=value
	equip_slot=slot
	font=panel.game.fonts
	if not item.is_empty():
		picture=Content.icon_texture(item)
		tooltip_text=item.name+"\n드래그로 이동 · 한 칸 보관"
	else:tooltip_text=Content.SLOT_NAMES.get(slot,"")
	for state in ["normal","hover","pressed","focus"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	pressed.connect(func():
		if panel!=null and not item.is_empty():panel.select_item(item.id))
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _draw():
	var r=Rect2(Vector2.ONE*2,size-Vector2.ONE*4)
	var rarity=int(item.get("rarity",0))
	var alpha=0.30 if faded else 1.0
	var art=preload("res://scripts/ui_art.gd")
	draw_texture_rect(art.texture("equipped" if selected else ["socket","magic","rare"][clampi(rarity,0,2)]),r,false,Color(1,1,1,alpha))
	var display=picture
	if display==null and equip_slot!="":display=Content.icon_texture({"category":"weapon" if equip_slot=="weapon" else "armor","slot":equip_slot,"weapon_type":"sword"})
	if display!=null:
		var space=size-Vector2(13,17)
		var ratio=minf(space.x/display.get_width(),space.y/display.get_height())
		var dims=display.get_size()*ratio
		draw_texture_rect(display,Rect2((size-dims)*.5,dims),false,Color(1,1,1,alpha*(.24 if item.is_empty() else 1)))
	if is_hovered() and not preview_only:draw_rect(r,Color(1,1,1,0.13))
	if font!=null and not item.is_empty():
		var text_value=str(item.get("count",1)) if item.has("count") else ("+"+str(item.get("bonus",0)))
		draw_string_outline(font,Vector2(6,size.y-6),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color("152c2c"))
		draw_string(font,Vector2(6,size.y-6),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("fff0c9"))

func _get_drag_data(_at_position: Vector2) -> Variant:
	if preview_only or item.is_empty():return null
	panel.selected_id=item.id
	panel.refresh.call_deferred(true)
	var position_data=panel.player().bag_positions.get(item.id,{"rotated":false})
	var data={"kind":"inventory_item","id":item.id,"slot":equip_slot,"rotated":position_data.rotated}
	var preview=load("res://scripts/inventory_item_ui.gd").new()
	preview.configure(panel,item)
	preview.preview_only=true
	preview.modulate=Color(1,1,1,0.82)
	preview.size=Vector2(Content.item_size(item,data.rotated))*panel.grid.CELL
	preview.position=-preview.size*0.5
	data["preview"]=preview
	set_drag_preview(preview)
	return data

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if equip_slot=="" or not data is Dictionary or data.get("kind")!="inventory_item":return false
	var incoming=panel.item_by_id(data.id)
	return not incoming.is_empty() and incoming.get("slot","")==equip_slot

func _drop_data(_at_position: Vector2, data: Variant):
	panel.game.session.act("equip",data.id)
	panel.refresh(true)
