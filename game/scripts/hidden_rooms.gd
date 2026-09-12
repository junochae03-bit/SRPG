extends RefCounted
## Optional geometry is absent until a nearby clue is opened by the party.
const DISCOVERY_RADIUS=4.0
const ROOM_RADIUS=4
const Inventory=preload("res://scripts/inventory_model.gd")
static func generate(map)->Array:
	if map.floor_number<=0 or map.raid_arena:return []
	var result=[];var rng=RandomNumberGenerator.new();rng.seed=map.seed_value+89519
	var directions=[Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2(1,1).normalized(),Vector2(-1,1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]
	var first=rng.randi_range(1,7)
	var candidates=[]
	for offset in range(7):
		var room=1+(first+offset)%7
		for direction in directions:
			candidates.append(Vector2i((Vector2(map.rooms[room])+direction*(map.room_radii[room]+8)).round()))
	# Interior voids supply a pocket when all perimeter anchors touch the edge.
	for y in range(6,map.SIZE-6,4):
		for x in range(6,map.SIZE-6,4):candidates.append(Vector2i(x,y))
	for center in candidates:
		if center.x<6 or center.y<6 or center.x>map.SIZE-7 or center.y>map.SIZE-7:continue
		if result.any(func(region):return Vector2(center).distance_to(region.center)<13):continue
		var free=true
		for dx in range(-5,6):
			for dy in range(-5,6):
				if map.floor_cells.has(center+Vector2i(dx,dy)):free=false;break
			if not free:break
		if not free:continue
		var clue=Vector2.ZERO;var nearest=INF
		for cell in map.floor_cells:
			var distance=Vector2(center).distance_squared_to(Vector2(cell))
			if distance<nearest:nearest=distance;clue=Vector2(cell)
		if nearest>144 or clue.distance_to(map.spawn)<10:continue
		result.append({"id":"hidden_%d"%result.size(),"kind":"secret","pos":clue,"center":Vector2(center),"room":-1,"tool":result.size()==1,"tier":int((map.floor_number-1)/10),"generation":"%d.%s.%d"%[map.seed_value,map.zone,map.floor_number]})
		if result.size()==2:return result
	return result
static func discover(sim):
	for region in sim.map.hidden_regions:
		if sim.map.revealed_regions.has(region.id):continue
		for p in sim.players.values():
			if p.hp>0 and p.pos.distance_to(region.pos)<=DISCOVERY_RADIUS and sim.map.line_clear(p.pos,region.pos):
				sim.map.revealed_regions[region.id]=true
				for id in sim.players:sim.notice(id,"벽 틈에서 바람이 느껴집니다.")
				break
static func open(map,id:String)->bool:
	if map.opened_regions.has(id):return false
	for region in map.hidden_regions:
		if region.id!=id:continue
		map.carve_room(Vector2i(region.center),ROOM_RADIUS,0)
		map.carve_segment(Vector2i(region.pos),Vector2i(region.center),1)
		map.opened_regions[id]=true;map.revealed_regions[id]=true;map.revision+=1
		return true
	return false
static func synchronize(map,opened:Array,discovered:Array):
	for id in discovered:
		if map.hidden_regions.any(func(region):return region.id==id):map.revealed_regions[id]=true
	for id in opened:open(map,id)
static func snapshots(sim,id:int)->Array:
	var result=[]
	for region in sim.map.hidden_regions:
		if not sim.map.revealed_regions.has(region.id):continue
		var entry=region.duplicate(true);var opened=sim.map.opened_regions.has(region.id)
		entry.merge({"name":"봉인된 보관실" if region.tool else "바람이 새는 벽","icon":"locked" if region.tool else "search","material":"essence","opened":opened,"claimed":sim.exploration_claims.get(id,{}).has(region.id),"remaining":0})
		if opened:entry.pos=region.center;entry.name="숨겨진 보관실";entry.icon="quest_reward"
		for enemy in sim.enemies.values():
			if enemy.hp>0 and enemy.pos.distance_to(entry.pos)<8:entry.remaining+=1
		result.append(entry)
	return result
static func use(sim,p:Dictionary,argument:String)->bool:
	var parts=argument.split(":")
	if parts.size()!=3:return false
	var choices=snapshots(sim,p.id).filter(func(entry):return entry.generation==parts[0] and entry.id==parts[1])
	if choices.is_empty():return false
	var site=choices[0]
	if p.hp<=0 or p.get("down_time",0)>0 or p.get("network_leaving",false) or p.pos.distance_to(site.pos)>2.8 or not sim.map.line_clear(p.pos,site.pos):return false
	if site.remaining>0:sim.notice(p.id,"주변 적을 먼저 처치하세요.");return false
	if site.claimed:return false
	if parts[2]=="open" and not site.opened:
		if site.tool:
			if p.materials.get("tool",0)<1:sim.notice(p.id,"탐사 도구가 필요합니다. 마을 상점에서 구입할 수 있습니다.");return false
			p.materials.tool-=1
			if p.materials.tool==0:p.bag_positions.erase("@mat:tool")
		open(sim.map,site.id);sim.dirty[p.id]=true;sim.notice(p.id,"숨겨진 길이 열렸습니다.");return true
	if parts[2]!="collect" or not site.opened:return false
	var staged=p.duplicate(true);var amount=3+int(site.tier)
	if not Inventory.add_stack(staged,"essence",amount):sim.notice(p.id,Inventory.stack_failure_reason(p,"essence",amount));return false
	staged.gold+=40+site.tier*20
	for key in ["materials","bag_positions","gold"]:p[key]=staged[key]
	if not sim.exploration_claims.has(p.id):sim.exploration_claims[p.id]={}
	sim.exploration_claims[p.id][site.id]="collect";sim.dirty[p.id]=true;sim.notice(p.id,"정수 +%d · 금화 +%d"%[amount,40+site.tier*20]);return true
