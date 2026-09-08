extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const World=preload("res://scripts/world_catalog.gd")
const Attacks=preload("res://scripts/monster_attacks.gd")
const Loot=preload("res://scripts/loot_tables.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
	var tables=Loot.new();check(tables.tables.size()==World.ENEMIES.size(),"every monster has a separate table")
	var types={};var signatures={}
	for zone in World.DUNGEONS:
		var sim=Sim.new(700,zone);sim.add_player(1,"검증")
		check(sim.enemies.size()==23,"21 ordinary plus elite and boss "+zone)
		check(sim.enemies.values().filter(func(e):return e.elite).size()==1,"exactly one elite "+zone)
		for e in sim.enemies.values():types[e.kind]=true
		var elite=sim.enemies.values().filter(func(e):return e.elite)[0];var boss=sim.enemies.values().back()
		check(elite.max_hp<boss.max_hp and elite.max_hp>World.ENEMIES[World.DUNGEONS[zone].mobs[0]].health,"elite power between normal and boss "+zone)
		sim.kill(1,elite)
		check(sim.players[1].boss_kills==0 and sim.drops.values().any(func(d):return d.item.category=="weapon" and d.item.rarity>=1),"elite guaranteed gear without boss quest credit "+zone)
	check(types.size()==24,"all 24 monster types actually spawn")
	for kind in World.ENEMIES:
		check(tables.tables.has(kind) and not tables.tables[kind].is_empty(),"own drop table "+kind)
		var sim=Sim.new(900,"forest");sim.enemies.clear();var p=sim.add_player(1,"공격 검사");p.pos=Vector2(sim.map.rooms[1])+Vector2(1,0);p.max_hp=10000;p.hp=10000
		var e=sim.spawn_enemy(kind,p.pos-Vector2.RIGHT,5,kind in ["warden","golem","sentinel"])
		# Force each concrete row individually through the real kill-to-item path.
		for entry in tables.tables[kind]:
			var forced=entry.duplicate(true);forced.chance=1;sim.loot_tables.tables[kind]=[forced];sim.drops.clear();e.hp=e.max_hp;sim.kill(1,e)
			check(sim.drops.size()==1,"independent entry creates one drop "+kind+entry.key)
			var item=sim.drops.values()[0].item
			if entry.kind=="weapon":check(item.weapon_type in entry.get("weapons",[entry.get("weapon","sword")]),"monster weapon family preserved "+kind+entry.key)
			elif entry.kind in ["armor","accessory"]:check(item.slot==entry.slot,"monster armor slot preserved "+kind+entry.key)
			else:check(item.amount==entry.amount,"monster stack quantity preserved "+kind+entry.key)
		if e.boss:continue
		e.hp=e.max_hp;e.pos=p.pos-Vector2.RIGHT;e.attack_pos=p.pos;e.pattern=0;p.hp=10000;p.defense=0;sim.events.clear()
		var areas=Attacks.pattern(kind,e.pos,p.pos);signatures[JSON.stringify(areas)]=true
		check(not areas.is_empty(),"distinct attack pattern exists "+kind)
		sim.monster_attacks.begin(e,p.pos);sim.monster_attacks.release(e)
		for i in range(20):sim.monster_attacks.tick(.1)
		check(p.hp<10000 and sim.events.any(func(event):return event.type=="monster_attack"),"real pattern damages target and emits effect "+kind)
		p.hp=10000;p.invulnerable=5;p.enemy_slow_time=0;p.stamina=100;sim.monster_attacks.begin(e,p.pos);sim.monster_attacks.release(e)
		for i in range(20):sim.monster_attacks.tick(.1)
		check(p.hp==10000 and p.stamina==100 and p.enemy_slow_time==0,"dodge protects against damage and status "+kind)
		p.invulnerable=0;var area=areas[0].duplicate(true);area.from=Vector2(-20,-20);area.pos=p.pos;area.shape="circle";sim.monster_attacks.impact(area,e)
		check(p.hp==10000,"walls block monster attacks "+kind)
		p.pos=sim.map.spawn;area.from=p.pos;area.pos=p.pos;sim.monster_attacks.impact(area,e);check(p.hp==10000,"town safe zone blocks monster attacks "+kind)
	check(signatures.size()==21,"all 21 nonboss attack profiles differ")
	var sim=Sim.new();sim.enemies.clear();var p=sim.add_player(1,"취소 검사");p.pos=Vector2(sim.map.rooms[1]);p.hp=1000;p.max_hp=1000
	var e=sim.spawn_enemy("centurion",p.pos-Vector2.RIGHT,10);sim.monster_attacks.begin(e,p.pos);sim.monster_attacks.release(e);var hp=p.hp;e.hp=0
	sim.monster_attacks.tick(1);check(sim.monster_attacks.zones.is_empty() and p.hp==hp,"death cancels pending elite followup")
	e.hp=e.max_hp;sim.monster_attacks.begin(e,p.pos);sim.monster_attacks.release(e);hp=p.hp;e.stun_time=1;sim.monster_attacks.tick(.1)
	check(sim.monster_attacks.zones.is_empty() and p.hp==hp,"stun cancels pending elite followup")
	print("MONSTERS_V05_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
