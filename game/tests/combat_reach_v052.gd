extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const Geometry=preload("res://scripts/enemy_hit_geometry.gd")
const Aim=preload("res://scripts/monster_aim.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const World=preload("res://scripts/world_catalog.gd")
const Scaling=preload("res://scripts/skill_scaling.gd")
const Balance=preload("res://scripts/job_balance.gd")
const Reach=preload("res://scripts/skill_reach.gd")
const Active=preload("res://scripts/active_skills.gd")
const Vfx=preload("res://scripts/skill_vfx.gd")
const Stagger=preload("res://scripts/boss_stagger.gd")
var checks=0
var failures:Array=[]
var area_samples:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)

func fixture(job:String="warrior",kind:String="shade")->Dictionary:
	var sim=Sim.new(177);sim.enemies.clear()
	for x in range(0,55):
		for y in range(0,55):sim.map.floor_cells[Vector2i(x,y)]=true
	var p=sim.add_player(1,"범위 검사");p.class_id=job;p.level=100;p.skill_ranks={};p.skill_loadout={};p.constellation_allocations={}
	sim.recalculate(p);sim.combat.jobs.reset(p);sim.combat.constellation.reset(p)
	p.pos=Vector2(24,24);p.aim=Vector2.RIGHT;p.stamina=10000.;p.max_stamina=10000.
	var e=sim.spawn_enemy(kind,p.pos+Vector2.RIGHT,1,kind=="warden");e.hp=1000000;e.max_hp=e.hp
	if e.has("stagger"):e.stagger.max_value=1000000.
	return {"sim":sim,"p":p,"e":e,"origin":p.pos}

func hits(f:Dictionary)->Array:
	return f.sim.events.filter(func(event):return event.type=="damage" and event.get("enemy",false))
func active(job:String,mode:String)->Dictionary:
	for node in Content.SKILLS[job]:
		if node.effect=="active" and Stagger.skill_profile(node,1).mode==mode:return node
	check(false,"required active "+job+":"+mode);return {}
func cast(f:Dictionary,node:Dictionary):
	f.p.skill_ranks[node.id]=1;f.p.skill_loadout.skill_q=node.id
	check(f.sim.action(f.p.id,"skill_q"),"cast "+node.id)
	for i in range(65):
		f.sim.clock+=.05;f.sim.combat.tick_player(f.p,.05);f.sim.combat.skills.tick(.05)

func input_geometry():
	# Reproduce the actual bug: the rendered torso is hundreds of pixels above
	# its foot, so inverse projection alone sends a shot behind the character.
	for kind in ["shade","orc_champion","warden"]:
		var f=fixture("ranger",kind);f.e.pos=f.origin+Vector2(4,0)
		var height=World.display_height(kind);var foot=Dungeon.iso(f.e.pos)
		var rect=Rect2(-height*.4,-height,height*.8,height)
		var transform=Transform2D(0.,Vector2.ONE,0.,foot)
		var frames={};Aim.register(frames,f.e,rect,transform)
		var mouse=foot+Vector2(0,-height*.66)
		var ground=Dungeon.from_iso(mouse)
		var old_aim=f.origin.direction_to(ground)
		var new_aim=Aim.direction(mouse,ground,f.origin,f.sim.enemies,frames,f.sim.map)
		check(old_aim.dot(f.origin.direction_to(f.e.pos))<.96,"old torso aim deviates "+kind)
		check(new_aim.is_equal_approx(Vector2.RIGHT),"body click resolves to ground anchor "+kind)
		# A line built from the old mouse direction demonstrably misses the old
		# receiving body, while the actual new projectile lands exactly once.
		var old_radius=1.55 if kind=="warden" else 1.15 if kind=="orc_champion" else .65
		var closest=Geometry2D.get_closest_point_to_segment(f.e.pos,f.origin,f.origin+old_aim*8.)
		check(closest.distance_to(f.e.pos)>old_radius+.42,"old full projectile misses torso-selected body "+kind)
		f.p.aim=new_aim;f.sim.combat.launch(f.p,"bow",new_aim,50,8,14,0)
		f.sim.combat.tick_projectiles(.5)
		check(hits(f).size()==1,"actual torso-selected projectile damages once "+kind)
		var empty=foot+Vector2(400,40)
		check(Aim.direction(empty,Dungeon.from_iso(empty),f.origin,f.sim.enemies,frames,f.sim.map).is_equal_approx(f.origin.direction_to(Dungeon.from_iso(empty))),"empty ground keeps free aim "+kind)
		# Reflection, small recoil rotation and scale use the exact draw transform.
		transform=Transform2D(.12,Vector2(-1.08,.94),0.,foot+Vector2(7,-4));frames.clear()
		Aim.register(frames,f.e,rect,transform)
		check(Aim.target_at(transform*rect.get_center(),f.sim.enemies,frames,f.origin,f.sim.map).get("id",-1)==f.e.id,"mirrored rotated sprite body "+kind)
		f.e.hp=0
		check(Aim.target_at(transform*rect.get_center(),f.sim.enemies,frames,f.origin,f.sim.map).is_empty(),"dead body not selected")
		f.e.hp=f.e.max_hp;f.e.pos+=Vector2(5,0)
		check(Aim.target_at(transform*rect.get_center(),f.sim.enemies,frames,f.origin,f.sim.map).is_empty(),"stale portal body not selected")
	var f=fixture();f.e.pos=f.origin+Vector2(4,0)
	var front=f.sim.spawn_enemy("shade",f.e.pos+Vector2(.2,.2),1);var frames={}
	var rect=Rect2(-55,-130,110,130);var transform=Transform2D(0.,Vector2.ONE,0.,Vector2(700,500))
	Aim.register(frames,f.e,rect,transform);Aim.register(frames,front,rect,transform)
	check(Aim.target_at(Vector2(700,450),f.sim.enemies,frames,f.origin,f.sim.map).id==front.id,"overlap chooses frontmost rendered monster")
	for y in range(0,55):f.sim.map.floor_cells.erase(Vector2i(26,y))
	check(Aim.target_at(Vector2(700,450),f.sim.enemies,frames,f.origin,f.sim.map).is_empty(),"cursor selection respects walls")

