extends RefCounted

const Dungeon = preload("res://scripts/dungeon.gd")
const Content = preload("res://scripts/content.gd")
const Inventory = preload("res://scripts/inventory_model.gd")
const Progression=preload("res://scripts/progression.gd")
var map
var balance: Dictionary
var players: Dictionary = {}
var enemies: Dictionary = {}
var drops: Dictionary = {}
var clock = 0.0
var serial = 0
var events: Array = []
var dirty: Dictionary = {}
var rng = RandomNumberGenerator.new()
var combat
var monster_attacks
var loot_tables=preload("res://scripts/loot_tables.gd").new()

func _init(seed_value: int = 20260908,zone:String="forest"):
	combat=preload("res://scripts/player_combat.gd").new(self)
	monster_attacks=preload("res://scripts/monster_attacks.gd").new(self)
	map = Dungeon.new(seed_value,zone)
	balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	balance.enemies=preload("res://scripts/world_catalog.gd").ENEMIES.duplicate(true)
	rng.seed = seed_value + 93
	if zone=="town":return
	var dungeon_config=preload("res://scripts/world_catalog.gd").DUNGEONS[zone]
	for i in range(1, map.rooms.size()):
		var center = Vector2(map.rooms[i])
		for j in range(3 if i < 8 else 1):
			var kind=dungeon_config.boss if i==8 else dungeon_config.mobs[((i-1)*3+j)%dungeon_config.mobs.size()]
			spawn_enemy(kind,center+Vector2(j-1,j%2),dungeon_config.level+(4 if i==8 else j),i==8)
		if i==7:spawn_enemy(dungeon_config.elite,Vector2(map.rooms[5])+Vector2(1,-1),dungeon_config.level+3,false)

func spawn_enemy(kind:String,pos:Vector2,level:int,boss:bool=false)->Dictionary:
	var config=balance.enemies[kind];var id=enemies.size()+1
	var e={"id":id,"kind":kind,"name":config.name,"pos":pos,"home":pos,"hp":config.health,"max_hp":config.health,"cooldown":0.0,"windup":0.0,"target":0,"attack_pos":pos,"respawn":0.0,"level":level,"boss":boss,"elite":config.get("elite",false),"phase":1,"pattern":0,"ability_cd":4.0,"attack_motion":0.0}
	enemies[id]=e;return e

func add_player(id: int, player_name: String, saved: Dictionary = {}) -> Dictionary:
	var p = {"id":id,"name":player_name,"pos":map.spawn,"dir":Vector2.ZERO,"aim":Vector2.RIGHT,
		"hp":120,"max_hp":120,"level":1,"xp":0,"gold":0,"potions":5,"inventory":[],"equipped":"",
		"equipment":{},"bag_positions":{},"materials":{},"class_id":"warrior","skill_ranks":{},"costume":"none","avatar":"auto","legacy_costume":"","training_given":false,
		"stats":{},"skill_loadout":{},"guild_contract":{},"dungeon_clears":{},"kills":0,"boss_kills":0,"quest_done":false,"attack_cd":0.0,"nova_cd":0.0,"potion_cd":0.0,"return_cd":0.0,"swing":0.0,"input_age":0.0}
	saved=saved.duplicate(true)
	if not saved.is_empty():Content.migrate_appearance(saved)
	for key in ["level","xp","gold","potions","inventory","equipped","kills","boss_kills","quest_done","equipment","bag_positions","materials","class_id","skill_ranks","costume","avatar","legacy_costume","training_given","stats","skill_loadout","guild_contract","dungeon_clears"]:
		if saved.has(key):
			p[key] = saved[key]
	p.level = clampi(int(p.level), 1, 100)
	Content.migrate_skills(p)
	Progression.initialize(p)
	if int(saved.get("schema_version",0))<3:p.bag_positions={}
	combat.initialize(p)
	Inventory.initialize(p)
	recalculate(p)
	p.hp = p.max_hp
	players[id] = p
	return p

func persistent(id: int) -> Dictionary:
	var result = {"schema_version":5}
	for key in ["name","level","xp","gold","potions","inventory","equipped","kills","boss_kills","quest_done","equipment","bag_positions","materials","class_id","skill_ranks","costume","avatar","legacy_costume","training_given","stats","skill_loadout","guild_contract","dungeon_clears"]:
		result[key] = players[id][key]
	return result

func set_input(id: int, direction: Vector2, aim: Vector2, sprint: bool = false):
	if not players.has(id) or not direction.is_finite() or not aim.is_finite():
		return
	players[id].dir = direction.limit_length(1.0)
	players[id].aim = aim.limit_length(1.0)
	players[id].input_age = 0.0
	players[id].sprint=sprint

