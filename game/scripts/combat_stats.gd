extends RefCounted
const Content=preload("res://scripts/content.gd")
const Progression=preload("res://scripts/progression.gd")
static func critical(p:Dictionary,jobs)->Dictionary:
	var base=clampf(Content.skill_bonus(p,"critical"),0,.65)
	var job=clampf(jobs.value(p,"crit")+(jobs.passive(p,4)*.02 if p.class_id=="swordsman" else 0)+(.15 if p.job_state.dice_time>0 and p.job_state.dice==3 else 0),0,1)
	var basic_damage=1.5+Content.skill_bonus(p,"critical_damage")
	var job_damage=1.5+jobs.value(p,"crit_damage")+(jobs.passive(p,5)*.08 if p.class_id=="swordsman" else 0)
	return {"chance":1-(1-base)*(1-job),"maximum":basic_damage*job_damage if base>0 and job>0 else job_damage if job>0 else basic_damage}
static func rows(sim,p:Dictionary)->Array:
	var crit=critical(p,sim.combat.jobs)
	return [["물리 공격",str(sim.combat.jobs.attack_power(p,sim.damage_for(p,"physical")))],["마법 공격",str(sim.combat.jobs.attack_power(p,sim.damage_for(p,"magic")))],["치명타 확률","%.1f%%"%(crit.chance*100)],["공격 속도","%.2f회/초"%(1./sim.combat.attack_interval(p))],["물리 방어",str(p.defense)],["마법 방어",str(p.magic_defense)]]
static func details(sim,p:Dictionary)->String:
	var crit=critical(p,sim.combat.jobs)
	var stagger=preload("res://scripts/boss_stagger.gd").skill_profile({},1,p)
	return "기본 물리 / 마법 공격 %d / %d\n공통 공격 강화 %+.1f%%\n치명타 피해 최대 ×%.2f\n스킬 재사용 감소 %.1f%%\n기술 무력화 보정 +%.1f%%\n직업 무력화 보정 +%.1f%%\n민첩 이동 속도 +%.1f%%\n\n공격력은 공통 강화까지 반영합니다.\n대상 조건·기술별 계수는 타격 시 적용됩니다.\n무력화 보정은 곱으로 적용되며,\n기술별 별자리 효과는 해당 기술에서 확인합니다."%[sim.damage_for(p,"physical"),sim.damage_for(p,"magic"),((1+sim.combat.jobs.value(p,"attack"))*(1+sim.combat.jobs.value(p,"potion_attack"))-1)*100,crit.maximum,(1-Progression.cooldown_factor(p))*100,(stagger.multiplier-1)*100,(stagger.class_multiplier-1)*100,(Progression.move_speed(p)-1)*100]
