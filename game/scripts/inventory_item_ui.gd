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
	var colors=[Color("92a299"),Color("699fbe"),Color("c29d58")]
	var border=Color("e4ba62") if selected else colors[clampi(rarity,0,2)]
	var alpha=0.30 if faded else 1.0
	draw_style_box(_box(Color("d5e0d7") if equip_slot!="" else Color("e7eee1"),border),r)
	if picture!=null:
		var space=size-Vector2(14,19)
		var ratio=minf(space.x/picture.get_width(),space.y/picture.get_height())
		var dims=picture.get_size()*ratio
		draw_texture_rect(picture,Rect2((size-dims)*0.5,dims),false,Color(1,1,1,alpha))
	if is_hovered() and not preview_only:draw_rect(r,Color(1,1,1,0.13))
	if font!=null and not item.is_empty():
		var text_value=str(item.get("count",1)) if item.has("count") else ("+"+str(item.get("bonus",0)))
		draw_string(font,Vector2(6,size.y-7),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("294744"))

func _box(background: Color, border: Color) -> StyleBoxFlat:
	var box=StyleBoxFlat.new()
	box.bg_color=background
	box.border_color=border
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(3)
	return box

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
