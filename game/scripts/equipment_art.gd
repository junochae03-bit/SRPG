extends RefCounted

const CATALOG_PATH="res://assets/equipment/items.json"
const JOBS=["warrior","ranger","mage","rogue","fighter","tank","runesword","swordsman","summoner","elementalist","healer","sniper","hunter","explorer","thief","reaper","gambler","breaker","infighter","martialist"]
const FAMILIES=["warrior","mage","ranger","rogue","fighter"]
const ARMOR_SLOTS=["head","chest","hands","legs","feet"]
const ACCESSORIES=["seed_necklace","amber_brooch","crystal_ring","star_earrings","dawn_pendant"]
const ItemArt=preload("res://scripts/item_art.gd")
const JobItemArt=preload("res://scripts/job_item_art.gd")
static var catalog:Dictionary={}
static var cache:Dictionary={}
static var sheets:Dictionary={}
static var load_modes:Dictionary={}
static var fallback_requests:Array=[]
static var failed_assets:Array=[]
static var initialized=false

# Presentation keys are derived from saved equipment fields; items remain unchanged.
static func key(item:Dictionary)->String:
	if item.is_empty():return ""
	var category=str(item.get("category","weapon"))
	var tier=clampi(int(item.get("tier",0)),0,9)
	match category:
		"weapon":
			var job=str(item.get("job_lock",""))
			if job.is_empty():
				var family=str(item.get("family",""))
				job=family if family in FAMILIES else {"sword":"warrior","bow":"ranger","staff":"mage"}.get(str(item.get("weapon_type","sword")),"")
			if job not in JOBS:return ""
			# Old saves can retain a different usable weapon on the three base jobs.
			var base_weapon={"warrior":"sword","ranger":"bow","mage":"staff"}.get(job,"")
			if base_weapon!="" and item.has("weapon_type") and str(item.weapon_type)!=base_weapon:return ""
			return "weapon_"+job+"_"+("trail" if tier<3 else "adept" if tier<7 else "relic")
		"armor":
			var family=str(item.get("family","warrior"));var slot=str(item.get("slot","chest"))
			if family not in FAMILIES or slot not in ARMOR_SLOTS:return ""
			return "armor_"+family+"_"+slot+"_"+("trail" if tier<5 else "relic")
		"accessory":return "accessory_"+ACCESSORIES[int(tier/2)]
	return ""

static func initialize():
	if initialized or not FileAccess.file_exists(CATALOG_PATH):return
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Dictionary and parsed.get("items") is Dictionary:
		catalog=parsed.items;initialized=true

static func texture(item:Dictionary)->Texture2D:
	var appearance=key(item)
	if appearance.is_empty():return legacy_texture(item)
	initialize()
	if cache.has(appearance):return cache[appearance]
	var entry=catalog.get(appearance,{})
	if not entry is Dictionary:return legacy_texture(item,"asset_failure")
	var rect=entry.get("rect",[]);var path=str(entry.get("sheet",""))
	if not rect is Array or rect.size()!=4 or path.is_empty() or not ResourceLoader.exists(path):return legacy_texture(item,"asset_failure")
	var source=sheet_texture(path)
	if source==null:return legacy_texture(item,"asset_failure")
	var region=Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3]))
	if region.position.x<0 or region.position.y<0 or region.size.x<=0 or region.size.y<=0 or region.end.x>source.get_width() or region.end.y>source.get_height():return legacy_texture(item,"asset_failure")
	var result=AtlasTexture.new();result.atlas=source;result.region=region;result.filter_clip=true
	result.set_meta("source_path",path)
	cache[appearance]=result;return result

static func source_image(path:String,imported_only:bool=false)->Image:
	# Source PNGs are available during development; exported PCKs may only
	# contain an imported texture/remap. Both paths retain the original pixels.
	if not imported_only and FileAccess.file_exists(path):
		var raw=Image.new()
		if raw.load_png_from_buffer(FileAccess.get_file_as_bytes(path))==OK:
			raw.set_meta("equipment_load_mode","source_png");return raw
	var imported=load(path) as Texture2D if ResourceLoader.exists(path) else null
	if imported==null:return null
	var image=imported.get_image()
	if image!=null:image.set_meta("equipment_load_mode","imported_texture")
	return image

