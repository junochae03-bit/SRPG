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
	e.attack_pos=target;e.attack_areas=raid_pattern(e,target) if e.get("raid",false) else pattern(e.kind,e.pos,target,int(e.pattern))
	if e.get("raid",false) and int(e.pattern)%4==3:
		var direction=e.pos.direction_to(target)
		if direction==Vector2.ZERO:direction=Vector2.RIGHT
		e.windup=maxf(e.windup,1.5);e["wall_charge"]=true
		e.attack_areas=[area("line",e.pos,e.pos+direction*6.5,.65,0,1.15)];e.attack_areas[0].sound="heavy"
	else:e.erase("wall_charge")

func stagger_punishment(e:Dictionary):
	# A stationary circle gives every class time to leave on foot; a successful
	# dodge also works. This uses the same red telegraph renderer as other attacks.
	e.erase("wall_charge");e.windup=1.8;e.attack_pos=e.pos
	e.attack_areas=[area("circle",e.pos,e.pos,3.6,0,1.35)]
	e.attack_areas[0].sound="heavy"
	e.attack_areas[0]["damage_cap"]=.70
func release(e:Dictionary):
	if e.get("wall_charge",false):
		release_wall_charge(e);return
	var areas=e.get("attack_areas",pattern(e.kind,e.pos,e.attack_pos,int(e.get("pattern",0))))
	if e.kind in ["shade","bat","fox","cave_bat"] and sim.map.line_clear(e.pos,e.attack_pos):e.pos=sim.map.move(e.pos,e.pos.direction_to(e.attack_pos)*minf(2.5,e.pos.distance_to(e.attack_pos)))
	for z in areas:
		if e.hp<=0 or e.get("stagger",{}).get("state","") in ["check","down"]:break
		var zone=z.duplicate(true);zone.enemy=e.id;zone.timer=float(zone.delay)
		if zone.timer<=0:impact(zone,e)
		else:zones.append(zone)
	e.erase("attack_areas")
func release_wall_charge(e:Dictionary):
	var attacks=e.get("attack_areas",[])
	if attacks.is_empty():e.erase("wall_charge");return
	var attack:Dictionary=attacks[0].duplicate(true);var direction:Vector2=attack.from.direction_to(attack.pos);var wall=false
	var remaining=attack.from.distance_to(attack.pos)
	while remaining>.001:
		var step=minf(.16,remaining);var next:Vector2=e.pos+direction*step
		if not sim.map.walkable(next+direction*.2):wall=true;break
		e.pos=next;remaining-=step
	attack.pos=e.pos;impact(attack,e);e.erase("wall_charge");e.erase("attack_areas")
	if wall and e.hp>0:
		e.cooldown=maxf(e.cooldown,1.)
		var broken=preload("res://scripts/boss_stagger.gd").break_boss(sim,e)
		for p in sim.players.values():sim.notice(p.id,"벽 충돌! 보스가 빈틈을 드러냈습니다." if broken else "벽 충돌 · 돌진 정지")

func tick(delta:float):
	var keep=[]
	for zone in zones:
		var e=sim.enemies.get(zone.enemy,{})
		if e.is_empty() or e.hp<=0 or e.get("stun_time",0)>0 or e.get("stagger",{}).get("state","") in ["check","down"]:continue
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
	if e.hp<=0 or e.get("stagger",{}).get("state","") in ["check","down"]:return
	sim.events.append({"type":"monster_attack","pos":zone.pos,"area":zone.duplicate(true),"sound":zone.sound,"duration":.3,"owner":1})
	for p in sim.players.values():
		if contains(zone,p.pos) and sim.map.line_clear(zone.from,p.pos):damage(e,p,zone)
		for pet in p.get("job_state",{}).get("pets",[]):
			if contains(zone,pet.pos) and sim.map.line_clear(zone.from,pet.pos):pet.hp-=e.get("damage",sim.balance.enemies[e.kind].damage)*zone.multiplier*(1.3 if e.get("raid",false) and e.phase==2 else 1.)*(1-sim.combat.jobs.value(p,"pet_guard"))
