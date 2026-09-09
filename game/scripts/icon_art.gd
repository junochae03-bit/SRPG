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
	if node.get("effect","")=="upgrade":
		Content.initialize_jobs()
		for group in Content.SKILLS.values():
			for other in group:
				if other.id==node.get("target",""):return skill(other)
	if node.get("runtime","")=="job":
		var mode=node.get("mode","")
		var mapped={"heal":32,"regen":32,"field_heal":34,"shield":33,"guard":33,"fortress":33,"haste":34,"buff_attack":10,"buff_crit":17,"buff_crit_damage":16,"shot":13,"fan":15,"barrage":14,"field":29,"slow":24,"wall":24,"burst":28,"chain":30,"blink":26,"summon":31,"pet_command":30,"pet_recall":26,"pet_heal":32,"pet_buff":34,"pet_haste":34,"pet_sacrifice":33,"bleed":7,"blind":25,"mark":13,"root":31,"trap":21,"trap_bleed":21,"bleed_shot":19,"pull_shot":23,"execute_shot":16,"slow_shot":24,"root_shot":21,"heavy":4,"heavy_dash":2,"heavy_execute":4,"charge":4,"charge_area":1,"charge_spin":1,"charge_execute":11,"parry":9,"parry_counter":9,"parry_knee":9,"combo":1,"finisher":11,"rush":2,"retreat":12,"weave":26,"teleport":26,"teleport_chain":30,"chain_pull":23,"chain_dash":2,"chain_group":30,"chain_retreat":12,"settle":27,"settle_fan":27,"settle_heavy":28,"settle_barrage":29}
		if mapped.has(mode):return texture("active",mapped[mode])
	if node.get("effect","")=="passive":
		var family=Content.base_class(str(node.id).get_slice("_",0));var index=int(str(node.id).right(2))-1
		var indices={"warrior":[5,22,2,3,6,7],"mage":[26,1,24,3,11,28],"ranger":[18,25,22,17,4,14],"rogue":[4,25,20,9,26,24],"fighter":[3,2,6,5,15,8]}
		return texture("support",indices.get(family,[0,1,2,3,4,5])[clampi(index,0,5)])
	return texture("active",ACTIVE.get(node.get("id",""),int(node.get("index",0))%36)) if node.get("effect","")=="active" else texture("support",SUPPORT.get(node.get("effect",""),28))
static func function_icon(key:String)->Texture2D:return texture("support",SUPPORT[key])
static func action(p:Dictionary,key:String,weapon:String)->Texture2D:
	if key in Content.ACTIONS:return skill(Content.active_node(p,key))
	if key=="nova":return texture("active",{"warrior":11,"ranger":15,"mage":26}[p.class_id])
	if key=="attack":return texture("active",{"sword":0,"axe":1,"bow":13,"staff":27}[weapon])
	if key=="heavy":return texture("active",{"sword":4,"axe":1,"bow":16,"staff":28}[weapon])
	return function_icon(key)
