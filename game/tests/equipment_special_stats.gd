extends SceneTree
const Special=preload("res://scripts/equipment_special_stats.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Sim=preload("res://scripts/simulation.gd")
const Local=preload("res://scripts/local_session.gd")
const Content=preload("res://scripts/content.gd")
const Items=preload("res://scripts/consumables.gd")
const Balance=preload("res://scripts/job_balance.gd")
const Scaling=preload("res://scripts/skill_scaling.gd")
const Stagger=preload("res://scripts/boss_stagger.gd")
const Progression=preload("res://scripts/progression.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func close(a:float,b:float)->bool:return absf(a-b)<.0001
func fixture(job:String="warrior")->Dictionary:
	var sim=Sim.new(81223,"forest",1);sim.enemies.clear()
	var p=sim.add_player(1,"세부 옵션");p.level=100;p.class_id=job;p.stats={};p.skill_ranks={};p.skill_loadout={};p.inventory=[];p.equipped="";p.equipment={}
	Inventory.initialize(p);sim.recalculate(p);sim.combat.jobs.reset(p)
	p.pos=Vector2(sim.map.rooms[1]);p.aim=Vector2.RIGHT;p.stamina=1000;p.max_stamina=1000
	return {"sim":sim,"p":p}
func all_points(p:Dictionary):
	p.equipment_special_points={}
	for key in Special.active_pool():p.equipment_special_points[key]=12
func node_for(job:String,mode:String)->Dictionary:
	for node in Content.SKILLS[job]:
		if node.effect=="active" and Stagger.skill_profile(node,1).mode==mode:return node
	check(false,"missing skill "+job+" "+mode);return {}
func advance(f:Dictionary,seconds:float):
	for i in range(ceili(seconds/.02)):
		f.sim.clock+=.02;f.sim.combat.jobs.tick(f.p,.02)
func cast(f:Dictionary,node:Dictionary)->bool:
	f.p.skill_ranks[node.id]=1;f.p.skill_loadout.skill_q=node.id;f.p.skill_cooldowns={}
	return f.sim.action(1,"skill_q")
func generation_and_save():
	check(Special.active_pool().size()==8,"only eight implemented stats roll")
	for rarity in range(5):
		for index in range(16):
			var id="roll-%d-%d"%[rarity,index]
			var item=Equipment.make("head",0,rarity,id)
			check(Special.valid_item(item) and item.special_stats.size()==Special.LINES[rarity],"rarity bounds and unique rows "+id)
			check(item==Equipment.make("head",0,rarity,id),"deterministic retry "+id)
			var original=item.special_stats.duplicate(true);item.upgrade=8;Equipment.normalize(item,{"class_id":"warrior"})
			check(not Special.generate(item,id) and item.special_stats==original,"upgrade and regenerate cannot reroll "+id)
	var f=fixture();var p=f.p;var item=Equipment.make("head",0,4,"equipped-option")
	item.special_stats=[{"id":"medicine","points":3},{"id":"breathing","points":3}]
	check(Inventory.add_gear(p,item) and Inventory.equip(p,item.id),"new equipment enters real inventory")
	f.sim.recalculate(p)
	check(not Equipment.active(item) and Special.points(p,"medicine")==3,"special lines activate at upgrade zero")
	check(Equipment.option_text(item).contains("약학 +3") and Equipment.option_text(item).contains("착용 즉시"),"tooltip separates immediate options from locked affix")
	var saved=f.sim.persistent(1).duplicate(true);saved.world_seed=81223
	check(not saved.has("equipment_special_points"),"derived cache is not a save authority")
	var local=Local.new();var parsed=local.validate_save(JSON.parse_string(JSON.stringify(saved)))
	check(parsed!=null and parsed.inventory[0].special_stats==item.special_stats,"save accepts and preserves generated rows")
	check(parsed!=null and parsed.inventory[0].special_stats_version is int and parsed.inventory[0].special_stats.all(func(row):return row.points is int),"JSON option numbers restore canonical integer types")
	if parsed!=null:
		var restored=Sim.new(81223,"town");var loaded=restored.add_player(1,"",parsed)
		check(Special.points(loaded,"medicine")==3,"load rebuilds equipped effect cache")
		check(restored.snapshot(1).players[1].equipment_special_points==loaded.equipment_special_points,"network snapshot carries authoritative cache")
	for change in ["future","unknown","duplicate","fraction","overflow","missing_version","extra_row","preview"]:
		var bad=saved.duplicate(true);var gear=bad.inventory[0]
		match change:
			"future":gear.special_stats_version=2
			"unknown":gear.special_stats[0].id="crafting_luck"
			"duplicate":gear.special_stats[1].id=gear.special_stats[0].id
			"fraction":gear.special_stats[0].points=2.5
			"overflow":gear.special_stats[0].points=100
			"missing_version":gear.erase("special_stats_version")
			"extra_row":gear.special_stats.append({"id":"composure","points":2})
			"preview":Special.preview(gear)
		check(local.validate_save(bad)==null,"save rejects malformed option "+change)
	var legacy=saved.duplicate(true);legacy.inventory[0].erase("special_stats");legacy.inventory[0].erase("special_stats_version")
	parsed=local.validate_save(legacy)
	check(parsed!=null and not parsed.inventory[0].has("special_stats"),"legacy remains unrolled")
	var preview=Equipment.make("head",0,4,"@craft-preview")
	check(not Special.valid_item(preview) and Special.valid_item(preview,true) and not preview.has("special_stats"),"preview exposes unresolved line count only")
	check(Special.option_text(preview).contains("2줄") and not Special.generate(preview,preview.id),"preview cannot roll before final ID")
	preview.id="crafted-final"
	check(Special.generate(preview,preview.id) and Special.valid_item(preview),"final host ID resolves preview once")
	var capped=[]
	for index in range(6):
		var copy=item.duplicate(true);copy.id="cap-"+str(index);capped.append(copy)
	check(Special.totals(capped).medicine==12 and Special.totals([item,item]).medicine==3,"aggregate cap and duplicate ID defense")
	p.equipment.head="";f.sim.recalculate(p);check(Special.points(p,"medicine")==0,"unequip removes effects")
	p.equipment.head=item.id;p.class_id="mage";f.sim.recalculate(p);check(Special.points(p,"medicine")==0,"wrong family has no effects")
	p.class_id="warrior";p.level=1;item.required_level=30;f.sim.recalculate(p);check(Special.points(p,"medicine")==0,"unmet level has no effects")
	local.free()
func actual_consumers():
	var f=fixture();var p=f.p;var sim=f.sim;var plain=Items.health_recovery(p);all_points(p)
	check(Items.health_recovery(p)==roundi(plain*1.036),"medicine shares actual potion calculation")
	p.hp=1;p.potions=2;p.potion_cd=0
	check(Items.use(sim,p,"potion") and p.hp==1+roundi(plain*1.036),"actual potion applies medicine exactly once")
	p.potion_cd=0;p.consumables.mana_potion=1;p.stamina=0
	check(Items.use(sim,p,"mana_potion") and p.stamina==60,"medicine does not improve stamina potion")
	p.stamina=24.1
	check(sim.action(1,"dodge") and close(p.stamina,0),"base dodge uses discounted affordability and debit")
	p.dodge_time=0;p.dodge_cd=0;p.invulnerable=0;p.stamina=19.28
	check(sim.action(1,"heavy_begin"),"base heavy accepts discounted cost")
	p.charge_time=.9;check(sim.action(1,"heavy") and close(p.stamina,0),"base heavy discounted debit")
	p.attack_cd=0;p.stamina=100;p.sprint=true;p.dir=Vector2.RIGHT
	sim.combat.tick_player(p,.1);check(close(p.stamina,100-23*.964*.1),"sprint drain uses breathing")
	p.sprint=false;p.dir=Vector2.ZERO;p.invulnerable=0;p.hp=p.max_hp;p.stamina=100;p.enemy_slow_time=0;p.stats.fortitude=60
	var e=sim.spawn_enemy("frost_slime",p.pos+Vector2.RIGHT,0,false);e.damage=10
	var zone=sim.monster_attacks.area("circle",e.pos,p.pos,2.);zone.slow=3.;zone.drain=20.
	sim.monster_attacks.damage(e,p,zone)
	check(close(p.enemy_slow_time,3*.952),"actual incoming slow duration")
	check(close(p.hurt_time,.16*.9*.964),"actual normal hurt combines fortitude once")
	check(p.stamina==80,"breathing never reduces hostile stamina drain")
	check(close(Special.hurt_duration(p,1,.1),.7),"normal hurt total reduction cap")
	for job in ["rogue","breaker"]:
		f=fixture(job);p=f.p;all_points(p);p.stamina=9.64
		check(f.sim.action(1,"dodge") and close(p.stamina,0),"job dodge discounted "+job)
		p.dodge_time=0;p.invulnerable=0;p.stamina=19.28
		check(f.sim.action(1,"heavy_begin"),"job heavy discounted start "+job)
		p.stamina=0
		check(not f.sim.action(1,"heavy") and p.stamina==0,"drained charge cannot overspend "+job)
	f=fixture("healer");p=f.p;all_points(p)
	var ally=f.sim.add_player(2,"회복 대상");ally.pos=p.pos;ally.stats.vitality=60;f.sim.recalculate(ally);ally.hp=1
	var node=node_for("healer","heal");var profile=Balance.profile(p,node,1,f.sim.damage_for(p),p.max_hp)
	var expected=roundi(profile.heal*float(ally.max_hp)/p.max_hp*Progression.received_healing(ally))
	check(cast(f,node),"actual heal cast accepted");advance(f,2.)
	check(ally.hp==1+expected,"first aid caster and recipient vitality apply exactly once")
	f=fixture("tank");p=f.p;all_points(p);node=node_for("tank","shield")
	profile=Balance.profile(p,node,1,f.sim.damage_for(p),p.max_hp)
	check(cast(f,node),"actual shield cast accepted");advance(f,1.)
	check(close(p.job_state.shield,profile.shield),"actual absorption shield equals advertised value")
	for job in ["warrior","healer"]:
		f=fixture(job);p=f.p;node=node_for(job,"wave" if job=="warrior" else "heal")
		var before=Scaling.profile(node,1,{"player":p}) if job=="warrior" else Balance.profile(p,node,1,100,1000)
		all_points(p)
		var after=Scaling.profile(node,1,{"player":p}) if job=="warrior" else Balance.profile(p,node,1,100,1000)
		check(close(after.cost,before.cost*.964) and close(after.cooldown,before.cooldown*.982),"base/job preview cost and cooldown "+job)
		var stamina=p.stamina
		check(cast(f,node) and close(p.skill_cooldowns[node.id],after.cooldown) and close(p.stamina,stamina-after.cost),"base/job actual cost and cooldown "+job)
	var sheet={};all_points(sheet)
	var values={"cooldown":6.01,"cost":20.,"heal":10.,"barrier":.5,"shield":20.,"regen":3.}
	var capped=Special.profile(sheet,{"cooldown":10.},values.duplicate(true))
	check(close(capped.cooldown,6.) and capped.barrier==.5,"normal CDR cap and percent mitigation exclusion")
	check(close(Special.profile(sheet,{"cooldown":10.},{"cooldown":4.8},8.).cooldown,4.8),"CDR cap respects the same-rank passive baseline")
	check(Special.profile(sheet,{"ultimate":true},values.duplicate(true))==values,"ultimate profile is unchanged")
func stagger_budget():
	var f=fixture();var p=f.p;var sim=f.sim;var damage=sim.damage_for(p);all_points(p)
	var e=sim.spawn_enemy("warden",p.pos+Vector2.RIGHT,100,true);e.hp=100000;e.max_hp=e.hp;e.raid=false;e.stagger.max_value=10000.
	check(sim.damage_for(p)==damage,"special support stats do not change direct attack damage")
	check(sim.action(1,"attack") and close(e.stagger.value,7*1.03),"actual basic attack stagger")
	var node=node_for("warrior","spin");var token=Stagger.token(node,1,p,sim.clock,2);var advertised=Stagger.skill_profile(node,1,p).value
	var initial=e.stagger.value;p.equipment_special_points={}
	for i in range(4):Stagger.apply(sim,p,e,Stagger.context(token))
	check(close(e.stagger.value-initial,advertised),"multi-hit budget snapshots equipment once and cannot overdraw")
	var ultimate=node.duplicate(true);ultimate.ultimate=true;var baseline=Stagger.skill_profile(ultimate,1,p).value;all_points(p)
	check(Stagger.skill_profile(ultimate,1,p).value==baseline,"ultimate stagger excluded")
	check(close(Stagger.basic_token(true,1,0,p).value,20*1.03),"heavy stagger exact value")
func run():
	Content.initialize_jobs();generation_and_save();actual_consumers();stagger_budget()
	check(Progression.configuration().save_schema_version==8 and Progression.configuration().equipment_special_stats.active_roll_pool.size()==8,"DB metadata matches runtime")
	print("EQUIPMENT_SPECIAL_STATS_TESTS checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
