extends Control
const Gat=preload("res://scripts/gat_art.gd")
var sheet={"class_id":"warrior","avatar":"auto","costume":"none"}
var opaque_bounds={}
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	material=Gat.material()
func _draw():
	var frame=Gat.frame(sheet,Time.get_ticks_msec()/1000.0)
	var anchor=Vector2(size.x*.5,size.y-22)
	draw_set_transform(anchor,0,Vector2(1,.32));draw_circle(Vector2.ZERO,68,Color("355b4938"));draw_set_transform(Vector2.ZERO)
	draw_texture_rect(frame.texture,draw_rect_for(frame),false)
func opaque_rect_for(frame:Dictionary)->Rect2:
	var texture:Texture2D=frame.texture;var key=texture.get_instance_id()
	if not opaque_bounds.has(key):
		var rect=Rect2(texture.get_image().get_used_rect())
		opaque_bounds[key]=rect if rect.has_area() else Rect2(Vector2.ZERO,texture.get_size())
	return opaque_bounds[key]
func draw_rect_for(frame:Dictionary)->Rect2:
	var opaque=opaque_rect_for(frame)
	var available=Rect2(Vector2(8,0),Vector2(maxf(1,size.x-16),maxf(1,size.y-22)))
	var factor=minf(230.0/maxf(1,float(frame.height)),minf(available.size.x/opaque.size.x,available.size.y/opaque.size.y))
	var anchor=Vector2(size.x*.5,size.y-22);var at=anchor-frame.foot*factor
	# Fit actual ears, hats and held equipment into the preview, keeping the
	# support foot at its authored anchor wherever the available room permits.
	var drawn=Rect2(at+opaque.position*factor,opaque.size*factor)
	at.x+=maxf(0,available.position.x-drawn.position.x)-maxf(0,drawn.end.x-available.end.x)
	at.y+=maxf(0,available.position.y-drawn.position.y)-maxf(0,drawn.end.y-available.end.y)
	return Rect2(at,frame.texture.get_size()*factor)
func _process(_delta):queue_redraw()
