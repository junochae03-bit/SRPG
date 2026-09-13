extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const Guard=preload("res://scripts/enemy_defense.gd")
const Stagger=preload("res://scripts/boss_stagger.gd")
var checks=0
var failures=[]
var results=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func fixture(job:String,kind:String):
	var sim=Sim.new(941,"cave",12);sim.enemies.clear();sim.map.floor_cells.clear();sim.map.spawn=Vector2.ONE
	for x in range(1,25):
		for y in range(1,25):sim.map.floor_cells[Vector2i(x,y)]=true
	var p=sim.add_player(1,"공략");p.class_id=job;p.level=20;p.skill_ranks={};p.skill_loadout={};p.pos=Vector2(10,10);p.aim=Vector2.RIGHT
	sim.combat.jobs.reset(p);sim.recalculate(p);p.invulnerable=10000.;p.hp=p.max_hp
	var enemy=sim.spawn_enemy(kind,Vector2(12,10),20);enemy.hp=1000000;enemy.max_hp=1000000;enemy.cooldown=10000.;enemy.speed=0.
	return sim
func _initialize():
	Content.initialize_jobs()
	for job in Content.CLASSES:
		for kind in ["beetle","clockwork","centurion"]:
			for heavy in [false,true]:
				var sim=fixture(job,kind);var p=sim.players[1];var enemy=sim.enemies[1];var broken=false;var attacks=0
				for step in range(400):
					if heavy:
						if p.charge_time>=.9:
							if sim.action(1,"heavy"):attacks+=1
						elif p.charge_time<0:sim.action(1,"heavy_begin")
					elif sim.action(1,"attack"):attacks+=1
					sim.tick(.05)
					if enemy.get("guard_break_time",0)>0:broken=true;break
				check(broken,"actual solo %s %s %s"%[job,kind,"heavy" if heavy else "basic"])
				check(enemy.hp<enemy.max_hp,"real hit path reaches enemy")
				results.append({"class":job,"enemy":kind,"method":"heavy" if heavy else "basic","seconds":sim.clock,"attacks":attacks,"broken":broken})
	var sim=fixture("warrior","clockwork");var enemy=sim.enemies[1];var p=sim.players[1]
	var basic=Stagger.context(Stagger.basic_token(false,0.,sim.clock))
	sim.combat.hit(p,enemy,100,null,basic)
	check(enemy.guard_layers==2,"basic removes one layer")
	for index in range(20):sim.combat.hit(p,enemy,100,null,basic)
	check(enemy.guard_layers==2,"repeat same projectile or splash cannot spend more layers")
	var dot={"budget":{"value":60.,"count":20,"dot":true,"created":sim.clock},"weight":.05}
	for index in range(20):sim.combat.hit(p,enemy,100,null,dot)
	check(enemy.guard_layers==2,"periodic damage cannot consume contact charges")
	sim.combat.hit(p,enemy,100,null,Stagger.context(Stagger.basic_token(true,1.,sim.clock)))
	check(enemy.guard_layers==0 and enemy.guard_break_time==Guard.LAYER_BREAK_SECONDS,"full charge is solo alternative")
	Guard.tick(enemy,Guard.LAYER_BREAK_SECONDS,sim.clock+Guard.LAYER_BREAK_SECONDS)
	check(enemy.guard_layers==3 and enemy.guard_break_time==0.,"layers restore when exposure expires")
	Guard.initialize(enemy);check(enemy.guard_layers==3 and not enemy.has("guard_pressure"),"new spawn clears old defense state")
	sim=fixture("infighter","clockwork");p=sim.players[1];enemy=sim.enemies[1]
	p.skill_ranks["infighter_a01"]=1;p.skill_loadout.skill_q="infighter_a01"
	check(sim.action(1,"skill_q"),"actual multihit skill accepted")
	for step in range(30):sim.tick(.05)
	check(enemy.guard_break_time>0,"one actual barrage removes layered shield")
	sim=fixture("thief","clockwork");p=sim.players[1];enemy=sim.enemies[1]
	p.skill_ranks["thief_a09"]=1;p.skill_loadout.skill_q="thief_a09"
	check(sim.action(1,"skill_q"),"actual bleed skill accepted")
	for step in range(10):sim.tick(.05)
	check(enemy.get("job_status",{}).has("bleed"),"real action creates bleed status")
	var bleed_before=enemy.hp
	for step in range(50):sim.tick(.05)
	check(enemy.hp<bleed_before and enemy.guard_layers==3,"actual status ticks damage but do not spend ward layers")
	sim=fixture("breaker","beetle");p=sim.players[1];enemy=sim.enemies[1]
	p.skill_ranks["breaker_a01"]=1;p.skill_loadout.skill_q="breaker_a01"
	check(sim.action(1,"skill_q"),"actual high stagger skill accepted")
	for step in range(60):sim.tick(.05)
	check(enemy.guard_break_time>0,"high stagger cast supplies a separate solo armor solution")
	sim=fixture("warrior","centurion");p=sim.players[1];enemy=sim.enemies[1]
	var before=enemy.hp;sim.combat.hit(p,enemy,100,null,{});var guarded=before-enemy.hp
	enemy.windup=.7;before=enemy.hp;sim.combat.hit(p,enemy,100,null,{})
	check(before-enemy.hp>guarded and Guard.exposed(enemy),"attacking during windup bypasses brace")
	enemy.windup=0.;enemy.attack_motion=.2;check(Guard.exposed(enemy),"recovery remains an opening")
	enemy.attack_motion=0.;check(not Guard.exposed(enemy),"brace returns outside opening")
	enemy.stun_time=.2;check(Guard.exposed(enemy),"stun is an alternative opening")
	enemy.stun_time=0.;enemy.boss=true;check(Guard.type_for(enemy).is_empty() and Guard.factor(sim,enemy,{})==.75,"raid rules never replaced")
	var file=FileAccess.open("res://../artifacts/enemy-defense-solo.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
	print("ENEMY_DEFENSE_SOLO checks=%d failures=%d scenarios=%d"%[checks,failures.size(),results.size()]);quit(0 if failures.is_empty() else 1)
