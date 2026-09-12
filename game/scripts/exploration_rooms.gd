extends RefCounted

const Inventory=preload("res://scripts/inventory_model.gd")
const Content=preload("res://scripts/content.gd")
const REACH=2.8
const THREAT_RADIUS=8.0
const DEFINITIONS={
	"gather":{"name":"마력 광맥","icon":"ore","choices":["gather"],"purpose":"재료 채집"},
	"rest":{"name":"여행자의 화로","icon":"inn","choices":["rest"],"purpose":"중간 휴식"},
	"shrine":{"name":"갈림길의 제단","icon":"essence","choices":["recover","offering"],"purpose":"회복 또는 정수"}
}
const SITE_ART={"ore":"cave_ore_boulders","seed":"autumn_berry_shrub","rest":"lava_forge_brazier","shrine":"ruins_stone_basin"}

static func draw_site(game,site:Dictionary):
	if site.kind=="secret":
		var at=game.world_point(site.pos)
		var data=preload("res://scripts/environment_art.gd").frame("flood_shipwreck_crate" if site.opened else "ruins_rubble")
		var scale_value=(85. if site.opened else 55.)/data.height
		game.draw_texture_rect(data.texture,Rect2(at-data.foot*scale_value,data.texture.get_size()*scale_value),false,Color(.65,.65,.65,.65) if site.claimed else Color.WHITE)
		preload("res://scripts/icon_library.gd").draw(game,"confirm" if site.claimed else site.icon,Rect2(at+Vector2(25,-30),Vector2(26,26)))
		return
	var art_id=SITE_ART[site.material if site.kind=="gather" else site.kind]
	var data=preload("res://scripts/environment_art.gd").frame(art_id)
	var scale_value=100.0/float(data.height);var at=game.world_point(site.pos)
	var dimensions=data.texture.get_size()*scale_value
	game.draw_texture_rect(data.texture,Rect2(at-data.foot*scale_value,dimensions),false,Color(.7,.7,.7,.65) if site.claimed else Color.WHITE)
	preload("res://scripts/icon_library.gd").draw(game,"confirm" if site.claimed else site.icon,Rect2(at+Vector2(24,-25),Vector2(26,26)))

static func configuration()->Dictionary:
	return {"version":1,"definitions":DEFINITIONS.duplicate(true),"site_art":SITE_ART,"interaction_radius":REACH,"threat_radius":THREAT_RADIUS,"sites_per_floor":3,"sites_per_raid":1,"claim_scope":"one_per_player_per_generated_floor","generation":"independent_seed_plus_57103","request_generation_format":"seed.zone.floor","reward_tier":"floor((floor-1)/10)","gather_amount":"3+tier","offering_potions":1,"offering_essence":"2+tier","shrine_recovery":0.35,"rest_hp_stamina":1.0}

static func generate(map)->Array:
	if map.floor_number<=0:return []
	var generation="%d.%s.%d"%[map.seed_value,map.zone,map.floor_number]
	if map.raid_arena:return [{"id":"room_1","room":1,"kind":"rest","pos":Vector2(map.rooms[1]),"material":"ore","tier":int((map.floor_number-1)/10),"generation":generation}]
	var rng=RandomNumberGenerator.new();rng.seed=map.seed_value+57103
	var pool=[1,2,3,4,5,6,7]
	for index in range(pool.size()-1,0,-1):
		var other=rng.randi_range(0,index);var before=pool[index];pool[index]=pool[other];pool[other]=before
	var result=[];var kinds=DEFINITIONS.keys()
	for index in range(3):
		var kind=kinds[index];var room=int(pool[index]);var pos=Vector2(map.rooms[room])
		var material="seed" if map.zone=="forest" else "ore"
		result.append({"id":"room_%d"%room,"room":room,"kind":kind,"pos":pos,"material":material,"tier":int((map.floor_number-1)/10),"generation":generation})
	return result

static func nearest(sites:Array,pos:Vector2)->Dictionary:
	var result={};var distance=REACH
	for site in sites:
		var current=pos.distance_to(site.pos)
		if current<=distance:result=site;distance=current
	return result

static func threats(sim,site:Dictionary)->int:
	var count=0
	for enemy in sim.enemies.values():
		if enemy.hp>0 and (enemy.get("encounter_room",-1)==site.room or enemy.pos.distance_to(site.pos)<THREAT_RADIUS):count+=1
	return count

