extends RefCounted
const SOURCE="res://assets/town_v052/training-scarecrow.png"
const HEIGHT=300.0
static var sprite:AtlasTexture
static func texture()->Texture2D:
	if sprite==null:
		var source:Texture2D=load(SOURCE)
		sprite=AtlasTexture.new();sprite.atlas=source;sprite.region=source.get_image().get_used_rect();sprite.filter_clip=true
	return sprite
static func draw(game,enemy:Dictionary,point:Vector2):
	var frame=texture();var dimensions=frame.get_size()*HEIGHT/frame.get_height()
	var rect=Rect2(Vector2(-dimensions.x*.5,-HEIGHT),dimensions)
	game.draw_set_transform(point,0,Vector2(1,.42));game.draw_circle(Vector2.ZERO,64,Color("32574a60"))
	if game.hover_enemy_id==int(enemy.id):game.draw_arc(Vector2.ZERO,71,0,TAU,48,Color("ffda73"),3,true)
	game.draw_set_transform(point)
	game.draw_texture_rect(frame,rect,false)
	preload("res://scripts/monster_aim.gd").register(game.monster_aim_frames,enemy,rect,Transform2D(0.,point))
	game.draw_set_transform(Vector2.ZERO)
	game.text_at(point+Vector2(0,-HEIGHT-20),"거대 훈련 허수아비",19,Color("fff1ce"),true)
