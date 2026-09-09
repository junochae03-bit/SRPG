extends SceneTree
const DB=preload("res://scripts/game_database.gd")
const Equipment=preload("res://scripts/equipment_art.gd")
const Costume=preload("res://scripts/costume_art_v04.gd")
const Content=preload("res://scripts/content.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var start=Time.get_ticks_usec();var base=DB.snapshot();var base_ms=(Time.get_ticks_usec()-start)/1000.
	check(not base.has("art_assets") and DB._art_cache.is_empty(),"PCK/game snapshot never enters management source scanner")
	var costume_sheets=Costume._sheet_textures.size();var equipment_sheets=Equipment.sheets.size()
	start=Time.get_ticks_usec();var db=DB.snapshot(true);var art_ms=(Time.get_ticks_usec()-start)/1000.
	check(Costume._sheet_textures.size()==costume_sheets,"management registry does not decode costume sheets")
	check(Equipment.sheets.size()==equipment_sheets,"management registry does not decode additional equipment sheets")
	check(DB.snapshot()==base and not DB.snapshot().has("art_assets"),"management cache does not mutate game snapshot")
	check(db.equipment==base.equipment and db.skills==base.skills,"gameplay tables preserved")
	var assets={};var categories={};var uses={};var equipment_links={};var skill_icons={};var npc_frames={};var floors={};var applied={}
	for a in db.art_assets:
		check(not assets.has(a.id),"stable unique region "+a.id);assets[a.id]=a
		categories[a.category]=int(categories.get(a.category,0))+1
		check(ResourceLoader.exists(a.path),"real runtime source "+a.id)
		if a.path.ends_with(".png"):
			check(a.rect.size()==4 and a.rect[2]>0 and a.rect[3]>0,"nonempty authored rectangle "+a.id)
		else:check(a.rect.is_empty() and a.category=="vfx","procedural effects are not invented sprite sheets")
		check(not a.path.contains("theme-") and not a.path.contains("/sources/") and not a.path.contains("/preview/"),"only integrated art "+a.id)
	for u in db.art_uses:
		check(assets.has(u.art_id),"use references asset "+u.id);uses[u.art_id]=true
		if u.target_table not in ["runtime","catalog"]:check(db[u.target_table].any(func(r):return str(r.id)==u.target_id),"use references game owner "+u.id)
		if u.usage_kind=="runtime_mapping":applied[u.art_id]=true
		var a=assets[u.art_id]
		if u.target_table=="equipment":equipment_links[u.target_id]=a
		if u.target_table in ["skills","constellations"] and a.category=="icon":skill_icons[u.target_id]=true
		if u.target_table=="floors" and a.category=="floor_tile":floors[u.target_id]=true
		if a.id.begins_with("art:character:costume:pink-") and u.usage_kind=="runtime_mapping":
			check(u.target_table=="runtime" and u.mapping.role=="npc","NPC-only gunner never linked to player class")
			npc_frames[a.id]=true;check(a.frame==15 and a.action=="idle","NPC-only unused combat frames excluded")
	check(uses.size()==assets.size(),"every registered region has a runtime or explicitcatalog consumer")
	for a in assets.values():check(a.status==("applied" if applied.has(a.id) else "available_catalog"),"actual use and available catalog are not conflated "+a.id)
	check(npc_frames.size()==3,"all three visiting NPC idle regions")
	check(db.art_assets.filter(func(a):return a.metadata.has("equipment_key")).size()==115,"all115 newequipment regions")
	check(floors.size()==100 and categories.floor_tile==6,"all100floors share the6 finished ground materials")
	check(skill_icons.size()==1510,"every original/specialization icon mapped")
	for e in db.equipment:
		var a=equipment_links.get(e.id,{})
		check(not a.is_empty() and a.path==e.asset.path and a.rect==e.asset.rect,"actual item reader path/rect matches equipment DB "+e.id)
	var new_frames=db.art_assets.filter(func(a):return a.id.begins_with("art:character:costume:") and a.frame>=0)
	check(new_frames.size()==528,"all33 completed costumes and16frames remain manageable")
	check(new_frames.filter(func(a):return a.status=="applied").size()==30*16+3,"480player poses+3NPCidle applied")
	check(new_frames.filter(func(a):return a.status=="available_catalog").size()==45,"45 unusedNPCposes explicitlyavailable,notgameplayuses")
	check(categories.icon==168,"all168 finished icon regions remain manageable")
	check(db.art_assets.filter(func(a):return a.id.begins_with("art:environment:")).size()==108,"108decorations connected")
	check(db.art_assets.filter(func(a):return a.category=="vfx" and a.action=="procedural").size()==18,"18 live proceduralVFXfamilies")
	start=Time.get_ticks_usec();DB.query("equipment",{"class_id":"warrior"});var cached_query_ms=(Time.get_ticks_usec()-start)/1000.
	print("ART_REGISTRY_V05 checks=",checks," failures=",failures.size()," assets=",assets.size()," uses=",db.art_uses.size()," categories=",categories," base_snapshot_ms=",base_ms," management_extra_ms=",art_ms," cached_codex_query_ms=",cached_query_ms," costume_decodes=",Costume._sheet_textures.size()-costume_sheets)
	quit(0 if failures.is_empty() else 1)