func damage(e:Dictionary,p:Dictionary,zone:Dictionary):
	if e.hp<=0 or e.get("stagger",{}).get("state","") in ["check","down"]:return
	if p.hp<=0 or p.get("network_leaving",false) or p.invulnerable>0 or sim.map.in_town(p.pos):return
	var amount=preload("res://scripts/progression.gd").received(p,e.get("damage",sim.balance.enemies[e.kind].damage)*zone.multiplier*(1.3 if e.get("raid",false) and e.phase==2 else 1.),e.kind in ["ember_slime","frost_slime","goblin_shaman","spellbook","spider","golem","warden"])
	if zone.has("damage_cap"):amount=mini(amount,maxi(1,roundi(p.max_hp*float(zone.damage_cap))))
	if p.barrier_time>0:amount=maxi(1,roundi(amount*(1-p.barrier_strength)))
	amount=sim.combat.jobs.receive(p,e,amount,zone.get("shape","circle")!="ring")
	if amount<=0:return
	p.erase("revive_target");p.erase("revive_progress")
	p.combat_time=4;p.hp-=amount;p.hurt_time=.16;p.stamina=maxf(0,p.stamina-zone.drain)
	p.enemy_slow_time=maxf(p.enemy_slow_time,zone.slow)
	if zone.knock>0:p.pos=sim.map.move(p.pos,zone.from.direction_to(p.pos)*zone.knock*(1-sim.combat.jobs.passive(p,1)*.12 if p.class_id=="breaker" and (p.charge_time>=0 or not p.job_state.casting.is_empty()) else 1))
	var reflected=int(Content.skill_bonus(p,"thorns"))
	if reflected>0 and e.hp>0 and e.pos.distance_to(p.pos)<2:sim.combat.hit(p,e,reflected,null,{})
	sim.events.append({"type":"damage","pos":p.pos,"amount":amount,"enemy":false,"owner":p.id})
	if p.hp<=0:sim.player_defeated(p)
const Content=preload("res://scripts/content.gd")
static func draw_area(canvas,zone:Dictionary,color:Color):
	var points=PackedVector2Array()
	if zone.shape=="line":
		# contains() measures distance to a segment, including its rounded ends.
		# Draw that same capsule instead of a shorter square-ended rectangle.
		var direction:Vector2=(zone.pos-zone.from).normalized()
		if direction==Vector2.ZERO:direction=Vector2.RIGHT
		for i in range(13):points.append(canvas.world_point(zone.pos+direction.rotated(-PI*.5+i*PI/12)*zone.radius))
		for i in range(13):points.append(canvas.world_point(zone.from+direction.rotated(PI*.5+i*PI/12)*zone.radius))
	elif zone.shape=="cone":
		points.append(canvas.world_point(zone.from));var direction:Vector2=(zone.pos-zone.from).normalized();var angle=float(zone.get("angle",.8))
		for i in range(21):points.append(canvas.world_point(zone.from+direction.rotated(lerpf(-angle,angle,i/20.0))*zone.radius))
	else:
		for i in range(40):points.append(canvas.world_point(zone.pos+Vector2.from_angle(i*TAU/40)*zone.radius))
	if zone.get("shape","circle")!="ring":canvas.draw_colored_polygon(points,Color(color,.23))
	points.append(points[0]);canvas.draw_polyline(points,color,2.0,true)
	if zone.shape=="ring":
		# Keep the safe center empty while making the dangerous annulus readable.
		for i in range(40):
			var a=Vector2.from_angle(i*TAU/40);var b=Vector2.from_angle((i+1)*TAU/40)
			canvas.draw_colored_polygon(PackedVector2Array([canvas.world_point(zone.pos+a*zone.inner),canvas.world_point(zone.pos+a*zone.radius),canvas.world_point(zone.pos+b*zone.radius),canvas.world_point(zone.pos+b*zone.inner)]),Color(color,.23))
		points=PackedVector2Array()
		for i in range(41):points.append(canvas.world_point(zone.pos+Vector2.from_angle(i*TAU/40)*zone.inner))
		canvas.draw_polyline(points,color,2.0,true)

static func raid_pattern(e:Dictionary,target:Vector2)->Array:
	var origin:Vector2=e.pos;var direction=origin.direction_to(target)
	if direction==Vector2.ZERO:direction=Vector2.RIGHT
	var chapter=int((int(e.get("floor",10))-1)/10);var sequence=(int(e.pattern)+chapter)%3;var result=[]
	if sequence==0:
		result=[area("cone",origin,origin+direction,3.1+chapter*.06,0,1.15)]
		result[0].angle=.8;result[0].sound="heavy"
		if chapter>=3:result.append(area("circle",origin,target,1.3,.65,.7));result.back().sound="nova"
	elif sequence==1:
		for i in range(2+int(chapter/3)):
			result.append(area("circle",origin,target+direction.orthogonal()*(i-(1+int(chapter/3))*.5)*1.8,1.1,.3*i,.65));result.back().sound="staff"
	else:
		result=[area("ring",origin,origin,3.6,0,1.)];result[0].inner=1.25;result[0].sound="nova"
		if chapter>=5:
			for i in range(2):result.append(area("line",origin,origin+direction.rotated(PI*i)*4.8,.36,.6,.65));result.back().sound="heavy"
	if e.phase==2 and chapter>=2:
		result.append(area("circle",origin,target,1.1,1.1,.6));result.back().sound="nova"
	return result
