extends RefCounted
# Read-only encyclopedia and export share live gameplay catalogues. No saved state.
const Content=preload("res://scripts/content.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
const EquipmentArt=preload("res://scripts/equipment_art.gd")
const World=preload("res://scripts/world_catalog.gd")
const WorldArt=preload("res://scripts/world_art.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
const Scaling=preload("res://scripts/skill_scaling.gd")
const Jobs=preload("res://scripts/job_balance.gd")
const Attacks=preload("res://scripts/monster_attacks.gd")
const Build=preload("res://scripts/skill_build.gd")
const REFERENCE={"damage":100.0,"max_hp":1000,"level":100,"technique":0,"note":"공격력 100 / 최대 HP 1000 / 기술 0 / 장비·별자리·다른 패시브·직업 자원 보정 없음. 강화 노드는 원기술 3랭크 기준. 실전 피해·쿨타임은 캐릭터와 적 상태에 따라 달라집니다."}
static var _cache:Dictionary={}
static var _art_cache:Dictionary={}
static var _textures:Dictionary={}

static func reset_cache():
	_cache.clear();_art_cache.clear();_textures.clear()

static func snapshot(include_art:bool=false)->Dictionary:
	if not _cache.is_empty():return _with_art() if include_art else _cache
	Content.initialize_jobs()
	if Build.nodes_for("warrior").is_empty():Build.initialize(Content.SKILLS,Content.CLASSES)
	var db={"metadata":{"schema_version":2,"reference":REFERENCE,"drop_note":"기본 드랍은 항목별 독립 판정. 레이드 추가 장비 1개는 기본 드랍과 별도이며 등급 확률 합계만 100%.","build_policy":{"version":Build.BUILD_VERSION,"max_keystones":Build.MAX_KEYSTONES,"point_budget":"level-1, shared with original skill ranks","baseline_allocations":{}}},"classes":[],"equipment":[],"monsters":[],"raids":[],"floors":[],"appearances":[],"drops":[],"raid_drops":[],"skills":[],"skill_parents":[],"skill_ranks":[],"build_nodes":[],"constellations":[],"constellation_edges":[],"exclusive_groups":[],"effect_definitions":[],"constellation_effects":[],"constellation_exclusions":[]}
	var class_ids=Content.CLASSES.keys();class_ids.sort()
	for class_id in class_ids:
		var c=Content.CLASSES[class_id].duplicate(true)
		c.merge({"id":class_id,"family":Content.base_class(class_id),"family_name":Equipment.FAMILY_NAMES[Content.base_class(class_id)]},true);db.classes.append(c)
		for tier in range(10):
			for grade in range(5):db.equipment.append(_equipment("sword",class_id,tier,grade))
	var families=Equipment.FAMILY_NAMES.keys();families.sort()
	for family in families:
		for slot in Content.SLOTS:
			if slot=="weapon":continue
			for tier in range(10):
				for grade in range(5):db.equipment.append(_equipment(slot,family,tier,grade))
	var monster_ids=World.ENEMIES.keys();monster_ids.sort()
	for kind in monster_ids:
		var m=World.ENEMIES[kind].duplicate(true)
		m.merge({"id":kind,"kind":kind,"monster_id":kind,"role":"boss" if m.ai=="boss" else "elite" if m.get("elite",false) else "normal","level":0,"floors":[],"asset":_monster_asset(kind),"display_height":World.display_height(kind)},true)
		m["patterns"]=_patterns(kind);m["description"]=_pattern_text(m.patterns)
		if m.ai=="boss":m["stagger"]=_boss_stagger(0)
		m["subtitle"]={"normal":"일반 몬스터","elite":"엘리트","boss":"보스 기본형"}[m.role]+" · 기본 수치 (층별 수치는 출현 정보 참조)"
		db.monsters.append(m)
	for floor_number in range(1,101):
		var f=Abyss.config(floor_number)
		f["art_theme"]=preload("res://scripts/environment_art.gd").theme(f.terrain,floor_number)
		f["environment_ids"]=preload("res://scripts/environment_art.gd").ids(f.terrain,floor_number)
		f["id"]=floor_number;f["required_level"]=maxi(1,floor_number-7);f["tier"]=int((floor_number-1)/10)
		f["guardian_id"]=f.boss if f.raid else f.elite;f["raid_id"]="raid:%03d"%floor_number if f.raid else ""
		f["description"]=f.lore;db.floors.append(f)
		for kind in f.mobs:_appearance(db,f,kind,"normal")
		_appearance(db,f,f.elite,"elite")
		_appearance(db,f,f.guardian_id,"raid" if f.raid else "guardian")
		if f.raid:
			var r=Abyss.enemy_stats(f.boss,floor_number,true,true)
			r.merge({"id":f.raid_id,"name":f.title,"kind":f.boss,"monster_id":f.boss,"role":"raid","floor":floor_number,"floors":[floor_number],"level":f.level,"asset":_monster_asset(f.boss,floor_number,true),"display_height":World.display_height(f.boss),"patterns":_raid_patterns(floor_number),"description":f.lore,"subtitle":"B%d 레이드 · LV.%d"%[floor_number,f.level]},true)
			r["stagger"]=_boss_stagger(floor_number)
			db.raids.append(r)
			for grade in range(2,5):
				var chance=_grade_tail(floor_number,grade)-_grade_tail(floor_number,grade+1)
				if chance<=.00000001:continue
				db.raid_drops.append({"id":"raid-drop:%03d:%d"%[floor_number,grade],"raid_id":f.raid_id,"floor":floor_number,"monster_id":f.boss,"monster_name":f.title,"name":Equipment.GRADES[grade]+" 추가 장비","kind":"equipment","slot":"any","rarity":grade,"grade_name":Equipment.GRADES[grade],"chance":snappedf(chance,.000000001),"amount":1,"roll_mode":"guaranteed_extra_conditional_grade","slot_probability":1.0/Content.SLOTS.size(),"slots":Content.SLOTS,"tier":f.tier,"description":"레이드 격파 시 추가 장비 1개 확정. 그 1개의 등급 확률입니다. 7개 부위는 균등 선택, 무기는 현재 직업 전용·방어구는 계열 공용.","subtitle":"B%d · %s · 추가 장비 내 %.0f%%"%[floor_number,f.title,chance*100],"asset":_equipment("sword","warrior",f.tier,grade).asset})
	for m in db.monsters:
		for a in db.appearances:
			if a.monster_id==m.id and not m.floors.has(a.floor_id):m.floors.append(a.floor_id)
	var tables=preload("res://scripts/loot_tables.gd").new().tables
	for kind in monster_ids:
		for entry in tables[kind]:
			var d=entry.duplicate(true);var item={"category":d.kind,"slot":d.get("slot","weapon"),"weapon_type":d.get("weapon",d.get("weapons",["sword"])[0])}
			if d.kind=="material":item.material=d.material
			var name=Content.MATERIALS[d.material] if d.kind=="material" else "회복 물약" if d.kind=="consumable" else Equipment.GRADES[int(d.get("rarity",0))]+" "+("현재 직업 무기" if d.kind=="weapon" else Content.SLOT_NAMES[d.slot])
			d.merge({"id":"drop:"+kind+":"+d.key,"monster_id":kind,"monster_name":World.ENEMIES[kind].name,"name":name,"rarity":int(d.get("rarity",0)),"amount":int(d.get("amount",1)),"roll_mode":"independent_per_entry","slot":"weapon" if d.kind=="weapon" else d.get("slot",""),"asset":_item_asset(item),"description":"항목별 독립 판정입니다. 장비 부위·등급은 이 행을 따르고, 무기 형태는 처치한 캐릭터의 전용 무기로 변환됩니다. 던전 장비 단계는 해당 층에 따릅니다." if d.kind in ["weapon","armor","accessory"] else "항목별 독립 판정입니다. 다른 항목과 동시에 드랍될 수 있습니다.","subtitle":World.ENEMIES[kind].name+" · 독립 "+Scaling.number(float(d.chance)*100)+"%"},true)
			db.drops.append(d)
	for class_id in class_ids:
		for node in Content.SKILLS[class_id]:
			var s=node.duplicate(true)
			s.merge({"class_id":class_id,"class_name":Content.CLASSES[class_id].name,"family":Content.base_class(class_id),"node":node.duplicate(true),"max_rank":Content.max_rank(node),"asset":_texture_ref(preload("res://scripts/icon_art.gd").skill(node)),"ranks":[],"subtitle":Content.CLASSES[class_id].name+" · "+("액티브" if node.effect=="active" else "강화" if node.effect=="upgrade" else "패시브")},true)
			for parent_id in node.parents:db.skill_parents.append({"skill_id":node.id,"parent_id":parent_id,"required_rank":int(node.get("required_rank",1)),"mode":node.get("parent_mode","any")})
			for rank in range(1,s.max_rank+1):
				var r=_skill_rank(class_id,node,rank);s.ranks.append(r);db.skill_ranks.append(r)
			db.skills.append(s)
	var groups={};var effect_ids={}
	for class_id in class_ids:
		for n in Build.nodes_for(class_id):
			db.build_nodes.append({"id":n.id,"class_id":class_id,"type":n.type,"cost":n.cost,"max_rank":n.max_rank,"required_level":int(n.get("level",1)),"exclusive_group":n.exclusive_group})
			if n.type=="original":continue
			var row=n.duplicate(true)
			row["node"]=n.duplicate(true);row["class_name"]=Content.CLASSES[class_id].name;row["asset"]=_texture_ref(preload("res://scripts/icon_art.gd").skill(n));row["subtitle"]=Content.CLASSES[class_id].name+" · "+n.cluster_name+" · %dSP"%n.cost
			row["description"]=n.description+"\n연결: "+n.synergy+"\n조건·대가: "+n.tradeoff if n.type!="minor" else n.description
			row["ranks"]=[{"skill_id":n.id,"rank":1,"metrics":[["별자리 효과",n.effects_text],["공유 SP 비용",str(n.cost)],["최대 핵심 선택",str(Build.MAX_KEYSTONES)]],"profile":{"effects":n.effects},"stagger":{"base":0.,"value":0.,"grade":"직접 타격 없음","multiplier":1.}}]
			db.constellations.append(row)
			if not n.exclusive_group.is_empty():groups[n.exclusive_group]={"id":n.exclusive_group,"class_id":class_id,"max_selected":1}
			for parent in n.parents:db.constellation_edges.append({"node_id":n.id,"parent_id":parent,"required_rank":n.required_rank,"mode":n.parent_mode})
			for other in n.get("exclusive_with",[]):
				if n.id<other:db.constellation_exclusions.append({"left_id":n.id,"right_id":other})
			for effect_id in n.effects:
				effect_ids[effect_id]={"id":effect_id,"name":Build.effect_label(effect_id)}
				db.constellation_effects.append({"node_id":n.id,"effect_id":effect_id,"value":n.effects[effect_id]})
	db.exclusive_groups=groups.values();db.effect_definitions=effect_ids.values()
	_cache=db
	return _with_art() if include_art else _cache

static func _with_art()->Dictionary:
	# Management export only. The game/codex uses snapshot() without this flag,
	# so packed .gdc scripts never enter the development source-call scanner.
	if _art_cache.is_empty():
		_art_cache=_cache.duplicate()
		_art_cache["metadata"]=_cache.metadata.duplicate(true)
		_art_cache.merge(preload("res://scripts/art_registry.gd").snapshot(_cache))
		_art_cache.metadata.schema_version=3
		_art_cache.metadata.art_registry_note="실제 카탈로그·소비 경로에 연결된 영역. 플레이 중 그린 횟수는 아니며 파일 SHA256·출처 검증은 portable DB 생성 시 기록합니다."
	return _art_cache

static func _equipment(slot:String,owner:String,tier:int,grade:int)->Dictionary:
	var id="eq:%s:%s:%02d:%d"%[owner,"weapon" if slot=="sword" else slot,tier,grade]
	var e=Equipment.make(slot,tier,grade,id,"focus",owner)
	e.merge({"grade_name":Equipment.GRADES[grade],"grade_color":Equipment.COLORS[grade].to_html(),"slot_name":Content.SLOT_NAMES[e.slot],"restriction":Equipment.restriction_text(e),"option_unlock":Equipment.UNLOCK[grade],"option_summary":_option_summary(e),"subtitle":Equipment.GRADES[grade]+" · "+Equipment.restriction_text(e),"description":"기본 강화 +0 기준. 도감은 부위·착용 직업/계열·단계·등급의 조합이며 실제 전리품의 추가 옵션은 별도 결정됩니다.","asset":_item_asset(e)},true)
	return e

static func _item_asset(item:Dictionary)->Dictionary:
	# Database rows need source coordinates, not decoded/keyed atlas pixels.
	# Visible cards still resolve their texture lazily through asset_texture().
	if item.get("category","") in ["weapon","armor","accessory"]:
		var key=EquipmentArt.key(item)
		if not key.is_empty():
			EquipmentArt.initialize()
			var entry=EquipmentArt.catalog.get(key,{})
			if entry is Dictionary:
				var rect=entry.get("rect",[]);var path=str(entry.get("sheet",""))
				# Source PNGs may be replaced by prepared RGBA in exported PCKs.
				# Catalog validation owns source existence; querying owns no pixels.
				if rect is Array and rect.size()==4 and not path.is_empty():
					return {"path":path,"rect":[float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3])]}
	# Preserve legacy equipment, consumables and material presentation fallback.
	return _texture_ref(Content.icon_texture(item))

