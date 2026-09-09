extends SceneTree
const Creation=preload("res://scripts/character_creation.gd")
const Local=preload("res://scripts/local_session.gd")
const Progression=preload("res://scripts/progression.gd")
const Content=preload("res://scripts/content.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func write_json(path:String,value:Dictionary):
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()
func run():
	Content.initialize_jobs()
	var folder=ProjectSettings.globalize_path("res://../runtime/creation-v04/"+str(Time.get_ticks_usec()))
	for cls in Creation.CLASSES:
		var local=Local.new();root.add_child(local);local.set_physics_process(false);local.save_directory=folder.path_join(cls)
		var sheet={"name":"  별빛 모험가  ","class_id":cls,"avatar":"auto","costume":"none","stats":Creation.suggested(cls)}
		check(Creation.reason(sheet).is_empty(),cls+" suggested valid")
		check(local.slot_state(1)=="empty" and not FileAccess.file_exists(local.save_directory.path_join("slot-1.json")),"new slot inspection never writes")
		check(local.create_character(sheet,1),cls+" create")
		var p=local.sim.players[1]
		check(p.class_id==cls and p.avatar==sheet.avatar and p.name=="별빛 모험가","identity applied")
		check(p.stats==sheet.stats and p.creation_points==10 and Progression.available(p)==0,"exactly ten creation points consumed")
		check(local.sim.map.zone=="forest" and local.sim.map.floor_number==0 and not p.tutorial_done,"new player starts tutorial")
		check(p.defense==sheet.stats.endurance*2+6 and local.sim.damage_for(p,"magic")==22+sheet.stats.magic*2,"created stats and starter gear change actual combat")
		check(p.inventory.size()==4 and p.equipment.values().filter(func(id):return id!="").size()==4 and p.training_given,"new character begins with four equipped starter pieces")
		check(local.sim.combat.weapon_type(p)==Content.CLASSES[cls].weapon and p.inventory[0].job_lock==cls,"starter weapon belongs to chosen class")
		check(not local.sim.action(1,"claim_starters"),"automatic starter kit cannot be claimed twice")
		var saved=local.parse_save(local.save_path());check(saved!=null and saved.schema_version==7,"V7 creation save accepted")
		var before=FileAccess.get_file_as_string(local.save_path());local.disconnect_game()
		check(not local.create_character(sheet,1),"existing slot cannot be replaced")
		check(FileAccess.get_file_as_string(local.save_path())==before,"rejected creation leaves original bytes unchanged")
		local.start_game("다른 이름",1);p=local.sim.players[1]
		check(p.name=="별빛 모험가" and p.stats==sheet.stats and p.creation_points==10,"restart preserves character sheet")
		check(p.inventory.size()==4 and p.equipment.values().filter(func(id):return id!="").size()==4 and p.training_given,"restart preserves equipment without duplicating the kit")
		p.level=2;check(Progression.available(p)==3,"level gain remains three points")
		local.disconnect_game();root.remove_child(local);local.free()
	var good={"name":"별", "class_id":"mage","avatar":"auto","stats":Creation.suggested("mage")}
	for invalid_name in ["","   ","가".repeat(17),"별\n빛","별\t빛"]:
		var bad=good.duplicate(true);bad.name=invalid_name;check(not Creation.reason(bad).is_empty(),"invalid name rejected")
	for bad_value in [-1,1.5,"3",INF]:
		var bad=good.duplicate(true);bad.stats.magic=bad_value;check(not Creation.reason(bad).is_empty(),"invalid stat rejected")
	for field in ["class_id","avatar"]:
		var bad=good.duplicate(true);bad[field]="missing";check(not Creation.reason(bad).is_empty(),"invalid "+field)
	var bad=good.duplicate(true);bad.stats.magic+=1;check(not Creation.reason(bad).is_empty(),"overspend rejects")
	bad=good.duplicate(true);bad.stats.magic-=1;check(not Creation.reason(bad).is_empty(),"unspent creator points reject")
	var local=Local.new();root.add_child(local);local.set_physics_process(false);local.save_directory=folder.path_join("migration");local.start_game("옛 모험",1)
	var p=local.sim.players[1];p.level=20;p.gold=817;p.stats.strength=11;p.skill_ranks={"blade":2};p.tutorial_done=true;local.save_game()
	var old=local.sim.persistent(1);old.world_seed=local.world_seed;old.schema_version=6;old.creation_points=10;old.constellation_allocations={"forged":1};write_json(local.save_path(),old)
	var parsed=local.parse_save(local.save_path())
	check(parsed!=null and parsed.gold==817 and parsed.stats.strength==11 and parsed.skill_ranks.blade==2,"V6 retains property stats skills")
	check(parsed.creation_points==0 and parsed.constellation_allocations.is_empty(),"old schema cannot inject new free points or traits")
	local.connected=false;local.start_game("무시",1);local.set_physics_process(false);local.save_game()
	var current=local.parse_save(local.save_path());check(current.schema_version==7 and current.name=="옛 모험" and current.skill_build_version==2,"old character upgraded once")
	var stable=FileAccess.get_file_as_string(local.save_path());local.start_game("무시",1);local.save_game();check(FileAccess.get_file_as_string(local.save_path())==stable,"second load does not refund or alter property")
	current.constellation_allocations={"forged":1};write_json(local.save_path()+".invalid",current);check(local.parse_save(local.save_path()+".invalid")==null,"unknown constellation save rejected")
	current.constellation_allocations={};current.creation_points=11;write_json(local.save_path()+".invalid",current);check(local.parse_save(local.save_path()+".invalid")==null,"forged creation budget rejected")
	local.disconnect_game();root.remove_child(local);local.free()
	var blocked=Local.new();root.add_child(blocked);blocked.set_physics_process(false)
	var blocker=folder.path_join("read-only-parent");var file=FileAccess.open(blocker,FileAccess.WRITE);file.store_string("unchanged");file.close()
	blocked.save_directory=blocker.path_join("cannot-create")
	var previous_state=blocked.state.duplicate(true);var previous_slot=blocked.slot;var previous_seed=blocked.world_seed;var previous_snapshots=blocked.received_snapshots;var signals={"changed":0,"entered":0}
	blocked.changed.connect(func():signals.changed+=1);blocked.entered.connect(func():signals.entered+=1)
	check(not blocked.create_character(good,2),"write failure rejects creation")
	check(blocked.sim==null and not blocked.connected and blocked.slot==previous_slot and blocked.world_seed==previous_seed and blocked.state==previous_state,"write failure leaves session unchanged")
	check(blocked.received_snapshots==previous_snapshots and signals.changed==0 and signals.entered==0,"failed creation publishes no committed state")
	check(FileAccess.get_file_as_string(blocker)=="unchanged","failed save preserves blocking file")
	root.remove_child(blocked);blocked.free()
	print("CHARACTER_CREATION_V04_TESTS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
