extends RefCounted
const Content=preload("res://scripts/content.gd")
var tables:Dictionary
func _init():tables=JSON.parse_string(FileAccess.get_file_as_string("res://data/drop_tables.json")).monsters

func roll(kind:String,rng:RandomNumberGenerator,chance_bonus:float=0.0)->Array:
	var result=[]
	for entry in tables.get(kind,[]):
		var draw=rng.randf()
		if float(entry.chance)>=1.0 or draw<minf(1.0,float(entry.chance)*(1+chance_bonus)):result.append(entry.duplicate(true))
	return result

func item(entry:Dictionary,id:String,rng:RandomNumberGenerator,balance:Dictionary)->Dictionary:
	var result={"id":id,"category":entry.kind,"rarity":int(entry.get("rarity",0)),"bonus":0}
	if entry.kind in ["material","consumable"]:result.amount=int(entry.get("amount",1))
	match entry.kind:
		"material":result.material=entry.material;result.name=Content.MATERIALS[entry.material]
		"consumable":result.name="회복 물약";result.bonus=60
		"weapon":
			var weapon=entry.get("weapon","sword")
			if entry.has("weapons"):weapon=entry.weapons[rng.randi_range(0,entry.weapons.size()-1)]
			result.slot="weapon";result.weapon_type=weapon
			result.name=["여행자의 ","별빛 ","은하의 "][result.rarity]+Content.WEAPONS[weapon].name
			result.bonus=rng.randi_range(int(balance.loot.bonus_min[result.rarity]),int(balance.loot.bonus_max[result.rarity]))
		_:
			result.slot=entry.slot;result.bonus=1+result.rarity*2+rng.randi_range(0,1)
			result.name=["여행자의 ","별빛 ","은하의 "][result.rarity]+Content.SLOT_NAMES[entry.slot]
	return result