static func _option_summary(item:Dictionary)->String:
	if item.rarity==0:return "일반 · 추가 옵션 없음"
	if item.rarity<3:return "+%d 강화 시 힘·내구·기술·민첩·마력 중 1종 +%d"%[Equipment.UNLOCK[item.rarity],3*item.rarity+2*item.tier]
	return "+%d 강화 시 위력·회복·보호막 / 사거리·범위 / 지속·지원 중 1종 +%d%%"%[Equipment.UNLOCK[item.rarity],8 if item.rarity==3 else 12]

static func _appearance(db:Dictionary,f:Dictionary,kind:String,role:String):
	var a=Abyss.enemy_stats(kind,f.floor,role=="raid",role in ["guardian","raid"])
	a["asset"]=_monster_asset(kind,f.floor,role=="raid")
	a["name"]=f.title if role=="raid" else WorldArt.appearance_name(kind,f.floor,World.ENEMIES[kind].name)
	a.merge({"id":"appearance:%03d:%s:%s"%[f.floor,kind,role],"floor_id":f.floor,"monster_id":kind,"role":role,"level":f.level+(3 if role=="elite" else 0),"raid_id":f.raid_id if role=="raid" else ""},true);db.appearances.append(a)

static func _grade_tail(floor_number:int,grade:int)->float:
	if grade<=2:return 1.
	if grade>4:return 0.
	var lo=0.;var hi=1.
	for i in range(48):
		var mid=(lo+hi)*.5
		if Abyss.raid_grade(floor_number,mid)>=grade:lo=mid
		else:hi=mid
	return (lo+hi)*.5

