extends RefCounted
# Pure visual lookup. Skill identifiers disambiguate reused job sprite rows.
const PALETTES={
	"slash":["ffd375","fff8cf"],"spin":["f9b962","fff2bc"],
	"fire":["ff792f","fff1a0"],"frost":["65d8ff","eaffff"],
	"thunder":["b298ff","fff4ff"],"impact":["edab63","fff0c0"],
	"rain":["85e8bb","efffd7"],"shot":["82dfc9","f3ffd5"],
	"poison":["9dde66","e2ffac"],"heal":["7ef2b0","e8ffe6"],
	"barrier":["76c8ff","e0faff"],"haste":["64ece0","e2fff8"],
	"summon":["bc93ff","f6e8ff"],"cards":["ff809b","fff0bc"],
	"chain":["ac9aff","f1e9ff"],"vortex":["ad77e8","e8caff"],
	"blink":["b398ff","f5eaff"],"rune":["77dfe8","ebffff"]
}
const BASE_EFFECTS={
	"sun_cleave":"slash","blade_wave":"slash","whirlwind":"spin",
	"arrow_rain":"rain","frost":"frost","frost_nova":"frost",
	"thunder":"thunder","rush":"blink","leap":"blink","blink":"blink",
	"piercing":"shot","piercing_shot":"shot","retreat_shot":"shot","volley":"shot","starburst":"rune","star_impact":"rune"
}
const JOB_DEFAULTS={"tank":"barrier","runesword":"rune","swordsman":"slash",
	"summoner":"summon","elementalist":"fire","healer":"heal","sniper":"shot",
	"hunter":"poison","explorer":"impact","thief":"poison","reaper":"slash",
	"gambler":"cards","infighter":"impact","breaker":"impact","martialist":"impact",
	"rogue":"slash","fighter":"impact"}

static func profile(e:Dictionary)->Dictionary:
	var family=str(e.get("vfx",""))
	if not PALETTES.has(family):family=family_for(e)
	var palette=PALETTES.get(family,["c7b9ef","ffffff"])
	var color=Color(palette[0]);var accent=Color(palette[1])
	var cls=str(e.get("class_id",str(e.get("fx","")).get_slice(":",0)))
	if cls=="reaper" and family in ["slash","spin","chain","blink"]:color=Color("b589ef");accent=Color("efdcff")
	elif cls=="tank" and family=="barrier":color=Color("eac879");accent=Color("fff8d6")
	elif cls=="runesword" and family in ["slash","rune"]:color=Color("6fe5e7");accent=Color("ebffff")
	elif cls in ["thief","rogue"] and family in ["slash","blink"]:color=Color("ce81ef");accent=Color("f9dcff")
	return {"family":family,"color":color,"accent":accent}

static func family_for(e:Dictionary)->String:
	var kind=str(e.get("fx",""));var mode=str(e.get("skill_mode",""))
	var id=str(e.get("skill_id",""));var cls=str(e.get("class_id",""))
	if cls.is_empty() and kind.contains(":"):cls=kind.get_slice(":",0)
	# Automatic dodge/support proc rows retain their authored sprite meaning.
	if kind.contains(":") and id.is_empty() and mode.is_empty():return ""
	if id.begins_with("elementalist_a"):
		var index=int(id.trim_prefix("elementalist_a"))
		if index<=4:return "fire"
		if index<=8:return "frost"
		if index==9:return "chain"
		if index==10:return "thunder"
		if index==11:return "haste"
		return "thunder"
	if BASE_EFFECTS.has(kind):return BASE_EFFECTS[kind]
	for basic in ["warrior","ranger","mage"]:
		if kind.begins_with(basic+"_"):
			cls=basic;mode=kind.trim_prefix(basic+"_");break
	if cls=="gambler":return "cards"
	if mode in ["heal","regen","field_heal","cleanse","meditate","pet_heal"]:return "heal"
	if mode in ["guard","shield","barrier","wall","fortress","share","parry","parry_counter","parry_knee","pet_guard","ally_dash"]:return "barrier" if mode!="ally_dash" else "blink"
	if mode in ["haste","pet_haste"]:return "haste"
	if mode in ["summon","pet_command","pet_buff","pet_burst","pet_recall","pet_sacrifice","pet_pull"]:return "summon"
	if mode in ["buff_attack","buff_crit","buff_crit_damage","stance","empower","enchant","chant","distribute"]:return "rune"
	if mode in ["dash","rush","weave","retreat","flank","blink","teleport","teleport_chain","return_anchor","heavy_dash"]:return "blink"
	if mode.begins_with("chain_") or mode=="chain":return "chain"
	if mode in ["pull","taunt"]:return "vortex"
	if mode in ["spin","charge_spin"]:return "spin"
	if mode in ["trap","trap_bleed","bleed","blind","weaken","vulnerable","break_armor","root"]:return "poison"
	if mode in ["shot","fan","root_shot","slow_shot","bleed_shot","pull_shot","execute_shot"]:
		if mode in ["bleed_shot","root_shot"]:return "poison"
		return "slash" if cls=="warrior" else "rune" if cls=="mage" else "shot"
	if mode in ["field","barrage"]:
		if cls in ["ranger","sniper"]:return "rain"
		if cls=="mage":return "frost"
		if cls=="hunter":return "poison"
		if cls in ["warrior","runesword"]:return "rune"
		return "impact"
	if mode=="burst":return "fire" if cls=="mage" else "rain" if cls=="ranger" else "impact"
	if mode=="nova_ring":return "rune" if cls=="mage" else "spin"
	if mode=="slow":return "frost" if cls in ["mage","runesword"] else "poison"
	if mode=="mark":return "rune"
	if mode in ["uppercut","stun","break_guard","finisher"] or mode.begins_with("charge"):return "impact"
	if mode in ["strike","combo","execute","heavy","heavy_execute"]:return "impact" if cls in ["fighter","breaker","infighter","martialist"] else "slash"
	if kind.contains(":"):return JOB_DEFAULTS.get(cls,"")
	return ""
