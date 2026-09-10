extends RefCounted
# Pure cast values shared by runtime, growth comparisons and HUD. Conditional
# combat resources (cards, grit, marks, crits) are applied only on execution.
const ROLES={
	"tank":["수호 · 정면 방어 / 보호막","정면을 지키며 보호막과 도발로 전투를 통제합니다.",.9,1.0],
	"swordsman":["결투 · 치명타 / 집중 공격","한 대상을 연속 압박하고 치명타 창을 활용합니다.",.95,1.0],
	"runesword":["룬 전투 · 평타 축적 / 마력 소비","기본 공격으로 룬을 모아 마력 기술에 소비합니다.",.9,1.15],
	"summoner":["소환 · 지속 피해 / 지휘","소환수를 유지하고 지휘·강화 기술로 함께 싸웁니다.",.55,.85],
	"elementalist":["원소 · 캐스팅 / 광역 제압","시전 시간을 확보하면 넓은 범위에 강한 마법을 펼칩니다.",1.0,1.85],
	"healer":["치유 · 회복 / 지원","자신에게도 적용되는 치유와 강화로 안전하게 전진합니다.",.7,1.0],
	"sniper":["저격 · 긴 사거리 / 정밀 사격","안전한 거리를 유지하고 관통 사격을 집중합니다.",1.15,1.2],
	"hunter":["사냥 · 출혈 / 덫과 동료","사냥개와 덫으로 적을 붙잡고 지속 피해를 누적합니다.",.85,.8],
	"explorer":["기동 · 이동 / 군중 제어","이동과 제어기를 이어서 유리한 위치를 잡습니다.",1.0,1.0],
	"thief":["교란 · 표식 / 약점 노출","표식으로 접근하고 약화 효과를 쌓아 빈틈을 노립니다.",.7,.7],
	"reaper":["사슬 · 접근 / 즉결 강공격","사슬을 적중시켜 긴 차지를 즉시 발동합니다.",1.15,1.25],
	"gambler":["승부 · 카드 / 정산","52장 덱을 관리하고 높은 패에서 정산합니다.",1.0,1.2],
	"infighter":["난타 · 몰아침 / 연속 회피","짧은 사거리에서 빠른 타격과 두 번의 회피를 활용합니다.",.65,.9],
	"breaker":["파괴 · 기세 / 차지와 반격","기세와 피격 자원을 차지에 소비해 큰 한 방을 만듭니다.",1.25,1.35],
	"martialist":["연무 · 다른 기술 연결 / 마무리","서로 다른 기술로 연무를 쌓고 마무리로 소비합니다.",1.1,1.05],
	"rogue":["도적 기초 · 교란 / 기동","가볍게 치고 빠지며 도적 전직을 준비합니다.",1.,1.],
	"fighter":["격투 기초 · 근접 / 회피","권격과 회피를 익혀 격투 전직을 준비합니다.",1.,1.]}
const BUFF_KEYS={"haste":"haste","buff_attack":"attack","buff_crit":"crit","buff_crit_damage":"crit_damage","guard":"guard","fortress":"defense","share":"defense","chant":"attack","stand_card":"stand","dice_buff":"attack","enchant":"attack","stance":"attack","empower":"attack"}
const SUPPORT=["heal","regen","field_heal","shield","ally_dash","wall","cleanse","distribute","return_anchor","parry","parry_counter","parry_knee","meditate","hit_card","hold_card","cut_card","dice","reroll","summon","pet_heal","pet_recall","pet_buff","pet_haste","pet_guard","pet_sacrifice"]
static func role(id:String)->Array:return ROLES.get(id,["모험가 · 기초 성장","기술을 배우고 여섯 슬롯에 배치하세요.",1.,1.])
static func passive(p:Dictionary,index:int)->int:return int(p.get("skill_ranks",{}).get(p.class_id+"_p%02d"%(index+1),0))
static func hits(mode:String)->int:
	return 6 if mode in ["barrage","settle_barrage"] else 5 if mode in ["field","trap","trap_bleed"] else 3 if mode in ["combo","fan","settle_fan"] else 1
