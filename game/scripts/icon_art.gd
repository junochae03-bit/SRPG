extends RefCounted
## Semantic icon routing shared by the skill tree, HUD, services and codex.
const Content=preload("res://scripts/content.gd")
const Library=preload("res://scripts/icon_library.gd")

# Legacy function/effect names remain accepted; every value is a semantic key.
const SUPPORT={
	"damage":"physical_attack","health":"health","defense":"defense","stamina":"stamina",
	"stamina_regen":"stamina","speed":"agility","heavy_power":"charge","critical":"critical",
	"critical_damage":"critical_damage","lifesteal":"lifesteal","execute":"vulnerable","thorns":"counter",
	"health_regen":"regen","potion_power":"heal","potion":"consumable","xp_bonus":"experience",
	"gold_bonus":"gold","dodge_duration":"dash","dodge_discount":"dash","dodge":"dash",
	"sprint_discount":"agility","sprint":"agility","heavy_discount":"stamina","skill_discount":"stamina",
	"projectile_speed":"arrow","pierce":"arrow","slow_duration":"slow","stun_duration":"stun",
	"knockback":"strength","elite_damage":"elite","attack_haste":"attack_speed","skill_haste":"cooldown",
	"range":"range","melee_range":"range","skill_radius":"area","skill_power":"arcane",
	"satchel":"bag","growth":"skills","interact":"interact","return":"return_home","portal":"portal",
	"smith":"smith","shop":"shop","alchemy":"alchemy","guild":"guild","inn":"inn",
	"attack":"physical_attack","heavy":"charge","nova":"arcane"
}
const BASIC_ACTIVE={
	"blade_wave":"slash","whirlwind":"whirlwind","rush":"dash",
	"warrior_fan":"slash","warrior_burst":"earth","warrior_field":"rune",
	"warrior_chain":"chain","warrior_pull":"chain","warrior_heal":"heal",
	"warrior_barrier":"shield","warrior_haste":"haste","warrior_nova_ring":"holy",
	"piercing_shot":"arrow","arrow_rain":"arrow","retreat_shot":"dash",
	"ranger_fan":"arrow","ranger_burst":"fire","ranger_field":"trap",
	"ranger_chain":"arrow","ranger_pull":"wind","ranger_heal":"heal",
	"ranger_barrier":"shield","ranger_haste":"haste","ranger_nova_ring":"whirlwind",
	"frost_nova":"ice","thunder":"lightning","blink":"dash",
	"mage_fan":"arcane","mage_burst":"fire","mage_field":"ice",
	"mage_chain":"lightning","mage_pull":"arcane","mage_heal":"heal",
	"mage_barrier":"shield","mage_haste":"haste","mage_nova_ring":"arcane"
}
const MODES={
	"ally_dash":"dash","heal":"heal","regen":"regen","field_heal":"regen",
	"shield":"shield","guard":"guard","fortress":"shield","wall":"shield","share":"shield",
	"haste":"haste","buff_crit":"critical","buff_crit_damage":"critical_damage",
	"chant":"holy","enchant":"rune","cleanse":"heal","distribute":"gift",
	"dash":"dash","rush":"dash","retreat":"dash","weave":"dash","flank":"dash",
	"blink":"dash","teleport":"dash","teleport_chain":"shadow","return_anchor":"return_home",
	"spin":"whirlwind","charge_spin":"whirlwind","combo":"combo","finisher":"combo_resource",
	"uppercut":"strength","break_guard":"armor_break","charge":"charge","charge_area":"earth",
	"charge_execute":"charge","heavy":"charge","heavy_dash":"dash","heavy_execute":"charge",
	"execute":"slash","root":"root","slow":"slow","stun":"stun","bleed":"bleed",
	"blind":"blind","weaken":"weaken","vulnerable":"vulnerable","break_armor":"armor_break",
	"mark":"mark","taunt":"taunt","pull":"chain","parry":"guard","parry_counter":"counter",
	"parry_knee":"counter","meditate":"momentum","trap":"trap","trap_bleed":"trap",
	"chain_pull":"chain","chain_dash":"chain","chain_group":"chain","chain_retreat":"chain",
	"root_shot":"root","slow_shot":"slow","bleed_shot":"bleed","pull_shot":"chain","execute_shot":"arrow",
	"summon":"summon","pet_command":"pet_command","pet_buff":"companion","pet_haste":"haste",
	"pet_guard":"guard","pet_heal":"heal","pet_recall":"companion","pet_burst":"pet_command",
	"pet_pull":"chain","pet_sacrifice":"shield",
	"hit_card":"card_draw","hold_card":"card_hold","cut_card":"card_discard","stand_card":"card_hold",
	"settle":"card_hand","settle_fan":"card_hand","settle_heavy":"card_hand","settle_barrage":"card_hand",
	"dice":"dice","reroll":"dice","dice_buff":"dice","card_retreat":"card_hand"
}
# Each row follows that job's p01..p06 descriptions and JobBalance.passive_metrics.
const JOB_PASSIVES={
	"tank":["shield","defense","guard","shield","counter","taunt"],
	"runesword":["rune","attack_speed","area","stamina","cooldown","shield"],
	"swordsman":["slash","boss","combo","stamina","critical","critical_damage"],
	"summoner":["summon","companion","rune","stamina","cooldown","pet_command"],
	"elementalist":["fire","burn","ice","guard","lightning","stamina"],
	"healer":["heal","stamina","holy","stamina","shield","shield"],
	"sniper":["arrow","range","boss","stamina","agility","dash"],
	"hunter":["bleed","arrow","trap","root","gift","pickup"],
	"explorer":["chain","attack_speed","root","vulnerable","stamina","agility"],
	"thief":["dash","mark","area","vulnerable","gift","cooldown"],
	"reaper":["chain","haste","charge","shadow","heal","cooldown"],
	"gambler":["card_discard","dash","card_hand","dice","cooldown","arrow"],
	"infighter":["rush_resource","strength","haste","dash","defense","heal"],
	"breaker":["momentum","guard","stamina","counter","defense","cooldown"],
	"martialist":["range","combo_resource","combo","stagger","attack_speed","physical_attack"]
}
# Specializations route by their actual behavior, never by an old FX row.
const CONSTELLATION_EFFECTS={
	"skill_damage":"skills","skill_range":"range","skill_radius":"area","skill_haste":"cooldown",
	"skill_discount":"stamina","skill_duration":"cooldown","move_speed":"agility","attack_speed":"attack_speed",
	"stagger_power":"stagger","support_power":"holy","followup_damage":"combo","stagger_followup":"stagger",
	"execute_damage":"vulnerable","efficiency_followup":"stamina","mobility_refund":"dash","slow_on_followup":"slow",
	"support_followup":"holy","guard_on_followup":"shield","control_damage":"root","heal_on_followup":"regen",
	"echo":"area","focus":"mark","momentum":"momentum","warrior_wave":"slash","warrior_reprise":"counter",
	"ranger_chain":"chain","ranger_snare":"trap","mage_burn":"burn","mage_relay":"rune",
	"rogue_contract":"mark","rogue_venom":"poison","fighter_flurry":"combo","fighter_crush":"charge"
}
static var nodes_by_id:Dictionary={}

