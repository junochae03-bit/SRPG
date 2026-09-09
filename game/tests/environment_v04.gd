extends SceneTree
const Env=preload("res://scripts/environment_art.gd")
const Art=preload("res://scripts/world_art.gd")
const Forest=preload("res://scripts/forest_environment.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
var checks=0
var failures=[]
func check(value:bool,label:String):
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
	Env.initialize();Art.dungeon_initialize()
	check(Env.catalog.objects.size()==108,"all completed environment props")
	check(Art.dungeon_catalog.objects.size()==48,"all completed monster key poses")
	var used={};var expected_environment={};var species={};var boss_species={};var host=Node2D.new();root.add_child(host);var renderer=Forest.new(host)
	for id in Env.catalog.objects:
		var data=Env.frame(id);check(data.texture!=null and data.foot.y<=data.height,"valid environment texture and foot "+id)
	for f in range(1,101):
		var config=Abyss.config(f);var map=Dungeon.new(20260909+f,config.terrain,f);renderer.rebuild(map)
		var allowed=Env.ids(config.terrain,f)
		for id in allowed:expected_environment[id]=true;check(Env.catalog.objects.has(id),"curated art stays registered")
		check(not renderer.props.is_empty(),"scenery populated B%d"%f)
		for prop in renderer.props:
			used[prop.art_id]=true
			check(prop.art_id in allowed,"only biome-selected illustrations are placed B%d"%f)
			check(renderer.clear_for_prop(prop.pos) and not map.walkable(prop.pos),"walkable and entrance clear B%d"%f)
		for kind in config.mobs+[config.elite]:
			var idle=Art.variant_frame(kind,f);var attack=Art.variant_frame(kind,f,false,true)
			if idle.is_empty():continue
			species[idle.species]=true
			check(idle.height==attack.height and idle.texture!=attack.texture,"one body scale across two poses")
			check(idle.art_id.ends_with("_idle") and attack.art_id.ends_with("_attack"),"attack pose follows attack state")
		if f%10==0:
			var boss=Art.variant_frame(config.boss,f,true)
			if not boss.is_empty():boss_species[boss.species]=true
	for zone in ["town","forest"]:
		var map=Dungeon.new(20260909,zone);renderer.rebuild(map)
		for id in Env.ids(zone,0):expected_environment[id]=true
		for prop in renderer.props:used[prop.art_id]=true;check(renderer.clear_for_prop(prop.pos),zone+" entrance safe")
	check(used.size()==expected_environment.size() and used.keys().all(func(id):return expected_environment.has(id)),"live maps use exactly curated biome selections, not all available art")
	check(used.size()<108 and Env.catalog.objects.size()==108,"unused furniture remains registered without forced placement")
	for id in Env.ids("forest",1):check(id in ["forest_oak_tree","forest_birch_tree","forest_mossy_boulders","forest_flower_shrub","forest_hollow_log"],"forest uses reviewed natural silhouettes")
	for id in Env.ids("snow",51):check(id in ["snow_snow_fir","snow_frost_birch","snow_ice_boulders","snow_snow_shrub","snow_stone_cairn"],"glacier uses reviewed natural silhouettes")
	for id in used:check(not id.begins_with("ice_") and not id.begins_with("bamboo_") and not id.begins_with("desert_") and not id.begins_with("sky_") and not id.begins_with("graveyard_") and not id.begins_with("dragon_"),"unrelated indoor and ceremonial art is not scattered "+id)
	check(species.size()==18,"every new common monster appearance reachable")
	check(boss_species.size()==6,"every new raid appearance reachable")
	var db=preload("res://scripts/game_database.gd").snapshot()
	check(db.floors.size()==100 and db.monsters.size()==24,"gameplay IDs and floor count preserved")
	for row in db.appearances:
		var expected=Art.variant_frame(row.monster_id,row.floor_id,row.role=="raid")
		if not expected.is_empty():check(row.asset.art_id==expected.art_id,"database and runtime share appearance")
	var sim=preload("res://scripts/simulation.gd").new(20260909,"cave",41)
	var elite=sim.enemies.values().filter(func(e):return e.kind=="orc_champion")[0]
	check(elite.name=="흑요각 코뿔소","spawn uses actual appearance name while keeping combat kind")
	var records=preload("res://scripts/game_database.gd").query("monsters",{"floor":41,"q":"코뿔소"}).items
	check(not records.is_empty(),"floor search finds appearance name")
	for record in records:
		check(record.asset.species=="lava_obsidian_rhino" and record.base_name!="", "floor card has actual art and original identity")
	var base=preload("res://scripts/game_database.gd").detail("monsters","orc_champion")
	check(base.name!="흑요각 코뿔소","floor presentation never mutates canonical record")
	host.queue_free();await process_frame
	print("ENVIRONMENT_V04_TESTS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
