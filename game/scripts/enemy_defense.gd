extends RefCounted
const World=preload("res://scripts/world_catalog.gd")
const THRESHOLD=40.0
const BREAK_SECONDS=4.0
const RESET_SECONDS=4.0
const LAYERS=3
const LAYER_BREAK_SECONDS=5.0
const PROFILES={
	"armor":{"name":"단단한 갑피","counter":"강공격 · 무력화","mitigation":.75},
	"layers":{"name":"겹친 보호막","counter":"연속 타격","mitigation":.75},
	"brace":{"name":"방어 자세","counter":"공격 틈새 · 강공격","mitigation":.60}
}

static func type_for(enemy:Dictionary)->String:
	if enemy.get("boss",false) or enemy.get("raid",false) or enemy.get("training",false):return ""
	if enemy.get("kind","")=="clockwork":return "layers"
	if enemy.get("kind","")=="centurion":return "brace"
	return "armor" if World.ENEMIES.get(enemy.get("kind",""),{}).get("ai","")=="armored" else ""

static func initialize(enemy:Dictionary):
	for key in ["guard_pressure","guard_last_hit","guard_break_time","guard_layers"]:enemy.erase(key)
	if type_for(enemy)=="layers":enemy["guard_layers"]=LAYERS

static func tick(enemy:Dictionary,delta:float,clock:float):
	if enemy.hp<=0:return
	enemy["guard_break_time"]=maxf(0.,float(enemy.get("guard_break_time",0))-delta)
	if clock-float(enemy.get("guard_last_hit",clock))>RESET_SECONDS:enemy["guard_pressure"]=0.
	if type_for(enemy)=="layers" and enemy.guard_break_time<=0 and int(enemy.get("guard_layers",LAYERS))<=0:enemy.guard_layers=LAYERS

static func exposed(enemy:Dictionary)->bool:
	return enemy.get("guard_break_time",0)>0 or (type_for(enemy)=="brace" and (enemy.get("windup",0)>0 or enemy.get("attack_motion",0)>0 or enemy.get("stun_time",0)>0))

static func factor(sim,enemy:Dictionary,context:Dictionary)->float:
	# Raid armor and its dedicated stagger state machine remain separate.
	if enemy.get("boss",false):return .75
	var kind=type_for(enemy)
	if kind.is_empty() or exposed(enemy):return 1.
	if kind=="layers":return layer_factor(sim,enemy,context)
	var mitigation=float(PROFILES[kind].mitigation)
	var budget:Dictionary=context.get("budget",{})
	if budget.is_empty():return mitigation
	if sim.clock-float(enemy.get("guard_last_hit",-100.))>RESET_SECONDS:enemy["guard_pressure"]=0.
	enemy["guard_last_hit"]=sim.clock
	if not budget.has("guard_spent"):budget.guard_spent={}
	var value=maxf(0.,float(budget.get("value",0)))
	var spent=float(budget.guard_spent.get(enemy.id,0))
	var pressure=minf(value-spent,value*maxf(0.,float(context.get("weight",1.))))
	if pressure<=0:return mitigation
	budget.guard_spent[enemy.id]=spent+pressure
	enemy["guard_pressure"]=float(enemy.get("guard_pressure",0))+pressure
	if enemy.guard_pressure<THRESHOLD:return mitigation
	break_guard(sim,enemy,BREAK_SECONDS)
	return 1.

static func layer_factor(sim,enemy:Dictionary,context:Dictionary)->float:
	var budget:Dictionary=context.get("budget",{})
	if budget.is_empty() or budget.get("dot",false):return .75
	# Actual cast hit count bounds repeat contacts, including projectile splash.
	if not budget.has("ward_spent"):budget.ward_spent={}
	var chips=2 if (budget.get("source","")=="heavy" and budget.get("value",0)>=19.9) or (budget.get("source","")!="basic" and budget.get("value",0)>=32.) else 1
	var cap=mini(LAYERS,maxi(chips,int(budget.get("count",1))))
	var spent=int(budget.ward_spent.get(enemy.id,0));chips=mini(chips,cap-spent)
	if chips<=0:return .75
	budget.ward_spent[enemy.id]=spent+chips
	enemy["guard_layers"]=maxi(0,int(enemy.get("guard_layers",LAYERS))-chips)
	if enemy.guard_layers>0:return .75
	break_guard(sim,enemy,LAYER_BREAK_SECONDS)
	return 1.

static func break_guard(sim,enemy:Dictionary,seconds:float):
	enemy.guard_pressure=0.;enemy.guard_break_time=seconds
	enemy.stun_time=maxf(float(enemy.get("stun_time",0)),.5);enemy.windup=0.;enemy.erase("attack_areas")
	sim.monster_attacks.zones=sim.monster_attacks.zones.filter(func(zone):return zone.enemy!=enemy.id)
	sim.events.append({"type":"skill_fx","fx":"guard_break","pos":enemy.pos,"dir":Vector2.RIGHT,"owner":0,"duration":.4,"radius":.8,"sound":"heavy"})

static func description(enemy:Dictionary)->Dictionary:
	var kind=type_for(enemy)
	if kind.is_empty():return {}
	var result:Dictionary=PROFILES[kind].duplicate();result["type"]=kind;result["exposed"]=exposed(enemy)
	result["layers"]=int(enemy.get("guard_layers",LAYERS));result["pressure"]=clampf(float(enemy.get("guard_pressure",0))/THRESHOLD,0,1)
	return result

static func configuration()->Dictionary:
	return {"profiles":PROFILES,"layer_kinds":["clockwork"],"brace_kinds":["centurion"],"armored_mitigation":.75,"threshold":THRESHOLD,"break_seconds":BREAK_SECONDS,"pressure_reset_seconds":RESET_SECONDS,"source":"normalized_existing_stagger_budget","per_cast_cap":true,"layers":LAYERS,"layer_break_seconds":LAYER_BREAK_SECONDS,"layer_damage_over_time":false,"layer_contact_cap":"min(3,max(chips,cast_hit_count))","charged_or_high_stagger_chips":2,"brace_exposure":["attack_windup","attack_recovery","stun","guard_break"],"raid_override":false}
