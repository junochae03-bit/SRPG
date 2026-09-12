extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const Geometry=preload("res://scripts/enemy_hit_geometry.gd")
const World=preload("res://scripts/world_catalog.gd")
const Stagger=preload("res://scripts/boss_stagger.gd")
const Scaling=preload("res://scripts/skill_scaling.gd")
const Active=preload("res://scripts/active_skills.gd")
const Balance=preload("res://scripts/job_balance.gd")
const Rules=preload("res://scripts/skill_build.gd")
const MonsterAttacks=preload("res://scripts/monster_attacks.gd")
var checks=0
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)

func fixture(kind:String="shade",job:String="warrior")->Dictionary:
	var sim=Sim.new(177);sim.enemies.clear()
	# Open arena isolates receiving geometry from navigation. Wall rejection is
	# checked separately below; normal Dungeon.move/line_clear are still in use.
	for x in range(0,39):
		for y in range(0,39):sim.map.floor_cells[Vector2i(x,y)]=true
	var p=sim.add_player(1,"피격 범위 검사");p.class_id=job;p.level=99;p.skill_ranks={};p.skill_loadout={};p.constellation_allocations={}
	sim.recalculate(p);sim.combat.jobs.reset(p);sim.combat.constellation.reset(p)
	p.pos=Vector2(19,19);p.aim=Vector2.RIGHT;p.stamina=10000.;p.max_stamina=10000.
	var e=sim.spawn_enemy(kind,p.pos+Vector2.RIGHT,1,kind=="warden");e.hp=1000000;e.max_hp=e.hp
	if e.has("stagger"):e.stagger.max_value=1000000.
	return {"sim":sim,"p":p,"e":e,"origin":p.pos}

func reset(f:Dictionary):
	f.p.pos=f.origin;f.p.aim=Vector2.RIGHT;f.p.attack_cd=0.;f.p.charge_time=-1.;f.p.stamina=f.p.max_stamina
	f.p.skill_cooldowns={};f.p.job_state.lock=0.;f.p.job_state.casting={};f.p.job_state.pets=[]
	f.e.hp=f.e.max_hp;f.sim.events.clear();f.sim.combat.projectiles.clear();f.sim.combat.skills.zones.clear();f.sim.combat.constellation.pending.clear()

func damage_hits(f:Dictionary)->int:
	return f.sim.events.filter(func(ev):return ev.type=="damage" and ev.get("enemy",false)).size()

func node_for(job:String,mode:String)->Dictionary:
	for n in Content.SKILLS[job]:
		if n.effect=="active" and Stagger.skill_profile(n,1).mode==mode:return n
	check(false,"fixture skill exists "+job+" "+mode);return {}

func cast(f:Dictionary,node:Dictionary):
	f.p.skill_ranks[node.id]=1;f.p.skill_loadout.skill_q=node.id
	check(f.sim.action(f.p.id,"skill_q"),"actual skill cast "+node.id)