static func _boss_stagger(floor_number:int)->Dictionary:
	var module=load("res://scripts/boss_stagger.gd");var enemy={"boss":true,"floor":floor_number}
	module.initialize(enemy)
	var result=enemy.stagger.duplicate(true)
	result["down_seconds"]=module.DOWN_SECONDS;result["immunity_seconds"]=module.IMMUNITY_SECONDS;result["check_seconds"]=module.CHECK_SECONDS;result["down_damage_multiplier"]=module.DOWN_DAMAGE
	return result

static func _reference_player(class_id:String)->Dictionary:
	return {"class_id":class_id,"level":100,"stats":{"strength":0,"endurance":0,"technique":0,"agility":0,"magic":0},"gear_stats":{},"skill_ranks":{},"constellation_allocations":{},"inventory":[],"equipment":{}}

static func _skill_rank(class_id:String,node:Dictionary,rank:int)->Dictionary:
	var p=_reference_player(class_id);var advanced=node.get("runtime","")=="job" or Content.CLASSES[class_id].has("base") or class_id in ["rogue","fighter"]
	var metrics=Jobs.metrics(p,node,rank,REFERENCE.damage,REFERENCE.max_hp) if advanced else Scaling.metrics(node,rank,REFERENCE.damage,REFERENCE.max_hp)
	var profile={}
	if node.effect=="active":profile=Jobs.profile(p,node,rank,REFERENCE.damage,REFERENCE.max_hp) if advanced else Scaling.profile(node,rank)
	elif node.effect=="upgrade":
		var target=Content.SKILLS[class_id].filter(func(n):return n.id==node.target)[0]
		profile=Jobs.profile(p,target,3,REFERENCE.damage,REFERENCE.max_hp,true);profile["reference_target_rank"]=3
	else:profile={"effect":node.effect,"value":float(node.get("value",0))*rank}
	var stagger=load("res://scripts/boss_stagger.gd").skill_profile(node,rank,p)
	return {"skill_id":node.id,"rank":rank,"metrics":metrics,"profile":profile,"stagger":stagger}