static func damaging(mode:String)->bool:return mode not in SUPPORT and not BUFF_KEYS.has(mode)
static func profile(p:Dictionary,node:Dictionary,rank:int,damage:float,max_hp:float,upgrade:bool=false)->Dictionary:
	var n=node.duplicate(true);var r=clampi(rank,1,5)-1;var mode=str(n.mode);var scale=1+.22*r
	n.radius=preload("res://scripts/skill_reach.gd").job_radius(mode,str(p.class_id),float(n.radius))
	var count=hits(mode)
	var budget={"field":3.8,"trap":3.,"trap_bleed":2.8,"barrage":4.,"settle_barrage":4.,"combo":2.8,"fan":2.8,"settle_fan":2.8,"finisher":2.4,"execute":2.2,"heavy":3.8,"heavy_dash":3.6,"heavy_execute":4.,"charge":5.,"charge_area":4.8,"charge_spin":4.8,"charge_execute":5.2,"pet_command":2.4,"pet_burst":3.,"pet_pull":2.4}.get(mode,1.8)
	if n.get("rune_cost",0)>0:budget*=1.2
	var s={"node":n,"rank":r+1,"up":upgrade,"power":budget/count*scale*role(p.class_id)[3],"count":count,"time":float(n.windup),"cooldown":float(n.cooldown)*(1-.035*r),"cost":float(n.cost),"heal":0.,"regen":0.,"shield":(max_hp*.12+damage*.18)*scale,"buff":(.35 if mode=="guard" else .16)* (1+.12*r),"pet_power":.32*scale,"pet_hp":max_hp*(.28+.025*r),"pet_buff":.25+.045*r,"parry":.25,"counter_power":2.*scale,"mitigation":0.}
	n.duration=float(n.duration)+.35*r
	if mode in ["heal","regen","field_heal"]:
		s.heal=max_hp*({"heal":.18,"regen":.035,"field_heal":.06}[mode])*(1+.18*r)
		s.regen=max_hp*({"heal":0.,"regen":.014,"field_heal":.022}[mode])*(1+.16*r)
		s.cooldown=maxf(s.cooldown,(8. if mode=="heal" else 10.)*(1-.035*r))
	if mode=="summon":s.cooldown=maxf(s.cooldown,10.*(1-.035*r))
	if mode=="pet_sacrifice":s.cooldown=maxf(s.cooldown,16.*(1-.035*r))
	if mode in ["guard","fortress","share","shield","wall"]:s.cooldown=maxf(s.cooldown,9.*(1-.035*r))
	if mode in ["buff_crit","buff_crit_damage"]:s.buff=.12*(1+.15*r) if mode=="buff_crit" else .3*(1+.15*r)
	match p.class_id:
		"runesword":
			n.radius+=passive(p,2)*.1
			if n.index in [4,5,6,7]:s.cost-=passive(p,3)
			if n.index==8:s.cooldown-=passive(p,4)*.2
		"swordsman":
			if n.index in [1,3,5,6,10]:s.power*=1+passive(p,0)*.05
			if n.index==4:s.cost-=passive(p,3)
		"summoner":
			n.duration+=passive(p,2)*.3;s.pet_hp*=1+passive(p,1)*.1;s.pet_power*=1+passive(p,0)*.025
			if n.index in [4,5,6,7]:s.cost-=passive(p,3)
			if n.index>=8:s.cooldown-=passive(p,4)*.2
		"elementalist":
			s.power*=1+passive(p,int(n.index/4)*2)*.05
			if n.index<4:n.duration+=passive(p,1)*.3
			s.cost-=passive(p,5)
		"healer":
			n.duration+=passive(p,2)*.3;s.cost-=passive(p,3);s.heal*=1+passive(p,0)*.05;s.regen*=1+passive(p,0)*.05;s.shield*=1+passive(p,4)*.06
		"tank":s.shield*=1+passive(p,3)*.06
		"sniper":s.power*=1+passive(p,0)*.05;n.range+=passive(p,1)*.4;s.cost-=passive(p,3)
		"hunter":
			if n.index in [4,5,7]:s.cooldown-=passive(p,2)*.3
		"explorer":
			s.time=maxf(0,s.time-passive(p,1)*.025)
			if n.index<4:s.power*=1+passive(p,0)*.05
			if n.index>=8:s.cost-=passive(p,4)
		"thief":n.radius+=passive(p,2)*.08
		"reaper":
			if n.index in [4,5,6,7]:s.power*=1+passive(p,2)*.05
			if n.index<4:n.range+=passive(p,0)*.2
		"infighter":n.duration+=passive(p,2)*.1
		"gambler":
			if n.index in [0,1,2]:s.cooldown-=passive(p,0)*.12
		"martialist":n.range+=passive(p,0)*.1
	if upgrade:
		n.duration+=2.;s.heal*=1.15;s.regen*=1.15;s.shield*=1.15;s.buff*=1.15;s.pet_power*=1.15;s.pet_hp*=1.15;s.pet_buff*=1.15;s.counter_power*=1.15
		if mode.begins_with("charge") or mode.begins_with("heavy") or mode in ["execute","finisher"]:s.power*=1.25
		else:s.power*=1.15
		if mode in ["dash","rush","retreat","flank","blink","teleport","teleport_chain","chain_dash","chain_pull","chain_group","chain_retreat"]:n.distance+=.6;n.range+=1.;s.mitigation=.12
		elif mode in ["parry","parry_counter","parry_knee"]:s.mitigation=.12
		elif mode in ["shot","fan","settle","settle_heavy","settle_fan","settle_barrage","root_shot","slow_shot","bleed_shot","pull_shot","execute_shot"]:n.range+=1.5
		else:n.radius+=.35
		if mode in ["hit_card","hold_card","cut_card"]:s.cooldown*=.85
	s["recall_heal"]=(.15+.03*(r+1))*(1.15 if upgrade else 1.)
	s["sacrifice_ratio"]=(.6+.08*(r+1))*(1.15 if upgrade else 1.)
	s["anchor_range"]=8.+.4*r+(1. if upgrade else 0.)
	s["meditate_rate"]=(25.+5*r)*(1.15 if upgrade else 1.)
	var gear=preload("res://scripts/equipment_catalog.gd").skill_modifiers(p)
	s.power*=1.+gear.force;s.heal*=1.+gear.force;s.regen*=1.+gear.force;s.shield*=1.+gear.force;s.pet_power*=1.+gear.force;s.counter_power*=1.+gear.force
	n.radius*=1.+gear.reach;n.range*=1.+gear.reach;n.duration*=1.+gear.echo;s.buff*=1.+gear.echo;s.pet_buff*=1.+gear.echo;s.meditate_rate*=1.+gear.echo;s.recall_heal*=1.+gear.echo;s.parry*=1.+gear.echo
	s.cooldown=maxf(.5,s.cooldown*preload("res://scripts/progression.gd").cooldown_factor(p));s.cost=maxf(5,s.cost)
	return preload("res://scripts/constellation_effects.gd").resolve(p,node,s,true)
