extends SceneTree
const DB=preload("res://scripts/game_database.gd")
const Town=preload("res://scripts/town_operations.gd")
const Inv=preload("res://scripts/inventory_model.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const Training=preload("res://scripts/training_ground.gd")
var failures=0
func _initialize():run.call_deferred()
func check(value:bool,label:String):
	if not value:failures+=1;push_error(label)
func run():
	var data=DB.snapshot()
	check(data.inventory_rules[0].capacity==Inv.WIDTH*Inv.HEIGHT,"live capacity")
	check(data.inventory_rules[0].max_materials==Inv.MAX_MATERIALS,"live material limit")
	check(data.dungeon_layouts.size()==Dungeon.LAYOUTS.size(),"all layouts")
	for layout in data.dungeon_layouts:
		check(layout.points==Dungeon.LAYOUTS[layout.id].points and layout.links==Dungeon.LAYOUTS[layout.id].links,"layout graph "+layout.id)
	check(data.training_rules[0].health==Training.HEALTH,"training target health")
	check(data.training_rules[0].empty_summary.dps==0,"empty DPS")
	check(data.service_operations.size()==Town.OPERATIONS.size(),"primary routing count")
	var found_batch=false
	for sample in data.service_samples:
		if sample.operation_id=="alchemy:potion" and sample.quantity==5:
			found_batch=true
			var q=Town.describe(DB._service_reference_player(),"alchemy","potion",{"quantity":5})
			check(sample.gold_cost==q.cost,"batch cost matches live quote")
			var output=0
			for row in data.service_outputs:
				if row.sample_id==sample.id and row.item_id=="potion":output+=row.amount
			check(output==q.outputs.potion,"batch output matches live quote")
	check(found_batch,"batch recipe present")
	var art=DB.snapshot(true)
	var environment=preload("res://scripts/environment_art.gd")
	var expected_live={}
	for floor_row in data.floors:
		for key in environment.ids(floor_row.terrain,floor_row.id):expected_live["art:environment:"+key]=true
	for zone in ["town","forest"]:
		for key in environment.ids(zone,0):expected_live["art:environment:"+key]=true
	var registered_environment=0
	var applied_environment=0
	var available_environment=0
	for asset in art.art_assets:
		if not asset.id.begins_with("art:environment:"):continue
		registered_environment+=1
		if asset.status=="applied":applied_environment+=1
		else:available_environment+=1
		check((asset.status=="applied")==expected_live.has(asset.id),"배경 적용 상태와 실제 배치 목록 일치: "+asset.id)
	check(registered_environment==108 and registered_environment==environment.catalog.objects.size(),"배경 원화 108개 전체 등록")
	check(applied_environment==68 and available_environment==40,"배경 적용 68개 및 준비 40개 구분")
	for use_row in art.art_uses:
		if use_row.art_id.begins_with("art:environment:") and not expected_live.has(use_row.art_id):
			check(use_row.target_table=="catalog" and use_row.usage_kind=="catalog_available","미배치 배경은 준비 목록에만 연결")
	var shared_building_owners=[]
	var facility_icons={}
	for use_row in art.art_uses:
		if use_row.art_id=="art:town:1" and use_row.target_table=="facilities":shared_building_owners.append(use_row.target_id)
		if use_row.target_table=="runtime" and use_row.target_id in ["town:costume","town:training"] and use_row.art_id.begins_with("art:icon:"):facility_icons[use_row.target_id]=use_row.art_id
	check(shared_building_owners.has("shop") and shared_building_owners.has("costume"),"shared building art preserves both facility uses")
	check(facility_icons.get("town:costume","")=="art:icon:chest","costume icon alias resolved")
	check(facility_icons.get("town:training","")=="art:icon:physical_attack","training icon alias resolved")
	var training_art={}
	for asset in art.art_assets:
		if asset.id=="art:training:scarecrow":training_art=asset
	check(not training_art.is_empty(),"training art registered")
	if not training_art.is_empty():
		var actual=preload("res://scripts/training_art.gd").texture()
		check(training_art.rect==[actual.region.position.x,actual.region.position.y,actual.region.size.x,actual.region.size.y],"actual training crop")
		check(training_art.metadata.source_dimensions==[actual.atlas.get_width(),actual.atlas.get_height()],"actual training PNG dimensions")
		var owners=[]
		for use_row in art.art_uses:
			if use_row.art_id==training_art.id:owners.append(use_row.target_table+":"+use_row.target_id)
		check(owners.has("facilities:training") and owners.has("training_rules:training"),"training portrait and world target owners")
	print("DATABASE_WORLD_RULES_V052 failures=",failures)
	quit(0 if failures==0 else 1)
