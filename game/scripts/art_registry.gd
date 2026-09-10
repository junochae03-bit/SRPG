extends RefCounted
## Live consumer mappings, not an inventory of every file in the asset directory.
## File hashes/provenance records are enriched by the portable DB exporter.
const Content=preload("res://scripts/content.gd")
const Env=preload("res://scripts/environment_art.gd")
const World=preload("res://scripts/world_art.gd")
const Creatures=preload("res://scripts/world_catalog.gd")
const Equipment=preload("res://scripts/equipment_art.gd")
const Icons=preload("res://scripts/icon_art.gd")
const Library=preload("res://scripts/icon_library.gd")
const Costumes=preload("res://scripts/costume_art_v04.gd")
const Gat=preload("res://scripts/gat_art.gd")
const Motion=preload("res://scripts/combat_sprite_art.gd")
const Jobs=preload("res://scripts/job_art.gd")
const Vfx=preload("res://scripts/skill_vfx_catalog.gd")
var assets:Dictionary={}
var uses:Dictionary={}

static func snapshot(db:Dictionary)->Dictionary:
	var registry=load("res://scripts/art_registry.gd").new()
	registry.collect(db)
	return {"art_assets":registry.assets.values(),"art_uses":registry.uses.values()}

func add(id:String,category:String,name:String,path:String,rect:Array,provenance:String,catalog:String,metadata:Dictionary={},frame:int=-1,action:String="")->String:
	var row={"id":id,"category":category,"name":name,"path":path,"rect":rect,"frame":frame,"action":action,"provenance":provenance,"catalog":catalog,"metadata":metadata}
	if assets.has(id):
		assert(assets[id]==row,"Inconsistent art identity: "+id)
	else:assets[id]=row
	return id

func use(id:String,table:String,target:String,consumer:String,mapping:Dictionary={},usage_kind:String="runtime_mapping"):
	assert(assets.has(id),"Unknown art use: "+id)
	var row={"art_id":id,"target_table":table,"target_id":target,"consumer":consumer,"mapping":mapping,"usage_kind":usage_kind}
	row["id"]="use:"+JSON.stringify(row,"",true).sha256_text().substr(0,24)
	uses[row.id]=row

