extends SceneTree
## Item artwork only: equipment data and existing character choices stay intact.
const C = preload("res://scripts/content.gd")
const E = preload("res://scripts/equipment_catalog.gd")
const Art = preload("res://scripts/equipment_art.gd")
const DB = preload("res://scripts/game_database.gd")
const Sim = preload("res://scripts/simulation.gd")
const Inventory = preload("res://scripts/inventory_model.gd")
var checks = 0
var failures: Array[String] = []
var coverage: Array = []
var appearance_checks = 0
func _initialize(): run.call_deferred()
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func stats(sim, p: Dictionary) -> Dictionary:
	return {"damage": sim.damage_for(p), "hp": p.hp, "max_hp": p.max_hp, "defense": p.defense, "stamina": p.stamina, "max_stamina": p.max_stamina, "stats": p.stats.duplicate(true), "gear_stats": p.gear_stats.duplicate(true)}

func verify_rgba(catalog:Dictionary):
	var sources={};var rendered={};var widths={}
	for entry in catalog.values():
		var path=entry.sheet
		if sources.has(path):continue
		var raw=Art.source_image(path);var imported=Art.source_image(path,true)
		check(raw!=null and imported!=null,"raw and exported imported fallback available "+path)
		if raw==null or imported==null:continue
		var live=Art.sheet_texture(path).get_image();var fallback=Art.rgba_image(imported)
		check(live.get_size()==raw.get_size()+Vector2i.ONE,"transparent padding bypasses shared shader "+path)
		check(fallback!=null and live.get_data()==fallback.get_data(),"imported-only fallback matches PNG rendering "+path)
		raw.convert(Image.FORMAT_RGBA8);sources[path]=raw.get_data();rendered[path]=live.get_data();widths[path]=raw.get_width()
	for key in catalog:
		var entry=catalog[key];var path=entry.sheet
		if not sources.has(path):continue
		var original:PackedByteArray=sources[path];var rgba:PackedByteArray=rendered[path];var width=int(widths[path]);var r=entry.rect
		var keyed=0;var visible_pixels=0;var correct_alpha=true;var rgb_unchanged=true
		for y in range(r[1],r[1]+r[3]):
			for x in range(r[0],r[0]+r[2]):
				var a=(y*width+x)*4;var b=(y*(width+1)+x)*4
				var is_key=original[a]>=166 and original[a+2]>=166 and original[a+1]<=89
				if is_key:keyed+=1
				if rgba[b+3]>0:visible_pixels+=1
				if rgba[b+3]!=(0 if is_key else original[a+3]):correct_alpha=false
				if rgba[b]!=original[a] or rgba[b+1]!=original[a+1] or rgba[b+2]!=original[a+2]:rgb_unchanged=false
		check(correct_alpha and keyed>0,"all native magenta becomes alpha zero "+key)
		check(rgb_unchanged and visible_pixels>0,"authored RGB retained and sprite visible "+key)

func verify_existing_characters():
	var sim = Sim.new(123, "town")
	for cls in C.CLASSES:
		var avatars=C.avatar_options(cls)
		var costumes=C.costume_options(cls).filter(func(key):return key!="none")
		var choices=[{"avatar":"auto","costume":"none"},{"avatar":avatars[1] if avatars.size()>1 else "auto","costume":"none"},{"avatar":"auto","costume":costumes[0] if not costumes.is_empty() else "none"}]
		for choice in choices:
			var costume=choice.costume
			sim.players.clear()
			var p = sim.add_player(1, "장비 이미지 검사", {"schema_version": 6, "level": 100, "class_id": cls, "avatar": choice.avatar, "costume": costume, "tutorial_done": true})
			check(C.appearance_allowed(cls,p.avatar,p.costume) and p.avatar==choice.avatar and p.costume==costume,"fixture obeys current class appearance rules "+cls)
			for slot in C.SLOTS:
				var item = E.make("sword" if slot == "weapon" else slot, 8, 3, "check-" + slot, "focus", cls)
				check(Inventory.add_gear(p, item) and Inventory.equip(p, item.id), "real equipment fixture " + cls + ":" + slot)
			sim.recalculate(p)
			var before: Dictionary = sim.persistent(1).duplicate(true)
			var values = stats(sim, p)
			for item in p.inventory:
				check(Art.texture(item) == C.icon_texture(item), "equipped item shares presentation texture " + cls)
			var local_snapshot = sim.snapshot(1).players[1]
			var remote_snapshot = sim.snapshot(2).players[1]
			check(local_snapshot.costume == costume and remote_snapshot.costume == costume and local_snapshot.avatar == p.avatar and remote_snapshot.avatar == p.avatar, "snapshots preserve original appearance " + cls + ":" + costume)
			check(sim.persistent(1) == before and stats(sim, p) == values, "item presentation preserves saved data and combat values " + cls + ":" + costume)
			check(not p.has("equipment_outfit") and not remote_snapshot.has("equipment_outfit"), "item images add no character outfit state " + cls)
			appearance_checks += 1
	for choice in C.COSTUMES:
		check(not str(choice).begins_with("gear_") and choice != "equipment_auto", "existing costume choices remain unchanged")
	sim = null

