extends SceneTree
func _initialize():run.call_deferred()
func run():
	var path=ProjectSettings.globalize_path("res://../runtime/database-live.json")
	var cache_path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):path=arg.trim_prefix("--output=")
		if arg.begins_with("--cache-output="):cache_path=arg.trim_prefix("--cache-output=")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null:push_error("Cannot write database export: "+path);quit(1);return
	var database=preload("res://scripts/game_database.gd")
	database.reset_cache()
	var data=database.snapshot(false,false)
	if not cache_path.is_empty():
		var prepared=FileAccess.open(cache_path,FileAccess.WRITE)
		if prepared==null:push_error("Cannot write codex cache");quit(1);return
		prepared.store_buffer(database.prepared_bytes(data));prepared.close()
	data=database.snapshot(true,false)
	file.store_string(JSON.stringify(data,"\t",true,true)+"\n");file.close()
	print("DATABASE_EXPORT equipment=",data.equipment.size()," monsters=",data.monsters.size()," raids=",data.raids.size()," skills=",data.skills.size()," output=",path)
	quit(0)
