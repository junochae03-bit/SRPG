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
	var previous_slot=slot
	slot = clampi(slot_number,1,3)
	DirAccess.make_dir_recursive_absolute(save_directory)
	var saved = load_slot()
	if not enter_saved(saved,chosen_name):slot=previous_slot

func slot_state(slot_number:int)->String:
	var path=save_directory.path_join("slot-%d.json"%clampi(slot_number,1,3))
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"):return "empty"
	return "saved" if parse_save(path)!=null or parse_save(path+".bak")!=null else "damaged"

func create_character(sheet:Dictionary,slot_number:int)->bool:
	if connected or slot_number<1 or slot_number>3 or slot_state(slot_number)!="empty":return false
	var saved=preload("res://scripts/character_creation.gd").player_data(sheet)
	if saved.is_empty():return false
	var previous_slot=slot
	slot=slot_number
	if enter_saved(saved,saved.name):return true
	slot=previous_slot;return false

func enter_saved(saved:Dictionary,chosen_name:String)->bool:
	var candidate_seed=int(saved.get("world_seed",20260908+slot*137))
	var candidate=Simulation.new(candidate_seed,"town" if not saved.is_empty() and (int(saved.get("schema_version",0))<6 or saved.get("tutorial_done",false)) else "forest")
	var display_name = saved.get("name",chosen_name.strip_edges().left(16))
	if display_name.is_empty(): display_name="모험가"
	candidate.add_player(local_id,display_name,saved)
	var data=candidate.persistent(local_id);data.world_seed=candidate_seed
	if not write_save(data,save_path()):return false
	sim=candidate;world_seed=candidate_seed
	connected=true
	paused=false
	save_time=0.0
	refresh()
	entered.emit()
	status_changed.emit("슬롯 %d · 모험을 시작합니다." % slot)
	return true

func new_expedition():
	if not connected: return
	enter_floor(int(sim.players[local_id].get("highest_floor",1)))

func travel(zone:String)->bool:
	if not connected or zone not in ["town","forest","cave","ruins"]:return false
	if zone!="town":return enter_floor({"forest":1,"cave":11,"ruins":21}[zone])
	var p=sim.players[local_id]
	if not p.tutorial_done:
		if p.tutorial_kills<5:sim.notice(local_id,"숲에서 적 5마리를 처치하고 마을로 향하세요.");flush_events();return false
		p.gold+=0 if p.quest_done else 100;p.tutorial_done=true;p.quest_done=true;sim.notice(local_id,"꽃바람 숲 완료 · 햇살 마을에 도착했습니다. 금화 +100")
	return change_map("town",0)

func enter_floor(floor_number:int)->bool:
	if not connected:return false
	var p=sim.players[local_id];var reason=preload("res://scripts/abyss_catalog.gd").locked_reason(p,floor_number)
	if not reason.is_empty():sim.notice(local_id,reason);flush_events();return false
	if sim.map.zone!="town":
		if floor_number!=sim.map.floor_number+1 or p.pos.distance_to(sim.map.exit_position)>2.8:return false
		if sim.enemies.values().any(func(e):return e.get("guardian",false) and e.hp>0):return false
	return change_map(preload("res://scripts/abyss_catalog.gd").config(floor_number).terrain,floor_number)