static func snapshot(sim,id:int)->Array:
	var result=[];var claims=sim.exploration_claims.get(id,{})
	for original in sim.map.exploration_sites:
		var site=original.duplicate(true);var definition=DEFINITIONS[site.kind]
		site.merge({"name":definition.name,"icon":definition.icon,"claimed":claims.has(site.id),"remaining":threats(sim,site)})
		if site.kind=="gather":site.name="별씨앗 군락" if site.material=="seed" else "반짝 광맥";site.icon=site.material
		result.append(site)
	result.append_array(preload("res://scripts/hidden_rooms.gd").snapshots(sim,id))
	return result

static func failure(sim,p:Dictionary,site:Dictionary)->String:
	if p.get("down_time",0)>0 or p.get("network_leaving",false) or p.hp<=0:return "지금은 이용할 수 없습니다."
	if p.pos.distance_to(site.pos)>REACH or not sim.map.line_clear(p.pos,site.pos):return "가까이 다가가세요."
	if sim.exploration_claims.get(p.id,{}).has(site.id):return "이미 이용했습니다."
	if threats(sim,site)>0:return "주변 적을 먼저 처치하세요."
	return ""

static func use(sim,p:Dictionary,argument:String)->bool:
	var parts=argument.split(":")
	if parts.size()!=3:return false
	if parts[1].begins_with("hidden_"):return preload("res://scripts/hidden_rooms.gd").use(sim,p,argument)
	var site={}
	for entry in sim.map.exploration_sites:
		if entry.id==parts[1] and entry.generation==parts[0]:site=entry;break
	if site.is_empty() or parts[2] not in DEFINITIONS[site.kind].choices:return false
	var reason=failure(sim,p,site)
	if not reason.is_empty():sim.notice(p.id,reason);return false
	# Stage both cost and reward. A full bag or potion shortage must leave
	# the choice, inventory, currency and per-player claim untouched.
	var staged=p.duplicate(true);var message=""
	match parts[2]:
		"gather":
			var amount=3+int(site.tier)
			if not Inventory.add_stack(staged,site.material,amount):sim.notice(p.id,Inventory.stack_failure_reason(p,site.material,amount));return false
			message=Content.MATERIALS[site.material]+" ×%d"%amount
		"rest":
			if p.hp>=p.max_hp and p.stamina>=p.max_stamina:sim.notice(p.id,"생명력과 기력이 가득 찼습니다.");return false
			staged.hp=p.max_hp;staged.stamina=p.max_stamina;message="생명력 · 기력 회복"
		"recover":
			if p.hp>=p.max_hp:sim.notice(p.id,"생명력이 가득 찼습니다.");return false
			var amount=mini(p.max_hp-p.hp,maxi(1,roundi(p.max_hp*.35)))
			staged.hp+=amount;message="생명력 +%d"%amount
		"offering":
			if p.potions<1:sim.notice(p.id,"물약 1개가 필요합니다.");return false
			staged.potions-=1
			if staged.potions==0:staged.bag_positions.erase("@potion")
			var amount=2+int(site.tier)
			if not Inventory.add_stack(staged,"essence",amount):sim.notice(p.id,Inventory.stack_failure_reason(staged,"essence",amount));return false
			message="물약 −1 · 정수 +%d"%amount
	for key in ["hp","stamina","potions","materials","bag_positions"]:p[key]=staged[key]
	if not sim.exploration_claims.has(p.id):sim.exploration_claims[p.id]={}
	sim.exploration_claims[p.id][site.id]=parts[2]
	sim.dirty[p.id]=true
	sim.notice(p.id,message)
	return true

static func interact(sim,p:Dictionary)->bool:
	var site=nearest(snapshot(sim,p.id),p.pos)
	if site.is_empty():return false
	if site.kind=="secret":return use(sim,p,site.generation+":"+site.id+(":collect" if site.opened else ":open"))
	if site.kind=="shrine":
		var reason=failure(sim,p,site)
		sim.notice(p.id,reason if not reason.is_empty() else "제단에서 회복 또는 정수를 선택하세요.")
		return false
	return use(sim,p,site.generation+":"+site.id+":"+str(DEFINITIONS[site.kind].choices[0]))