static func rgba_image(source:Image)->Image:
	if source==null or source.is_empty():return null
	var image=source.duplicate() as Image
	if image.is_compressed() and image.decompress()!=OK:return null
	image.clear_mipmaps();image.convert(Image.FORMAT_RGBA8)
	var pixels=image.get_data()
	for at in range(0,pixels.size(),4):
		if pixels[at]>=166 and pixels[at+2]>=166 and pixels[at+1]<=89:pixels[at+3]=0
	var keyed=Image.create_from_data(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8,pixels)
	# Avoid the shared world shader's size-based violet-crystal key branch.
	# Right/bottom padding leaves every authored atlas rectangle unchanged.
	var padded=Image.create(keyed.get_width()+1,keyed.get_height()+1,false,Image.FORMAT_RGBA8)
	padded.fill(Color.TRANSPARENT);padded.blit_rect(keyed,Rect2i(Vector2i.ZERO,keyed.get_size()),Vector2i.ZERO)
	return padded

static func sheet_texture(path:String)->ImageTexture:
	if sheets.has(path):return sheets[path]
	var source=source_image(path);var image=rgba_image(source)
	if image==null:
		if path not in failed_assets:failed_assets.append(path)
		return null
	var result=ImageTexture.create_from_image(image);sheets[path]=result;load_modes[path]=str(source.get_meta("equipment_load_mode","unknown"));return result

static func texture_for_asset(asset:Dictionary)->Texture2D:
	initialize();var rect=asset.get("rect",[])
	if rect.size()!=4:return null
	var region=Rect2(rect[0],rect[1],rect[2],rect[3])
	for appearance in catalog:
		var entry=catalog[appearance];var bounds=entry.rect
		if entry.sheet==asset.get("path","") and region==Rect2(bounds[0],bounds[1],bounds[2],bounds[3]):
			if cache.has(appearance):return cache[appearance]
			var source=sheet_texture(entry.sheet)
			if source==null:return null
			var result=AtlasTexture.new();result.atlas=source;result.region=region;result.filter_clip=true;result.set_meta("source_path",entry.sheet)
			cache[appearance]=result;return result
	var missing=str(asset)
	if missing not in failed_assets:failed_assets.append(missing)
	return null

static func describe_texture(value:Texture2D)->Dictionary:
	if not value is AtlasTexture or not value.has_meta("source_path"):return {}
	var path=str(value.get_meta("source_path"));var appearance=""
	for candidate in cache:
		if cache[candidate]==value:appearance=candidate;break
	return {"key":appearance,"source_path":path,"rect":[value.region.position.x,value.region.position.y,value.region.size.x,value.region.size.y],"rgba_padded":sheets.get(path)==value.atlas and value.atlas is ImageTexture}

static func audit()->Dictionary:
	var records=[]
	for path in sheets:
		var texture=sheets[path]
		records.append({"path":path,"load_mode":load_modes.get(path,"unknown"),"width":texture.get_width(),"height":texture.get_height(),"source_png_available":FileAccess.file_exists(path),"imported_available":ResourceLoader.exists(path)})
	return {"resolved_keys":cache.keys(),"sheets":records,"fallback_requests":fallback_requests.duplicate(),"failed_assets":failed_assets.duplicate()}

static func legacy_texture(item:Dictionary,reason:String="legacy_appearance")->Texture2D:
	var requested={"id":str(item.get("id","")),"key":key(item),"category":str(item.get("category","weapon")),"weapon_type":str(item.get("weapon_type","")),"job_lock":str(item.get("job_lock","")),"reason":reason}
	if requested not in fallback_requests:fallback_requests.append(requested)
	if reason=="asset_failure" and requested not in failed_assets:failed_assets.append(requested)
	if item.get("category","")=="weapon" and item.get("job_lock","") in JobItemArt.JOBS:return JobItemArt.texture(item.job_lock)
	var old_key=str(item.get("weapon_type","sword"))
	match item.get("category","weapon"):
		"armor","accessory":old_key=str(item.get("slot","chest"))
		"consumable":old_key="potion"
		"material":old_key=str(item.get("material",str(item.get("id","")).trim_prefix("@mat:")))
	return ItemArt.texture(old_key)
