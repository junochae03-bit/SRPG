extends SceneTree
const Dungeon=preload("res://scripts/dungeon.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func run():
	var folder="D:/SSRPG/publish/SRPG-v04/runtime/entry-visual-"+str(Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(folder)
	var game=load("res://main.tscn").instantiate();game.options.mute=true;game.options["save-dir"]=folder;root.add_child(game)
	game.set_physics_process(false);game.session.set_physics_process(false)
	game.session.start_game("모험가",1);var local=game.session;var p=local.sim.players[1]
	p.tutorial_done=true;p.level=100;p.highest_floor=100;local.world_seed=20316478
	check(local.travel("town") and local.enter_floor(1),"actual session town -> dungeon transition")
	local.sim.enemies.clear();local.refresh();p=local.sim.players[1]
	check(not local.paused and not game.town_panel.visible,"entrance closes portal and resumes gameplay")
	check(game.dungeon==local.sim.map and game.forest.map==local.sim.map,"render and collision use same actual dungeon instance")
	check(p.pos==local.sim.map.spawn and local.sim.map.walkable(p.pos),"actual entry snapshot is a walkable spawn")
	check(game.forest.material.get_shader_parameter("camp")==p.pos,"terrain mask camp matches actual spawn")
	var snapshot={"seed":local.world_seed,"zone":local.sim.map.zone,"floor":local.sim.map.floor_number,"spawn":str(p.pos),"next_room":str(local.sim.map.rooms[1]),"exit":str(local.sim.map.exit_position),"paused":local.paused,"walkable":local.sim.map.walkable(p.pos),"same_render_map":game.dungeon==local.sim.map}
	await create_timer(.2).timeout;await process_frame;await RenderingServer.frame_post_draw
	var capture=folder+"/entry.png";check(root.get_texture().get_image().save_png(capture)==OK,"entrance screenshot captured")
	var before=p.pos
	local.send_input(Vector2.RIGHT,Vector2.RIGHT);local._physics_process(.2)
	check(p.pos.distance_to(before)>.5,"real session input moves from entrance")
	snapshot["after_input"]=str(p.pos);snapshot["distance"]=p.pos.distance_to(before)
	var output=FileAccess.open(folder+"/snapshot.json",FileAccess.WRITE);output.store_string(JSON.stringify(snapshot,"\t"));output.close()
	print("ENTRY_VISUAL ",JSON.stringify(snapshot)," CAPTURE ",capture)
	game.stop_audio();local.connected=false;game.queue_free();game=null;await process_frame;await process_frame
	print("DUNGEON_ENTRY_VISUAL_V04 checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
