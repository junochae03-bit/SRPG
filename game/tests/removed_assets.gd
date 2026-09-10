extends SceneTree
const Content=preload("res://scripts/content.gd")
const Wardrobe=preload("res://scripts/wardrobe.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
	call_deferred("run")
func run():
	Content.initialize_jobs()
	for cls in Content.CLASSES:
		for removed in ["traveler","witch","starlight","celestial"]:
			check(removed not in Content.costume_options(cls),"removed from selection")
			var p={"schema_version":7,"class_id":cls,"costume":removed,"avatar":"auto","gold":777,"level":100,"owned_appearances":["costume:"+removed]}
			Content.migrate_appearance(p);Wardrobe.normalize(p,p.duplicate(true))
			check(p.costume=="none" and p.gold==777 and p.level==100,"normalize preserves progress")
			check(p.owned_appearances.is_empty(),"removed ownership filtered")
	for path in ["res://assets/animations.json","res://assets/costumes/animations.json","res://assets/koongya/forest_background.png"]:check(not FileAccess.file_exists(path),"source removed")
	var local=preload("res://scripts/local_session.gd").new();root.add_child(local);local.set_physics_process(false)
	local.save_directory=ProjectSettings.globalize_path("res://../runtime/removed-assets/"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(local.save_directory)
	var sim=preload("res://scripts/simulation.gd").new(452,"town");var player=sim.add_player(1,"외형 복원 검사")
	player.level=35;player.gold=777;player.materials={"ore":8};player.tutorial_done=true
	var equipment=preload("res://scripts/equipment_catalog.gd").make("sword",0,1,"migration-sword","none","warrior")
	player.inventory=[equipment];player.equipment.weapon=equipment.id;player.equipped=equipment.id
	var valid=Wardrobe.options("warrior").filter(func(id):return id.begins_with("costume:"))[0]
	for schema in [3,7]:
		for removed in ["traveler","witch","starlight","celestial"]:
			var saved=sim.persistent(1);saved.world_seed=452;saved.schema_version=schema;saved.costume=removed;saved.owned_appearances=[valid,"costume:"+removed]
			if schema==3:saved.stats={"strength":0,"dexterity":0,"intelligence":0,"vitality":0}
			var path=local.save_directory.path_join("input.json");var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(saved));f.close()
			var parsed=local.parse_save(path);check(parsed!=null,"actual old save parses")
			if parsed==null:continue
			var raw_control=saved.duplicate(true);raw_control.costume="none";raw_control.owned_appearances=[valid]
			var control_path=local.save_directory.path_join("control.json");f=FileAccess.open(control_path,FileAccess.WRITE);f.store_string(JSON.stringify(raw_control));f.close()
			var control=local.parse_save(control_path);check(control!=null,"independent control file parses")
			if control==null:continue
			check(local.enter_saved(control,"대조군"),"matching schema migration control restores")
			var expected=local.parse_save(local.save_path())
			check(local.enter_saved(parsed,"복원"),"simulation restores and saves")
			var restored=local.parse_save(local.save_path());check(restored!=null,"rewritten save parses")
			if restored==null:continue
			check(restored.costume=="none" and restored.owned_appearances==[valid],"only removed appearance cleared")
			for key in ["level","gold","xp","inventory","equipment","materials","skill_ranks","stats"]:check(restored[key]==expected[key],"same schema migration preserves "+key)
	for invalid in [["costume:traveler","costume:missing"],["costume:witch",valid,valid],["costume:celestial",42]]:
		var saved=sim.persistent(1);saved.world_seed=452;saved.owned_appearances=invalid
		var path=local.save_directory.path_join("invalid.json");var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(saved));file.close()
		check(local.parse_save(path)==null,"unrelated invalid ownership still rejected")
	local.disconnect_game();root.remove_child(local);local.free()
	print("REMOVED_ASSETS_TESTS checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
