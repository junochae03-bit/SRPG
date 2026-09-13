extends RefCounted
const Geometry=preload("res://scripts/enemy_hit_geometry.gd")
const TARGETED=["teleport","teleport_chain","chain_pull","chain_dash","chain_retreat","chain_group"]
const GROUND=["field","trap","trap_bleed","burst","root","slow","pull","wall"]

static func target_failure(sim,p:Dictionary,cast:Dictionary)->String:
	if cast.node.mode not in TARGETED:
		if cast.node.mode not in GROUND or int(cast.get("target",-1))<0:return ""
	var enemy:Dictionary=sim.enemies.get(cast.get("target",-1),{})
	if enemy.is_empty() or enemy.get("hp",0)<=0:return "대상이 사라졌습니다."
	if not Geometry.circle(enemy,p.pos,float(cast.node.range)):return "대상이 사거리를 벗어났습니다."
	if not sim.map.line_clear(p.pos,enemy.pos):return "대상까지의 경로가 막혔습니다."
	return ""

static func casting_speed(p:Dictionary)->float:
	return .2+(int(p.get("skill_ranks",{}).get("sniper_p05",0))*.04 if p.class_id=="sniper" else 0.)

static func rows(p:Dictionary,cast:Dictionary)->Array:
	var result=[]
	if cast.node.mode in TARGETED:result.append(["발동 조건","표적 · 사거리 · 시야"])
	elif cast.node.mode in GROUND:result.append(["표적 추적","사거리·시야 안에서만"])
	if cast.time>0:
		result.append(["시전 중 이동","%.0f%%"%(casting_speed(p)*100.)])
		result.append(["시전 취소","기력·재사용 소모 유지"])
	if cast.node.mode=="guard":result.append(["방어·시전 보호","정면 피격"])
	return result

static func configuration()->Dictionary:
	return {"targeted_modes":TARGETED,"ground_modes":GROUND,"empty_ground_allowed":true,"release_checks":["alive","body_range","line_clear"],"cancel_refund":false,"casting_move_factor":.2,"sniper_passive_move_per_rank":.04,"guard_interrupt_protection":"front_only"}
