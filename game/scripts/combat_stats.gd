extends RefCounted
const Content=preload("res://scripts/content.gd")
const Progression=preload("res://scripts/progression.gd")
static func critical(p:Dictionary,jobs)->Dictionary:
	var base=clampf(Content.skill_bonus(p,"critical"),0,.65)
	var job=clampf(jobs.value(p,"crit")+(jobs.passive(p,4)*.02 if p.class_id=="swordsman" else 0)+(.15 if p.job_state.dice_time>0 and p.job_state.dice==3 else 0),0,1)
	var basic_damage=1.5+Content.skill_bonus(p,"critical_damage")
	var job_damage=1.5+jobs.value(p,"crit_damage")+(jobs.passive(p,5)*.08 if p.class_id=="swordsman" else 0)
	# One roll shared by damage and UI. Merge chance before adding precision;
	# use the strongest applicable critical multiplier, never two multiplications.
	var multiplier=maxf(basic_damage,job_damage)
	return {"chance":Progression.critical_chance(p,1-(1-base)*(1-job)),"maximum":Progression.critical_multiplier(p,multiplier)}
static func rows(sim,p:Dictionary)->Array:
	var crit=critical(p,sim.combat.jobs)
	return [["물리 공격",str(sim.combat.jobs.attack_power(p,sim.damage_for(p,"physical")))],["마법 공격",str(sim.combat.jobs.attack_power(p,sim.damage_for(p,"magic")))],["치명타 확률","%.1f%%"%(crit.chance*100)],["공격 속도","%.2f회/초"%(1./sim.combat.attack_interval(p))],["물리 방어",str(p.defense)],["마법 방어",str(p.magic_defense)]]
static func details(sim,p:Dictionary)->String:
	var crit=critical(p,sim.combat.jobs)
	var stagger=preload("res://scripts/boss_stagger.gd").skill_profile({},1,p)
	return "기본 물리 / 마법 공격 %d / %d\n공통 공격 강화 %+.1f%%\n치명타 피해 ×%.2f\n특화 무력화 보정 +%.1f%%\n직업 무력화 보정 +%.1f%%\n신속 이동 / 시전 속도 +%.1f%% / +%.1f%%\n받는 기술 회복 +%.1f%%\n일반 피격 경직 감소 %.1f%%\n%s\n\n대상 조건·기술별 계수는 타격 시 적용됩니다."%[sim.damage_for(p,"physical"),sim.damage_for(p,"magic"),((1+sim.combat.jobs.value(p,"attack"))*(1+sim.combat.jobs.value(p,"potion_attack"))-1)*100,crit.maximum,(stagger.multiplier-1)*100,(stagger.class_multiplier-1)*100,(Progression.move_speed(p)-1)*100,(Progression.cast_speed(p)-1)*100,(Progression.received_healing(p)-1)*100,(1-Progression.hurt_duration_factor(p))*100,preload("res://scripts/stat_specialization.gd").description(p)]
