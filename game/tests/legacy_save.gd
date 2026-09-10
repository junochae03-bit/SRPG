extends SceneTree
const Session=preload("res://scripts/local_session.gd")
const Content=preload("res://scripts/content.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
func _initialize():run.call_deferred()
func run():
	var args={}
	for arg in OS.get_cmdline_user_args():
		var pair=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	var session=Session.new();root.add_child(session);session.save_directory=args["save-dir"]
	var old=session.parse_save(session.save_path())
	assert(old!=null)
	session.start_game("호환성",1);session.paused=true
	var p=session.sim.players[1]
	for field in ["name","level","xp","gold","potions","equipped","kills","boss_kills","quest_done"]:assert(p[field]==old[field],field)
	assert(p.inventory.size()==old.inventory.size())
	for i in range(old.inventory.size()):
		for field in ["id","rarity","bonus"]:assert(p.inventory[i][field]==old.inventory[i][field])
		# 장비 표시명은 현재 카탈로그로 이관되며 소유 ID와 전투 수치는 유지한다.
		var expected=old.inventory[i].duplicate(true)
		preload("res://scripts/equipment_catalog.gd").normalize(expected,old)
		assert(p.inventory[i].name==expected.name,"저장 장비의 현재 카탈로그 이름")
	assert(p.bag_positions.size()==Inventory.bag_items(p).size())
	for item in Inventory.bag_items(p):
		var pos=p.bag_positions[item.id]
		assert(Inventory.can_place(p,item.id,Vector2i(pos.x,pos.y),pos.rotated))
	assert(p.skill_ranks==old.get("skill_ranks",{}))
	assert(Content.available_points(p)==Content.available_points(old))
	session.save_game();var migrated=session.parse_save(session.save_path());assert(migrated!=null and migrated.schema_version==7)
	session.disconnect_game();session.start_game("재시작",1);session.paused=true
	assert(session.sim.players[1].inventory==p.inventory)
	assert(session.sim.players[1].bag_positions==p.bag_positions)
	print("LEGACY_SAVE_PASS level=",p.level," items=",p.inventory.size()," gold=",p.gold)
	session.disconnect_game();session.queue_free();await process_frame;quit()