func damage_for(p: Dictionary) -> int:
	var damage = 18 + Progression.damage(p,combat.weapon_type(p)) + int(Content.skill_bonus(p,"damage"))
	damage+=int(preload("res://scripts/equipment_catalog.gd").bonus(p,"damage"))
	for item in p.inventory:
		if item.id == p.equipped or item.id==p.equipment.get("accessory",""):
			damage += int(item.bonus)
	return damage

func recalculate(p: Dictionary):
	var old_max=int(p.get("max_hp",120))
	p.max_hp=120+Progression.bonus(p,"vitality")*10+int(Content.skill_bonus(p,"health"))
	p["defense"]=int(Content.skill_bonus(p,"defense"))+int(Progression.bonus(p,"vitality")*.2)
	for item in p.inventory:
		if Inventory.is_equipped(p,item.id) and item.get("category","")=="armor":
			p.defense+=int(item.bonus)
			if item.slot=="chest":p.max_hp+=int(item.bonus)*5
	p["max_stamina"]=100.0+Content.skill_bonus(p,"stamina")+Progression.bonus(p,"intelligence")
	p.max_hp+=int(preload("res://scripts/equipment_catalog.gd").bonus(p,"health"))
	p.defense+=int(preload("res://scripts/equipment_catalog.gd").bonus(p,"defense"))
	p.max_stamina+=preload("res://scripts/equipment_catalog.gd").bonus(p,"stamina")
	p.hp=clampi(int(p.hp)+p.max_hp-old_max,1,p.max_hp)
	p["stamina"]=minf(float(p.get("stamina",p.max_stamina)),p.max_stamina)

func gear_changed(p: Dictionary):
	recalculate(p)
	dirty[p.id]=true

func notice(id: int, message: String):
	events.append({"type":"notice","owner":id,"text":message})

