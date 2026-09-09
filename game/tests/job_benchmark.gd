extends SceneTree
const Simulation=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const LOADOUTS={
	"tank":[8,9,11,1,4,2],"swordsman":[0,1,3,4,5,8],"runesword":[0,2,4,6,8,9],
	"summoner":[0,1,2,4,5,8],"elementalist":[0,1,2,4,8,10],"healer":[0,1,4,5,9,11],
	"sniper":[0,1,3,4,6,10],"hunter":[0,1,4,5,8,10],"explorer":[0,1,2,4,8,11],
	"thief":[0,1,5,6,8,9],"reaper":[0,4,5,7,8,9],"gambler":[0,2,4,5,8,11],
	"infighter":[0,1,2,3,4,8],"breaker":[0,1,3,4,8,10],"martialist":[0,2,4,5,7,9]}
func _initialize():
	Content.initialize_jobs()
	var report={"scenario":"LV60, 177 stats (100 primary / 77 vitality), 36 SP (all actives and passives rank2), six equipped, default gear, 30 seconds, three seeds, stationary targets; movement restored to melee range; no enemy AI or incoming damage; cooldown/stamina/resources real","jobs":{}}
	for job in LOADOUTS:
		var row={"single_dps":0.,"five_dps":0.,"casts":0.,"minimum_stamina":0.}
		for seed_value in [123,456,789]:
			for count in [1,5]:
				var sample=measure(job,count,seed_value)
				row["single_dps" if count==1 else "five_dps"]+=sample.damage/30./3.
				if count==1:row.casts+=sample.casts/3.;row.minimum_stamina+=sample.minimum_stamina/3.
		for key in row:row[key]=snappedf(row[key],.1)
		report.jobs[job]=row
	var suffix="current"
	if not OS.get_cmdline_user_args().is_empty():suffix=OS.get_cmdline_user_args()[0]
	var path=ProjectSettings.globalize_path("res://../artifacts/job-benchmark-"+suffix+".json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir());FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit()
static func measure(job:String,count:int,seed_value:int)->Dictionary:
	var sim=Simulation.new(seed_value);sim.enemies.clear()
	var p=sim.add_player(1,"측정");p.class_id=job;p.level=60;p.stats={"strength":0,"dexterity":0,"intelligence":0,"vitality":77}
	p.stats[{"sword":"strength","axe":"strength","bow":"dexterity","staff":"intelligence"}[Content.CLASSES[job].weapon]]=100
	p.skill_ranks={};p.skill_loadout={}
	for n in Content.SKILLS[job]:
		if n.effect in ["active","passive"]:p.skill_ranks[n.id]=2
	for i in range(6):p.skill_loadout[Content.ACTIONS[i]]=job+"_a%02d"%(LOADOUTS[job][i]+1)
	sim.recalculate(p);sim.combat.jobs.reset(p);p.stamina=p.max_stamina
	var origin=Vector2(sim.map.rooms[1]);p.pos=origin;p.aim=Vector2.RIGHT
	var positions=[]
	for i in range(count):
		var pos=origin+Vector2(1.1+(i%2)*.45,(i/2-1)*.45 if count>1 else 0.);positions.append(pos)
		var e=sim.spawn_enemy("shade",pos,60,count==1);e.hp=10000000;e.max_hp=e.hp
	var casts=0;var minimum_stamina=p.stamina;var cursor=0
	for tick in range(750):
		p.pos=origin;p.aim=Vector2.RIGHT;p.attack_cd=maxf(0,p.attack_cd-.04)
		for i in range(count):sim.enemies[i+1].pos=positions[i]
		for offset in range(6):
			var index=(cursor+offset)%6;var node=Content.active_node(p,Content.ACTIONS[index])
			if node.mode=="summon" and p.job_state.pets.any(func(pet):return pet.source==node.id):continue
			if node.mode in ["heal","regen"] and p.hp>p.max_hp*.85:continue
			if sim.action(1,Content.ACTIONS[index]):casts+=1;cursor=(index+1)%6;break
		sim.action(1,"attack");minimum_stamina=minf(minimum_stamina,p.stamina)
		sim.combat.tick_player(p,.04);sim.combat.tick_projectiles(.04);sim.combat.skills.tick(.04);sim.events.clear()
	var damage=0
	for e in sim.enemies.values():damage+=10000000-e.hp
	return {"damage":damage,"casts":casts,"minimum_stamina":minimum_stamina}