static func metrics(p:Dictionary,node:Dictionary,rank:int,damage:float,max_hp:float)->Array:
	if node.effect=="upgrade":
		var context=p.duplicate(true);context.skill_ranks[node.id]=rank
		var target=preload("res://scripts/content.gd").SKILLS[p.class_id].filter(func(n):return n.id==node.target)[0]
		var target_rank=maxi(3,int(context.skill_ranks.get(target.id,0)))
		return [["원기술 비교 기준","%d랭크"%target_rank]]+metrics(context,target,target_rank,damage,max_hp)
	if node.effect!="active":
		if node.effect=="passive":return passive_metrics(p.class_id,int(str(node.id).right(2))-1,rank)
		return preload("res://scripts/skill_scaling.gd").metrics(node,rank,damage,int(max_hp))
	var s=profile(p,node,rank,damage,max_hp,p.get("skill_ranks",{}).get(node.id+"_upgrade",0)>0);var rows=[];var mode=node.mode
	if damaging(mode):
		rows.append(["지휘 총 피해" if mode.begins_with("pet_") else "기본 피해 / 타격",str(roundi(damage*s.power))]);rows.append(["타격 수",str(s.count)])
	elif mode in ["heal","regen","field_heal"]:
		rows.append(["즉시 회복",str(roundi(s.heal))])
		if s.regen>0:rows.append(["초당 회복","%.1f"%s.regen])
	elif mode in ["shield","ally_dash"]:rows.append(["기본 보호막",str(roundi(s.shield))])
	elif mode=="summon":rows.append(["소환수 타격",str(roundi(damage*s.pet_power))]);rows.append(["소환수 생명력",str(roundi(s.pet_hp))])
	elif mode.begins_with("pet_"):
		if mode in ["pet_buff","pet_haste","pet_guard"]:rows.append(["동료 강화","+%.0f%%"%(s.pet_buff*100)])
		elif mode=="pet_heal":rows.append(["동료 회복","100%"]);rows.append(["동료 피해 감소","%.1f%%"%(s.pet_buff*100)])
		elif mode=="pet_recall":rows.append(["동료 회복","%.1f%%"%(s.recall_heal*100)])
		elif mode=="pet_sacrifice":rows.append(["생명력→보호막","%.0f%%"%(s.sacrifice_ratio*100)]);rows.append(["보호막 상한","HP 60%"])
	elif mode=="cleanse":rows.append(["정화 후 피해 감소","%.1f%%"%(s.buff*100)])
	elif mode=="distribute":rows.append(["공유 보호막",str(roundi(s.shield*.4))])
	elif mode=="meditate":rows.append(["초당 기세 획득","%.1f"%s.meditate_rate]);rows.append(["집중 시간","1.2초"])
	elif mode=="return_anchor":rows.append(["귀환 표식 거리","%.1f칸"%s.anchor_range])
	elif BUFF_KEYS.has(mode):rows.append([{ "haste":"공격 속도","crit":"치명타 확률","crit_damage":"치명타 피해","guard":"정면 피해 감소","defense":"받는 피해 감소","attack":"공격력","stand":"기본 공격"}.get(BUFF_KEYS[mode],"효과"),"정지" if mode=="stand_card" else "+%.1f%%"%(s.buff*100)])
	elif mode.begins_with("parry"):
		rows.append(["패링 판정창","%.2f초"%s.parry])
		if mode=="parry":rows.append(["반격권 지속","5초"])
		else:rows.append(["반격 기본 피해",str(roundi(damage*s.counter_power))])
	if BUFF_KEYS.has(mode) or mode in ["shield","ally_dash","wall","regen","field_heal","cleanse","distribute","dice","reroll","pet_buff","pet_haste","pet_heal","pet_guard","pet_sacrifice","slow","stun","root","bleed","blind","vulnerable","weaken","break_armor"]:rows.append(["지속시간","%.1f초"%s.node.duration])
	if s.time>0:rows.append(["시전 시간","%.2f초"%s.time])
	rows.append(["재사용 시간","%.2f초"%s.cooldown]);rows.append(["소모 기력","%.0f"%s.cost])
	rows.append_array(preload("res://scripts/constellation_effects.gd").metrics(s))
	if node.get("rune_cost",0)>0:rows.append(["소모 룬",str(node.rune_cost)])
	if rank==0:
		for row in rows:row[1]="미습득"
	return rows