func receiving_boundaries():
	var snapshot=World.ENEMIES.duplicate(true)
	for kind in World.ENEMIES:
		var e={"kind":kind,"pos":Vector2.ZERO};var r=Geometry.radius(e)
		check(r>=1. and r<=2.15,"bounded receiving body "+kind)
		check(Geometry.circle(e,Vector2(r+2.-.001,0),2.) and not Geometry.circle(e,Vector2(r+2.+.001,0),2.),"precise circular edge "+kind)
		check(Geometry.forward_segment(e,Vector2(-3,r+.42-.001),Vector2(3,r+.42-.001),.42) and not Geometry.forward_segment(e,Vector2(-3,r+.42+.001),Vector2(3,r+.42+.001),.42),"precise swept projectile edge "+kind)
		check(not Geometry.arc(e,Vector2(1.2,0),Vector2.RIGHT,5.,-.05,.7),"backward swing remains a miss "+kind)
		check(not Geometry.forward_segment(e,Vector2(1.2,0),Vector2(3,0),.42),"projectile fired away remains a miss "+kind)
	for kind in ["shade","orc_champion","warden"]:
		for inside in [true,false]:
			var f=fixture("warrior",kind);var r=Geometry.radius(f.e)
			var reach=float(Content.WEAPONS[f.sim.combat.weapon_type(f.p)].range)+Content.skill_bonus(f.p,"melee_range")
			f.e.pos=f.origin+Vector2(reach+r+(-.02 if inside else .02),0)
			check(f.sim.action(1,"attack"),"actual edge basic accepted")
			check(hits(f).size()==(1 if inside else 0),"actual basic includes enlarged body edge "+kind+str(inside))
		var f=fixture("warrior",kind);f.e.pos=f.origin+Vector2(3,0)
		for y in range(0,55):f.sim.map.floor_cells.erase(Vector2i(26,y))
		f.sim.action(1,"attack");f.sim.combat.area(f.p,f.origin,8.,50)
		f.sim.combat.skills.add_zone(f.p,"frost",f.origin,8.,40,[0.,.1]);f.sim.combat.skills.tick(.2)
		f.sim.combat.launch(f.p,"bow",Vector2.RIGHT,50,8,10,0);f.sim.combat.tick_projectiles(.5)
		check(hits(f).is_empty(),"wider body and area never pass wall "+kind)
	# A projectile travelling alongside a thin wall must not detonate on the
	# enlarged receiving body behind it, nor spend a pierce/bleed hit ledger.
	var f=fixture("hunter","warden");f.e.pos=f.origin+Vector2(2,1.7)
	for x in range(0,55):f.sim.map.floor_cells.erase(Vector2i(x,25))
	f.sim.combat.launch(f.p,"bow",Vector2.RIGHT,50,8,10,3.)
	f.sim.combat.projectiles.back().status="bleed";f.sim.combat.projectiles.back().pierce=5
	f.sim.combat.tick_projectiles(.4)
	check(hits(f).is_empty() and f.sim.combat.projectiles[0].hit.is_empty(),"parallel wall prevents splash and ledger consumption")
	check(not f.e.get("job_status",{}).has("bleed"),"parallel wall prevents status application")
	check(World.ENEMIES==snapshot,"enemy outgoing damage/reach/navigation settings untouched")

