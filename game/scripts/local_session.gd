extends Node

signal changed
signal status_changed(message: String)
signal event_received(event: Dictionary)
signal entered
signal action_performed(kind: String)
signal facility_requested(key:String)

const Simulation = preload("res://scripts/simulation.gd")
const Content = preload("res://scripts/content.gd")
var sim
var state = {"players":{},"enemies":{},"drops":{},"clock":0.0}
var connected = false
var local_id = 1
var world_seed = 20260908
var slot = 1
var save_directory = ProjectSettings.globalize_path("res://../runtime/saves") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("saves")
var paused = false
var save_time = 0.0
var received_snapshots = 0

func start_game(chosen_name: String, slot_number: int):
	slot = clampi(slot_number,1,3)
	DirAccess.make_dir_recursive_absolute(save_directory)
	var saved = load_slot()
	world_seed = int(saved.get("world_seed",20260908+slot*137))
	sim = Simulation.new(world_seed,"town")
	var display_name = saved.get("name",chosen_name.strip_edges().left(16))
	if display_name.is_empty(): display_name="모험가"
	sim.add_player(local_id,display_name,saved)
	connected=true
	paused=false
	save_time=0.0
	refresh()
	save_game()
	entered.emit()
	status_changed.emit("슬롯 %d · 모험을 시작합니다." % slot)

func new_expedition():
	if not connected: return
	travel("forest")

func travel(zone:String)->bool:
	if not connected or zone not in ["town","forest","cave","ruins"]:return false
	if zone!="town" and not sim.map.in_town(sim.players[local_id].pos):return false
	var previous=sim.players[local_id];var saved=sim.persistent(local_id)
	world_seed+=7919;sim=Simulation.new(world_seed,zone)
	var p=sim.add_player(local_id,saved.name,saved);p.hp=mini(p.max_hp,previous.hp);p.stamina=minf(p.max_stamina,previous.stamina)
	paused=false;save_game();refresh();entered.emit();return true

func refresh():
	state=sim.snapshot(local_id)
	received_snapshots+=1
	changed.emit()

func send_input(direction: Vector2, aim: Vector2, sprint: bool = false):
	if connected and not paused:sim.set_input(local_id,direction,aim,sprint)

func act(kind: String, argument: String = "") -> bool:
	if not connected: return false
	if paused and kind not in ["equip","unequip","unequip_to","discard","move_item","invest","reset_skills","class","costume","avatar","claim_starters","potion","stat","reset_stats","bind_skill","facility"]: return false
	if kind=="return":
		if sim.map.zone=="town" or sim.players[local_id].return_cd>0:return false
		return travel("town")
	if kind=="interact" and sim.map.zone=="town":
		var facility=preload("res://scripts/world_catalog.gd").nearest(sim.players[local_id].pos)
		if facility!="":facility_requested.emit(facility);return true
		return false
	var success=sim.action(local_id,kind,argument)
	if success:action_performed.emit(kind)
	flush_events()
	refresh()
	return success

func flush_events():
	for event in sim.events: event_received.emit(event)
	sim.events.clear()
	if not sim.dirty.is_empty():
		save_game()
		sim.dirty.clear()

func disconnect_game():
	if connected:save_game()
	connected=false
	paused=false
	state={"players":{},"enemies":{},"drops":{},"clock":0.0}
	status_changed.emit("저장했습니다. 같은 슬롯에서 이어서 모험할 수 있습니다.")
	changed.emit()

func save_path() -> String:
	return save_directory.path_join("slot-%d.json" % slot)

