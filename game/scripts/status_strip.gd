extends Control
const Status=preload("res://scripts/status_markers.gd")
const Icons=preload("res://scripts/icon_library.gd")
var game
var markers:Array=[]
var entries:Array=[]
class Marker extends Control:
	var game
	var entry:Dictionary={}
	func _make_custom_tooltip(value:String)->Object:return preload("res://scripts/ui_art.gd").tooltip(game,value)
	func _draw():
		if entry.is_empty():return
		Icons.draw(self,entry.icon,Rect2(5,0,32,32))
		var value="%d초"%ceili(entry.remaining)
		var width=game.fonts.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		var baseline=Vector2((size.x-width)*.5,49)
		draw_string_outline(game.fonts,baseline,value,HORIZONTAL_ALIGNMENT_LEFT,-1,13,4,Color("243d39"))
		draw_string(game.fonts,baseline,value,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("fff4d2"))
func setup(owner_game):
	game=owner_game;position=Vector2(28,178);size=Vector2(352,168);mouse_filter=Control.MOUSE_FILTER_IGNORE
	for i in range(24):
		var marker=Marker.new();marker.game=game;marker.position=Vector2(i%8*44,int(i/8)*56);marker.size=Vector2(42,54);marker.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(marker);marker.hide();markers.append(marker)
func refresh(p:Dictionary):
	entries=Status.timed_for(p)
	for i in range(markers.size()):
		var marker=markers[i];marker.visible=i<entries.size()
		if not marker.visible:continue
		marker.entry=entries[i];marker.tooltip_text=entries[i].name+"\n%d초"%ceili(entries[i].remaining);marker.queue_redraw()
