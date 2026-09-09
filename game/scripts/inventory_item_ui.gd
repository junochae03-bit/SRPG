extends Button

const Content = preload("res://scripts/content.gd")
const Library = preload("res://scripts/icon_library.gd")
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
	material=preload("res://scripts/gat_art.gd").material()
	item=value
	equip_slot=slot
	font=panel.game.fonts
	if not item.is_empty():
		picture=Content.icon_texture(item)
		tooltip_text=item.name
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
	draw_texture_rect(art.texture("equipped" if selected else ["socket","magic","rare","rare","rare"][clampi(rarity,0,4)]),r,false,Color(1,1,1,alpha))
	if not item.is_empty():
		var color=preload("res://scripts/equipment_catalog.gd").COLORS[clampi(rarity,0,4)];color.a=alpha
		draw_rect(r.grow(-3),color,false,2.)
		if rarity>=3:
			for corner in [Vector2(7,7),Vector2(size.x-7,7),Vector2(7,size.y-7),size-Vector2(7,7)]:draw_circle(corner,2.3,color)
	var display=picture
	if display==null and equip_slot!="":display=Library.texture(equip_slot)
	if display!=null:
		var space=size-Vector2(9,12)
		var ratio=minf(space.x/display.get_width(),space.y/display.get_height())
		var dims=display.get_size()*ratio
		draw_texture_rect(display,Rect2((size-dims)*.5,dims),false,Color(1,1,1,alpha*(.6 if item.is_empty() else 1)))
	if not item.is_empty() and not preview_only:
		var badge="selected" if equip_slot!="" else "locked" if item.category in ["weapon","armor","accessory"] and not preload("res://scripts/equipment_catalog.gd").reason(panel.player(),item).is_empty() else ""
		if not badge.is_empty():draw_texture_rect(Library.texture(badge),Rect2(Vector2(size.x-22,4),Vector2(18,18)),false,Color(1,1,1,alpha))
	if is_hovered() and not preview_only:draw_rect(r.grow(-2),Color("f6dea0"),false,2.)
	if font!=null and not item.is_empty():
		var text_value=quantity_text()
		draw_string_outline(font,Vector2(6,size.y-6),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,17,4,Color("152c2c"))
		draw_string(font,Vector2(6,size.y-6),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("fff0c9"))

func quantity_text()->String:
	if item.has("count"):return str(item.count)
	return "+%d"%int(item.get("upgrade",0)) if int(item.get("upgrade",0))>0 else ""

func _gui_input(event:InputEvent):
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and event.double_click and not preview_only and not item.is_empty():
		panel.quick_activate(item.id);accept_event()

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
	return not incoming.is_empty() and incoming.get("slot","")==equip_slot and preload("res://scripts/equipment_catalog.gd").reason(panel.player(),incoming).is_empty()

func _drop_data(_at_position: Vector2, data: Variant):
	panel.game.session.act("equip",data.id)
	panel.refresh(true)