static func _texture_ref(texture:Texture2D)->Dictionary:
	if texture is AtlasTexture:return {"path":str(texture.get_meta("source_path",texture.atlas.resource_path)),"rect":[texture.region.position.x,texture.region.position.y,texture.region.size.x,texture.region.size.y]}
	return {"path":texture.resource_path,"rect":[0,0,texture.get_width(),texture.get_height()]}

static func _monster_asset(kind:String,floor_number:int=0,raid:bool=false)->Dictionary:
	var themed=preload("res://scripts/world_art.gd").variant_frame(kind,floor_number,raid)
	if not themed.is_empty():
		var asset=_texture_ref(themed.texture)
		asset.merge({"art_id":themed.art_id,"species":themed.species,"appearance_name":themed.name,"foot":[themed.foot.x,themed.foot.y],"body_height":themed.height,"animation":"idle/attack key poses"},true)
		return asset
	var m=World.ENEMIES[kind];var sheet="bosses" if m.ai=="boss" else m.get("art_sheet","enemies")
	var index=["warden","golem","sentinel"].find(kind)*3 if m.ai=="boss" else int(m.art)
	var frame=preload("res://scripts/world_art.gd").frame(sheet,index);var asset=_texture_ref(frame.texture)
	asset["sheet_key"]=sheet;asset["frame_index"]=index;asset["foot"]=[frame.foot.x,frame.foot.y]
	return asset

