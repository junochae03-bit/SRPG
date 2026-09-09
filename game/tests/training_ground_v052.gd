extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Training=preload("res://scripts/training_ground.gd")
const Content=preload("res://scripts/content.gd")
const Stagger=preload("res://scripts/boss_stagger.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var sim=Sim.new(20260910,"town");var p=sim.add_player(1,"훈련 검증",{"schema_version":7,"class_id":"warrior","level":100,"tutorial_done":true})
	var dummies=sim.enemies.values().filter(func(e):return e.get("training",false))
	check(dummies.size()==1,"town spawns one giant practice target")
	if dummies.is_empty():finish();return
	var e=dummies[0]
	check(e.pos==Training.POSITION and e.hp==Training.HEALTH and e.boss and not e.raid and not e.guardian,"immortal target uses normal boss stagger without raid or guardian progression")
	check(sim.map.walkable(e.pos) and Training.contains(e.pos),"training dummy sits on its reachable court")
	check(sim.map.in_town(sim.map.spawn) and not sim.map.in_town(Training.POSITION),"town remains safe except marked training court")
	var baseline=sim.persistent(1).duplicate(true)
	sim.combat.hit(p,e,100)
	check(Training.summary(p).hits==0 and e.hp==e.max_hp,"attacks from outside practice court cannot damage or record")
	check(sim.combat.jobs.target(p,100).is_empty(),"pets do not target training dummy from safe town")
	p.pos=Training.POSITION+Vector2(-3,0);p.aim=Vector2.RIGHT
	check(sim.action(1,"attack"),"basic attack is usable inside town practice court")
	var stats=Training.summary(p)
	check(stats.hits==1 and stats.total_damage>0 and stats.last_skill=="기본 공격" and stats.last_skill_id=="basic","actual basic hit records amount and source")
	check(e.hp==e.max_hp and not e.get("rewarded",false),"normal attack leaves target alive at full health")
	check(sim.persistent(1)==baseline and sim.drops.is_empty(),"training grants no experience gold drops kills or quest progress")
	sim.kill(1,e)
	check(sim.persistent(1)==baseline and sim.drops.is_empty() and e.hp==e.max_hp,"even forced kill path cannot reward or despawn practice object")
	sim.combat.hit(p,e,Training.HEALTH*2)
	check(e.hp==e.max_hp and sim.drops.is_empty() and not e.get("rewarded",false),"larger than maximum damage still cannot kill training dummy")
	# Find a deterministic critical RNG seed; keep the skill rank legal.
	var critical_node={}
	for n in Content.SKILLS.warrior:
		if n.effect=="critical":critical_node=n;break
	check(not critical_node.is_empty(),"warrior has a legal critical passive")
	if not critical_node.is_empty():
		p.skill_ranks[critical_node.id]=Content.max_rank(critical_node)
		var chance=minf(.65,Content.skill_bonus(p,"critical"));var rng=RandomNumberGenerator.new();var chosen=-1
		for seed in range(500):
			rng.seed=seed
			if rng.randf()<chance:chosen=seed;break
		check(chosen>=0,"deterministic critical fixture exists")
		if chosen>=0:
			sim.rng.seed=chosen;p.attack_cd=0.;sim.events.clear();var count=Training.summary(p).criticals
			check(sim.action(1,"attack"),"actual critical practice attack")
			check(Training.summary(p).criticals==count+1 and sim.events.any(func(event):return event.type=="damage" and event.get("critical",false)),"practice critical count matches actual damage event flag")
	# Skills may be rebound in the town court, and the same cast/stagger budget
	# is used on the dummy as on an ordinary boss.
	var spin={}
	for n in Content.SKILLS.warrior:
		if n.id=="whirlwind":spin=n;break
	p.skill_ranks[spin.id]=1
	check(sim.action(1,"bind_skill","skill_q:"+spin.id),"active slot binding is allowed within town training area")
	p.stamina=p.max_stamina;p.skill_cooldowns={};e.stagger.max_value=20.;sim.events.clear()
	check(sim.action(1,"skill_q"),"real area skill casts on target")
	for step in range(70):sim.tick(.02)
	stats=Training.summary(p)
	check(stats.last_skill==spin.name and stats.last_skill_id==spin.id,"training shows learned skill name instead of internal effect id")
	check(stats.stagger_breaks>=1 and e.stagger.state=="down","normal skill budget can stagger the practice boss")
	check(stats.dps>0 and is_finite(stats.dps) and stats.elapsed>=1,"damage meter has bounded meaningful elapsed time")
	var hp=p.hp;var progress={}
	for key in ["level","xp","gold","kills","boss_kills","quest_done","tutorial_kills","highest_floor","cleared_floor","raid_clears","guild_contract","dungeon_clears"]:progress[key]=sim.persistent(1)[key]
	for step in range(300):sim.tick(.1)
	check(p.hp==hp and sim.monster_attacks.zones.is_empty() and not sim.events.any(func(event):return event.type=="monster_attack" or event.type=="damage" and not event.get("enemy",false)),"long practice never triggers enemy AI or counterattack")
	for key in progress:check(sim.persistent(1)[key]==progress[key],"long practice preserves progression "+key)
	check(e.hp==e.max_hp and e.pos==Training.POSITION and e.stagger.state=="ready","dummy stays anchored and stagger immunity returns to ready")
	var learned=p.skill_ranks.duplicate(true);var loadout=p.skill_loadout.duplicate(true);var items=p.inventory.duplicate(true)
	p.hp=maxi(1,p.hp-20);hp=p.hp;p.stamina=1;p.attack_cd=5.;p.skill_cooldowns[spin.id]=100.
	sim.combat.launch(p,"bow",Vector2.RIGHT,10,8,10,0);sim.combat.skills.add_zone(p,"frost",e.pos,3,10,[1.])
	check(sim.action(1,"training_reset"),"explicit practice reset accepted inside court")
	check(Training.summary(p).hits==0 and Training.summary(p).total_damage==0 and p.attack_cd==0 and p.skill_cooldowns.is_empty() and p.stamina==p.max_stamina,"reset clears measurement and restores skill availability")
	check(sim.combat.projectiles.is_empty() and sim.combat.skills.zones.is_empty() and sim.combat.constellation.pending.is_empty(),"reset cancels in-flight own attacks and delayed effects")
	check(p.hp==hp and p.skill_ranks==learned and p.skill_loadout==loadout and p.inventory==items,"reset keeps character health learned build and possessions")
	check(not sim.persistent(1).has("training_stats"),"training session measurements never enter character saves")
	p.pos=sim.map.spawn
	check(not sim.action(1,"training_reset"),"practice reset cannot be used remotely from town plaza")
	var other=Sim.new(20260910,"forest",1);var explorer=other.add_player(1,"던전 검증");explorer.pos=Training.POSITION
	check(not other.action(1,"training_reset"),"same coordinate inside a real dungeon does not enable practice reset")
	finish()
func finish():
	print("TRAINING_GROUND_V052 checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