static func lookup_node(id:String)->Dictionary:
	if nodes_by_id.is_empty():
		Content.initialize_jobs()
		for group in Content.SKILLS.values():
			for node in group:nodes_by_id[node.id]=node
	return nodes_by_id.get(id,{})

static func key_for_skill(node:Dictionary)->String:
	if node.is_empty():return "skill_empty"
	var id=str(node.get("id",""));var effect=str(node.get("effect",""))
	var cls=id.get_slice("_",0)
	if effect=="constellation":
		for key in node.get("effects",{}):
			if key=="skill_damage":return "magic_attack" if node.get("family","")=="mage" else "physical_attack"
			if CONSTELLATION_EFFECTS.has(key):return CONSTELLATION_EFFECTS[key]
		return "unknown"
	if effect=="upgrade":
		var target=lookup_node(str(node.get("target","")))
		return key_for_skill(target) if not target.is_empty() and target.get("effect","")!="upgrade" else "unknown"
	if effect=="passive":
		var index=int(id.right(2))-1;var keys=JOB_PASSIVES.get(cls,[])
		return keys[index] if index>=0 and index<keys.size() else "unknown"
	if effect!="active":
		if effect=="damage" and cls=="mage":return "magic_attack"
		return SUPPORT.get(effect,"unknown")
	if BASIC_ACTIVE.has(id):return BASIC_ACTIVE[id]
	var mode=str(node.get("mode",""))
	if cls=="elementalist":
		# Fire / ice / lightning are separate branches sharing old FX rows.
		var number=int(id.trim_prefix("elementalist_a"))
		if number>=1 and number<=4:return "fire"
		if number>=5 and number<=8:return "ice"
		if number in [9,10]:return "lightning"
		if number==11:return "haste"
		if number==12:return "wind"
	if MODES.has(mode):return MODES[mode]
	match mode:
		"strike":return "strength" if cls in ["fighter","breaker","infighter","martialist"] else "holy" if cls=="healer" else "slash"
		"shot","fan":return "arcane" if cls in ["mage","summoner"] else "arrow"
		"field":return "rune" if cls in ["warrior","runesword"] else "trap" if cls in ["ranger","hunter"] else "area"
		"burst":return "rune" if cls=="runesword" else "earth"
		"barrage":return "arrow" if cls in ["ranger","sniper","hunter"] else "combo"
		"chain":return "lightning" if cls in ["mage","elementalist","runesword"] else "chain"
		"buff_attack","stance","empower":return "magic_attack" if cls in ["mage","elementalist","summoner"] else "physical_attack"
	return "unknown"

static func skill(node:Dictionary)->Texture2D:
	return Library.texture(key_for_skill(node))

static func function_icon(key:String)->Texture2D:
	return Library.texture(SUPPORT.get(key,key))

static func action(p:Dictionary,key:String,weapon:String)->Texture2D:
	if key in Content.ACTIONS:
		Content.initialize_jobs()
		if not Content.SKILLS.has(p.get("class_id","")):return Library.texture("skill_empty")
		return skill(Content.active_node(p,key))
	if key=="nova":
		var base=Content.base_class(str(p.get("class_id","warrior")))
		return Library.texture({"warrior":"slash","ranger":"arrow","mage":"arcane","rogue":"shadow","fighter":"strength"}.get(base,"skills"))
	if key=="attack":return Library.texture({"sword":"slash","axe":"slash","bow":"arrow","staff":"arcane"}.get(weapon,"physical_attack"))
	if key=="heavy":return Library.texture("charge")
	return function_icon(key)
