extends RefCounted
var sim_ref:WeakRef
var sim:
	get:return sim_ref.get_ref()
var zones:Array=[]
func _init(owner_sim):sim_ref=weakref(owner_sim)
static func area(shape:String,origin:Vector2,target:Vector2,radius:float,delay=0.0,multiplier=1.0)->Dictionary:
	return {"shape":shape,"from":origin,"pos":target,"radius":radius,"delay":delay,"multiplier":multiplier,"drain":0.0,"slow":0.0,"knock":0.0,"sound":"hit_sword"}
static func pattern(kind:String,origin:Vector2,target:Vector2,sequence:int=0)->Array:
	var direction=origin.direction_to(target)
	if direction==Vector2.ZERO:direction=Vector2.RIGHT
	var a=[]
	match kind:
		"shade":a=[area("circle",origin,target,1.0)]
		"imp":a=[area("line",origin,origin+direction*1.5,.35),area("line",origin,origin+direction*1.7,.28,.24,.7)]
		"fairy":a=[area("line",origin,target,.22)];a[0].drain=8;a[0].sound="bow"
		"beetle":a=[area("circle",origin,origin,1.3)];a[0].knock=.5
		"bat":a=[area("line",origin,origin+direction*3.1,.58)];a[0].knock=.9;a[0].sound="heavy"
		"mole":a=[area("cone",origin,origin+direction,2.0,0,1.25)];a[0].angle=.95;a[0].sound="heavy"
		"clockwork":a=[area("line",origin,origin+direction*2.5,.32),area("circle",origin,origin+direction*.6,.9,.38,.65)];a[1].knock=.7
		"spellbook":
			for angle in [-.2,0,.2]:a.append(area("line",origin,origin+direction.rotated(angle)*5,.18,0,.55));a.back().sound="staff"
		"fox":a=[area("circle",origin,target,.8),area("cone",target,target+direction,1.1,.35,.65)];a[1].angle=.7
		"ember_slime":
			for i in range(4):a.append(area("circle",origin,target,1.45,i*.5,1.0 if i==0 else .35));a.back().sound="nova"
		"frost_slime":a=[area("circle",origin,target,1.05)];a[0].slow=2;a[0].sound="staff"
		"cave_bat":a=[area("cone",origin,origin+direction,2.1,0,.9)];a[0].angle=.55;a[0].drain=6
		"rat":a=[area("circle",origin,target,.55,0,.65),area("circle",origin,target,.55,.18,.65)]
		"spider":a=[area("circle",origin,target,1.25,0,.7)];a[0].slow=3;a[0].sound="staff"
		"goblin_archer":a=[area("line",origin,origin+direction*4.8,.16)];a[0].sound="bow"
		"goblin_shaman":
			for i in range(3):a.append(area("circle",origin,target+direction.orthogonal()*(i-1)*.85,.7,i*.22,.55));a.back().sound="staff"
		"orc_axeman":
			a=[area("cone",origin,origin+direction.rotated(-.3),2.3,0,1.0),area("cone",origin,origin+direction.rotated(.4),2.0,.5,.8)]
			for z in a:z.angle=.85;z.sound="heavy"
		"skeleton":a=[area("line",origin,origin+direction*2.0,.24),area("line",origin,origin+direction*2.2,.24,.42,.8)]
		"goblin_captain":
			a=[area("cone",origin,origin+direction.rotated(-.35),1.9,0,.7),area("cone",origin,origin+direction.rotated(.35),1.9,.3,.7),area("line",origin,origin+direction*3.0,.42,.75,1.2)]
			for z in a:z.angle=.7
		"orc_champion":
			if sequence%2==0:
				a=[area("ring",origin,origin,2.6),area("ring",origin,origin,2.6,.6,.75)]
				for z in a:z.inner=.85;z.sound="heavy"
			else:a=[area("cone",origin,origin+direction,2.7,0,1.5)];a[0].angle=1.0;a[0].sound="heavy"
		"centurion":
			for i in range(4):a.append(area("line",origin,origin+direction.rotated(i*PI*.5)*4,.24,0,.7));a.back().sound="staff"
			a.append(area("circle",origin,target,1.4,.65,1.2));a.back().sound="heavy"
	return a
func begin(e:Dictionary,target:Vector2):
	e.attack_pos=target;e.attack_areas=pattern(e.kind,e.pos,target,int(e.pattern))