static func _patterns(kind:String)->Array:
	var result=[]
	for sequence in range(2):result.append(_json_value(Attacks.pattern(kind,Vector2.ZERO,Vector2(2,0),sequence)))
	return result

static func _raid_patterns(floor_number:int)->Array:
	var result=[]
	for phase in [1,2]:
		for sequence in range(3):result.append({"phase":phase,"sequence":sequence,"areas":_json_value(Attacks.raid_pattern({"pos":Vector2.ZERO,"floor":floor_number,"phase":phase,"pattern":sequence},Vector2(2,0)))})
	return result

static func _pattern_text(patterns:Array)->String:
	var names=[]
	for pattern in patterns:
		for area in pattern:
			var name={"circle":"원형 공격","line":"직선 공격","cone":"부채꼴 공격","ring":"고리 공격"}.get(area.shape,area.shape)
			if not names.has(name):names.append(name)
	return " / ".join(names) if not names.is_empty() else "보스 전용 패턴 · 층별 레이드 항목에서 단계별 판정 확인"

static func _json_value(value):
	if value is Vector2:return [value.x,value.y]
	if value is Dictionary:
		var out={}
		for key in value:out[key]=_json_value(value[key])
		return out
	if value is Array:
		var out=[]
		for item in value:out.append(_json_value(item))
		return out
	return value

