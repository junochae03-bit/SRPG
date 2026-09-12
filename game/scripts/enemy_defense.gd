extends RefCounted
const THRESHOLD=40.0
const BREAK_SECONDS=4.0
const RESET_SECONDS=4.0
static func factor(sim,enemy:Dictionary,context:Dictionary)->float:
	# Raid armor and its dedicated stagger state machine remain separate.
	if enemy.get("boss",false):return .75
	if enemy.get("guard_break_time",0)>0:return 1.
	var budget:Dictionary=context.get("budget",{})
	if budget.is_empty():return .75
	if sim.clock-float(enemy.get("guard_last_hit",-100.))>RESET_SECONDS:enemy["guard_pressure"]=0.
	enemy["guard_last_hit"]=sim.clock
	if not budget.has("guard_spent"):budget.guard_spent={}
	var value=maxf(0.,float(budget.get("value",0)))
	var spent=float(budget.guard_spent.get(enemy.id,0))
	var pressure=minf(value-spent,value*maxf(0.,float(context.get("weight",1.))))
	if pressure<=0:return .75
	budget.guard_spent[enemy.id]=spent+pressure
	enemy["guard_pressure"]=float(enemy.get("guard_pressure",0))+pressure
	if enemy.guard_pressure<THRESHOLD:return .75
	enemy.guard_pressure=0.;enemy["guard_break_time"]=BREAK_SECONDS
	enemy.stun_time=maxf(float(enemy.get("stun_time",0)),.5);enemy.windup=0.;enemy.erase("attack_areas")
	sim.monster_attacks.zones=sim.monster_attacks.zones.filter(func(zone):return zone.enemy!=enemy.id)
	return 1.
static func configuration()->Dictionary:
	return {"armored_mitigation":.75,"threshold":THRESHOLD,"break_seconds":BREAK_SECONDS,"pressure_reset_seconds":RESET_SECONDS,"source":"normalized_existing_stagger_budget","per_cast_cap":true,"raid_override":false}