func run():
	Content.initialize_jobs()
	var original_enemy_balance=World.ENEMIES.duplicate(true)
	for kind in World.ENEMIES:
		var e={"kind":kind,"pos":Vector2.ZERO};var r=Geometry.radius(e)
		check(r>=1. and r<=2.15,"finite receiving radius "+kind)
		check(Geometry.circle(e,Vector2(r+2.-.001,0),2.) and not Geometry.circle(e,Vector2(r+2.+.001,0),2.),"circle boundary includes body edge "+kind)
		check(Geometry.segment(e,Vector2(-2,r+.42-.001),Vector2(2,r+.42-.001),.42) and not Geometry.segment(e,Vector2(-2,r+.42+.001),Vector2(2,r+.42+.001),.42),"projectile capsule edge "+kind)
		check(Geometry.segment(e,Vector2(r+.2-.001,0),Vector2(r+.2-.001,0),.2),"zero-length segment still has receiving volume")
		check(not Geometry.forward_segment(e,Vector2.ZERO,Vector2.ZERO,.42),"paused projectile has no new collision sweep")
		check(not Geometry.arc(e,Vector2(1.2,0),Vector2.RIGHT,3.,-.05,.7),"large body never negates backward aim "+kind)
	check(Geometry.radius({"kind":"shade"})<Geometry.radius({"kind":"orc_champion"}) and Geometry.radius({"kind":"orc_champion"})<Geometry.radius({"kind":"warden"}),"common elite boss receiving size follows visual scale")
	for kind in ["shade","orc_champion","warden"]:
		var f=fixture(kind);var r=Geometry.radius(f.e);var weapon=Content.WEAPONS[f.sim.combat.weapon_type(f.p)]
		var reach=weapon.range+Content.skill_bonus(f.p,"melee_range")
		for heavy in [false,true]:
			for inside in [true,false]:
				reset(f);f.e.pos=f.origin+Vector2(reach+(.8 if heavy else 0.)+r+(-.02 if inside else .02),0)
				if heavy:
					check(f.sim.action(1,"heavy_begin"),"charge accepted");f.p.charge_time=.9
				check(f.sim.action(1,"heavy" if heavy else "attack"),"real basic/heavy attack accepted")
				check((damage_hits(f)==1)==inside,"actual basic/heavy body edge "+kind+str(heavy)+str(inside))
		reset(f);f.e.pos=f.origin+Vector2(1.2,0);f.p.aim=Vector2.LEFT;f.sim.action(1,"attack")
		check(damage_hits(f)==0,"real backward swing is still MISS "+kind)
		f.sim.combat.launch(f.p,"bow",Vector2.LEFT,50,8.,10.,0.);f.sim.combat.tick_projectiles(.2)
		check(damage_hits(f)==0,"body around projectile muzzle never negates backward aim "+kind)
		for inside in [true,false]:
			reset(f);f.e.pos=f.origin+Vector2(2.,r+.42+(-.02 if inside else .02))
			f.sim.combat.launch(f.p,"bow",Vector2.RIGHT,50,8.,10.,0.);f.sim.combat.projectiles.back().pierce=5
			f.sim.combat.tick_projectiles(.4);f.sim.combat.tick_projectiles(.1)
			check(damage_hits(f)==(1 if inside else 0),"actual projectile body edge and once-per-projectile hit ledger "+kind+str(inside))
			reset(f);f.e.pos=f.origin+Vector2(2.+r+(-.02 if inside else .02),0)
			f.sim.combat.area(f.p,f.origin,2.,50)
			check(damage_hits(f)==(1 if inside else 0),"actual circular area boundary "+kind+str(inside))
			reset(f);f.e.pos=f.origin+Vector2(2.+r+(-.02 if inside else .02),0)
			f.sim.combat.skills.add_zone(f.p,"frost",f.origin,2.,30,[0.,.1,.2])
			f.sim.combat.skills.tick(.3)
			check(damage_hits(f)==(3 if inside else 0),"all timed pulses use receiving geometry without extra hits "+kind+str(inside))
			reset(f);f.e.pos=f.origin+Vector2(2.,1.1+r+(-.02 if inside else .02));cast(f,node_for("warrior","dash"))
			check(damage_hits(f)==(1 if inside else 0),"real moving dash hits each touched body once "+kind+str(inside))
		# Skills and pets share target acquisition; enemy attack reach is not used.
		reset(f);f.e.pos=f.origin+Vector2(6.+r-.02,0)
		check(f.sim.combat.jobs.target(f.p,6.).get("id",-1)==f.e.id,"job target can acquire visible body at range edge "+kind)
		f.e.pos.x+=.04;check(f.sim.combat.jobs.target(f.p,6.).is_empty(),"job target rejects beyond receiving edge")
		reset(f);f.e.pos=f.origin+Vector2(1.6+r-.02,0)
		f.p.job_state.pets.append({"source":"test","pos":f.origin,"hp":100.,"cd":0.,"power":1.,"kind":0})
		f.sim.combat.jobs.tick(f.p,0.)
		check(damage_hits(f)==0,"manifestation never attacks without player input "+kind)
		f.p.class_id="hunter";f.sim.action(1,"attack");f.sim.combat.tick_projectiles(.6)
		check(damage_hits(f)==2,"player hit triggers manifestation at target body edge "+kind)
		f.p.class_id="warrior"
		# A wall still blocks the entire attack, even if body overlap is generous.
		reset(f);f.e.pos=f.origin+Vector2(reach+r-.02,0)
		for y in range(0,39):f.sim.map.floor_cells.erase(Vector2i(20,y))
		f.sim.action(1,"attack");f.sim.combat.area(f.p,f.origin,9.,50)
		f.sim.combat.skills.add_zone(f.p,"frost",f.origin,9.,30,[0.]);f.sim.combat.skills.tick(.1)
		f.sim.combat.launch(f.p,"bow",Vector2.RIGHT,50,8.,10.,0.);f.sim.combat.tick_projectiles(.5)
		check(damage_hits(f)==0,"receiving body cannot be hit through a wall "+kind)
	# Real advanced strike, selected-skill chain, and constellation wave delivery.
	var f=fixture("shade","swordsman");var n=node_for("swordsman","strike")
	var profile=Balance.profile(f.p,n,1,f.sim.damage_for(f.p),f.p.max_hp)
	f.e.pos=f.origin+Vector2(profile.node.radius+Geometry.radius(f.e)-.02,0);cast(f,n)
	for step in range(30):f.sim.clock+=.03;f.sim.combat.tick_player(f.p,.03);f.sim.combat.skills.tick(.03)
	check(damage_hits(f)>0,"actual advanced direct skill uses receiving body")
	f=fixture("shade","mage");n=node_for("mage","chain")
	var scaled=Scaling.profile(n,1,Active.bonuses(f.p));f.e.pos=f.origin+Vector2(scaled.range+Geometry.radius(f.e)-.02,0);cast(f,n)
	check(damage_hits(f)==1,"actual chain cast acquires by receiving edge")
	f=fixture("warden");n=node_for("warrior","spin");scaled=Scaling.profile(n,1,Active.bonuses(f.p))
	f.e.pos=f.origin+Vector2(scaled.radius+Geometry.radius(f.e)-.02,0);cast(f,n)
	for step in range(30):f.sim.clock+=.03;f.sim.combat.skills.tick(.03)
	var stagger_total=0.
	for event in f.sim.events:
		if event.type=="stagger_damage":stagger_total+=event.amount
	check(damage_hits(f)==scaled.count and stagger_total>0 and stagger_total<=Stagger.skill_profile(n,1,f.p).value+.02,"enlarged boss edge preserves multi-hit cast stagger budget")
	reset(f);f.e.pos=f.origin+Vector2(2.,1.1+Geometry.radius(f.e)-.02)
	var plan=Rules.path_plan(f.p,"warrior:star:3:key")
	check(plan.ok,"legal warrior wave fixture")
	f.p.constellation_allocations=plan.player.constellation_allocations;f.p.skill_ranks=plan.player.skill_ranks
	scaled=Scaling.profile(n,1,Active.bonuses(f.p))
	f.sim.combat.constellation.pending.append({"owner":1,"context":{},"kind":"wave","target":-1,"pos":f.origin,"time":0.,"amount":40,"radius":2.,"origin":f.origin,"aim":Vector2.RIGHT})
	# Real prepared context supplies the original budget even to delayed waves.
	var wave_context=f.sim.combat.constellation.prepare(f.p,n,scaled);wave_context.build.primary=false
	f.sim.combat.constellation.pending.back().context=wave_context;f.sim.combat.constellation.tick(.01)
	check(damage_hits(f)==1,"constellation line proc shares receiving geometry")
	var pattern=MonsterAttacks.pattern("shade",Vector2.ZERO,Vector2.RIGHT)
	check(pattern[0].radius==1. and not MonsterAttacks.contains(pattern[0],Vector2(2.01,0)),"enemy outgoing telegraph/reach is unchanged")
	check(World.ENEMIES==original_enemy_balance,"receiving helper leaves HP/damage/reach/balance catalog unchanged")
	print("ENEMY_HIT_GEOMETRY_V05 checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
