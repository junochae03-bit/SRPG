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
		["민첩 이동 속도","+%.1f%%"%((Progression.move_speed(p)-1.)*100.)],
		["기술 능력치 재사용 감소","%.1f%%"%((1.-Progression.cooldown_factor(p))*100.)]])
	var technique=maxf(0,Progression.bonus(p,"technique"))
	result.append(["기술 무력화 증가","+%.1f%%"%(60.*technique/(technique+60.))])
	# Two independent critical rolls can both succeed in the existing combat rules.
	var base=clampf(Content.skill_bonus(p,"critical"),0,.65)
	var jobs=sim.combat.jobs
	var extra=clampf(jobs.value(p,"crit")+(jobs.passive(p,4)*.02 if p.class_id=="swordsman" else 0)+(.15 if p.job_state.dice_time>0 and p.job_state.dice==3 else 0),0,1)
	result.append(["치명타 확률","%.1f%%"%((1.-(1.-base)*(1.-extra))*100.)])
	var multipliers=[]
	var normal=1.5+Content.skill_bonus(p,"critical_damage")
	var advanced=1.5+jobs.value(p,"crit_damage")+(jobs.passive(p,5)*.08 if p.class_id=="swordsman" else 0)
	if base>0 and extra<1:multipliers.append(normal)
	if extra>0:multipliers.append(advanced)
	if base>0 and extra>0:multipliers.append(normal*advanced)
	multipliers.sort()
	result.append(["치명타 피해 배율","—" if multipliers.is_empty() else "×%.2f"%multipliers[0] if is_equal_approx(multipliers[0],multipliers[-1]) else "×%.2f ~ %.2f"%[multipliers[0],multipliers[-1]]])
	return result
