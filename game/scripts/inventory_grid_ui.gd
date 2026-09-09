extends Control

const Inventory = preload("res://scripts/inventory_model.gd")
const Content = preload("res://scripts/content.gd")
const ItemControl = preload("res://scripts/inventory_item_ui.gd")
const CELL = 50
var panel
var hovered_cell=Vector2i(-1,-1)
var hovered_size=Vector2i.ONE
var allowed=false

func setup(owner_panel):
	panel=owner_panel
	size=Vector2(Inventory.WIDTH,Inventory.HEIGHT)*CELL
	mouse_filter=Control.MOUSE_FILTER_STOP

func rebuild():
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var p=panel.player()
	for item in Inventory.bag_items(p):
		if not p.bag_positions.has(item.id):continue
		var saved=p.bag_positions[item.id]
		var control=ItemControl.new()
		control.configure(panel,item)
		control.position=Vector2(saved.x,saved.y)*CELL
		control.size=Vector2(Content.item_size(item,saved.rotated))*CELL
		control.selected=panel.selected_id==item.id
		control.faded=not panel.matches_filter(item)
		add_child(control)
	queue_redraw()

func _draw():
	var socket=preload("res://scripts/ui_art.gd").texture("socket")
	for x in range(Inventory.WIDTH):
		for y in range(Inventory.HEIGHT):draw_texture_rect(socket,Rect2(Vector2(x,y)*CELL,Vector2.ONE*CELL),false)
	if get_viewport().gui_is_dragging() and hovered_cell.x>=0:
		draw_rect(Rect2(Vector2(hovered_cell)*CELL,Vector2(hovered_size)*CELL),Color(0.2,0.7,0.5,0.45) if allowed else Color(0.85,0.2,0.2,0.45))


func _process(_delta: float):
	if is_visible_in_tree():queue_redraw()

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if not data is Dictionary or data.get("kind")!="inventory_item":return false
	hovered_cell=Vector2i(floori(at.x/CELL),floori(at.y/CELL))
	var p=panel.player().duplicate(true)
	if data.get("slot","")!="":p.equipment[data.slot]=""
	hovered_size=Content.item_size(panel.item_by_id(data.id),data.rotated)
	allowed=Inventory.can_place(p,data.id,hovered_cell,data.rotated)
	queue_redraw()
	return allowed

func _drop_data(at: Vector2, data: Variant):
	var cell=Vector2i(floori(at.x/CELL),floori(at.y/CELL))
	var args={"id":data.id,"x":cell.x,"y":cell.y,"rotated":data.rotated,"slot":data.get("slot","")}
	panel.game.session.act("unequip_to" if args.slot!="" else "move_item",JSON.stringify(args))
	hovered_cell=Vector2i(-1,-1)
	panel.refresh(true)
