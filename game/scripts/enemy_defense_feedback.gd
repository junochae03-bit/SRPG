extends RefCounted
const Defense=preload("res://scripts/enemy_defense.gd")
static func draw(game,enemy:Dictionary,at:Vector2):
	if enemy.get("hp",0)<=0:return
	var data=Defense.description(enemy)
	if data.is_empty():return
	var color=Color("b7a3ef") if data.type=="layers" else Color("e4bc73")
	if data.exposed:color=Color("a9ecde")
	var shield=PackedVector2Array([at+Vector2(-9,-10),at+Vector2(9,-10),at+Vector2(8,2),at+Vector2(0,10),at+Vector2(-8,2),at+Vector2(-9,-10)])
	game.draw_colored_polygon(shield,Color("171e24dc"))
	game.draw_polyline(shield,color,2.,true)
	if data.exposed:
		game.draw_polyline(PackedVector2Array([at+Vector2(-2,-10),at+Vector2(3,-3),at+Vector2(-3,2),at+Vector2(2,8)]),color,2.,true)
	elif data.type=="layers":
		for index in range(3):game.draw_circle(at+Vector2((index-1)*5,-1),1.9,color if index<data.layers else Color("565361"))
	elif data.type=="brace":
		game.draw_line(at+Vector2(-5,-5),at+Vector2(5,-5),color,2.,true)
		game.draw_line(at+Vector2(0,-5),at+Vector2(0,5),color,2.,true)
	else:
		for index in range(3):
			var y=-5+index*4
			game.draw_line(at+Vector2(-5,y),at+Vector2(5,y),color if data.pressure<(index+1)/3. else Color("65513b"),2.,true)