static func passive_metrics(job:String,index:int,rank:int)->Array:
	# Numeric outcomes, including ranks formerly offering only a binary unlock.
	var definitions={
		"tank":[["저체력 보호막",8.,"%"],["합류 후 피해 감소",3.,"%"],["정면 방어",3.,"%"],["보호막 효율",6.,"%"],["방어 후 공격력",4.,"%"],["도발 유지",.5,"초"]],
		"runesword":[["추가 룬 용량",1.,"개"],["룬 생성 간격 감소",.035,"초"],["룬 기술 반경",.1,"칸"],["룬 기술 기력 절약",1.,""],["전이 재사용 감소",.2,"초"],["방호 피해 감소",3.,"%"]],
		"swordsman":[["검격 피해",5.,"%"],["보스·엘리트 피해",5.,"%"],["동일 표적 1중첩",1.,"%"],["가속 기력 절약",1.,""],["치명타 확률",2.,"%"],["치명타 피해",8.,"%"]],
		"summoner":[["소환수 피해",2.5,"%"],["소환수 생명력",10.,"%"],["지속시간",.3,"초"],["동료 강화 기력 절약",1.,""],["명령 재사용 감소",.2,"초"],["지정 표적 거리",.5,"칸"]],
		"elementalist":[["화염 피해",5.,"%"],["화염 효과 지속",.3,"초"],["냉기 피해",5.,"%"],["시전 방해 저항",12.,"%"],["번개 피해",5.,"%"],["기력 절약",1.,""]],
		"healer":[["회복량",5.,"%"],["유효 치유 기력 회복",1.,""],["축복 지속",.3,"초"],["지원 기력 절약",1.,""],["보호막 효율",6.,"%"],["저체력 보호막",8.,"%"]],
		"sniper":[["사격 기술 피해",5.,"%"],["사격 사거리",.4,"칸"],["보스 피해",5.,"%"],["사격 기력 절약",1.,""],["시전 중 이동 속도",4.,"%"],["후퇴 후 이동 속도",3.,"%"]],
		"hunter":[["출혈 피해",8.,"%"],["직접 피해",2.5,"%"],["덫 재사용 감소",.3,"초"],["속박 후 첫 타격",10.,"%"],["전리품 발생 보정",3.,"%"],["전리품 탐색 거리",.5,"칸"]],
		"explorer":[["채찍 기술 피해",5.,"%"],["시전 동작 감소",.025,"초"],["제어 효과 지속",.15,"초"],["제어된 대상 피해",5.,"%"],["이동 기력 절약",1.,""],["이동 후 속도",3.,"%"]],
		"thief":[["순간이동 후 속도",4.,"%"],["추가 표식 용량",1.,"개"],["약화 기술 반경",.08,"칸"],["약화 1종당 피해",1.5,"%"],["연계 버프 범위",.4,"칸"],["귀환 재사용 감소",.15,"초"]],
		"reaper":[["사슬 사거리",.2,"칸"],["사슬 후 이동 속도",4.,"%"],["강공격 피해",5.,"%"],["즉결 유지",.4,"초"],["강공격 적중 회복",2.,""],["완전 차지 쿨 감소",.2,"초"]],
		"gambler":[["패 조작 재사용 감소",.12,"초"],["버스트 후 이동 속도",5.,"%"],["17~20 정산 피해",3.,"%"],["21 정산 주사위 쿨 감소",.25,"초"],["주사위 중 시전 감소",.03,"초"],["정산 후 탄속 보정",1.,""]],
		"infighter":[["몰아침 유예",.15,"초"],["밀착 피해",4.,"%"],["기술 강화 지속",.1,"초"],["회피 후 적중 유예",.2,"초"],["연타 중 피해 감소",2.5,"%"],["8타마다 회복",2.,""]],
		"breaker":[["기세 보유 유예",.4,"초"],["차지 중 피해 감소",2.5,"%"],["패링 기력 회복",2.,""],["막은 피해→기세",5.,"%"],["강공격 후 피해 감소",2.5,"%"],["완전 차지 대시 쿨 감소",.2,"초"]],
		"martialist":[["기술 사거리",.1,"칸"],["연무 유예",.1,"초"],["연결 유예",.1,"초"],["연결기 마지막 경직",.1,"초"],["회피 후 평타 쿨 감소",.025,"초"],["3연무 후 연결기 피해",4.,"%"]]}
	var spec=definitions[job][index];var amount=spec[1]*rank
	if job=="elementalist" and index==3:amount=0. if rank==0 else minf(85,25+rank*12)
	var rows=[[spec[0],preload("res://scripts/skill_scaling.gd").number(amount)+spec[2]]]
	if job=="summoner" and index==0:rows.append(["최대 소환수",str(3 if rank>=3 else 2)])
	if job=="summoner" and index==5:rows.append(["평타 표적 지휘","사용" if rank>0 else "미습득"])
	return rows