func collect(db:Dictionary):
	Content.initialize_jobs();Equipment.initialize();Library.initialize();Env.initialize();World.initialize();World.dungeon_initialize();Gat.initialize();Motion.initialize();Jobs.initialize()
	for e in db.equipment:
		var key=Equipment.key(e);var entry=Equipment.catalog[key]
		var id=add("art:equipment:"+key,"equipment",entry.get("name",key),entry.sheet,entry.rect,"docs/EQUIPMENT_ART_PROMPTS.json",Equipment.CATALOG_PATH,{"equipment_key":key})
		use(id,"equipment",e.id,"game/scripts/equipment_art.gd:key",{"tier":e.tier,"rarity":e.rarity,"class_id":e.job_lock,"family":e.family,"slot":e.slot})
	for drop in db.drops:
		var id=""
		for a in assets.values():
			if a.path==drop.asset.path and a.rect==drop.asset.rect:id=a.id;break
		if id.is_empty():
			id=add("art:loot:"+drop.key,"equipment",drop.name,drop.asset.path,drop.asset.rect,"docs/ASSET_SOURCES.md","res://assets/sprites/item_regions.json",{"loot_kind":drop.kind})
		use(id,"drops",drop.id,"game/scripts/content.gd:icon_texture",{"kind":drop.kind})
	for s in db.skills+db.constellations:
		var key=Library.canonical(Icons.key_for_skill(s.node))
		icon(key,"constellations" if s.get("effect","")=="constellation" else "skills",s.id,"game/scripts/icon_art.gd:key_for_skill")
		if s.get("effect","")!="active":continue
		var profile=s.ranks[0].profile;var node=profile.get("node",s.node)
		var event={"skill_id":s.id,"class_id":s.class_id,"skill_mode":node.get("mode",profile.get("mode","")),"fx":s.node.get("fx",s.id)}
		var family=Vfx.family_for(event)
		if family.is_empty():continue
		var id=add("art:vfx:"+family,"vfx",family,"res://scripts/skill_vfx.gd",[],"docs/TEAM_HANDOFF_VFX.md","res://scripts/skill_vfx_catalog.gd",{"representation":"procedural_canvas","palette":Vfx.PALETTES[family]},-1,"procedural")
		use(id,"skills",s.id,"game/scripts/skill_vfx.gd:render",event)
	for f in db.floors:
		for key in Env.ids(f.terrain,f.id):environment(key,"floors",str(f.id),Env.theme(f.terrain,f.id))
	for zone in ["town","forest"]:
		for key in Env.ids(zone,0):environment(key,"runtime",zone,Env.theme(zone,0))
	for a in db.appearances:
		var variant=World.variant(a.monster_id,a.floor_id,a.role=="raid")
		if not variant.is_empty():
			for pose in ["idle","attack"]:
				var key=variant.species+"_"+pose;var entry=World.dungeon_catalog.objects[key]
				var id=add("art:monster:"+key,"monster",entry.name,entry.sheet,entry.rect,"docs/ENVIRONMENT_V04_PROVENANCE.json","res://assets/world/dungeon-v04/catalog.json",{"species":entry.species,"foot":entry.foot,"body_height":entry.body_height,"source_cell":entry.source_cell},-1,pose)
				use(id,"appearances",a.id,"game/scripts/main.gd:draw_actor",{"monster_id":a.monster_id,"floor":a.floor_id,"role":a.role,"theme":entry.theme})
		else:legacy_monster(a.monster_id,"appearances",a.id,{"floor":a.floor_id,"role":a.role})
	# Base monsters still appear in the codex and tutorial independently of variants.
	for m in db.monsters:legacy_monster(m.id,"monsters",m.id,{"base_catalog":true})
	for key in Creatures.FACILITIES:
		if not Creatures.FACILITIES[key].get("footprint",true):continue
		var facility=Creatures.FACILITIES[key];var i=int(facility.art);var entry=World.catalog.town;var f=entry.frames[i]
		var id=add("art:town:"+str(i),"environment","마을 건물 원화 "+str(i),entry.sheet,f.rect,"docs/ASSET_SOURCES.md","res://assets/world/catalog.json",{"foot":f.foot},i,"building")
		use(id,"facilities",key,"game/scripts/main.gd:draw_building",{"facility_name":facility.name})
	training_art()
	characters(db)
	companions()
	ui_icons()
	var title_path="res://assets/ui/title-storybook-v04.png";var title=load(title_path) as Texture2D
	var title_id=add("art:ui:title_storybook","ui","동화책 숲 타이틀",title_path,[0,0,title.get_width(),title.get_height()],"docs/TITLE_ART_V04.md","res://scripts/title_screen.gd")
	use(title_id,"runtime","title","game/scripts/title_screen.gd:setup")
	floor_tiles(db)
	available_catalog()
	render_cache_metadata()
	var applied={}
	for u in uses.values():
		if u.usage_kind=="runtime_mapping":applied[u.art_id]=true
	for a in assets.values():a["status"]="applied" if applied.has(a.id) else "available_catalog"

func render_cache_metadata():
	# Management-only descriptors. Do not decompress or create any texture here.
	var prepared=preload("res://scripts/prepared_art_v05.gd")
	for a in assets.values():
		var chroma=""
		if a.metadata.has("equipment_key"):chroma="magenta"
		elif a.id.begins_with("art:character:costume:"):
			var costume_id=str(a.id).split(":")[3]
			var e=Costumes.catalog()[costume_id]
			var f=e.frames[a.frame if a.frame>=0 else 15]
			chroma=str(f.get("chroma_key",e.chroma_key))
		if chroma.is_empty():continue
		var entry=prepared.descriptor(a.path,chroma)
		assert(not entry.is_empty(),"Missing prepared art metadata: "+a.id)
		if not entry.is_empty():a.metadata["render_cache"]={"catalog":prepared.CATALOG,"path":entry.path,"source":a.path,"key":chroma}

