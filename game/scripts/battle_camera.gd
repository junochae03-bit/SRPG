extends RefCounted
const Dungeon=preload("res://scripts/dungeon.gd")
const Art=preload("res://scripts/world_art.gd")
# Screen space reserved between the fixed boss meters and the quick items.
const SAFE=Rect2(253,235,1020,520)
static var silhouettes={}

static func annotations(dimensions:Vector2)->Rect2:
	# main.gd anchors these to the full frame height, not its support foot.
	# Reserve five 19px status icons, gaps and the overflow count at all times.
	var statuses=Rect2(Vector2(-72,-dimensions.y-66),Vector2(144,24))
	var stars=Rect2(Vector2(-24,-dimensions.y-33),Vector2(48,14))
	return statuses.merge(stars)

static func silhouette(enemy:Dictionary)->Rect2:
	var key="%s:%d:%s"%[enemy.kind,int(enemy.get("floor",0)),str(enemy.get("raid",false))]
	if silhouettes.has(key):return silhouettes[key]
	var bounds=Rect2()
	var first=true
	for index in 3:
		var frame=Art.variant_frame(enemy.kind,int(enemy.get("floor",0)),enemy.get("raid",false),index>0)
		var scale=1.0
		if frame.is_empty():
			var boss_index=["warden","golem","sentinel"].find(enemy.kind)
			frame=Art.frame("bosses",maxi(0,boss_index)*3+index)
			scale=335.0/Art.frame("bosses",maxi(0,boss_index)*3).height
		else:scale=335.0/frame.height
		# Both facings and every pose share one camera envelope, avoiding zoom pulses.
		var half_width=maxf(frame.foot.x,frame.texture.get_width()-frame.foot.x)*scale
		var rect=Rect2(Vector2(-half_width,-frame.foot.y*scale),Vector2(half_width*2,frame.texture.get_height()*scale))
		rect=rect.merge(annotations(frame.texture.get_size()*scale))
		bounds=rect if first else bounds.merge(rect);first=false
	silhouettes[key]=bounds.grow(18)
	return silhouettes[key]

static func framing(player:Dictionary,enemies:Array)->Dictionary:
	var closest={};var distance=8.5
	for enemy in enemies:
		var next=player.pos.distance_to(enemy.pos)
		if enemy.get("boss",false) and enemy.hp>0 and next<distance:
			closest=enemy;distance=next
	if closest.is_empty():return {"position":Dungeon.iso(player.pos),"anchor":438.0,"zoom":1.0,"boss":false}
	var at=Dungeon.iso(closest.pos)
	var bounds=silhouette(closest)
	bounds.position+=at
	bounds=bounds.merge(Rect2(Dungeon.iso(player.pos)-Vector2(75,140),Vector2(150,166)))
	var zoom=clampf(minf(SAFE.size.x/bounds.size.x,SAFE.size.y/bounds.size.y),.55,1.0)
	return {"position":bounds.get_center(),"anchor":SAFE.get_center().y,"zoom":zoom,"boss":true,"bounds":bounds}
