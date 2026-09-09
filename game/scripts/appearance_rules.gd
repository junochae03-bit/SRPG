extends RefCounted
# Selections match the visible weapon/motion. Unknown legacy illustrations remain
# available to existing NPC consumers rather than appearing in every job's picker.
const AVATARS={
	"warrior":["gat_role_tank_1","gat_role_tank_2","gat_blade_combat","gat_role_single_2"],
	"ranger":["gat_role_single_1"],
	"mage":["gat_role_aoe_1","gat_role_aoe_2","gat_role_buffer_1","gat_role_buffer_2","gat_role_debuffer_1","gat_role_debuffer_2","gat_role_healer_1","gat_role_healer_2"],
	"rogue":[],"fighter":[]}
const LEGACY={"traveler":["warrior"],"witch":["mage"],"starlight":["mage"],"celestial":["mage"],"gat_addition_01_1":["mage"],"gat_addition_02_2":["mage"],"gat_addition_10_2":["warrior"]}
static var custom={}
static var loaded=false
static func initialize():
	if loaded:return
	loaded=true;custom=JSON.parse_string(FileAccess.get_file_as_string("res://assets/costume_v04/class_matching.json"))
static func avatars(base:String)->Array:
	initialize();var result=["auto"]+AVATARS.get(base,[])
	for key in custom:
		if key.begins_with("gat_addition_") and base in custom[key].get("allowed_base_classes",[]):result.append(key)
	return result
static func allows_costume(id:String,job:String,base:String)->bool:
	if id=="none":return true
	initialize()
	if custom.has(id):
		var rule=custom[id]
		return job in rule.get("allowed_classes",[]) or base in rule.get("allowed_base_classes",[])
	return base in LEGACY.get(id,[])