func release(e:Dictionary):
	var areas=e.get("attack_areas",pattern(e.kind,e.pos,e.attack_pos,int(e.get("pattern",0))))
	if e.kind in ["shade","bat","fox","cave_bat"] and sim.map.line_clear(e.pos,e.attack_pos):e.pos=sim.map.move(e.pos,e.pos.direction_to(e.attack_pos)*minf(2.5,e.pos.distance_to(e.attack_pos)))
	for z in areas:
		var zone=z.duplicate(true);zone.enemy=e.id;zone.timer=float(zone.delay)
		if zone.timer<=0:impact(zone,e)
		else:zones.append(zone)
	e.erase("attack_areas")
func tick(delta:float):
	var keep=[]
	for zone in zones:
		var e=sim.enemies.get(zone.enemy,{})
		if e.is_empty() or e.hp<=0 or e.get("stun_time",0)>0:continue
		zone.timer-=delta
		if zone.timer<=0:impact(zone,e)
		else:keep.append(zone)
	zones=keep
static func contains(zone:Dictionary,point:Vector2)->bool:
	match zone.shape:
		"line":return point.distance_to(Geometry2D.get_closest_point_to_segment(point,zone.from,zone.pos))<=zone.radius
		"cone":
			var offset:Vector2=point-zone.from
			return offset.length()<=zone.radius and (offset.length()<.15 or absf((zone.pos-zone.from).angle_to(offset))<=float(zone.get("angle",.8)))
		"ring":return point.distance_to(zone.pos)<=zone.radius and point.distance_to(zone.pos)>=float(zone.inner)
	return point.distance_to(zone.pos)<=zone.radius
func impact(zone:Dictionary,e:Dictionary):
	sim.events.append({"type":"monster_attack","pos":zone.pos,"area":zone.duplicate(true),"sound":zone.sound,"duration":.3,"owner":1})
	for p in sim.players.values():
		if contains(zone,p.pos) and sim.map.line_clear(zone.from,p.pos):damage(e,p,zone)
func damage(e:Dictionary,p:Dictionary,zone:Dictionary):
	if p.invulnerable>0 or sim.map.in_town(p.pos):return
	var amount=maxi(1,roundi(sim.balance.enemies[e.kind].damage*zone.multiplier)-p.defense)
	if p.barrier_time>0:amount=maxi(1,roundi(amount*(1-p.barrier_strength)))
	p.combat_time=4;p.hp-=amount;p.hurt_time=.16;p.stamina=maxf(0,p.stamina-zone.drain)
	p.enemy_slow_time=maxf(p.enemy_slow_time,zone.slow)
	if zone.knock>0:p.pos=sim.map.move(p.pos,zone.from.direction_to(p.pos)*zone.knock)
	var reflected=int(Content.skill_bonus(p,"thorns"))
	if reflected>0 and e.hp>0 and e.pos.distance_to(p.pos)<2:sim.combat.hit(p,e,reflected)
	sim.events.append({"type":"damage","pos":p.pos,"amount":amount,"enemy":false,"owner":p.id})
	if p.hp<=0:
		p.gold=int(p.gold*.9);p.hp=p.max_hp;p.pos=sim.map.spawn;p.dir=Vector2.ZERO;p.enemy_slow_time=0
		sim.dirty[p.id]=true;sim.notice(p.id,"쓰러졌습니다. 금화 10%를 잃고 안전지대에서 회복했습니다.")
const Content=preload("res://scripts/content.gd")
static func draw_area(canvas,zone:Dictionary,color:Color):
	var points=PackedVector2Array()
	if zone.shape=="line":
		var perpendicular:Vector2=(zone.pos-zone.from).normalized().orthogonal()*zone.radius
		for p in [zone.from+perpendicular,zone.pos+perpendicular,zone.pos-perpendicular,zone.from-perpendicular]:points.append(canvas.world_point(p))
	elif zone.shape=="cone":
		points.append(canvas.world_point(zone.from));var direction:Vector2=(zone.pos-zone.from).normalized();var angle=float(zone.get("angle",.8))
		for i in range(21):points.append(canvas.world_point(zone.from+direction.rotated(lerpf(-angle,angle,i/20.0))*zone.radius))
	else:
		for i in range(40):points.append(canvas.world_point(zone.pos+Vector2.from_angle(i*TAU/40)*zone.radius))
	if zone.shape!="ring":canvas.draw_colored_polygon(points,Color(color,.15))
	points.append(points[0]);canvas.draw_polyline(points,color,2.0,true)
	if zone.shape=="ring":
		points=PackedVector2Array()
		for i in range(41):points.append(canvas.world_point(zone.pos+Vector2.from_angle(i*TAU/40)*zone.inner))
		canvas.draw_polyline(points,color,2.0,true)