func verify_export_fixture(db:Dictionary,catalog:Dictionary):
	# Mirror the portable EXE fixture using the live DB, then pass it through
	# the actual save parser and session entry before artwork lookups.
	var paths=[]
	for entry in catalog.values():
		if entry.sheet not in paths:paths.append(entry.sheet)
	var fields=["id","name","base_name","category","slot","weapon_type","bonus","rarity","tier","affix","upgrade","family","job_lock","required_level","resonance"]
	var items=[];var placements={};var equipment={}
	for path in paths:
		var candidates=db.equipment.filter(func(row):return row.asset.path==path and row.family=="warrior" and row.get("job_lock","") in ["","warrior"])
		candidates.sort_custom(func(a,b):return a.tier<b.tier if a.tier!=b.tier else a.rarity<b.rarity if a.rarity!=b.rarity else a.id<b.id)
		check(not candidates.is_empty(),"export fixture has a real item for "+path)
		if candidates.is_empty():continue
		var item={}
		for field in fields:item[field]=candidates[0][field]
		placements[item.id]={"x":items.size(),"y":0,"rotated":false};items.append(item)
	for slot in C.SLOTS:equipment[slot]=""
	var sim=Sim.new(123,"town");sim.add_player(1,"장비 저장 검사")
	var fixture=sim.persistent(1).duplicate(true)
	fixture.merge({"world_seed":123,"level":100,"class_id":"warrior","costume":"none","avatar":"auto","inventory":items,"equipment":equipment,"equipped":"","bag_positions":placements,"materials":{},"potions":0,"skill_ranks":{},"skill_loadout":{},"constellation_allocations":{},"tutorial_done":true,"quest_done":true,"stats":{"strength":11,"endurance":7,"technique":9,"agility":5,"magic":3},"gold":4321,"creation_points":10},true)
	var local=preload("res://scripts/local_session.gd").new()
	local.slot=3;local.save_directory=ProjectSettings.globalize_path("res://../runtime/equipment-export-fixture-"+str(Time.get_ticks_usec()))
	check(local.write_save(fixture,local.save_path()),"write isolated six-atlas portable fixture")
	var parsed=local.parse_save(local.save_path())
	check(parsed!=null,"actual save parser accepts six-atlas fixture")
	if parsed!=null:
		check(local.enter_saved(parsed,fixture.name),"actual session restores six-atlas fixture")
		if local.connected:
			var restored=local.sim.persistent(1)
			for field in ["inventory","equipment","equipped","bag_positions","materials","potions","class_id","costume","avatar","skill_ranks","skill_loadout","constellation_allocations","stats","gold","level","creation_points"]:
				check(restored[field]==fixture[field],"portable fixture field preserved: "+field)
			var consumed=[]
			for item in restored.inventory:
				var descriptor=Art.describe_texture(C.icon_texture(item));consumed.append(descriptor.source_path)
				check(descriptor.key==Art.key(item) and descriptor.rgba_padded,"restored fixture consumes actual equipment reader "+item.id)
			check(consumed.size()==6 and paths.all(func(path):return path in consumed),"portable fixture reaches all six atlas sources")
	local.free();sim=null