func action(id: int, kind: String, argument: String = "") -> bool:
	if not players.has(id):
		return false
	var p = players[id]
	if kind=="stat":
		if argument not in Progression.NAMES or Progression.available(p)<=0:return false
		p.stats[argument]+=1;gear_changed(p);return true
	if kind=="facility":
		var request=JSON.parse_string(argument)
		if not request is Dictionary:return false
		var success=preload("res://scripts/town_services.gd").transact(self,p,request)
		if not success:notice(id,"재료·금화·가방 공간과 시설 위치를 확인하세요.")
		return success
	if kind=="reset_stats":
		if not map.in_town(p.pos):return false
		p.stats={};Progression.initialize(p);gear_changed(p);return true
	if kind=="bind_skill":
		var parts=argument.split(":")
		if parts.size()!=2 or parts[0] not in ["skill_f","skill_v","skill_c"]:return false
		for node in Content.SKILLS[p.class_id]:
			if node.id==parts[1] and node.effect=="active" and int(p.skill_ranks.get(node.id,0))>0:
				p.skill_loadout[parts[0]]=node.id;dirty[id]=true;return true
		return false
	if kind in ["attack","nova","dodge","heavy_begin","heavy","cancel_charge","skill_f","skill_v","skill_c"]:
		return combat.act(p,kind)
	if kind == "potion":
		if p.potion_cd > 0 or p.potions <= 0 or p.hp >= p.max_hp:
			return false
		p.potions -= 1
		if p.potions==0:p.bag_positions.erase("@potion")
		var healing=60+int(Content.skill_bonus(p,"potion_power"))
		p.hp = mini(p.max_hp, p.hp + healing)
		p.potion_cd = 2.0
		dirty[id] = true
		notice(id, "생명력을 %d 회복했습니다." % healing)
		return true
	if kind == "return":
		if p.return_cd > 0: return false
		p.pos = map.spawn
		p.charge_time=-1.0
		p.dir = Vector2.ZERO
		p.return_cd = 8.0
		notice(id, "햇살 쉼터로 귀환했습니다. E로 회복 / 보급")
		return true
	if kind == "interact":
		if p.pos.distance_to(map.spawn) < 2.5:
			p.hp = p.max_hp
			if p.potions < 5 and p.gold >= 10:
				if Inventory.add_stack(p,"potion",1):p.gold -= 10
			dirty[id] = true
			notice(id, "쉼터에서 기운을 되찾았습니다. 물약 보급: 10 금화")
			return true
		var nearby=drops.keys()
		nearby.sort_custom(func(a,b):return p.pos.distance_squared_to(drops[a].pos)<p.pos.distance_squared_to(drops[b].pos))
		for item_id in nearby:
			var drop = drops[item_id]
			if drop.owner != id or p.pos.distance_to(drop.pos) > 1.8: continue
			if drop.item.get("category","") in ["consumable","material"]:
				var kind_name="potion" if drop.item.category=="consumable" else drop.item.material
				var amount=int(drop.item.get("amount",1))
				var accepted=mini(amount,Inventory.MAX_POTIONS-p.potions) if kind_name=="potion" else amount
				if accepted<=0 or not Inventory.add_stack(p,kind_name,accepted):
					notice(id,"가방 또는 물약 묶음이 가득 찼습니다. 전리품은 바닥에 남습니다.")
					continue
				drop.item.amount=amount-accepted
				if drop.item.amount<=0:drops.erase(item_id)
				gear_changed(p);notice(id,drop.item.name+" ×"+str(accepted)+" 획득")
				return true
			if not Inventory.add_gear(p,drop.item):
				notice(id, "가방이 가득 찼습니다.")
				continue
			var slot=drop.item.get("slot","weapon")
			if p.equipment.get(slot,"")=="":Inventory.equip(p,drop.item.id)
			drops.erase(item_id)
			gear_changed(p)
			notice(id, drop.item.name + " 획득 · I로 장착")
			return true
	if kind == "equip":
		if Inventory.equip(p,argument):
			gear_changed(p)
			notice(id,Inventory.find_item(p,argument).name+" 장착")
			return true
		notice(id,"장착을 바꿀 가방 공간이 부족하거나 올바른 장비가 아닙니다.")
		return false
	if kind=="unequip":
		if Inventory.unequip(p,argument):
			gear_changed(p)
			return true
		notice(id,"장비를 벗으려면 가방에 빈자리가 필요합니다.")
		return false
	if kind=="move_item" or kind=="unequip_to":
		var move=JSON.parse_string(argument)
		if not move is Dictionary or not move.get("id") is String or not move.get("rotated") is bool:return false
		if not move.get("x") is float or not move.get("y") is float:return false
		var moved=Inventory.unequip_to(p,str(move.get("slot","")),move.id,Vector2i(int(move.x),int(move.y)),move.rotated) if kind=="unequip_to" else Inventory.move_item(p,move.id,Vector2i(int(move.x),int(move.y)),move.rotated)
		if moved:
			gear_changed(p)
			return true
		return false
	if kind=="invest":
		if not Content.can_invest(p,argument):
			notice(id,"스킬 포인트와 선행 스킬을 확인하세요. 최대 3랭크입니다.")
			return false
		p.skill_ranks[argument]=int(p.skill_ranks.get(argument,0))+1
		gear_changed(p)
		return true
	if kind=="reset_skills" or kind=="class":
		if not map.in_town(p.pos):
			notice(id,"직업 변경과 스킬 초기화는 쉼터에서 가능합니다.")
			return false
		if kind=="class":
			if not Content.CLASSES.has(argument):return false
			if p.class_id==argument:return true
			p.class_id=argument
		p.skill_ranks.clear()
		p.skill_loadout.clear()
		gear_changed(p)
		notice(id,"스킬 포인트를 돌려받았습니다. "+Content.CLASSES[p.class_id].name)
		return true
	if kind=="costume":
		if not Content.COSTUMES.has(argument):return false
		p.costume=argument
		dirty[id]=true
		return true
	if kind=="avatar":
		if argument!="auto" and not Content.AVATARS.has(argument):return false
		p.avatar=argument;p.costume="none";dirty[id]=true
		return true
	if kind=="claim_starters":
		if not map.in_town(p.pos) or p.training_given:return false
		var staged=p.duplicate(true)
		for weapon in Content.WEAPONS:
			var item={"id":"training-"+weapon,"name":"연습용 "+Content.WEAPONS[weapon].name,"category":"weapon","slot":"weapon","weapon_type":weapon,"bonus":0,"rarity":0}
			if not Inventory.add_gear(staged,item):
				notice(id,"연습 무기 4종을 받으려면 가방에 넉넉한 빈자리가 필요합니다.")
				return false
		p.inventory=staged.inventory
		p.bag_positions=staged.bag_positions
		p.training_given=true
		if p.equipped=="":Inventory.equip(p,"training-sword")
		gear_changed(p)
		notice(id,"검·도끼·활·지팡이를 받았습니다. 가방에서 장착해 보세요.")
		return true
	if kind == "discard":
		for index in range(p.inventory.size()):
			if p.inventory[index].id == argument:
				if Inventory.is_equipped(p,argument):
					notice(id, "장착 중인 무기는 정리할 수 없습니다. 다른 무기를 먼저 장착하세요.")
					return false
				p.inventory.remove_at(index)
				p.bag_positions.erase(argument)
				p.gold += 3
				dirty[id] = true
				notice(id, "무기를 정리했습니다. 금화 +3")
				return true
	return false

