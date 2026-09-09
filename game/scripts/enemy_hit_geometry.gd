extends RefCounted
# Receiving volume only. Enemy attacks, navigation collision, damage and
# per-cast hit/stagger ledgers deliberately continue using their own rules.
const World=preload("res://scripts/world_catalog.gd")

static func radius(enemy:Dictionary)->float:
	var kind:String=enemy.get("kind","")
	var config:Dictionary=World.ENEMIES.get(kind,{})
	if enemy.get("boss",false) or config.get("ai","")=="boss":return 1.55
	var height=World.display_height(kind) if not config.is_empty() else 112.
	if enemy.get("elite",config.get("elite",false)):return clampf(height/180.,.95,1.15)
	return clampf(height/180.,.65,.90)

static func edge_distance(enemy:Dictionary,origin:Vector2)->float:
	return maxf(0.,origin.distance_to(enemy.pos)-radius(enemy))

static func circle(enemy:Dictionary,origin:Vector2,reach:float)->bool:
	return origin.distance_squared_to(enemy.pos)<=pow(maxf(0.,reach)+radius(enemy),2.)

static func segment(enemy:Dictionary,start:Vector2,end:Vector2,width:float)->bool:
	return circle(enemy,Geometry2D.get_closest_point_to_segment(enemy.pos,start,end),width)

static func forward_segment(enemy:Dictionary,start:Vector2,end:Vector2,width:float)->bool:
	# A large body may overlap the muzzle at point-blank range. A projectile
	# deliberately fired away from its center must still be able to miss.
	return start!=end and (enemy.pos-start).dot(end-start)>=0. and segment(enemy,start,end,width)

static func arc(enemy:Dictionary,origin:Vector2,aim:Vector2,reach:float,minimum_dot:float,close_range:float=0.)->bool:
	if not circle(enemy,origin,reach):return false
	var offset:Vector2=enemy.pos-origin
	# Keep deliberate aiming and the original close-range melee allowance: a
	# large boss should not turn a swing aimed backwards into a successful hit.
	return offset.length()<=close_range or aim.dot(offset.normalized())>=minimum_dot
