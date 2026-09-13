extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Visual=preload("res://scripts/projectile_visual_v071.gd")
const Stagger=preload("res://scripts/boss_stagger.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize():run.call_deferred()
func fixture()->Dictionary:
	var sim=Sim.new(20260910,"forest",1);sim.enemies.clear();sim.events.clear()
	for x in range(18,40):
		for y in range(18,35):sim.map.floor_cells[Vector2i(x,y)]=true
	var p=sim.add_player(1,"Projectile",{"schema_version":7,"class_id":"runesword","level":30,"tutorial_done":true})
	p.pos=Vector2(24,24);p.aim=Vector2.RIGHT
	var e=sim.spawn_enemy("shade",p.pos+Vector2(3,0),1);e.hp=10000;e.max_hp=e.hp
	return {"sim":sim,"p":p,"e":e}
func events(f:Dictionary,kind:String)->Array:
	return f.sim.events.filter(func(e):return e.type==kind)
func launch(f:Dictionary,amount:int=37)->Dictionary:
	f.sim.combat.launch(f.p,"bow",Vector2.RIGHT,amount,10,14,0)
	return f.sim.combat.projectiles.back()
func fly(f:Dictionary):
	for i in range(30):f.sim.combat.tick_projectiles(.04)
func run():
	for key in Visual.data().families:
		var f=fixture();var shot=launch(f);shot.visual_family=key
		# Metadata is intentionally set after launch, as real skill casts do.
		shot.skill_mode="burst";shot.vfx="fire"
		var speed=shot.speed;var range_left=shot.remaining
		f.sim.combat.tick_projectiles(.02)
		check(events(f,"projectile_launch").size()==1,"one launch "+key)
		var event=events(f,"projectile_launch")[0]
		check(event.pos==shot.visual_start and event.visual_offset==shot.visual_origin,"final launch socket "+key)
		check(event.visual_family==key and event.skill_mode=="burst" and event.vfx=="fire","late metadata preserved "+key)
		check(shot.speed==speed and is_equal_approx(shot.remaining,range_left-speed*.02),"speed and travel unchanged "+key)
		var wire=bytes_to_var(var_to_bytes(f.sim.snapshot(1)))
		check(wire.projectiles[0].visual_family==key and wire.projectiles[0].class_id==f.p.class_id,"snapshot round trip metadata "+key)
		fly(f)
		check(events(f,"projectile_launch").size()==1 and events(f,"projectile_impact").size()==1,"one accepted impact "+key)
		check(f.e.hp==9963 and events(f,"damage").size()==1,"exact damage 37 unchanged "+key)
		check(events(f,"projectile_impact")[0].pos==f.e.pos,"impact at accepted enemy position "+key)
	for mode in ["miss","wall","zero_damage","dead"]:
		var f=fixture();var shot=launch(f,0 if mode=="zero_damage" else 37)
		if mode=="miss":f.e.pos+=Vector2(0,4)
		if mode=="dead":f.e.hp=0
		if mode=="wall":
			for y in range(18,35):f.sim.map.floor_cells.erase(Vector2i(25,y))
		var hp=f.e.hp;fly(f)
		check(events(f,"projectile_impact").is_empty() and f.e.hp==hp,"no rejected hit decoration "+mode)
		check(shot.hit.is_empty() and f.sim.combat.projectiles.is_empty(),"no rejected ledger and normal expiry "+mode)
	var f=fixture();f.e.pos=f.p.pos+Vector2(2,0)
	var second=f.sim.spawn_enemy("shade",f.p.pos+Vector2(5,0),1);second.hp=10000
	var third=f.sim.spawn_enemy("shade",f.p.pos+Vector2(8,0),1);third.hp=10000
	var shot=launch(f);shot.pierce=1;fly(f)
	check(shot.hit==[f.e.id,second.id],"pierce budget consumes two accepted targets")
	check(events(f,"projectile_impact").size()==2 and events(f,"damage").size()==2,"pierce emits once per accepted target")
	check(f.e.hp==9963 and second.hp==9963 and third.hp==10000,"pierce damage and untouched third target")
	f=fixture();f.sim.enemies.clear();f.e=f.sim.spawn_enemy("warden",f.p.pos+Vector2(3,0),1,true);f.e.hp=10000;f.e.max_hp=10000
	f.sim.combat.stagger_context=Stagger.context(Stagger.basic_token(false,0,f.sim.clock))
	shot=launch(f);f.sim.clock=1.;Stagger.reset(f.sim,f.e);fly(f)
	check(events(f,"projectile_impact").is_empty() and shot.hit.is_empty() and f.e.hp==10000,"reset boss rejection emits no hit")
	print("PROJECTILE_COMBAT_V071 checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