func parse_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):return null
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK:return null
	var value=parser.data
	if not value is Dictionary or int(value.get("schema_version",0)) not in [1,2,3,4,5]:return null
	for key in ["level","xp","gold","potions","kills","boss_kills","world_seed"]:
		if not value.get(key) is float and not value.get(key) is int:return null
		if value[key]<0:return null
	if value.level<1 or value.level>100 or value.potions>20:return null
	if not value.get("name") is String or not value.get("equipped") is String or not value.get("quest_done") is bool:return null
	if not value.get("inventory") is Array or value.inventory.size()>80:return null
	var ids=[]
	for item in value.inventory:
		if not item is Dictionary:return null
		if not item.get("id") is String or not item.get("name") is String:return null
		if ids.has(item.id):return null
		ids.append(item.id)
		for key in ["bonus","rarity"]:
			if not item.get(key) is float and not item.get(key) is int:return null
		if item.bonus<0 or item.bonus>100 or item.rarity<0 or item.rarity>2:return null
		if item.get("category","weapon") not in ["weapon","armor","accessory"]:return null
		if item.get("slot","weapon") not in Content.SLOTS:return null
		if item.get("weapon_type","sword") not in Content.WEAPONS:return null
	if value.equipped!="" and not ids.has(value.equipped):return null
	Content.migrate_appearance(value)
	if value.get("avatar","auto")!="auto" and value.get("avatar") not in Content.AVATARS:return null
	if not value.get("legacy_costume","") is String:return null
	if value.get("class_id","warrior") not in Content.CLASSES or value.get("costume","none") not in Content.COSTUMES:return null
	if not value.get("training_given",false) is bool:return null
	for field in ["equipment","bag_positions","materials","skill_ranks"]:
		if not value.get(field,{}) is Dictionary:return null
	for slot in value.get("equipment",{}):
		var id=value.equipment[slot]
		if slot not in Content.SLOTS or not id is String or (id!="" and id not in ids):return null
	if value.get("equipment",{}).get("weapon",value.equipped)!=value.equipped:return null
	for key in value.get("materials",{}):
		var amount=value.materials[key]
		if key not in Content.MATERIALS or (not amount is float and not amount is int) or amount<0 or amount>999999:return null
		value.materials[key]=int(amount)
	for id in value.get("bag_positions",{}):
		var place=value.bag_positions[id]
		if not id is String or not place is Dictionary or not place.get("rotated") is bool:return null
		for axis in ["x","y"]:
			if not place.get(axis) is float and not place.get(axis) is int:return null
			place[axis]=int(place[axis])
		if place.x<0 or place.x>=10 or place.y<0 or place.y>=6:return null
	Content.migrate_skills(value)
	var allowed=[]
	for node in Content.SKILLS[value.get("class_id","warrior")]:allowed.append(node.id)
	var spent=0
	for key in value.get("skill_ranks",{}):
		var rank=value.skill_ranks[key]
		if key not in allowed or (not rank is float and not rank is int) or rank<0 or rank>3:return null
		value.skill_ranks[key]=int(rank)
		spent+=int(rank)
	if spent>int(value.level)-1:return null
	if not value.get("stats",{}) is Dictionary or not value.get("skill_loadout",{}) is Dictionary:return null
	var stats_spent=0
	for key in value.get("stats",{}):
		if key not in preload("res://scripts/progression.gd").NAMES:return null
		var amount=value.stats[key]
		if (not amount is float and not amount is int) or amount<0 or amount!=floor(amount):return null
		value.stats[key]=int(amount);stats_spent+=int(amount)
	if stats_spent>(int(value.level)-1)*3:return null
	for action in value.get("skill_loadout",{}):
		if action not in ["skill_f","skill_v","skill_c"]:return null
		var valid=false
		for node in Content.SKILLS[value.get("class_id","warrior")]:
			if node.id==value.skill_loadout[action] and node.effect=="active" and value.get("skill_ranks",{}).get(node.id,0)>0:valid=true
		if not valid:return null
	if not value.get("guild_contract",{}) is Dictionary or not value.get("dungeon_clears",{}) is Dictionary:return null
	var contract=value.get("guild_contract",{})
	if not contract.is_empty():
		if contract.get("zone","") not in preload("res://scripts/world_catalog.gd").DUNGEONS:return null
		for key in ["progress","target"]:
			if (not contract.get(key) is float and not contract.get(key) is int) or contract[key]<0:return null
			contract[key]=int(contract[key])
		if contract.target!=10 or contract.progress>10:return null
	for zone in value.get("dungeon_clears",{}):
		if zone not in preload("res://scripts/world_catalog.gd").DUNGEONS:return null
		var count=value.dungeon_clears[zone]
		if (not count is float and not count is int) or count<0:return null
		value.dungeon_clears[zone]=int(count)
	for key in ["level","xp","gold","potions","kills","boss_kills","world_seed"]:
		value[key]=int(value[key])
	for item in value.inventory:
		item.bonus=int(item.bonus)
		item.rarity=int(item.rarity)
		for field in ["tier","upgrade"]:
			if item.has(field):
				if (not item[field] is float and not item[field] is int) or item[field]<0 or item[field]>5:return null
				item[field]=int(item[field])
		if item.get("affix","none") not in preload("res://scripts/equipment_catalog.gd").AFFIXES:return null
	return value

func load_slot() -> Dictionary:
	var path=save_path()
	var value=parse_save(path)
	if value!=null:return value
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path,path+".corrupt-"+str(Time.get_ticks_msec()))
		var backup=parse_save(path+".bak")
		if backup!=null:return backup
	return {}

func save_game():
	if sim==null or not sim.players.has(local_id):return
	DirAccess.make_dir_recursive_absolute(save_directory)
	var data=sim.persistent(local_id)
	data.world_seed=world_seed
	var path=save_path()
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:
		event_received.emit({"type":"notice","text":"저장할 수 없습니다. 폴더 쓰기 권한을 확인하세요."})
		return
	file.store_string(JSON.stringify(data,"\t"));file.flush();file.close()
	if parse_save(path)!=null:DirAccess.copy_absolute(path,path+".bak")
	var error=DirAccess.rename_absolute(path+".tmp",path)
	if error!=OK:push_error("Save failed: "+error_string(error))

func _physics_process(delta: float):
	if not connected or paused:return
	sim.tick(delta)
	flush_events()
	refresh()
	save_time+=delta
	if save_time>=5:
		save_game()
		save_time=0

func _exit_tree():
	if connected:save_game()
