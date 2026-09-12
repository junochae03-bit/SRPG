extends RefCounted
## Small rank marks remain inside the portrait's own outline, clear of captions.
const LEVELS=[1,30,60,100]
const COLORS=["a99779","b8ced9","e8c76b","badfe8"]
static func rank_for(level:int)->int:
	var rank=0
	for i in LEVELS.size():
		if level>=LEVELS[i]:rank=i
	return rank
static func draw_frame(canvas:CanvasItem,rect:Rect2,level:int):
	var rank=rank_for(level);var color=Color(COLORS[rank])
	canvas.draw_rect(rect,Color("171e23"),false,4)
	canvas.draw_rect(rect,color,false,1)
	for corner in [Vector2.ZERO,Vector2(1,0),Vector2(0,1),Vector2.ONE]:
		var at=rect.position+rect.size*corner;var toward=Vector2.ONE-corner*2
		canvas.draw_polyline(PackedVector2Array([at+Vector2(toward.x*10,0),at,at+Vector2(0,toward.y*10)]),color,2)
	for i in range(rank):
		var center=Vector2(rect.get_center().x+(i-(rank-1)*.5)*11,rect.position.y)
		canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(-3,0),center+Vector2(0,-3),center+Vector2(3,0),center+Vector2(0,3)]),color)
