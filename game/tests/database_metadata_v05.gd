extends SceneTree
const DB=preload("res://scripts/game_database.gd")
const EquipmentArt=preload("res://scripts/equipment_art.gd")
const Content=preload("res://scripts/content.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	check(EquipmentArt.sheets.is_empty() and EquipmentArt.cache.is_empty(),"fresh process has no decoded equipment sheets")
	var start=Time.get_ticks_usec();var db=DB.snapshot();var elapsed_ms=(Time.get_ticks_usec()-start)/1000.
	check(EquipmentArt.sheets.is_empty() and EquipmentArt.cache.is_empty(),"cold snapshot reads equipment metadata without decoding any sheet")
	check(DB._textures.is_empty(),"metadata snapshot does not populate visible-card texture cache")
	check(db.equipment.size()==2500 and db.drops.size()==132 and db.raid_drops.size()==24,"all existing item records remain present")
	# Compare the published portable records independently of the new helper.
	var baseline_path=ProjectSettings.globalize_path("res://../docs/database/stelrpg-database.json")
	var published=JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
	check(published is Dictionary,"portable database regression baseline is readable")
	if published is Dictionary:
		for table in ["equipment","drops","raid_drops"]:
			var expected={}
			for row in published[table]:expected[row.id]=row
			check(db[table].size()==expected.size(),"unchanged table size "+table)
			for row in db[table]:
				check(expected.has(row.id),"existing record ID "+row.id)
				if expected.has(row.id):
					check(row.asset==expected[row.id].asset,"original path and rectangle preserved "+row.id)
	# An unsupported old axe and non-equipment drops keep the original fallback.
	for item in [{"category":"weapon","weapon_type":"axe"},{"category":"consumable"},{"category":"material","material":"ore"}]:
		check(DB._item_asset(item)==DB._texture_ref(Content.icon_texture(item)),"legacy fallback remains identical "+str(item))
	check(EquipmentArt.sheets.is_empty(),"legacy fallback never decodes a new equipment sheet")
	# Resolving one visible card loads only its atlas; other five remain deferred.
	var row=db.equipment[0];var original_asset=row.asset.duplicate(true)
	var texture=DB.asset_texture(row)
	check(texture!=null,"visible equipment card still resolves")
	check(EquipmentArt.sheets.size()==1 and EquipmentArt.cache.size()==1,"one visible card loads exactly one equipment atlas and region")
	if texture!=null:check(DB._texture_ref(texture)==original_asset,"lazy texture retains original source path and bounds")
	check(row.asset==original_asset,"texture resolution does not mutate metadata")
	print("DATABASE_METADATA_V05_TESTS checks=",checks," failures=",failures.size()," cold_snapshot_ms=",elapsed_ms," loaded_equipment_sheets=",EquipmentArt.sheets.size())
	quit(0 if failures.is_empty() else 1)
