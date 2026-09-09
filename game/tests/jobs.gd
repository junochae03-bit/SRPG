extends SceneTree
const Simulation=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const Jobs=preload("res://scripts/job_combat.gd")
var failures=[]
var checks=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func run():
	Content.initialize_jobs()
	var sim=Simulation.new(123,"town");var p=sim.add_player(1,"검증")
	check(Content.CLASSES.size()==20,"five basic and fifteen advanced jobs")
	check(not sim.action(1,"class","swordsman"),"level 30 gate")
	p.level=30
	check(sim.action(1,"class","swordsman"),"warrior advancement")
	check(not sim.action(1,"class","breaker"),"base family gate")
	check(sim.action(1,"invest","swordsman_a01"),"learn active")
	check(sim.action(1,"bind_skill","skill_q:swordsman_a01"),"six-slot binding")
	check(sim.action(1,"bind_skill","skill_x:swordsman_a01") and not p.skill_loadout.has("skill_q"),"unique loadout")
	check(not Content.can_invest(p,"swordsman_a01_upgrade"),"third advancement gate")
	p.level=60;p.skill_ranks.swordsman_a01=3
	check(Content.can_invest(p,"swordsman_a01_upgrade"),"third level and rank gate")
	check(Jobs.hand_total([0,13,9])==12,"multiple aces")
	check(is_equal_approx(Jobs.payout([0,9]),2.1),"natural blackjack")
	check(is_equal_approx(Jobs.payout([6,19,32]),1.85),"three-card 21")
	var world=Simulation.new(123);var hero=world.add_player(1,"runtime");hero.level=100;hero.max_stamina=10000;hero.stamina=10000
	for job in Content.CLASSES:
		if not Content.CLASSES[job].has("base") or Content.CLASSES[job].get("starter",false):continue
		hero.class_id=job;world.combat.jobs.reset(hero);hero.skill_ranks={};hero.skill_loadout={}
		var count=0
		for node in Content.SKILLS[job]:
			if node.effect!="active":continue
			count+=1;hero.skill_ranks[node.id]=3;hero.skill_loadout.skill_q=node.id
			hero.pos=Vector2(world.map.rooms[1]);hero.aim=Vector2.RIGHT;hero.stamina=10000;hero.skill_cooldowns.clear();hero.job_state.casting={};hero.job_state.lock=0.;hero.job_state.candidates=[];hero.charge_time=-1;hero.dodge_time=0
			world.enemies.clear();var enemy=world.spawn_enemy("shade",hero.pos+Vector2(1,0),30);enemy.hp=100000;enemy.max_hp=100000
			hero.job_state.runes=10;hero.job_state.marks={str(enemy.id):8.};hero.job_state.dice=1;hero.job_state.dice_time=9.
			if job in ["hunter","summoner"] and hero.job_state.pets.is_empty():hero.job_state.pets.append({"source":"test","pos":hero.pos,"hp":100.,"cd":0.,"power":1.,"kind":0})
			check(world.action(1,"skill_q"),"cast "+node.id)
			for tick in range(15):world.combat.tick_player(hero,.1);world.combat.tick_projectiles(.1);world.combat.skills.tick(.1)
		check(count==12,"12 actives "+job)
	hero.class_id="breaker";world.combat.jobs.reset(hero);hero.pos=Vector2(world.map.rooms[1]);hero.aim=Vector2.RIGHT
	var e=world.enemies.values()[0];e.pos=hero.pos+Vector2(1,0)
	world.combat.jobs.receive(hero,e,50,false);var initial=Jobs.grit(hero)
	world.combat.jobs.tick(hero,1.)
	check(Jobs.grit(hero)<initial*.6,"fast independent grit decay")
	world.combat.jobs.receive(hero,e,20,false);world.combat.jobs.tick(hero,1.1)
	check(hero.job_state.grit.size()==1,"new hit does not refresh old grit")
	var before=Jobs.grit(hero);world.combat.jobs.spend_grit(hero,100)
	check(before>0 and Jobs.grit(hero)<.01,"consume temporary grit first")
	hero.class_id="gambler";world.combat.jobs.reset(hero)
	for i in range(100):world.combat.jobs.basic(hero)
	var cards=hero.job_state.deck+hero.job_state.hand+hero.job_state.discard
	check(cards.size()==52,"deck conserved across reshuffle")
	var unique={}
	for card in cards:unique[card]=true
	check(unique.size()==52,"no duplicated cards")
	# Resources and action identity are checked by their outcomes, not just dispatch.
	hero.class_id="breaker";world.combat.jobs.reset(hero);hero.stamina=100;hero.attack_cd=0;hero.charge_time=-1;hero.dodge_time=0;hero.aim=Vector2.RIGHT;e.pos=hero.pos+Vector2.RIGHT
	hero.job_state.parry=.25
	check(world.combat.jobs.receive(hero,e,40,true)==0 and hero.job_state.counter>0,"front parry grants counter without damage")
	hero.job_state.parry=.25;e.pos=hero.pos-Vector2.RIGHT
	check(world.combat.jobs.receive(hero,e,40,true)>0,"rear attack bypasses parry")
	check(world.action(1,"heavy_begin"),"breaker begins heavy")
	var snap=hero.job_state.heavy_grit
	world.combat.jobs.tick(hero,.5)
	check(snap>0 and hero.job_state.heavy_grit==snap,"charge snapshots consumed grit")
	world.action(1,"cancel_charge")
	check(hero.charge_time<0 and hero.job_state.heavy_grit==0 and Jobs.grit(hero)<.01,"cancel spends rather than refunds snapshot")
	hero.class_id="infighter";world.combat.jobs.reset(hero);hero.stamina=100;hero.dodge_time=0
	check(world.action(1,"dodge"),"first infighter dash")
	world.combat.tick_player(hero,.2)
	check(world.action(1,"dodge") and not world.action(1,"dodge"),"two charges only")
	hero.class_id="reaper";world.combat.jobs.reset(hero);hero.skill_ranks={"reaper_a01":1};hero.skill_loadout={"skill_q":"reaper_a01"};hero.skill_cooldowns.clear();hero.stamina=100;hero.dodge_time=0;hero.aim=Vector2.RIGHT;e.pos=hero.pos+Vector2.RIGHT;e.hp=10000;e.boss=true
	check(world.action(1,"skill_q"),"boss accepts chain approach")
	world.combat.tick_player(hero,1.)
	check(hero.job_state.instant>0,"chain grants uncharged heavy token")
	hero.class_id="thief";world.combat.jobs.reset(hero);hero.skill_ranks={};hero.job_state.support_sent=[]
	world.combat.jobs.status(hero,e,"weaken",3.)
	check(e.job_status.has("weaken") and world.combat.jobs.value(hero,"defense")>0,"debuff grants support buff")
	hero.class_id="gambler";world.combat.jobs.reset(hero);hero.skill_ranks={"gambler_a03":1};hero.skill_loadout={"skill_q":"gambler_a03"};hero.skill_cooldowns.clear();hero.stamina=100;hero.dodge_time=0
	check(world.action(1,"skill_q"),"cut card offers choice")
	world.combat.tick_player(hero,1.)
	check(hero.job_state.candidates.size()==2,"exactly two visible candidates")
	world.action(1,"card_next");world.action(1,"attack")
	cards=hero.job_state.deck+hero.job_state.hand+hero.job_state.discard
	check(cards.size()==52 and hero.job_state.candidates.is_empty(),"cut selection conserves deck")
	var session=preload("res://scripts/local_session.gd").new();root.add_child(session)
	session.save_directory="/tmp/srpg-job-saves-"+str(Time.get_ticks_usec());session.start_game("저장 검증",1);session.set_physics_process(false)
	var saved_hero=session.sim.players[1];saved_hero.level=100
	for cls in Content.CLASSES:
		if not Content.CLASSES[cls].has("base"):continue
		saved_hero.class_id=cls;saved_hero.skill_ranks={};saved_hero.skill_loadout={};session.sim.combat.jobs.reset(saved_hero)
		for node in Content.SKILLS[cls]:
			if node.effect=="active" and saved_hero.skill_loadout.size()<6:saved_hero.skill_ranks[node.id]=3;saved_hero.skill_loadout[Content.ACTIONS[saved_hero.skill_loadout.size()]]=node.id
		session.save_game();var parsed=session.parse_save(session.save_path())
		check(parsed!=null and parsed.class_id==cls and parsed.skill_loadout==saved_hero.skill_loadout,"save restores job and six slots "+cls)
	session.disconnect_game();session.queue_free()
	print("JOBS: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
