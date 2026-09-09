extends RefCounted
const Art=preload("res://scripts/gat_art.gd")
# These finished gun poses belong to visiting NPCs. The playable roster has
# bows, but no firearm job, so they are not offered as player appearances.
const RESIDENTS=[
	{"costume":"pink-beret-gunner","name":"기계도시 사절","pos":Vector2(16,21),"render_id":201},
	{"costume":"pink-black-veil-hanbok","name":"유적 탐사원","pos":Vector2(20,19),"render_id":202},
	{"costume":"pink-bunny-hoodie","name":"유랑 사수","pos":Vector2(23,23),"render_id":203}]
static func draw(game,data:Dictionary):
	var frame=Art.frame(data,0.0);var point=game.world_point(data.pos)
	var scale=112.0/frame.height
	game.draw_circle(point,25,Color("32574a40"))
	game.draw_texture_rect(frame.texture,Rect2(point-frame.foot*scale,frame.texture.get_size()*scale),false)
	game.text_at(point+Vector2(0,27),data.name,16,Color("fff0b8"),true)
	game.record_art_usage("npc",data.costume)