func kill(id: int, enemy: Dictionary):
	var p = players[id]
	var config = balance.enemies[enemy.kind]
	enemy.hp = 0
	enemy.respawn = config.respawn
	enemy.windup = 0.0
	enemy["slow_time"]=0.0;enemy["stun_time"]=0.0
	p.xp += roundi(config.xp*(1+Content.skill_bonus(p,"xp_bonus")))
	p.gold += roundi(config.gold*(1+Content.skill_bonus(p,"gold_bonus")+preload("res://scripts/equipment_catalog.gd").bonus(p,"gold_bonus")))
	p.kills += 1
	if not p.guild_contract.is_empty() and p.guild_contract.zone==map.zone:p.guild_contract.progress=mini(p.guild_contract.target,int(p.guild_contract.progress)+1)
	if enemy.get("boss",enemy.kind=="warden"):
		p.boss_kills += 1;p.dungeon_clears[map.zone]=int(p.dungeon_clears.get(map.zone,0))+1
		notice(id,"보스 격파 · "+enemy.name+" · R로 마을 귀환")
	while p.xp >= Progression.xp_required(p.level) and p.level < 100:
		p.xp -= Progression.xp_required(p.level)
		p.level += 1
		recalculate(p)
		p.hp = p.max_hp
		notice(id, "LEVEL UP · %d · 스킬 +1 / 능력치 +3 · K에서 투자" % p.level)
	if p.kills >= 5 and p.boss_kills >= 1 and not p.quest_done:
		p.quest_done = true
		p.gold += 100
		notice(id, "의뢰 완료 · 정원의 소란 · 금화 +100")
	for entry in loot_tables.roll(enemy.kind,rng):
		serial += 1
		var item_id = str(Time.get_unix_time_from_system()).replace(".", "") + "-" + str(serial)
		var item=loot_tables.item(entry,item_id,rng,balance)
		if item.category in ["weapon","armor","accessory"]:
			var type=item.get("weapon_type","sword") if item.category=="weapon" else item.slot
			var tier=clampi(int(preload("res://scripts/world_catalog.gd").DUNGEONS[map.zone].theme)+rng.randi_range(0,1)+(1 if enemy.get("boss",false) or enemy.get("elite",false) else 0),0,4)
			var affixes=preload("res://scripts/equipment_catalog.gd").AFFIXES.keys()
			item=preload("res://scripts/equipment_catalog.gd").make(type,tier,int(item.rarity),item_id,affixes[rng.randi_range(0,affixes.size()-1)])
		var offset=Vector2.from_angle(serial*2.399)*rng.randf_range(.15,.8)
		drops[item_id] = {"item":item,"pos":map.move(enemy.pos,offset),"owner":id,"expires":clock + 90.0}
	dirty[id]=true

