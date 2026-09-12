extends Control
## Personal profile at top left; consumables above skills and class detail below.
const Art=preload("res://scripts/ui_art.gd")
const Content=preload("res://scripts/content.gd")
const PROFILE=Rect2(20,711,370,172)
const PERSONAL=Rect2(20,16,385,141)
const SKILLS=Rect2(490,793,546,94)
var hud
var tabs=[]
var consumables:Control
var party:Control
var personal_surface:Control
var backings_visible=true
var selected_tab=1
func setup(owner_hud):
	hud=owner_hud;mouse_filter=Control.MOUSE_FILTER_IGNORE;show_behind_parent=true
	hud.name_label.position=Vector2(127,23);hud.name_label.size=Vector2(263,29);hud.name_label.add_theme_font_size_override("font_size",21)
	hud.class_label.position=Vector2(129,66);hud.class_label.size=Vector2(258,22);hud.class_label.show();hud.money_label.hide()
	hud.hp_label.position=Vector2(130,95);hud.hp_label.size=Vector2(250,20);hud.hp_label.add_theme_font_size_override("font_size",12);hud.hp_label.mouse_filter=Control.MOUSE_FILTER_STOP
	hud.name_label.mouse_filter=Control.MOUSE_FILTER_STOP
	hud.bag_button.hide();hud.growth_button.hide()
	hud.status_strip.position=Vector2(28,505)
	hud.job_resource.position=Vector2(20,711);hud.job_resource.scale=Vector2.ONE*.86
	for child in hud.job_resource.get_children():
		if child is NinePatchRect:child.hide()
	Art.decorate(hud.job_resource,"magic",5)
	for i in range(Content.ACTIONS.size()):
		var control=hud.circles[Content.ACTIONS[i]];control.position=Vector2(500+i*90,803);control.size=Vector2(74,74);control.show_caption=false
	for action in ["potion","interact","return"]:hud.circles[action].hide()
	for i in range(3):
		var button=Button.new();button.position=Vector2(20+i*125,679);button.size=Vector2(120,26)
		button.text=["능력치","스킬","가방"][i];button.focus_mode=Control.FOCUS_NONE;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		button.add_theme_font_override("font",hud.game.fonts);button.add_theme_font_size_override("font_size",17)
		for state in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		for state in ["font_color","font_hover_color","font_pressed_color"]:button.add_theme_color_override(state,Color("fff0d0"))
		hud.chrome.add_child(button);tabs.append(button)
		button.pressed.connect(open_tab.bind(i));button.mouse_entered.connect(queue_redraw);button.mouse_exited.connect(queue_redraw)
	consumables=preload("res://scripts/consumable_bar.gd").new();hud.chrome.add_child(consumables);consumables.setup(hud.game)
	party=preload("res://scripts/party_hud.gd").new();hud.chrome.add_child(party);party.setup(hud.game)
	personal_surface=Control.new();personal_surface.mouse_filter=Control.MOUSE_FILTER_STOP;personal_surface.size=PERSONAL.size;hud.chrome.add_child(personal_surface);hud.chrome.move_child(personal_surface,0)
	align_personal()
	queue_redraw()
func align_personal():
	var offset=Vector2(-hud.game.ui_offset().x-8,20)
	hud.profile_offset=offset
	hud.name_label.position=Vector2(127,31)+offset
	hud.class_label.position=Vector2(129+offset.x,maxf(66+offset.y,hud.name_label.get_rect().end.y+4))
	hud.hp_label.position=Vector2(130+offset.x,maxf(95+offset.y,hud.class_label.get_rect().end.y+6))
	party.position=Vector2(20,170)+offset
	personal_surface.position=PERSONAL.position+offset
func open_tab(index:int):
	selected_tab=index;hud.job_resource.display_mode=index
	consumables.picker.hide()
	consumables.position=Vector2(106,802) if index==2 else Vector2(665,744)
	hud.job_resource.refresh(hud.p);queue_redraw()
func refresh():
	visible=not hud.chrome_hidden
	if hud.chrome_hidden:consumables.picker.hide()
	var p=hud.p
	if p.is_empty():return
	align_personal();party.refresh()
	hud.status_strip.position.y=maxf(505,party.position.y+party.size.y+8)
	var required=preload("res://scripts/progression.gd").xp_required(p.level)
	hud.hp_label.tooltip_text="Lv.%d · 생명력 %d / %d\n기력 %d / %d\n금화 %d · 경험치 %.1f%%"%[p.level,p.hp,p.max_hp,p.stamina,p.max_stamina,p.gold,100.*p.xp/maxf(1,required)]
	consumables.refresh()
func world_regions()->Array[Rect2]:
	var result:Array[Rect2]=[]
	if not is_visible_in_tree():return result
	var transform=get_global_transform_with_canvas()
	if backings_visible:
		result.append(transform*Rect2(PERSONAL.position+hud.profile_offset,PERSONAL.size))
		for circle in hud.circles.values():
			if circle.visible:result.append(transform*circle.get_rect().grow(3))
	for button in tabs:result.append(button.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,button.size))
	for slot in consumables.slots:result.append(slot.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,slot.size))
	if consumables.picker.visible:result.append(consumables.picker.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,consumables.picker.size))
	result.append_array(party.world_regions())
	return result
func panel(rect:Rect2,highlight=false):
	draw_texture_rect(Art.plain_paper(),rect,false,Color("303842"))
	draw_rect(rect,Color("d6b27f") if highlight else Color("967b58"),false,1)
func _draw():
	if hud==null:return
	if backings_visible:
		panel(Rect2(PERSONAL.position+hud.profile_offset,PERSONAL.size))
		for circle in hud.circles.values():
			if circle.visible:panel(circle.get_rect().grow(3),circle.is_hovered())
	for i in range(tabs.size()):
		var button=tabs[i];panel(button.get_rect(),button.is_hovered() or i==selected_tab)
		if i==selected_tab:draw_line(button.position+Vector2(8,button.size.y-2),button.position+Vector2(button.size.x-8,button.size.y-2),Color("e4c18b"),2)