func run():
	C.initialize_jobs()
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/equipment/items.json")).items
	check(catalog.size() == 115, "115 item sprites")
	var seen: Dictionary = {}
	var db = DB.snapshot()
	check(db.equipment.size() == 2500, "full equipment encyclopedia audited")
	for item in db.equipment:
		var before: Dictionary = item.duplicate(true)
		var key = Art.key(item)
		var texture: Texture2D = Art.texture(item)
		check(catalog.has(key), "known item sprite " + item.id)
		check(texture != null and texture is AtlasTexture, "actual equipment atlas loads " + item.id)
		check(Art.texture(item) == texture and C.icon_texture(item) == texture, "bag/drop share cached item texture " + item.id)
		if catalog.has(key) and texture is AtlasTexture:
			var entry = catalog[key]; var r = entry.rect
			check(texture.get_meta("source_path", "") == entry.sheet and texture.region == Rect2(r[0], r[1], r[2], r[3]), "item preserves source path and bounds " + item.id)
			var codex = DB.asset_texture(item)
			check(codex is AtlasTexture and codex.atlas == texture.atlas and codex.region == texture.region, "encyclopedia uses same sprite " + item.id)
		check(item == before, "art lookup leaves every equipment value unchanged " + item.id)
		seen[key] = true
		coverage.append({"item_id": item.id, "key": key, "tier": item.tier, "rarity": item.rarity, "slot": item.slot, "family": item.family})
	check(seen.size() == 115, "all 115 variants are reachable from real definitions")
	for key in catalog: check(seen.has(key), "no unused item sprite " + key)
	verify_rgba(catalog)
	var audit=Art.audit()
	check(audit.resolved_keys.size()==115 and audit.sheets.size()==6 and audit.failed_assets.is_empty(),"audit records all real atlas loads without missing assets")
	# The drop DB retains its pre-smart-loot axe illustration. It is not one of
	# the 2,500 class-bound equipment records checked above.
	var drop_axe={"id":"","key":"","category":"weapon","weapon_type":"axe","job_lock":"","reason":"legacy_appearance"}
	check(audit.fallback_requests==[drop_axe],"only the generic drop-table axe uses authored legacy compatibility: "+str(audit.fallback_requests))
	for row in audit.sheets:
		check(row.load_mode=="prepared_rgba" and row.source_png_available and row.imported_available,"source run uses prepared RGBA while preserving original source "+row.path)
	for key in catalog:
		var descriptor=Art.describe_texture(Art.cache[key]);var entry=catalog[key]
		check(descriptor.key==key and descriptor.source_path==entry.sheet and descriptor.rect==entry.rect and descriptor.rgba_padded,"actual consumer texture descriptor "+key)
	var legacy_axe = {"id": "legacy-axe", "name": "기존 도끼", "category": "weapon", "weapon_type": "axe", "bonus": 4, "rarity": 0}
	E.normalize(legacy_axe, {"class_id": "warrior"})
	check(legacy_axe.job_lock == "warrior" and Art.key(legacy_axe).is_empty() and C.icon_texture(legacy_axe) == preload("res://scripts/item_art.gd").texture("axe"), "migrated warrior axe retains its original axe artwork")
	check(Art.audit().fallback_requests.has({"id":"legacy-axe","key":"","category":"weapon","weapon_type":"axe","job_lock":"warrior","reason":"legacy_appearance"}) and Art.audit().failed_assets.is_empty(),"audit identifies migrated weapon compatibility separately from asset failures")
	verify_export_fixture(db,catalog)
	verify_existing_characters()
	var out = ProjectSettings.globalize_path("res://../artifacts")
	check(DirAccess.make_dir_recursive_absolute(out) == OK, "create equipment coverage directory")
	var file = FileAccess.open(out.path_join("equipment-art-coverage.json"), FileAccess.WRITE)
	check(file != null, "write item mapping audit")
	if file:
		file.store_string(JSON.stringify({"status": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures, "definitions": coverage, "appearance_checks": appearance_checks}, "  ")); file.close()
	print("EQUIPMENT_ART_MODEL checks=", checks, " failures=", failures.size(), " items=", seen.size(), " definitions=", coverage.size(), " appearances=", appearance_checks)
	quit(0 if failures.is_empty() else 1)
