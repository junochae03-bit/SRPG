extends SceneTree
const DB=preload("res://scripts/game_database.gd")
const Content=preload("res://scripts/content.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
const World=preload("res://scripts/world_catalog.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var db=DB.snapshot()
	check(db.equipment.size()==2500,"all gear grade combinations")
	check(db.monsters.size()==24 and db.raids.size()==10 and db.floors.size()==100,"monster and floor catalogs")
	check(db.skills.size()==610 and db.classes.size()==20,"every original and advanced class skill")
	var ids={}
	for e in db.equipment:
		check(not ids.has(e.id),"unique gear ID "+e.id);ids[e.id]=true
		var actual=Equipment.make("sword" if e.slot=="weapon" else e.slot,e.tier,e.rarity,e.id,"focus",e.job_lock if e.slot=="weapon" else e.family)
		check(e.bonus==actual.bonus and e.name==actual.name and e.required_level==actual.required_level,"actual equipment values "+e.id)
		check(not e.asset.is_empty() and DB.asset_texture(e)!=null,"real equipment art "+e.id)
	for a in db.appearances:
		var actual=Abyss.enemy_stats(a.monster_id,a.floor_id,a.role=="raid",a.role in ["guardian","raid"])
		check(a.health==actual.health and a.damage==actual.damage and a.xp==actual.xp,"live floor stats "+a.id)
	for floor_number in [1,10,51,100]:
		var sim=preload("res://scripts/simulation.gd").new(321,Abyss.config(floor_number).terrain,floor_number)
		for enemy in sim.enemies.values():
			var role="raid" if enemy.get("raid",false) else "guardian" if enemy.get("guardian",false) else "elite" if enemy.elite else "normal"
			var row=db.appearances.filter(func(a):return a.floor_id==floor_number and a.monster_id==enemy.kind and a.role==role)
			check(row.size()==1 and row[0].level==enemy.level and row[0].health==enemy.hp and row[0].damage==enemy.damage,"actual spawned enemy correspondence")
			if enemy.get("raid",false):
				var record=DB.detail("monsters","raid:%03d"%floor_number)
				check(record.stagger.max_value==enemy.stagger.max_value and record.stagger.check_max==enemy.stagger.check_max,"real raid stagger capacity")
	for raid in db.raids:
		var total=0.
		for d in db.raid_drops:
			if d.raid_id==raid.id:total+=d.chance
		check(is_equal_approx(total,1.),"conditional raid grades sum 1 "+raid.id)
	var drops=preload("res://scripts/loot_tables.gd").new()
	for d in db.drops:
		var entries=drops.tables[d.monster_id].filter(func(e):return e.key==d.key)
		check(entries.size()==1 and entries[0].chance==d.chance and d.rarity<=2,"independent real drop "+d.id)
	var rank_total=0
	for s in db.skills:
		rank_total+=s.max_rank
		for rank in s.ranks:
			check(rank.rank>=1 and rank.rank<=s.max_rank and rank.metrics is Array,"valid skill rank "+s.id)
			var stagger=preload("res://scripts/boss_stagger.gd").skill_profile(s.node,rank.rank,{})
			check(is_equal_approx(stagger.value,rank.stagger.value),"runtime stagger reference "+s.id)
		for parent in s.parents:check(DB.detail("skills",parent).class_id==s.class_id,"same class parent "+s.id)
	check(db.skill_ranks.size()==rank_total,"all rank rows")
	check(DB.query("equipment",{"class_id":"reaper","slot":"weapon","rarity":0}).total==10,"exclusive reaper weapon filter")
	check(DB.query("equipment",{"class_id":"reaper","slot":"chest","rarity":0}).total==10,"family armor filter")
	check(DB.query("skills",{"class_id":"warrior","effect":"passive"}).items.all(func(s):return s.effect not in ["active","upgrade"]),"legacy passive effect filter")
	check(DB.query("equipment",{"q":"없는 이름 qwerty"}).total==0,"search empty state")
	var page=DB.query("skills",{},99999,8);check(page.page==page.pages-1 and page.items.size()>0,"page clamped to valid last")
	check(DB.query("skills",{},0,0).items.size()==1,"invalid page size bounded")
	check(DB.detail("equipment","missing").is_empty(),"missing detail safe")
	var raid=DB.query("drops",{"monster_id":"raid:100"},0,100)
	check(raid.items.filter(func(d):return d.has("raid_id")).all(func(d):return d.raid_id=="raid:100"),"raid sources never mix same art other bosses")
	check(raid.items.any(func(d):return d.roll_mode=="independent_per_entry") and raid.items.any(func(d):return d.roll_mode=="guaranteed_extra_conditional_grade"),"raid base and extra both discoverable")
	check(DB.query("drops",{"monster_id":"sentinel"},0,100).items.all(func(d):return d.roll_mode=="independent_per_entry"),"base monster entries only")
	var epic=DB.detail("equipment","eq:reaper:weapon:09:3")
	var sources=DB.sources(epic)
	check(sources.size()==1 and sources[0].floor==100,"epic final tier source")
	check(is_equal_approx(sources[0].joint_slot_chance,.26/7.) and sources[0].chance==.26,"grade and slot chance distinguished")
	check(DB.query("drops",{"equipment_id":epic.id,"slot":"weapon","rarity":3}).total==1,"equipment source query")
	for source in DB.sources(DB.detail("equipment","eq:thief:weapon:03:1")):
		check(source.source_floors.all(func(f):return f>=31 and f<=40),"equipment source tier constraint")
	print("DATABASE_V03_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
