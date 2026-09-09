extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Dungeon = preload("res://scripts/dungeon.gd")
var checks = 0
var failures: Array[String] = []

func _initialize():
	run.call_deferred()

func check(condition: bool, description: String):
	checks += 1
	if not condition:
		failures.append(description)
		push_error("FAIL: " + description)

func run():
	for seed_value in range(30):
		var map = Dungeon.new(seed_value)
		var first = Vector2i(map.spawn)
		var queue = [first]
		var visited = {first:true}
		var index = 0
		while index < queue.size():
			var cell = queue[index]
			index += 1
			for off in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next = cell+off
				if map.floor_cells.has(next) and not visited.has(next):
					visited[next]=true
					queue.append(next)
		check(visited.size()==map.floor_cells.size(), "all floor connected seed " + str(seed_value))
		check(Dungeon.new(seed_value).floor_cells==map.floor_cells,"deterministic seed " + str(seed_value))
	var sim = Simulation.new(20260908)
	var p = sim.add_player(101,"검증자")
	sim.add_player(202,"동료")
	var origin = p.pos
	sim.set_input(101,Vector2(100,100),Vector2.RIGHT)
	sim.tick(0.1)
	check(p.pos.distance_to(origin)<=0.381,"server normalizes extreme direction")
	sim.set_input(101,Vector2(NAN,0),Vector2.RIGHT)
	check(p.dir.is_finite(),"NaN input rejected")
	sim.tick(0.5)
	check(p.dir==Vector2.ZERO,"stale input expires")
	check(not sim.map.walkable(Vector2(-10,-10)),"outside map rejected")
	var edge = Vector2(sim.map.rooms[0])+Vector2(-3,0)
	check(sim.map.move(edge,Vector2(-1,0)).x==edge.x,"wall collision blocks movement")
	check(not sim.action(999,"attack"),"unregistered player rejected")
	check(not sim.action(101,"attack"),"town attack rejected")
	var enemy=sim.enemies[1]
	p.pos=Vector2(sim.map.rooms[1])+Vector2(2,0)
	var before=enemy.hp
	sim.action(101,"attack")
	check(enemy.hp==before,"out of range target takes no damage")
	p.attack_cd=0.0
	p.pos=enemy.pos+Vector2(0.5,0)
	p.aim=Vector2.LEFT
	sim.action(101,"attack")
	check(enemy.hp==before-18,"server damage applied")
	check(not sim.action(101,"attack"),"attack cooldown enforced")
	p.hp=60
	check(sim.action(101,"potion") and p.hp==120 and p.potions==4,"potion heals and is consumed")
	check(not sim.action(101,"potion"),"potion cooldown enforced")
	p.potion_cd=0.0
	p.potions=0
	p.hp=60
	check(not sim.action(101,"potion"),"empty potion cannot heal")
	var boss=sim.enemies[sim.enemies.size()]
	p.pos=boss.pos+Vector2(0.4,0)
	p.aim=Vector2.LEFT
	p.attack_cd=0.0
	p.kills=4
	boss.hp=1
	sim.action(101,"attack")
	check(boss.hp==0 and p.boss_kills==1,"boss can be killed through attack")
	check(p.quest_done and p.gold==190,"quest reward granted once")
	check(p.level==1 and p.xp==220,"slower experience curve retains progress below level threshold")
	var boss_gear=sim.drops.values().filter(func(d):return d.item.category=="weapon")
	check(boss_gear.size()==1,"boss guaranteed weapon drop")
	var drop=boss_gear[0]
	p.pos=drop.pos
	check(drop.item.rarity==2,"boss drop is rare")
	sim.players[202].pos=p.pos
	check(not sim.action(202,"interact"),"other player cannot steal owned drop")
	check(sim.action(101,"interact") and p.inventory.size()==1,"owner collects guaranteed weapon")
	while sim.action(101,"interact"):pass
	check(not sim.action(101,"interact") and p.inventory.size()==1,"drop cannot be collected twice")
	check(p.equipped=="" and not sim.action(101,"equip",drop.item.id),"high level drop waits in bag")
	p.level=drop.item.required_level;sim.recalculate(p);var naked=sim.damage_for(p)
	check(sim.action(101,"equip",drop.item.id) and sim.damage_for(p)>naked,"eligible loot increases attack")
	check(not sim.action(101,"equip","forged-id"),"forged item cannot equip")
	var visible=sim.snapshot(202)
	var packed=var_to_bytes(visible).compress(FileAccess.COMPRESSION_DEFLATE)
	var unpacked=bytes_to_var(packed.decompress_dynamic(1048576,FileAccess.COMPRESSION_DEFLATE))
	check(unpacked.players[202].id==202 and unpacked.enemies.size()==sim.enemies.size(),"network snapshot compression roundtrip")
	check(not visible.players[101].has("inventory"),"other inventory is private")
	check(not visible.players[101].has("gold"),"other gold is private")
	var item_id=p.inventory[0].id
	var bag_model=preload("res://scripts/inventory_model.gd")
	for i in range(bag_model.CAPACITY):
		if not bag_model.add_gear(p,{"id":"test-"+str(i),"name":"test","category":"accessory","slot":"accessory","rarity":0,"bonus":1}):break
	sim.drops["full"]={"item":{"id":"overflow","name":"overflow","rarity":0,"bonus":1},"pos":p.pos,"owner":101,"expires":99.0}
	check(not sim.action(101,"interact") and sim.drops.has("full"),"full bag preserves ground drop")
	p.hp=1
	p.gold=100
	enemy.hp=52
	enemy.pos=p.pos
	enemy.attack_pos=p.pos
	enemy.windup=0.01
	sim.tick(0.03)
	check(p.hp==p.max_hp and p.pos==sim.map.spawn and p.gold==90,"death revives with gold penalty")
	var saved=sim.persistent(101)
	var restored=sim.add_player(303,"복원",saved)
	check(restored.inventory[0].id==item_id and restored.gold==p.gold,"persistent state roundtrip")
	check(restored.pos==sim.map.spawn,"reconnect starts in safety")
	print("RULE_TESTS checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