func training_art():
	const TrainingArt=preload("res://scripts/training_art.gd")
	var texture=TrainingArt.texture();var rect=texture.region
	var id=add("art:training:scarecrow","monster","거대 훈련 허수아비",TrainingArt.SOURCE,[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"game/assets/town_v052/PROVENANCE.md","res://scripts/training_art.gd",{"display_height":TrainingArt.HEIGHT,"source_dimensions":[texture.atlas.get_width(),texture.atlas.get_height()],"alpha":"original_preserved","crop":"Image.get_used_rect","training_only":true},-1,"stationary_training_target")
	use(id,"training_rules","training","game/scripts/training_art.gd:draw",{"role":"world_target"})
	use(id,"facilities","training","game/scripts/town_panel.gd:refresh",{"role":"facility_portrait"})

func icon(key:String,table:String,target:String,consumer:String):
	key=Library.canonical(key)
	assert(Library.entries.has(key),"Unmapped semantic icon: "+key)
	var entry=Library.entries[key]
	var id=add("art:icon:"+key,"icon",key,entry.path,entry.rect,"docs/ICON_ART_PROMPTS.json",Library.CATALOG_PATH,{"semantic_key":key})
	use(id,table,target,consumer)

func environment(key:String,table:String,target:String,theme:String):
	var e=Env.catalog.objects[key]
	var id=add("art:environment:"+key,"environment",e.name,e.sheet,e.rect,"docs/ENVIRONMENT_V04_PROVENANCE.json","res://assets/environment/biomes-v04/catalog.json",{"foot":e.foot,"source_cell":e.source_cell,"source_pack":e.source_pack})
	use(id,table,target,"game/scripts/forest_environment.gd:rebuild",{"theme":theme,"decoration_outside_walkable":true})

func legacy_monster(kind:String,table:String,target:String,mapping:Dictionary):
	var m=Creatures.ENEMIES[kind];var boss=m.ai=="boss";var sheet="bosses" if boss else m.get("art_sheet","enemies")
	var indexes=range(["warden","golem","sentinel"].find(kind)*3,["warden","golem","sentinel"].find(kind)*3+3) if boss else [int(m.art)]
	for i in indexes:
		var e=World.catalog[sheet];var f=e.frames[i]
		var id=add("art:monster:legacy:"+sheet+":"+str(i),"monster",m.name,e.sheet,f.rect,"docs/ASSET_SOURCES.md","res://assets/world/catalog.json",{"foot":f.foot},i,"idle/windup/attack" if boss else "single_pose")
		use(id,table,target,"game/scripts/main.gd:draw_actor",mapping)

func characters(db:Dictionary):
	for cls in db.classes:
		for avatar in Content.avatar_options(cls.id):
			if avatar=="auto" and Jobs.data.sprites.has(cls.id):
				character_frames("job:"+cls.id,Jobs.data.sprites[cls.id],"res://assets/jobs/catalog.json",range(16),"classes",cls.id,{"selector":"default","role":"player"},"game/scripts/job_art.gd:frame")
			else:
				var key=Gat.avatar({"class_id":cls.id,"avatar":avatar})
				gat_character(key,"classes",cls.id,{"selector":"avatar","avatar":avatar,"role":"player"},false)
		for costume in Content.costume_options(cls.id):
			if costume=="none":continue
			if Costumes.recognizes(costume):
				character_frames("costume:"+costume,Costumes.catalog()[costume],Costumes.CATALOG_PATH,range(16),"classes",cls.id,{"selector":"costume","costume":costume,"role":"player"},"game/scripts/costume_art_v04.gd:frame")
			elif Content.GAT_COSTUMES.has(costume):gat_character(costume,"classes",cls.id,{"selector":"costume","costume":costume,"role":"player"},false)
	for key in Creatures.RESIDENTS:
		var npc=Creatures.RESIDENTS[key]
		gat_character(npc.avatar,"runtime","npc:"+key,{"role":"npc","name":npc.name},true)
	for npc in preload("res://scripts/town_visitors.gd").RESIDENTS:
		character_frames("costume:"+npc.costume,Costumes.catalog()[npc.costume],Costumes.CATALOG_PATH,[15],"runtime","npc:"+npc.costume,{"role":"npc","name":npc.name},"game/scripts/town_visitors.gd:draw")

func gat_character(key:String,table:String,target:String,mapping:Dictionary,npc:bool):
	if Motion.AVATARS.has(key):
		var role=Motion.AVATARS[key]
		character_frames("motion:"+role,Motion.catalog[role],"res://assets/motions/catalog.json",[4,15] if npc else range(16),table,target,mapping,"game/scripts/combat_sprite_art.gd:frame")
	else:character_frames("gat:"+key,Gat.catalog[key],"res://assets/gat/catalog.json",[0,1] if npc else range(4),table,target,mapping,"game/scripts/gat_art.gd:frame")
	# Gat portraits intentionally use the original source, even for animated avatars.
	var e=Gat.catalog[key];var f=e.frames[0];var r=f.rect;var h=float(e.height)
	var rect=[clampf(r[0]+f.foot[0]-h*.29,r[0],r[0]+r[2]-h*.58),r[1]+h*.025,h*.58,h*.58]
	var id=add("art:character:gat:"+key+":portrait","character",key+" portrait",e.sheet,rect,"docs/ASSET_SOURCES.md","res://assets/gat/catalog.json",{},-1,"portrait")
	use(id,table,target,"game/scripts/gat_art.gd:portrait",mapping)

func character_frames(key:String,e:Dictionary,catalog:String,indexes,table:String,target:String,mapping:Dictionary,consumer:String):
	var provenance="docs/costume_v04/PROVENANCE.json" if key.begins_with("costume:") else "docs/ASSET_SOURCES.md"
	for i in indexes:
		var f=e.frames[i];var action=str(f.get("action","pose"));var path=f.get("sheet",e.sheet)
		var id=add("art:character:"+key+":"+str(i),"character",e.get("name",key),path,f.rect,provenance,catalog,{"foot":f.foot,"body_height":f.get("body_height",e.get("body_height",e.get("height",0)))},i,action)
		use(id,table,target,consumer,mapping)
	if mapping.role!="player" or not (key.begins_with("costume:") or key.begins_with("job:")):return
	var i=15 if key.begins_with("costume:") else 4;var f=e.frames[i];var r=f.rect;var h=float(f.get("body_height",e.get("body_height",0)))
	var side=minf(h*.68,minf(r[2],r[3])) if i==15 else h*.68
	var rect=[r[0]+clampf(f.foot[0]-side*.5,0,r[2]-side),r[1]+clampf(f.foot[1]-h,0,r[3]-side),side,side]
	if i==4:rect[1]=r[1]+maxf(0,f.foot[1]-h)
	var id=add("art:character:"+key+":portrait","character",e.get("name",key)+" portrait",f.get("sheet",e.sheet),rect,provenance,catalog,{},-1,"portrait")
	use(id,table,target,consumer.replace(":frame",":portrait"),mapping)

func companions():
	var e=Jobs.data.effects.companions
	for i in range(e.frames.size()):
		var f=e.frames[i];var cls="hunter" if i<4 else "summoner"
		var id=add("art:vfx:companion:"+str(i),"vfx","동료 · "+str(i),e.sheet,f.rect,"docs/ASSET_SOURCES.md","res://assets/jobs/catalog.json",{"foot":f.foot},i,"companion")
		use(id,"classes",cls,"game/scripts/job_art.gd:pets",{"pet_row":int(i/4)})
	# Only raw automatic procs bypass the procedural renderer. Original active
	# skills with a class:row sprite ID are normally procedural and are excluded.
	var rows={}
	for cls in Content.CLASSES:
		if Content.CLASSES[cls].has("base") and Jobs.data.effects.has(cls):rows[cls]=[3 if cls in ["breaker","martialist"] else 2]
	for pair in [["breaker",2],["thief",5],["gambler",5]]:
		if not rows[pair[0]].has(pair[1]):rows[pair[0]].append(pair[1])
	for cls in rows:
		var sheet=Jobs.data.effects[cls]
		for row in rows[cls]:
			for column in range(4):
				var index=row*4+column;var f=sheet.frames[index]
				var id=add("art:vfx:job_proc:"+cls+":"+str(index),"vfx",cls+" 자동 효과",sheet.sheet,f.rect,"docs/ASSET_SOURCES.md","res://assets/jobs/catalog.json",{"fx":cls+":"+str(row)},index,"automatic_proc")
				use(id,"classes",cls,"game/scripts/job_art.gd:render",{"raw_fx":cls+":"+str(row),"skill_id":"","skill_mode":""})

func ui_icons():
	# Explicit icon calls are source mappings, not a claim of a rendered session.
	# Do not register all 168 atlas regions just because the library contains them.
	var call_pattern=RegEx.new();call_pattern.compile("(?:Icons|Library|IconLibrary)\\.(?:texture|attach|draw|picture)\\([^;\\n]*")
	var literal=RegEx.new();literal.compile("\"([a-z][a-z0-9_]*)\"")
	var script_dir="res:/"+"/scripts/"
	for filename in DirAccess.get_files_at(script_dir):
		if filename.get_extension()!="gd" or filename in ["art_registry.gd","icon_library.gd","game_database.gd"]:continue
		var path=script_dir+filename;var code=FileAccess.get_file_as_string(path)
		if not code.contains("icon_library.gd"):continue
		for call in call_pattern.search_all(code):
			for match_key in literal.search_all(call.get_string()):
				var key=Library.canonical(match_key.get_string(1))
				if Library.entries.has(key):icon(key,"runtime",path,path.replace("res://","game/")+":semantic_icon_call")
	var statuses=preload("res://scripts/status_markers.gd")
	for key in statuses.STATUSES.values()+statuses.BUFFS.values()+["invulnerable","shield","haste","guard","counter","taunt","mark"]:icon(key,"runtime","actor_status","game/scripts/status_markers.gd:keys_for")
	for key in ["quest","quest_complete","trophy","boss"]:icon(key,"runtime","quest_state","game/scripts/combat_hud.gd:refresh")
	for key in Creatures.FACILITIES:icon(key,"runtime","town:"+key,"game/scripts/town_panel.gd:refresh")
	for cls in Content.CLASSES:icon("class_"+cls,"classes",cls,"game/scripts/codex_panel.gd:configure_filters")
	for slot in Content.SLOTS:icon(slot,"runtime","equipment_slot:"+slot,"game/scripts/inventory_item_ui.gd:_draw")
	for key in preload("res://scripts/progression.gd").NAMES:icon(Library.canonical(key),"runtime","stat:"+key,"game/scripts/character_sheet_ui.gd:setup")
	for key in ["enrage","stagger","stagger_check","stagger_broken","stagger_immune"]:icon(key,"runtime","boss_status","game/scripts/boss_hud.gd:draw_stagger")

func available_catalog():
	# 배치 목록과 별개로 완성된 배경 원화 전체를 보존한다.
	for key in Env.catalog.objects:
		var id="art:environment:"+key
		if assets.has(id):continue
		var entry=Env.catalog.objects[key]
		var catalog_path="res://assets/environment/biomes-v04/catalog.json"
		add(id,"environment",entry.name,entry.sheet,entry.rect,"docs/ENVIRONMENT_V04_PROVENANCE.json",catalog_path,{"foot":entry.foot,"source_cell":entry.source_cell,"source_pack":entry.source_pack})
		use(id,"catalog",catalog_path,"game/assets/environment/biomes-v04/catalog.json",{"environment_id":key},"catalog_available")
	# Finished regions already present in shipped source sheets remain searchable,
	# but a catalog entry is explicitly NOT a runtime/render consumer.
	for key in Library.keys():
		var id="art:icon:"+key
		if assets.has(id):continue
		var entry=Library.entries[key]
		add(id,"icon",key,entry.path,entry.rect,"docs/ICON_ART_PROMPTS.json",Library.CATALOG_PATH,{"semantic_key":key})
		use(id,"catalog",Library.CATALOG_PATH,"game/assets/icons/semantic_catalog.json",{},"catalog_available")
	for key in Costumes.ids():
		var e=Costumes.catalog()[key]
		for i in range(16):
			var id="art:character:costume:"+key+":"+str(i)
			if assets.has(id):continue
			var f=e.frames[i]
			add(id,"character",e.name,f.get("sheet",e.sheet),f.rect,"docs/costume_v04/PROVENANCE.json",Costumes.CATALOG_PATH,{"foot":f.foot,"body_height":f.get("body_height",e.body_height)},i,f.action)
			use(id,"catalog",Costumes.CATALOG_PATH,"game/assets/costume_v04/catalog.json",{"costume":key,"role":"npc_catalog_pose"},"catalog_available")

func floor_tiles(db:Dictionary):
	# The completed, integrated ground-only catalog is optional until its handoff.
	var path="res://assets/floor_tiles_v04/catalog.json"
	if not FileAccess.file_exists(path):return
	var cat=JSON.parse_string(FileAccess.get_file_as_string(path))
	for f in db.floors:tile_mapping(cat,f.art_theme,"floors",str(f.id))
	for zone in ["town","tutorial"]:tile_mapping(cat,zone,"runtime",zone)

func tile_mapping(cat:Dictionary,key:String,table:String,target:String):
	var mapping=cat.mappings[key]
	for layer in ["ground","path"]:
		var material_id=mapping[layer];var m=cat.materials[material_id]
		var id=add("art:floor_tile:"+material_id,"floor_tile",m.get("name",material_id),cat.atlas,m.sample_rect,"game/assets/floor_tiles_v04/catalog.json","res://assets/floor_tiles_v04/catalog.json",{"authored_rect":m.rect,"sample_rect":m.sample_rect},-1,"ground_sample")
		use(id,table,target,"res://shaders/forest_ground.gdshader",{"layer":layer,"theme":key,"profile":mapping})