func change_map(zone:String,floor_number:int)->bool:
	var previous=sim.players[local_id];var saved=sim.persistent(local_id)
	world_seed+=7919;sim=Simulation.new(world_seed,zone,floor_number)
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
	if paused and kind not in ["equip","unequip","unequip_to","discard","move_item","invest","uninvest","reset_skills","class","costume","avatar","claim_starters","potion","stat","reset_stats","bind_skill","facility"]: return false
	if kind=="return":
		if sim.map.zone=="town" or sim.players[local_id].return_cd>0:return false
		return travel("town")
	if kind=="interact" and sim.map.floor_number>0 and sim.players[local_id].pos.distance_to(sim.map.exit_position)<2.8:
		var near_drop=sim.drops.values().any(func(d):return d.owner==local_id and d.pos.distance_to(sim.players[local_id].pos)<=1.8)
		if not near_drop and sim.map.floor_number<100:return enter_floor(sim.map.floor_number+1)
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
	Content.initialize_jobs()
	if not FileAccess.file_exists(path):return null
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK:return null
	var value=parser.data
	if not value is Dictionary or int(value.get("schema_version",0)) not in [1,2,3,4,5,6,7]:return null
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
		if item.bonus<0 or item.bonus>100 or item.rarity<0 or item.rarity>(4 if int(value.schema_version)>=6 else 2):return null
		if item.get("category","weapon") not in ["weapon","armor","accessory"]:return null
		if item.get("slot","weapon") not in Content.SLOTS:return null
		if item.get("weapon_type","sword") not in Content.WEAPONS:return null
	if value.equipped!="" and not ids.has(value.equipped):return null
	Content.migrate_appearance(value)
	if value.get("avatar","auto")!="auto" and value.get("avatar") not in Content.AVATARS:return null
	if not value.get("legacy_costume","") is String:return null
	if value.get("class_id","warrior") not in Content.CLASSES or value.get("costume","none") not in Content.COSTUMES:return null
	if not value.get("training_given",false) is bool:return null
	var cls=Content.CLASSES[value.get("class_id","warrior")]
	if cls.has("base") and not cls.get("starter",false) and value.level<30:return null
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
	var allowed=[];var definitions={}
	for node in Content.SKILLS[value.get("class_id","warrior")]:allowed.append(node.id);definitions[node.id]=node
	var spent=0
	for key in value.get("skill_ranks",{}):
		var rank=value.skill_ranks[key]
		if key not in allowed or (not rank is float and not rank is int) or rank<0 or rank>Content.max_rank(definitions[key]) or rank!=floor(rank):return null
		if rank>0 and int(value.level)<definitions[key].get("level",1):return null
		value.skill_ranks[key]=int(rank)
		if rank>0 and definitions[key].effect=="upgrade" and not definitions[key].parents.any(func(parent):return value.skill_ranks.get(parent,0)>=definitions[key].get("required_rank",1)):return null
		spent+=int(rank)
	if spent>int(value.level)-1:return null
	if not value.get("stats",{}) is Dictionary or not value.get("skill_loadout",{}) is Dictionary:return null
	var stats_spent=0
	for key in value.get("stats",{}):
		if key not in (preload("res://scripts/progression.gd").NAMES.keys() if int(value.schema_version)>=6 else ["strength","dexterity","intelligence","vitality"]):return null
		var amount=value.stats[key]
		if (not amount is float and not amount is int) or amount<0 or amount!=floor(amount):return null
		value.stats[key]=int(amount);stats_spent+=int(amount)
	var creation_points=0
	if int(value.schema_version)>=7:
		if not value.get("creation_points") is int and not value.get("creation_points") is float:return null
		if float(value.creation_points) not in [0.0,10.0]:return null
		creation_points=int(value.creation_points);value.creation_points=creation_points
	if stats_spent>(int(value.level)-1)*3+creation_points:return null
	preload("res://scripts/progression.gd").migrate(value)
	var equipped_skills=[]
	for action in value.get("skill_loadout",{}):
		if value.skill_loadout[action] in equipped_skills:return null
		equipped_skills.append(value.skill_loadout[action])
		if action not in Content.ACTIONS:return null
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
				if (not item[field] is float and not item[field] is int) or item[field]<0 or item[field]>(9 if field=="tier" else 5):return null
				item[field]=int(item[field])
		if item.get("affix","none") not in preload("res://scripts/equipment_catalog.gd").AFFIXES:return null
	if int(value.schema_version)>=6:
		if not value.get("tutorial_done") is bool or not value.get("raid_clears") is Dictionary:return null
		for field in ["highest_floor","cleared_floor","tutorial_kills"]:
			if not value.get(field) is float and not value.get(field) is int:return null
			if value[field]<0 or value[field]!=floor(value[field]):return null
			value[field]=int(value[field])
		if value.highest_floor<1 or value.highest_floor>100 or value.cleared_floor>100 or value.highest_floor>value.cleared_floor+1:return null
		for key in value.raid_clears:
			if not key.is_valid_int() or int(key)<10 or int(key)>100 or int(key)%10!=0 or int(key)>value.cleared_floor:return null
			if not value.raid_clears[key] is float and not value.raid_clears[key] is int:return null
			if value.raid_clears[key]<1 or value.raid_clears[key]!=floor(value.raid_clears[key]):return null
			value.raid_clears[key]=int(value.raid_clears[key])
		for item in value.inventory:
			if item.get("family","") not in preload("res://scripts/equipment_catalog.gd").FAMILY_NAMES:return null
			if item.get("job_lock","") not in ([""] if item.category!="weapon" else Content.CLASSES.keys()):return null
			if not item.get("required_level") is float and not item.get("required_level") is int:return null
			if item.required_level<1 or item.required_level>100 or item.required_level!=floor(item.required_level):return null
			item.required_level=int(item.required_level)
			if item.get("resonance","") not in ([""] if item.rarity<3 else preload("res://scripts/equipment_catalog.gd").RESONANCE.keys()):return null
	if int(value.schema_version)>=7:
		if value.get("skill_build_version",0)!=2:return null
		value.skill_build_version=2
		if not value.get("constellation_allocations") is Dictionary:return null
		if not Content.Build.validate_build(value).ok:return null
		for key in value.constellation_allocations:value.constellation_allocations[key]=int(value.constellation_allocations[key])
	else:
		value["skill_build_version"]=2;value["constellation_allocations"]={};value["creation_points"]=0
	return value

func load_slot() -> Dictionary:
	var path=save_path()
	var value=parse_save(path)
	if value!=null:return value
	if not FileAccess.file_exists(path):
		var backup_only=parse_save(path+".bak")
		if backup_only!=null:return backup_only
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path,path+".corrupt-"+str(Time.get_ticks_msec()))
		var backup=parse_save(path+".bak")
		if backup!=null:return backup
	return {}

func save_game()->bool:
	if sim==null or not sim.players.has(local_id):return false
	var data=sim.persistent(local_id)
	data.world_seed=world_seed
	return write_save(data,save_path())

func write_save(data:Dictionary,path:String)->bool:
	var parent=path.get_base_dir()
	while not parent.is_empty() and not DirAccess.dir_exists_absolute(parent):
		if FileAccess.file_exists(parent):return false
		var next=parent.get_base_dir()
		if next==parent:break
		parent=next
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:
		event_received.emit({"type":"notice","text":"저장할 수 없습니다. 폴더 쓰기 권한을 확인하세요."})
		return false
	file.store_string(JSON.stringify(data,"\t"));file.flush();file.close()
	if parse_save(path)!=null:DirAccess.copy_absolute(path,path+".bak")
	var error=DirAccess.rename_absolute(path+".tmp",path)
	if error!=OK:push_error("Save failed: "+error_string(error))
	return error==OK

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
