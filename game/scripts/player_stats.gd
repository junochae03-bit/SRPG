extends RefCounted
const Content=preload("res://scripts/content.gd")
const Progression=preload("res://scripts/progression.gd")
static func rows(sim,p:Dictionary)->Array:
	var result=[]
	for key in Progression.NAMES:result.append([Progression.NAMES[key],str(Progression.bonus(p,key))])
	result.append_array([
		["기본 물리 공격력",str(sim.damage_for(p,"physical"))],
		["기본 마법 공격력",str(sim.damage_for(p,"magic"))],
		["물리 방어력",str(p.defense)],
		["마법 방어력",str(p.get("magic_defense",0))],
		["최대 생명력",str(p.max_hp)],
		["최대 기력","%d"%p.max_stamina],
		["기본 공격 간격","%.2f초"%sim.combat.attack_interval(p)],
		["신속 이동 속도","+%.1f%%"%((Progression.move_speed(p)-1.)*100.)],
		["신속 시전 속도","+%.1f%%"%((Progression.cast_speed(p)-1.)*100.)],
		["받는 기술 회복","+%.1f%%"%((Progression.received_healing(p)-1.)*100.)],
		["일반 피격 경직 감소","%.1f%%"%((1.-Progression.hurt_duration_factor(p))*100.)]])
	var critical=preload("res://scripts/combat_stats.gd").critical(p,sim.combat.jobs)
	result.append(["치명타 확률","%.1f%%"%(critical.chance*100.)])
	result.append(["치명타 피해 배율","×%.2f"%critical.maximum])
	result.append(["직업 특화",preload("res://scripts/stat_specialization.gd").description(p)])
	return result
