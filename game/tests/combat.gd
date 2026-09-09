extends SceneTree
const Simulation=preload("res://scripts/simulation.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Content=preload("res://scripts/content.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,name:String):
	checks+=1
	if not ok:failures.append(name);push_error(name)
func equip(sim,p,type):
	var id="test-"+type
	if Inventory.find_item(p,id).is_empty():Inventory.add_gear(p,{"id":id,"name":type,"weapon_type":type,"category":"weapon","slot":"weapon","bonus":0,"rarity":0})
	sim.action(p.id,"equip",id);p.attack_cd=0;p.charge_time=-1
func run():
	var sim=Simulation.new();var p=sim.add_player(1,"전투 검증")
	var room=Vector2(sim.map.rooms[1]);p.pos=room;p.aim=Vector2.RIGHT
	sim.enemies.clear()
	var enemy={"id":1,"pos":room+Vector2(1,0),"hp":9999,"max_hp":9999,"kind":"shade","home":room+Vector2(1,0),"cooldown":99.0,"windup":0.0,"attack_pos":room,"respawn":0}
	sim.enemies[1]=enemy
	equip(sim,p,"sword")
	var damage=[]
	for i in range(3):
		p.attack_cd=0;var before=enemy.hp
		check(sim.action(1,"attack"),"basic attack accepted "+str(i))
		damage.append(before-enemy.hp)
	check(damage==[18,18,18] and not p.has("combo"),"repeated attacks have equal damage and no combo state")
	check(not sim.action(1,"attack"),"basic attack cooldown enforced")
	sim.tick(2);check(not p.has("combo_time"),"removed combo has no lingering timer")
	p.attack_cd=0;p.stamina=100
	enemy.pos=p.pos+Vector2(1,0);enemy.home=enemy.pos
	check(sim.action(1,"heavy_begin"),"charge begins")
	check(not sim.action(1,"attack"),"basic attack blocked while charging")
	sim.tick(0.9);var before=enemy.hp
	check(sim.action(1,"heavy") and before-enemy.hp==54 and p.stamina==80,"full sword heavy triples damage and consumes stamina")
	check(not sim.action(1,"heavy"),"release cannot repeat without charge")
	p.attack_cd=0;p.stamina=19
	check(not sim.action(1,"heavy_begin"),"insufficient stamina cannot charge")
	equip(sim,p,"axe");enemy.pos=p.pos+Vector2(0,2);before=enemy.hp
	check(sim.action(1,"attack") and enemy.hp==before-25 and p.attack_cd>0.7,"axe wider reach and slower stronger strike")
	equip(sim,p,"bow");enemy.pos=p.pos+Vector2(2,0);enemy.home=enemy.pos;before=enemy.hp
	check(sim.action(1,"attack") and enemy.hp==before and sim.combat.projectiles.size()==1,"bow launches traveling projectile")
	sim.tick(0.18);check(enemy.hp==before-17,"arrow hits after travel")
	equip(sim,p,"staff");enemy.pos=p.pos+Vector2(1,0);before=enemy.hp
	var second=enemy.duplicate(true);second.id=2;second.pos=enemy.pos+Vector2(0,0.8);second.home=second.pos;sim.enemies[2]=second
	var second_before=second.hp
	sim.action(1,"attack");sim.tick(0.14)
	check(enemy.hp<before and second.hp<second_before,"staff projectile splashes nearby target")
	sim.combat.projectiles.clear()
	sim.combat.launch(p,"bow",Vector2.LEFT,99,10,13,0)
	for i in range(30):sim.tick(0.03)
	check(sim.combat.projectiles.is_empty(),"projectile stops at terrain boundary")
	p.pos=room;p.dir=Vector2.RIGHT;p.stamina=100
	sim.set_input(1,Vector2.RIGHT,Vector2.RIGHT,true);var origin=p.pos
	sim.tick(0.1)
	check(p.pos.distance_to(origin)>0.6 and p.stamina<100,"sprint increases speed and drains stamina")
	p.pos=room;p.stamina=100;p.dir=Vector2.RIGHT
	check(sim.action(1,"dodge") and p.stamina==75,"dodge consumes 25 stamina")
	check(not sim.action(1,"dodge"),"dodge cooldown enforced")
	enemy.pos=room;enemy.attack_pos=room;enemy.windup=0.01;before=p.hp
	sim.tick(0.03);check(p.hp==before and p.pos.distance_to(room)>0.3,"dodge moves and avoids telegraphed damage")
	p.invulnerable=0;p.dodge_time=0;p.pos=room;p.dir=Vector2.ZERO;p.defense=30
	enemy.pos=room;enemy.attack_pos=room;enemy.windup=0.01;before=p.hp
	sim.tick(0.03);check(p.hp==before-preload("res://scripts/progression.gd").received(p,sim.balance.enemies.shade.damage),"armor defense reduces incoming damage")
	p.pos=sim.map.spawn;p.level=10;p.stamina=100;p.dodge_time=0
	for type in ["warrior","ranger","mage"]:
		check(sim.action(1,"class",type),"class change at camp "+type)
		var nodes=Content.SKILLS[type]
		check(not sim.action(1,"invest",nodes[4].id),"final node requires parents "+type)
		var power=sim.damage_for(p)
		check(sim.action(1,"invest",nodes[0].id) and sim.damage_for(p)==power+2,"root investment changes damage "+type)
		for i in range(2):sim.action(1,"invest",nodes[0].id)
		check(not sim.action(1,"invest",nodes[0].id),"rank caps at three "+type)
		p.pos=room;p.nova_cd=0;p.stamina=100;p.aim=Vector2.RIGHT
		before=enemy.hp;enemy.pos=room+Vector2(1,0);enemy.home=enemy.pos
		check(not sim.action(1,"skill_q"),"unassigned sixth-slot system has no free signature "+type)
		check(not sim.action(1,"reset_skills"),"field respec rejected "+type)
		p.pos=sim.map.spawn
		check(sim.action(1,"reset_skills") and Content.available_points(p)==9,"camp reset refunds points "+type)
	print("COMBAT_TESTS checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
