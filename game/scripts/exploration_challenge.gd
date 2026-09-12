extends RefCounted

const Inventory=preload("res://scripts/inventory_model.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
const VARIANTS=[
	{"id":"pack","name":"무리의 습격","count":4,"elite":false,"essence":3},
	{"id":"champion","name":"정예의 반격","count":2,"elite":true,"essence":4}
]

static func configuration()->Dictionary:
	return {"variants":VARIANTS,"generation":"seed_plus_61417","safe_material":"2+tier","challenge_essence":"variant.essence+tier","wave_scope":"one_shared_wave_per_site","reward_scope":"one_personal_choice_per_site","arrival_grace_seconds":1.5,"optional":true}

static func variant(map)->Dictionary:
	var rng=RandomNumberGenerator.new();rng.seed=map.seed_value+61417
	return VARIANTS[rng.randi_range(0,VARIANTS.size()-1)]

static func remaining(sim,site:Dictionary)->int:
	var count=0
	for id in sim.exploration_challenges.get(site.id,[]):
		if sim.enemies.has(id) and sim.enemies[id].hp>0:count+=1
	return count

static func state(sim,site:Dictionary)->String:
	if not sim.exploration_challenges.has(site.id):return "idle"
	return "active" if remaining(sim,site)>0 else "cleared"

static func choices(site:Dictionary)->Array:
	match site.get("challenge_state","idle"):
		"idle":return ["salvage","challenge"]
		"cleared":return ["collect"]
	return []

static func describe(sim,site:Dictionary):
	var spec=variant(sim.map)
	site["challenge_state"]=state(sim,site)
	site["challenge_name"]=spec.name
	site["challenge_count"]=spec.count
	site["challenge_remaining"]=remaining(sim,site)
	site["challenge_reward"]=int(spec.essence)+int(site.tier)

static func use(sim,p:Dictionary,site:Dictionary,choice:String)->bool:
	var phase=state(sim,site)
	if choice=="challenge":
		if phase!="idle":sim.notice(p.id,"이미 시작한 도전입니다.");return false
		# Resolve the entire wave before spawning, so a blocked room cannot
		# consume the choice or leave a partially generated encounter.
		var positions=[];var spec=variant(sim.map)
		for index in range(32):
			var at=site.pos+Vector2.from_angle(index*TAU/16.)*(4.5 if index<16 else 6.)
			if not sim.map.walkable(at) or not sim.map.line_clear(site.pos,at):continue
			if sim.players.values().any(func(player):return player.hp>0 and player.pos.distance_to(at)<3.):continue
			if positions.any(func(other):return other.distance_to(at)<2.):continue
			positions.append(at)
			if positions.size()==int(spec.count):break
		if positions.size()!=int(spec.count):sim.notice(p.id,"도전 공간에서 조금 비켜서세요.");return false
		var config=Abyss.config(sim.map.floor_number);var ids=[]
		for index in range(positions.size()):
			var kind=config.elite if spec.elite and index==0 else config.mobs[posmod(index+sim.map.seed_value,config.mobs.size())]
			var enemy=sim.spawn_enemy(kind,positions[index],config.level)
			enemy["encounter_room"]=site.room;enemy["challenge_site"]=site.id
			enemy["stun_time"]=1.5;enemy.cooldown=1.5
			ids.append(enemy.id)
		preload("res://scripts/party_rules.gd").rescale(sim)
		sim.exploration_challenges[site.id]=ids
		sim.notice(p.id,spec.name+" · 적 %d"%spec.count)
		return true
	if (choice=="salvage" and phase!="idle") or (choice=="collect" and phase!="cleared"):return false
	if choice not in ["salvage","collect"]:return false
	var item=str(site.material) if choice=="salvage" else "essence"
	var amount=2+int(site.tier) if choice=="salvage" else int(variant(sim.map).essence)+int(site.tier)
	var staged=p.duplicate(true)
	if not Inventory.add_stack(staged,item,amount):sim.notice(p.id,Inventory.stack_failure_reason(p,item,amount));return false
	p.materials=staged.materials;p.bag_positions=staged.bag_positions
	if not sim.exploration_claims.has(p.id):sim.exploration_claims[p.id]={}
	sim.exploration_claims[p.id][site.id]=choice;sim.dirty[p.id]=true
	sim.notice(p.id,preload("res://scripts/content.gd").MATERIALS[item]+" +%d"%amount)
	return true
