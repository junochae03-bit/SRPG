extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const Scaling=preload("res://scripts/skill_scaling.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
	for cls in Content.CLASSES:
		for node in Content.SKILLS[cls]:
			var impacts=[];var times=[]
			for rank in [1,2,3]:
				var sim=Sim.new(909);sim.enemies.clear();var p=sim.add_player(1,"성장 검사");p.class_id=cls;p.level=100;p.skill_ranks={node.id:rank};p.skill_loadout={"skill_f":node.id};sim.recalculate(p)
				if node.effect!="active":
					impacts.append(Content.skill_bonus(p,node.effect));check(Scaling.passive_text(node,rank)!="+0","passive display has a real value "+node.id+str(rank));continue
				p.pos=Vector2(sim.map.rooms[1]);p.aim=Vector2.RIGHT;p.max_hp=1000;p.hp=60;p.stamina=1000;p.max_stamina=1000
				var s=Scaling.profile(node,rank);var center=p.pos+Vector2.RIGHT
				if s.mode in ["rain","thunder","burst","field","pull","blink"]:center=sim.combat.skills.target(p,3.5 if s.mode=="rain" else 4.0 if s.mode=="thunder" else s.distance if s.mode=="blink" else 3.0)
				for i in range(8):
					var e=sim.spawn_enemy("imp",center+Vector2(0,i*.10),1);e.hp=100000;e.max_hp=100000
				var hp=p.hp;var stamina=p.stamina
				check(sim.action(1,"skill_f"),"cast rank "+node.id+str(rank));times.append(p.skill_f_cd)
				check(is_equal_approx(stamina-p.stamina,s.cost),"displayed cost matches cast "+node.id+str(rank))
				check(sim.events.any(func(e):return e.get("rank",0)==rank),"rank reaches visual event "+node.id+str(rank))
				for shot in sim.combat.projectiles:check(is_equal_approx(shot.width,s.width),"rank changes projectile hit width "+node.id)
				for i in range(180):sim.combat.tick_projectiles(.02);sim.combat.skills.tick(.02)
				if s.mode=="heal":impacts.append(p.hp-hp)
				elif s.mode=="barrier":
					var enemy=sim.enemies.values()[0];var before=p.hp
					sim.monster_attacks.damage(enemy,p,{"multiplier":5.0,"drain":0,"slow":0,"knock":0})
					impacts.append(100-(before-p.hp));check(is_equal_approx(p.barrier_time,s.duration),"barrier duration "+str(rank))
				elif s.mode=="haste":
					p.dir=Vector2.RIGHT;var before=p.pos;sim.combat.tick_player(p,.1);impacts.append(p.pos.distance_to(before))
					sim.combat.attack(p,false,0);check(is_equal_approx(p.attack_cd,.48*(1-s.haste_attack)),"haste changes real attack delay "+str(rank))
				else:
					var damage=0
					for e in sim.enemies.values():damage+=100000-e.hp
					impacts.append(damage);check(damage>0,"rank damages real targets "+node.id+str(rank))
					if node.id=="blade_wave":check(100000-sim.enemies.values()[0].hp==[32,49,71][rank-1],"blade wave exact damage 32/49/71")
			check(impacts[1]>impacts[0] and impacts[2]>impacts[1],"each investment strengthens actual effect "+node.id)
			if node.effect=="active":check(times[2]<times[1] and times[1]<times[0],"rank improves real cooldown "+node.id)
	print("SKILLS_V01_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
