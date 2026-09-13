extends RefCounted
## Runtime projection of the design DB; no character state is stored here.
const PATH="res://data/exploration_crafting_v071.json"
static var _data:Dictionary={}
static func catalog()->Dictionary:
	if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data
static func materials()->Dictionary:return catalog().materials
static var _recipes:Dictionary={}
static func recipes()->Dictionary:
	if _recipes.is_empty():
		_recipes=catalog().recipes.duplicate(true)
		_recipes.merge(catalog().get("advanced_recipes",{}),false)
	return _recipes
static func enhancement_material(item:Dictionary,target:int)->String:
	for band in catalog().enhancement_materials.bands:
		if target>=int(band.target_min) and target<=int(band.target_max):return str(band.material_by_tier.get(str(int(item.get("tier",0))),"ore"))
	return "ore"
static func names()->Dictionary:
	var result={"seed":"별씨앗","ore":"반짝 광석","essence":"정원의 정수","tool":"탐사 도구"}
	for key in materials():result[key]=materials()[key].name
	return result
static func icon(key:String)->String:
	var value=str(materials().get(key,{}).get("icon","ore"))
	return {"coin":"gold","satchel":"bag"}.get(value,value)
static func limit(key:String)->int:return int(materials().get(key,{}).get("stack",99))
