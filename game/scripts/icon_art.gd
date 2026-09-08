extends RefCounted
const Content=preload("res://scripts/content.gd")
const ACTIVE={"blade_wave":0,"whirlwind":1,"rush":2,"warrior_fan":3,"warrior_burst":4,"warrior_field":5,"warrior_chain":6,"warrior_pull":7,"warrior_heal":8,"warrior_barrier":9,"warrior_haste":10,"warrior_nova_ring":11,"retreat_shot":12,"piercing_shot":13,"arrow_rain":14,"ranger_fan":15,"ranger_burst":16,"ranger_field":17,"ranger_chain":18,"ranger_pull":19,"ranger_heal":20,"ranger_barrier":21,"ranger_haste":22,"ranger_nova_ring":23,"frost_nova":24,"thunder":25,"blink":26,"mage_fan":27,"mage_burst":28,"mage_field":29,"mage_chain":30,"mage_pull":31,"mage_heal":32,"mage_barrier":33,"mage_haste":34,"mage_nova_ring":35}
const SUPPORT={"damage":0,"health":1,"defense":2,"stamina":3,"stamina_regen":3,"speed":4,"heavy_power":5,"critical":6,"critical_damage":7,"lifesteal":8,"execute":9,"thorns":10,"health_regen":11,"potion_power":12,"potion":12,"xp_bonus":13,"gold_bonus":14,"dodge_duration":15,"dodge_discount":15,"dodge":15,"sprint_discount":16,"heavy_discount":17,"skill_discount":17,"projectile_speed":18,"pierce":18,"slow_duration":19,"stun_duration":20,"knockback":21,"elite_damage":22,"attack_haste":23,"skill_haste":24,"range":25,"melee_range":25,"skill_radius":25,"skill_power":26,"satchel":27,"growth":28,"interact":29,"return":30,"portal":30,"smith":31,"shop":32,"alchemy":33,"guild":34,"inn":35}
static var catalog:Dictionary={}
static var cache:Dictionary={}
static func texture(sheet:String,index:int)->AtlasTexture:
	if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/icons/catalog.json"))
	var key=sheet+str(index)
	if not cache.has(key):
		var data=catalog[sheet];var r=data.frames[index]
		var tex=AtlasTexture.new();tex.atlas=load(data.sheet);tex.region=Rect2(r[0],r[1],r[2],r[3]);tex.filter_clip=true;cache[key]=tex
	return cache[key]
static func skill(node:Dictionary)->Texture2D:
	return texture("active",ACTIVE[node.id]) if node.effect=="active" else texture("support",SUPPORT[node.effect])
static func function_icon(key:String)->Texture2D:return texture("support",SUPPORT[key])
static func action(p:Dictionary,key:String,weapon:String)->Texture2D:
	if key in ["skill_f","skill_v","skill_c"]:return skill(Content.active_node(p,key))
	if key=="nova":return texture("active",{"warrior":11,"ranger":15,"mage":26}[p.class_id])
	if key=="attack":return texture("active",{"sword":0,"axe":1,"bow":13,"staff":27}[weapon])
	if key=="heavy":return texture("active",{"sword":4,"axe":1,"bow":16,"staff":28}[weapon])
	return function_icon(key)