static func query(kind:String,filters:Dictionary={},page:int=0,page_size:int=12)->Dictionary:
	var db=snapshot();var source=db.get(kind,[])
	if kind=="monsters":source=db.monsters+db.raids
	if kind=="drops":source=db.drops+db.raid_drops
	if kind=="skills":source=db.skills+db.constellations
	if kind=="drops" and not str(filters.get("equipment_id","")).is_empty():source=sources(detail("equipment",filters.equipment_id))
	var results=[];var q=str(filters.get("q","")).strip_edges().to_lower()
	for original_row in source:
		var row=monster_on_floor(original_row,int(filters.get("floor",0))) if kind=="monsters" else original_row
		if not q.is_empty() and not (str(row.id)+" "+str(row.get("name",""))+" "+str(row.get("subtitle",""))+" "+str(row.get("description",""))).to_lower().contains(q):continue
		var match_filter=true
		for key in ["family","class_id","slot","role","monster_id","effect","category","art_id","target_table","target_id","consumer"]:
			var wanted=str(filters.get(key,""))
			if wanted.is_empty():continue
			if kind=="equipment" and key=="class_id":
				if row.family!=Content.base_class(wanted) or (row.slot=="weapon" and row.job_lock!=wanted):match_filter=false
				continue
			if kind=="drops" and key in ["family","class_id"]:continue
			if kind=="skills" and key=="effect" and wanted=="passive":
				if row.effect in ["active","upgrade"]:match_filter=false
				continue
			if kind=="drops" and key=="slot" and row.get("slot","")=="any":continue
			if kind=="drops" and key=="monster_id":
				if wanted.begins_with("raid:"):
					var raid=detail("monsters",wanted)
					if raid.is_empty() or row.monster_id!=raid.monster_id or (row.has("raid_id") and row.raid_id!=wanted):match_filter=false
				elif row.monster_id!=wanted or row.has("raid_id"):match_filter=false
				continue
			if not wanted.is_empty() and str(row.get(key,""))!=wanted:match_filter=false;break
		if not match_filter:continue
		if int(filters.get("rarity",-1))>=0 and int(row.get("rarity",-1))!=int(filters.rarity):continue
		var f=int(filters.get("floor",0))
		if f>0:
			if kind=="monsters" and not row.get("floors",[]).has(f):continue
			if kind=="drops":
				if row.has("floor") and row.floor!=f:continue
				if not row.has("floor") and not detail("monsters",row.monster_id).get("floors",[]).has(f):continue
		results.append(row)
	page_size=clampi(page_size,1,100);var pages=maxi(1,ceili(results.size()/float(page_size)));page=clampi(page,0,pages-1)
	return {"items":results.slice(page*page_size,mini((page+1)*page_size,results.size())),"total":results.size(),"page":page,"pages":pages}

static func monster_on_floor(row:Dictionary,floor_number:int)->Dictionary:
	if row.is_empty() or floor_number<=0 or row.get("role","")=="raid":return row
	for appearance in snapshot().appearances:
		if appearance.monster_id==row.id and appearance.floor_id==floor_number:
			var result=row.duplicate(true)
			result["base_name"]=row.name;result["name"]=appearance.name;result["asset"]=appearance.asset
			result["subtitle"]="B%d 출현 외형 · 기본형 %s"%[floor_number,row.name]
			return result
	return row

static func sources(item:Dictionary)->Array:
	if item.is_empty():return []
	var db=snapshot();var results=[]
	for source in db.drops:
		if source.get("slot","")!=item.slot or int(source.rarity)!=int(item.rarity):continue
		var floors=[]
		for a in db.appearances:
			if a.monster_id==source.monster_id and int((a.floor_id-1)/10)==int(item.tier) and not floors.has(a.floor_id):floors.append(a.floor_id)
		if floors.is_empty():continue
		var row=source.duplicate(true);row["source_floors"]=floors
		row.description+=" 이 장비 단계의 출현층: "+", ".join(floors.map(func(f):return "B"+str(f)))+". 무기는 현재 직업, 방어구는 현재 계열로 결정됩니다."
		results.append(row)
	for source in db.raid_drops:
		if int(source.rarity)!=int(item.rarity) or int(source.tier)!=int(item.tier):continue
		var row=source.duplicate(true);row["source_floors"]=[source.floor];row["requested_slot"]=item.slot;row["joint_slot_chance"]=source.chance*source.slot_probability
		row.description+=" 선택 부위 "+Content.SLOT_NAMES[item.slot]+"까지 함께 나올 확률: "+Scaling.number(row.joint_slot_chance*100)+"%."
		results.append(row)
	return results

static func detail(kind:String,id:String)->Dictionary:
	var db=snapshot();var source=db.get(kind,[])
	if kind=="monsters":source=db.monsters+db.raids
	if kind=="drops":source=db.drops+db.raid_drops
	if kind=="skills":source=db.skills+db.constellations
	for row in source:
		if str(row.id)==id:return row
	return {}

static func asset_texture(row:Dictionary)->Texture2D:
	var a=row.get("asset",{})
	if a.is_empty():return null
	if str(a.get("path","")).contains("/assets/equipment/"):return preload("res://scripts/equipment_art.gd").texture_for_asset(a)
	var key=str(a)
	if not _textures.has(key):
		var texture=AtlasTexture.new();texture.atlas=load(a.path);texture.region=Rect2(a.rect[0],a.rect[1],a.rect[2],a.rect[3]);texture.filter_clip=true;_textures[key]=texture
	return _textures[key]
