extends SceneTree
const Simulation=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const Motion=preload("res://scripts/character_motion.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	for class_id in ["warrior","ranger","mage"]:
		var sim=Simulation.new();var p=sim.add_player(1,"기술 검증");p.class_id=class_id;p.level=40
		check(Content.SKILLS[class_id].size()==50,"fifty nodes "+class_id)
		for node in Content.SKILLS[class_id].slice(0,15):
			check(sim.action(1,"invest",node.id),"prerequisites permit earned investment "+node.id)
			check(int(p.skill_ranks[node.id])==1,"rank persisted "+node.id)
		check(Content.available_points(p)==24,"fifteen points deducted "+class_id)
		for action in ["skill_f","skill_v","skill_c"]:
			var room=Vector2(sim.map.rooms[1]);p.pos=room;p.aim=Vector2.RIGHT;p.dir=Vector2.ZERO;p.stamina=p.max_stamina;p[action+"_cd"]=0
			var node=Content.active_node(p,action);p.skill_ranks.erase(node.id)
			var before=p.stamina
			check(not sim.action(1,action) and p.stamina==before,"unlearned skill rejected without cost "+class_id+action)
			p.skill_ranks[node.id]=1;p.stamina=0
			check(not sim.action(1,action),"stamina required "+class_id+action)
			p.stamina=p.max_stamina
			sim.enemies.clear();sim.combat.projectiles.clear();sim.combat.skills.zones.clear();sim.events.clear()
			var enemy={"id":1,"pos":room+Vector2(1,0),"hp":99999,"max_hp":99999,"kind":"shade"}
			if action=="skill_v" and class_id!="warrior":enemy.pos=sim.combat.skills.target(p,3.5 if class_id=="ranger" else 4.0)
			sim.enemies[1]=enemy
			check(sim.action(1,action) and p.stamina<before,"learned skill accepted with cost "+class_id+action)
			check(not sim.action(1,action),"cooldown prevents duplicate "+class_id+action)
			check(sim.events.any(func(e):return e.type=="skill_fx"),"distinct effect emitted "+class_id+action)
			p.motion_time=p.motion_duration*.5
			var pose=Motion.pose(p)
			check(pose.offset.length()>0 or pose.weapon!=0 or pose.hand!=Vector2(16,-30),"visible motion "+class_id+action)
			for step in range(45):sim.combat.tick_projectiles(.03);sim.combat.skills.tick(.03)
			check(enemy.hp<99999,"skill damages target "+class_id+action)
			var rank_one_damage=99999-enemy.hp
			check(sim.combat.skills.zones.is_empty(),"all damage pulses finish "+class_id+action)
			if node.id=="frost_nova":check(enemy.get("slow_time",0)>2,"frost applies slow")
			if node.id=="thunder":check(enemy.get("stun_time",0)>.7,"thunder applies stun")
			if action=="skill_c":check(p.pos.distance_to(room)>2 and sim.map.walkable(p.pos),"movement skill respects walkable terrain "+class_id)
			p.skill_cooldowns.clear();p.pos=room;p.skill_ranks[node.id]=3;p[action+"_cd"]=0;p.stamina=p.max_stamina;enemy.hp=99999;enemy.pos=room+Vector2(1,0)
			if action=="skill_v" and class_id!="warrior":enemy.pos=sim.combat.skills.target(p,3.5 if class_id=="ranger" else 4.0)
			sim.combat.projectiles.clear();sim.action(1,action)
			for step in range(45):sim.combat.tick_projectiles(.03);sim.combat.skills.tick(.03)
			check(99999-enemy.hp>=rank_one_damage*2.1,"rank three damage exceeds twice rank one with stronger pulse/projectile profiles "+class_id+action)
			p.pos=sim.map.spawn;p[action+"_cd"]=0;p.stamina=p.max_stamina
			check(not sim.action(1,action),"camp blocks offensive skill "+class_id+action)
		var saved=sim.persistent(1);var restored=Simulation.new().add_player(1,"복원",saved)
		check(restored.skill_ranks==p.skill_ranks,"expanded ranks survive save model "+class_id)
		p.pos=sim.map.spawn;check(sim.action(1,"reset_skills") and Content.available_points(p)==39,"all expanded points refunded "+class_id)
	var legacy={"class_id":"warrior","skill_ranks":{"blade":1,"combo":3},"level":5}
	Content.migrate_skills(legacy)
	check(legacy.skill_ranks=={"blade":1,"heavy_training":3} and Content.available_points(legacy)==0,"legacy combo investment preserved as heavy training")
	var sim=Simulation.new();var p=sim.add_player(1,"효과 검증");p.pos=Vector2(sim.map.rooms[1]);p.aim=Vector2.RIGHT
	p.skill_ranks={"secondwind":3};p.stamina=0;sim.combat.tick_player(p,.5)
	check(is_equal_approx(p.stamina,12),"stamina regeneration passive changes actual rate")
	p.class_id="ranger";p.skill_ranks={"eagle":3};sim.combat.launch(p,"bow",Vector2.RIGHT,10,8,13,0)
	check(sim.combat.projectiles.back().speed==17.5,"projectile speed passive changes actual projectile")
	p.class_id="mage";p.skill_ranks={"wisdom":3};sim.action(1,"attack")
	check(is_equal_approx(p.attack_cd,.36),"haste changes actual cooldown")
	p.class_id="warrior";p.skill_ranks={"edge":3};p.attack_cd=0;sim.enemies.clear()
	var e={"id":1,"pos":p.pos+Vector2(2.2,0),"hp":999,"max_hp":999,"kind":"shade"};sim.enemies[1]=e
	sim.action(1,"attack");check(e.hp<999,"melee reach passive hits farther target")
	var slowed=Simulation.new();var hero=slowed.add_player(1,"상태 검증");hero.pos=Vector2(slowed.map.rooms[1]);var mob=slowed.enemies[1]
	mob.pos=hero.pos+Vector2(2,0);mob.home=mob.pos;mob.cooldown=99;mob.slow_time=2;var origin=mob.pos
	slowed.tick(.1);check(is_equal_approx(origin.distance_to(mob.pos),slowed.balance.enemies[mob.kind].speed*.45*.1),"slow reduces actual enemy movement to forty-five percent")
	mob.stun_time=1;mob.windup=.01;mob.attack_pos=hero.pos;var hp=hero.hp;origin=mob.pos
	slowed.tick(.1);check(mob.pos==origin and hero.hp==hp and mob.windup==0,"stun cancels windup and freezes enemy movement")
	print("SKILLS_V04_TESTS checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
