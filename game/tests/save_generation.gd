extends SceneTree
const Session=preload("res://scripts/local_session.gd")
const Sim=preload("res://scripts/simulation.gd")
const Production=preload("res://scripts/production_queue.gd")
var checks=0
var failures=[]
var options={}
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func write(path:String,value):
	DirAccess.make_dir_recursive_absolute(path.get_base_dir());var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()
func run():
	for arg in OS.get_cmdline_user_args():
		var parts=arg.trim_prefix("--").split("=",true,1)
		if parts.size()==2:options[parts[0]]=parts[1]
	var local=Session.new();local.slot=3;local.save_directory=options.get("directory",ProjectSettings.globalize_path("res://../runtime/save-generation/"+str(Time.get_ticks_usec())))
	var legacy=local.save_directory.path_join("slot-3.json")
	if options.get("verify","")=="true":
		var proof=JSON.parse_string(FileAccess.get_file_as_string(local.save_directory.path_join("proof.json")))
		check(FileAccess.get_sha256(local.save_path())==proof.current and FileAccess.get_sha256(local.save_path()+".bak")==proof.backup,"old executable cannot modify new generation or backup")
		check(local.slot_state(3)=="saved","new generation still listed")
		local.start_game("",3)
		check(local.connected and local.sim.players[1].production.queue.size()==1 and local.sim.players[1].production.queue[0].elapsed==3.,"new client restores reserved work after old executable roundtrip")
		check(local.sim.players[1].gold==proof.gold,"old executable cannot roll back reserved gold")
		local.connected=false;local.free();print("SAVE_GENERATION checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1);return
	var sim=Sim.new(8,"town");var p=sim.add_player(1,"이관 검사");p.tutorial_done=true;p.gold=1000
	Production.Inventory.add_stack(p,"seed",20)
	var old=sim.persistent(1);old.schema_version=7;old.erase("production");old.world_seed=8
	write(legacy,old);write(legacy+".bak",old)
	var original=FileAccess.get_sha256(legacy);var backup=FileAccess.get_sha256(legacy+".bak")
	check(local.slot_state(3)=="saved" and local.slot_read_path(3)==legacy,"legacy save discovered without writing")
	local.start_game("",3)
	check(local.connected and local.sim.players[1].name==old.name and FileAccess.file_exists(local.save_path()),"legacy character copied into new generation on entry")
	check(original==FileAccess.get_sha256(legacy) and backup==FileAccess.get_sha256(legacy+".bak"),"both legacy primary and backup remain byte-identical")
	p=local.sim.players[1];p.pos=Production.World.FACILITIES.alchemy.pos
	check(local.act("facility",JSON.stringify({"facility":"alchemy","operation":"production_start","recipe":"alchemy:potion","mode":"count","quantity":2})),"production reserved in new generation")
	local.paused=true;local._physics_process(3.);check(local.save_game(),"new generation saved after reservation")
	check(local.parse_save(local.save_path()).schema_version==8,"current production save has envelope8")
	# Reproduce the exact dangerous old-layout combination. The old executable
	# is allowed to roll back this legacy path, but cannot reach saves/v071.
	write(legacy,local.sim.persistent(1));write(legacy+".bak",old)
	write(local.save_directory.path_join("proof.json"),{"current":FileAccess.get_sha256(local.save_path()),"backup":FileAccess.get_sha256(local.save_path()+".bak"),"gold":p.gold})
	local.connected=false;local.free()
	# Corrupt a separate new slot: never silently fall back to a healthy legacy copy.
	var damaged=Session.new();damaged.slot=2;damaged.save_directory=options.get("directory",legacy.get_base_dir())
	write(damaged.save_directory.path_join("slot-2.json"),old);write(damaged.save_path(),{"bad":true})
	var bad_hash=FileAccess.get_sha256(damaged.save_path())
	check(damaged.slot_state(2)=="damaged" and damaged.load_slot().is_empty(),"damaged current generation does not read old generation")
	damaged.start_game("",2)
	check(not damaged.connected and FileAccess.get_sha256(damaged.save_path())==bad_hash,"damaged slot cannot silently become a new character")
	damaged.free()
	print("SAVE_GENERATION checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