func tick(delta: float):
	clock += delta
	for p in players.values():
		p.input_age += delta
		if p.input_age > 0.35: p.dir = Vector2.ZERO;p.sprint=false
		for key in ["attack_cd","nova_cd","potion_cd","return_cd","swing"]:
			p[key] = maxf(0, p[key] - delta)
		combat.tick_player(p,delta)
	combat.tick_projectiles(delta)
	combat.skills.tick(delta)
	monster_attacks.tick(delta)
	for e in enemies.values():
		var config = balance.enemies[e.kind]
		e.attack_motion=maxf(0,e.get("attack_motion",0)-delta)
		if e.hp <= 0:
			e.respawn -= delta
			if e.respawn <= 0:
				e.hp = e.max_hp
				e.pos = e.home
			continue
		e.cooldown = maxf(0, e.cooldown - delta)
		e.ability_cd=maxf(0,e.get("ability_cd",4)-delta)
		e.phase=2 if e.get("boss",false) and e.hp<e.max_hp*.5 else 1
		if config.ai=="healer" and e.ability_cd<=0:
			for friend in enemies.values():
				if friend.hp>0 and friend.pos.distance_to(e.pos)<3:friend.hp=mini(friend.max_hp,friend.hp+12)
			e.ability_cd=6;events.append({"type":"skill_fx","fx":"ranger_heal","pos":e.pos,"dir":Vector2.RIGHT,"owner":1,"duration":.6,"radius":2.0})
		e["slow_time"]=maxf(0,e.get("slow_time",0)-delta)
		e["stun_time"]=maxf(0,e.get("stun_time",0)-delta)
		if e.stun_time>0:e.windup=0;e.erase("attack_areas");continue
		var move_speed=config.speed*(0.45 if e.slow_time>0 else 1.0)
		if config.ai=="charger" and e.ability_cd<1.0:move_speed*=2.2
		if e.windup > 0:
			e.windup -= delta
			if e.windup <= 0:
				e.attack_motion=.35
				if not e.get("boss",false):
					monster_attacks.release(e);e.cooldown=1.7 if e.get("elite",false) else 1.25;continue
				if e.get("boss",false):
					events.append({"type":"skill_fx","fx":{"warden":"ranger_field","golem":"mage_burst","sentinel":"warrior_nova_ring"}[e.kind],"pos":e.attack_pos,"dir":Vector2.RIGHT,"owner":1,"duration":.8,"radius":config.range,"sound":"heavy"})
				for p in players.values():
					var impact=.9 if config.ai in ["ranged","healer"] else config.range
					if p.invulnerable<=0 and not map.in_town(p.pos) and p.pos.distance_to(e.attack_pos) <= impact and map.line_clear(e.pos, p.pos):
						var received=maxi(1,roundi(config.damage*(1.25 if e.phase==2 else 1.0))-p.defense)
						if p.barrier_time>0:received=maxi(1,roundi(received*(1-p.barrier_strength)))
						p.combat_time=4.0
						var reflected=int(Content.skill_bonus(p,"thorns"))
						if reflected>0 and e.pos.distance_to(p.pos)<2:combat.hit(p,e,reflected)
						p.hp -= received
						p.hurt_time=.16
						if config.ai=="spore":p.stamina=maxf(0,p.stamina-12)
						events.append({"type":"damage","pos":p.pos,"amount":received,"enemy":false,"owner":p.id})
						if p.hp <= 0:
							p.gold = int(p.gold * 0.9)
							p.hp = p.max_hp
							p.pos = map.spawn
							p.dir = Vector2.ZERO
							dirty[p.id] = true
							notice(p.id, "쓰러졌습니다. 금화 10%를 잃고 마을에서 회복했습니다.")
				e.cooldown = 1.8 if e.get("boss",false) else 1.2
			continue
		var target: Dictionary = {}
		var best = 6.5
		for p in players.values():
			var distance = e.pos.distance_to(p.pos)
			if distance < best and not map.in_town(p.pos) and p.pos.distance_to(e.home) < 8 and map.line_clear(e.pos, p.pos):
				best = distance
				target = p
		if target.is_empty():
			e.pos = map.move(e.pos, (e.home - e.pos).limit_length(move_speed * delta))
		elif best <= config.range and e.cooldown <= 0:
			e.windup = 1.0 if e.get("boss",false) else .65 if config.ai in ["ranged","spore"] else .5
			e.attack_pos = target.pos
			if not e.get("boss",false):
				e.windup=.9 if e.get("elite",false) or e.kind in ["mole","orc_axeman","bat"] else .65 if config.ai in ["ranged","healer"] else .5
				monster_attacks.begin(e,target.pos)
			e.pattern=int(e.get("pattern",0))+1
			if e.kind=="golem" and e.pattern%3==0 and map.line_clear(e.pos,target.pos):e.pos=map.move(e.pos,e.pos.direction_to(target.pos)*minf(1.0,best))
		elif config.ai in ["ranged","healer"] and best<2.0:
			e.pos=map.move(e.pos,target.pos.direction_to(e.pos)*move_speed*delta)
		elif best > config.range * 0.8:
			e.pos = map.move(e.pos, e.pos.direction_to(target.pos) * minf(best,move_speed * delta))
		if config.ai=="charger" and e.ability_cd<=0:e.ability_cd=3.0
	for key in drops.keys():
		if drops[key].expires <= clock: drops.erase(key)

func snapshot(for_id: int) -> Dictionary:
	var visible_players = {}
	for id in players:
		var p = players[id].duplicate(true)
		if id != for_id:
			p.erase("inventory")
			p.erase("gold")
		visible_players[id] = p
	var visible_drops = {}
	for id in drops:
		if drops[id].owner == for_id: visible_drops[id] = drops[id].duplicate(true)
	return {"players":visible_players,"enemies":enemies.duplicate(true),"drops":visible_drops,"clock":clock,"projectiles":combat.projectiles.duplicate(true),"enemy_attacks":monster_attacks.zones.duplicate(true)}
