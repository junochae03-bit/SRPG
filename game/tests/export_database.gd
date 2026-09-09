extends SceneTree
func _initialize():run.call_deferred()
func run():
	var path=ProjectSettings.globalize_path("res://../runtime/database-live.json")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):path=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null:push_error("Cannot write database export: "+path);quit(1);return
	var data=preload("res://scripts/game_database.gd").snapshot()
	file.store_string(JSON.stringify(data,"\t",true,true)+"\n");file.close()
	print("DATABASE_EXPORT equipment=",data.equipment.size()," monsters=",data.monsters.size()," raids=",data.raids.size()," skills=",data.skills.size()," output=",path)
	quit(0)
