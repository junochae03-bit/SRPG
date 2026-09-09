extends RefCounted
## Shared status row for world actors. All conditions read existing combat state.
const Icons=preload("res://scripts/icon_library.gd")
const STATUSES={"slow":"slow","stun":"stun","root":"root","bleed":"bleed","blind":"blind","vulnerable":"vulnerable","weaken":"weaken","break_armor":"armor_break"}
const BUFFS={"attack":"physical_attack","crit":"critical","crit_damage":"critical_damage","haste":"haste","speed":"agility","defense":"defense","armor":"defense","guard":"guard","regen":"regen","leech":"lifesteal","evade":"agility","stand":"card_hold","pet_guard":"guard","pet_power":"pet_command","pet_haste":"haste"}

static func add(keys:Array,key:String):
	if not keys.has(key):keys.append(key)

static func keys_for(actor:Dictionary,is_hero:bool)->Array:
	var keys=[]
	if actor.get("hp",1)<=0:return keys
	if is_hero:
		if actor.get("enemy_slow_time",0)>0:add(keys,"slow")
		if actor.get("invulnerable",0)>0:add(keys,"invulnerable")
		var state=actor.get("job_state",{})
		if actor.get("barrier_time",0)>0 or state.get("shield",0)>0:add(keys,"shield")
		if actor.get("haste_time",0)>0:add(keys,"haste")
		if state.get("parry",0)>0:add(keys,"guard")
		if state.get("counter",0)>0:add(keys,"counter")
		for key in state.get("buffs",{}):
			if BUFFS.has(key) and state.buffs[key].get("time",0)>0:add(keys,BUFFS[key])
	else:
		if actor.get("slow_time",0)>0:add(keys,"slow")
		if actor.get("stun_time",0)>0 or actor.get("stagger",{}).get("state","")=="down":add(keys,"stun")
		if actor.get("taunt_time",0)>0:add(keys,"taunt")
		for key in actor.get("job_status",{}):
			if STATUSES.has(key) and actor.job_status[key].get("time",0)>0:add(keys,STATUSES[key])
	return keys

static func draw(game,actor:Dictionary,at:Vector2,is_hero:bool):
	if actor.get("hp",1)<=0:return
	var keys=keys_for(actor,is_hero)
	if not is_hero and game.session!=null:
		var player=game.session.state.get("players",{}).get(game.session.local_id,{})
		if player.get("job_state",{}).get("marks",{}).get(str(actor.get("id",-1)),0)>0:add(keys,"mark")
	if keys.is_empty():return
	var count=mini(keys.size(),5);var size=19.;var gap=3.
	var total=count*size+(count-1)*gap+(23 if keys.size()>count else 0)
	var start=at-Vector2(total*.5,size*.5)
	for i in range(count):Icons.draw(game,keys[i],Rect2(start+Vector2(i*(size+gap),0),Vector2.ONE*size))
	if keys.size()>count:game.text_at(start+Vector2(count*(size+gap),size-3),"+%d"%(keys.size()-count),12,Color("fff1d4"))