func area_casts():
	for entry in [["warrior","spin",2.7],["ranger","rain",2.5],["mage","frost",3.],["mage","thunder",2.1]]:
		var f=fixture(str(entry[0]));var node=active(str(entry[0]),str(entry[1]))
		var profile=Scaling.profile(node,1,Active.bonuses(f.p));var center=f.origin
		if profile.mode=="rain":center+=Vector2(3.5,0)
		if profile.mode=="thunder":center+=Vector2(4.,0)
		f.e.pos=center+Vector2(0,float(entry[2])+Geometry.radius(f.e)+.25)
		var old_hp=f.e.hp;cast(f,node)
		check(f.e.hp<old_hp,"actual expanded area reaches previously missed enemy "+node.id)
		check(hits(f).size()==int(profile.count),"area preserves intended pulse count "+node.id)
		var effects=f.sim.events.filter(func(event):return event.type=="skill_fx" and event.get("skill_id","")==node.id)
		check(not effects.is_empty() and is_equal_approx(float(effects[0].radius),float(profile.radius)),"visible radius equals effective radius "+node.id)
		check(not effects.is_empty() and effects[0].get("ground_shape","")=="circle","area exposes actual ground contact shape "+node.id)
		area_samples.append({"id":node.id,"old_radius":entry[2],"radius":profile.radius,"pulses":profile.count,"hits":hits(f).size()})
	for mode in ["charge_area","charge_spin"]:
		var f=fixture("breaker");var node=active("breaker",mode);var before=Balance.profile(f.p,node,1,f.sim.damage_for(f.p),f.p.max_hp)
		f.e.pos=f.origin+Vector2(-3.,0)
		cast(f,node)
		check(hits(f).size()==1,"actual circular breaker hits rear body "+mode)
		check(float(before.node.radius)>=3.2,"charged area has useful radius "+mode)
		area_samples.append({"id":node.id,"old_radius":node.radius,"radius":before.node.radius,"pulses":before.count,"hits":hits(f).size()})
	var f=fixture("breaker");f.e.pos=f.origin+Vector2(-1.2,0);cast(f,active("breaker","charge"))
	check(hits(f).is_empty(),"focused charge remains directional")
	f=fixture("swordsman");f.e.pos=f.origin+Vector2(-1.2,0);cast(f,active("swordsman","strike"))
	check(hits(f).is_empty(),"duelist strike remains directional")
	# Actual ground-centered field plus a second enemy outside the old radius.
	f=fixture("elementalist");var n=active("elementalist","field");f.e.pos=f.origin+Vector2(4,0)
	var other=f.sim.spawn_enemy("shade",f.e.pos+Vector2(0,float(n.radius)+Geometry.radius(f.e)+.2),1);other.hp=1000000;other.max_hp=other.hp
	cast(f,n)
	check(other.hp<other.max_hp,"elementalist field reaches extra side target")
	check(hits(f).size()==10,"two field targets receive exactly five pulses each")
	# Broader boss contact cannot create more stagger than the per-cast budget.
	f=fixture("warrior","warden");n=active("warrior","spin");var s=Scaling.profile(n,1,Active.bonuses(f.p))
	f.e.pos=f.origin+Vector2(s.radius+Geometry.radius(f.e)-.02,0);cast(f,n)
	var stagger=0.
	for event in f.sim.events:
		if event.type=="stagger_damage":stagger+=event.amount
	check(hits(f).size()==s.count and stagger>0 and stagger<=Stagger.skill_profile(n,1,f.p).value+.02,"wide boss area preserves one stagger budget")

func profile_and_visual_contracts():
	for job in Content.CLASSES:
		var f=fixture(job);var p=f.p
		for n in Content.SKILLS[job]:
			if n.effect!="active":continue
			var source=n.duplicate(true)
			if Content.job(p):
				var low=Balance.profile(p,n,1,f.sim.damage_for(p),p.max_hp);var high=Balance.profile(p,n,5,f.sim.damage_for(p),p.max_hp)
				check(float(low.node.radius)>=float(n.radius),"job reach never shrinks "+n.id)
				check(is_equal_approx(float(low.node.range),float(n.range)),"job projectile/target range preserved "+n.id)
				check(high.power>low.power,"rank damage progression preserved "+n.id)
				if Reach.job_radius(n.mode,job,float(n.radius))==float(n.radius):check(is_equal_approx(float(low.node.radius),float(n.radius)),"focused/support radius preserved "+n.id)
			else:
				var low=Scaling.profile(n,1);var high=Scaling.profile(n,3)
				check(high.multiplier>low.multiplier and high.radius>low.radius,"base rank progression preserved "+n.id)
			check(n==source,"canonical node not mutated "+n.id)
	for shape in ["circle","arc"]:
		for radius in [1.7,3.2,4.2,6.,9.]:
			var event={"ground_shape":shape,"radius":radius,"dir":Vector2(1,2).normalized(),"arc_dot":0.}
			var points=Vfx.ground_contour(event)
			check(points.size()==(65 if shape=="circle" else 67),"bounded contour segments "+shape)
			for i in range(0 if shape=="circle" else 1,points.size() if shape=="circle" else points.size()-1):
				check(absf(Dungeon.from_iso(points[i]).length()-radius)<.0001,"outline exactly projects combat circle "+shape)
			check(Vfx.projected_radius(radius)>radius*47.,"old undersized visual radius corrected")
	print("COMBAT_REACH_V052_AREAS ",JSON.stringify(area_samples))

func run():
	Content.initialize_jobs()
	input_geometry();receiving_boundaries();area_casts();profile_and_visual_contracts()
	print("COMBAT_REACH_V052 checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
