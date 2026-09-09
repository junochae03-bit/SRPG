extends RefCounted
static var catalog:Dictionary={}
static var cache:Dictionary={}
# Curated after viewing the actual atlas artwork. Registration is an available
# library, not an instruction to scatter every finished illustration on a map.
const LIVE_POOLS={
	"forest":["forest_oak_tree","forest_birch_tree","forest_mossy_boulders","forest_flower_shrub","forest_hollow_log"],
	"snow":["snow_snow_fir","snow_frost_birch","snow_ice_boulders","snow_snow_shrub","snow_stone_cairn"],
	"autumn":["autumn_maple_tree","autumn_ginkgo_tree","autumn_leafy_boulders","autumn_berry_shrub","autumn_mushroom_stump"],
	"marsh":["marsh_willow_tree","marsh_hollow_cypress","marsh_fern_boulders","marsh_cattails","marsh_shelf_mushrooms"],
	"flood":["flood_coral_arch","flood_sunken_column","flood_rust_gate","flood_tidal_basin","flood_shipwreck_crate","flood_bronze_beacon","ruins_ivy_arch","ruins_obelisk","ruins_broken_column","ruins_wall_corner","ruins_stone_basin","ruins_rubble"],
	"spore":["spore_canopy_mushroom","spore_root_nest","spore_shelf_log","spore_puffball_cluster","spore_mycelium_stone","marsh_willow_tree","marsh_hollow_cypress","marsh_fern_boulders","marsh_cattails","marsh_shelf_mushrooms"],
	"lava":["lava_basalt_arch","lava_fumarole_pillar","lava_ember_crystals","lava_scorched_cart","lava_slag_boulders","lava_forge_brazier"],
	"nebula":["nebula_moonstone_arch","nebula_star_geode","nebula_celestial_orrery","nebula_astral_lantern","nebula_quartz_boulders","nebula_crystal_monolith"],
	"core":["core_fractured_pylon","core_bound_core","core_broken_ring_gate","core_core_altar","core_core_fragments","core_chained_obelisk"]}
static func initialize():
	if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/biomes-v04/catalog.json"))
static func theme(zone:String,floor_number:int)->String:
	initialize()
	if floor_number>0:return catalog.chapters[clampi(int((floor_number-1)/10),0,9)]
	return zone if catalog.themes.has(zone) else "forest"
static func ids(zone:String,floor_number:int)->Array:
	initialize();var key=theme(zone,floor_number)
	return LIVE_POOLS.get(key,catalog.themes[key])
static func available_ids(zone:String,floor_number:int)->Array:
	initialize();return catalog.themes[theme(zone,floor_number)]
static func frame(id:String)->Dictionary:
	initialize();var entry=catalog.objects[id]
	if not cache.has(id):
		var texture=AtlasTexture.new();var r=entry.rect
		texture.atlas=load(entry.sheet);texture.region=Rect2(r[0],r[1],r[2],r[3]);texture.filter_clip=true
		cache[id]=texture
	return {"texture":cache[id],"foot":Vector2(entry.foot[0],entry.foot[1]),"height":entry.rect[3],"id":id}
static func height(id:String)->float:
	if id.contains("tree") or id.contains("fir") or id.contains("birch") or id.contains("cypress"):return 225.
	if id.contains("arch") or id.contains("gate") or id.contains("column") or id.contains("tower") or id.contains("pylon"):return 172.
	if id.contains("shrub") or id.contains("rubble") or id.contains("scrap") or id.contains("fragments"):return 72.
	if id.contains("boulder") or id.contains("log") or id.contains("cattail") or id.contains("boardwalk"):return 94.
	return 125.
