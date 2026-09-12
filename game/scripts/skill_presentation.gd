extends RefCounted
## Presentation only. Numbers come from the same profiles used by combat.
const Scaling=preload("res://scripts/skill_scaling.gd")
const Balance=preload("res://scripts/job_balance.gd")
const Rules=preload("res://scripts/skill_build.gd")
const Reach=preload("res://scripts/skill_reach.gd")
# Display groups only: never replace the five rule clusters or saved node IDs.
const TREE_GROUPS={
	"warrior":["검술","돌파","수호"],"ranger":["사격","추적","덫과 생존"],
	"mage":["주문","원소","마력 제어"],"rogue":["암살","기습","교란"],"fighter":["격투","연무","반격"],
	"tank":["응징","진격","철벽"],"runesword":["검술","룬 해방","룬 수호"],"swordsman":["검술","검기","응수"],
	"sniper":["정밀 사격","관통","사격 준비"],"hunter":["사냥","추적","덫과 동료"],"explorer":["탐험 기술","기동","생존"],
	"summoner":["마력 공격","소환 지휘","동료 수호"],"elementalist":["원소 집중","원소 확산","원소 제어"],"healer":["심판","성역","치유"],
	"thief":["암살","기습","교란"],"reaper":["수확","추격","영혼 회수"],"gambler":["승부","패 운용","판 뒤집기"],
	"infighter":["강타","쇄도","투지"],"breaker":["파쇄","돌진","반격"],"martialist":["격투","연무","호흡"]}
static func tree_group(node:Dictionary)->int:
	if node.get("type","original")!="original":
		var cluster=int(node.get("cluster",0))
		if cluster in [0,1]:return 0
		if cluster==3:return 1
		if cluster==4:return 2
		# The old evasion route keeps its exact rules, but defensive recovery
		# and control appear with survival instead of offensive movement.
		for effect in node.get("effects",{}):
			if effect in ["skill_discount","mobility_refund","slow_on_followup","guard_on_followup","heal_on_followup"]:return 2
		return 1
	var target=str(node.get("target_active_id",node.get("target","")))
	if not target.is_empty() and target!=str(node.get("id","")):
		var original=Rules.definition(target)
		if not original.is_empty():return tree_group(original)
	var action=mode(node) if active(node) else str(node.get("effect",""))
	if action in preload("res://scripts/skill_node_roles.gd").SUPPORT or action in ["defense","health","health_regen","stamina","lifesteal","thorns","dodge_discount"]:return 2
	if action in ["dash","rush","retreat","weave","flank","blink","teleport","chain_dash","trap","trap_bleed","root","slow","root_shot","slow_shot"]:return 1
	return [0,0,1,1,2][clampi(int(node.get("cluster",0)),0,4)]
static func tree_group_names(class_id:String)->Array:return TREE_GROUPS.get(class_id,["공격","전개","지원"])
static func skill_summary(node:Dictionary)->String:
	# The canonical description stays below with all numeric details and caveats.
	# Here expose the first action/effect instead of repeating navigation advice.
	var summary=str(node.get("effects_text",""))
	if summary.is_empty():summary=str(node.get("description",""))
	summary=summary.get_slice(" · 랭크별",0).get_slice(". ",0).strip_edges()
	if summary=="부채꼴 투사체":summary="전방으로 투사체를 부채꼴로 펼쳐 여러 적을 공격합니다."
	elif summary=="관통하는 검기를 발사":summary="전방에 검기를 발사해 경로상의 적을 관통합니다."
	if summary.is_empty():summary=short_label(node)
	return summary
static func quickslot_description(p:Dictionary,node:Dictionary,rank:int,damage:float)->String:
	if node.is_empty() or rank<=0:return ""
	var lines=PackedStringArray([str(node.get("description",""))])
	var rows=Balance.metrics(p,node,rank,damage,p.max_hp) if node.get("runtime","")=="job" else Scaling.metrics(node,rank,damage,p.max_hp,preload("res://scripts/active_skills.gd").bonuses(p))
	rows.append_array(shape_rows(p,node,rank,damage,p.max_hp))
	for row in rows:lines.append(str(row[0])+"  "+str(row[1]))
	return "\n".join(lines)
const KEY_OUTCOMES={
	"echo":["추가 타격","같은 자리에 한 번 더"],"focus":["단일 집중","한 대상 피해 +25%"],"momentum":["회피 연계","회피 후 피해 +25%"],
	"warrior_wave":["전방 파동","첫 적중에서 검기"],"warrior_reprise":["수호 반격","지원 후 주변 파동"],
	"ranger_chain":["연쇄 사격","새 표적 2명 연쇄"],"ranger_snare":["지연 폭발","적중 위치에 폭발"],
	"mage_burn":["지속 피해","4초 동안 잔열"],"mage_relay":["문장 폭발","지원 위치에 폭발"],
	"rogue_contract":["낙인 연계","다른 기술로 낙인 소비"],"rogue_venom":["독 회수","회피로 독 즉시 폭발"],
	"fighter_flurry":["추적 연타","이동하는 적을 3타"],"fighter_crush":["한 방 압축","총 피해 +20%"]}
const NOTABLE_OUTCOMES={
	"followup_damage":"연결 → 대상 피해 +30%","stagger_followup":"연결 → 무력화 +40%","execute_damage":"HP<30% 적 피해 +15%",
	"efficiency_followup":"다른 기술 → 기력 −10%","mobility_refund":"회피 → 적중 기력 회수","slow_on_followup":"다른 기술 → 적중 감속",
	"support_followup":"지원 → 공격 피해 +15%","guard_on_followup":"다른 기술 → 적중 보호막","control_damage":"감속·속박 적 피해 +15%","heal_on_followup":"다른 기술 → 적중 회복"}
const UPGRADE_LABELS={
	"강화 효과 +15%, 지속시간 +2초.":"강화 위력 +15%",
	"공격이 있는 기술은 피해 +15%. 적용 효과 지속시간 +2초. 이동·사격 기술은 거리가 늘어납니다.":"기술 위력·거리 강화",
	"공유 보호막 15% 증가, 유지시간 2초 증가.":"공유 보호막 +15%",
	"귀환 가능한 거리 1칸 증가.":"귀환 거리 +1칸",
	"동료 회복량 15% 증가.":"동료 회복 +15%",
	"보호막 +15%, 유지시간 +2초.":"보호막 +15%",
	"생명력의 보호막 전환율 15% 증가. 상한은 최대 HP 60% 유지.":"HP→보호막 +15%",
	"소환수 공격력과 최대 생명력 +15%.":"동료 공격·HP +15%",
	"시전 후 1초 동안 받는 피해 12% 감소. 직접 반격 피해 +15%. 패링 판정창은 유지.":"시전 후 1초 피해 −12%",
	"재사용 시간 15% 감소.":"재사용 −15%",
	"정화 후 피해 감소 효과 15% 증가, 지속시간 2초 증가.":"정화 보호 효과 +15%",
	"즉시 회복량 15% 증가.":"즉시 회복 +15%",
	"초당 기세 획득량 15% 증가.":"기세 회복 +15%",
	"피해 +25%, 적용 효과 지속시간 +2초.":"피해 +25%",
	"회복 후 동료 피해 감소 효과 15% 증가, 지속시간 2초 증가.":"동료 방어 강화 +15%",
	"회복량과 지속 회복량 +15%. 지속 회복 시간 +2초.":"회복·지속 회복 +15%"}
const MODE_LABELS={
	"wave":"전방 관통","piercing":"관통 사격","spin":"주변 연타","rain":"지점 연타","nova_ring":"고리 폭발","frost":"주변 감속","thunder":"지점 기절",
	"fan":"부채꼴 공격","shot":"정밀 사격","strike":"근접 일격","burst":"범위 폭발","chain":"표적 연쇄","field":"지속 장판","barrage":"집중 연사",
	"dash":"돌진 공격","rush":"돌진 공격","retreat":"후퇴 사격","blink":"순간이동","flank":"측면 이동","teleport":"표적 이동","teleport_chain":"연속 순간이동",
	"chain_dash":"사슬 접근","chain_pull":"표적 끌기","chain_group":"여럿 모으기","chain_retreat":"사슬 후퇴","card_retreat":"후퇴 사격","return_anchor":"표식 귀환",
	"heal":"즉시 회복","regen":"지속 회복","field_heal":"회복 장판","shield":"보호막","ally_dash":"접근 · 보호막","wall":"방벽","cleanse":"정화 · 보호","distribute":"보호막 공유",
	"guard":"정면 방어","fortress":"받는 피해 감소","share":"받는 피해 감소","haste":"공격 속도 강화","buff_attack":"공격력 강화","buff_crit":"치명타 확률 강화","buff_crit_damage":"치명타 피해 강화",
	"chant":"공격력 강화","enchant":"공격력 강화","stance":"공격력 강화","empower":"공격력 강화","dice_buff":"공격력 강화",
	"mark":"표식 부여","slow":"감속 공격","stun":"기절 공격","root":"속박 공격","bleed":"출혈 공격","blind":"실명 공격","vulnerable":"약점 노출","weaken":"적 공격 약화","break_armor":"방어 파괴","break_guard":"방어 파괴",
	"root_shot":"속박 사격","slow_shot":"감속 사격","bleed_shot":"출혈 사격","pull_shot":"끌어오는 사격","execute_shot":"마무리 사격","pull":"적 모으기","taunt":"도발",
	"summon":"동료 소환","pet_command":"동료 집중 공격","pet_burst":"동료 범위 공격","pet_pull":"동료가 적 모으기","pet_heal":"동료 회복","pet_recall":"동료 귀환 · 회복",
	"pet_buff":"동료 강화","pet_haste":"동료 속도 강화","pet_guard":"동료 방어 강화","pet_sacrifice":"동료 HP → 보호막",
	"combo":"빠른 3연타","weave":"연결 공격","finisher":"연계 마무리","execute":"마무리 일격","uppercut":"올려치기","heavy":"강력한 일격","heavy_dash":"돌진 강타","heavy_execute":"마무리 강타",
	"charge":"충전 일격","charge_area":"충전 범위 공격","charge_spin":"충전 회전 공격","charge_execute":"충전 마무리","parry":"방어 성공 → 반격권","parry_counter":"방어 성공 → 반격","parry_knee":"방어 성공 → 반격","meditate":"기세 회복",
	"hit_card":"카드 한 장 추가","hold_card":"카드 보관","cut_card":"카드 제거","stand_card":"패 유지","dice":"주사위 굴리기","reroll":"주사위 재굴림",
	"settle":"패 정산 공격","settle_heavy":"패 정산 강타","settle_fan":"패 정산 부채꼴","settle_barrage":"패 정산 연사","barrier":"피해 감소","trap":"지속 덫","trap_bleed":"출혈 덫"}

static func mode(node:Dictionary)->String:
	return str(Scaling.LEGACY.get(node.id,node.get("icon_node",node)).get("mode","fan"))
static func active(node:Dictionary)->bool:return node.get("effect","")=="active"
static func role(node:Dictionary)->String:
	return str(node.get("node_kind","active" if active(node) else "active_module" if node.get("effect","")=="upgrade" else "character_passive" if node.get("type","") in ["notable","keystone"] else "stat_passive"))
static func role_caption(node:Dictionary)->String:
	return {"active":"사용 기술","active_module":"기술 강화","character_passive":"행동 변화","stat_passive":"능력치"}[role(node)]
static func key_effect(node:Dictionary)->String:
	for key in node.get("effects",{}):
		if KEY_OUTCOMES.has(key):return key
	return ""
static func branch(node:Dictionary)->Array:return KEY_OUTCOMES.get(key_effect(node),[node.get("cluster_name","성장"),"기술 강화"])
static func short_label(node:Dictionary)->String:
	if active(node):return MODE_LABELS.get(mode(node),str(node.name))
	if node.get("type","")=="keystone":return str(branch(node)[0])
	if node.get("type","")=="notable":
		for key in node.get("effects",{}):
			if NOTABLE_OUTCOMES.has(key):return NOTABLE_OUTCOMES[key]
	if node.get("type","")=="minor":return str(node.get("effects_text","")).get_slice(" · ",0).replace("스킬 효과 반경","반경").replace("스킬 재사용 시간","재사용").replace("스킬 소모 기력","기력 소모").replace("스킬 ","")
	if node.get("effect","")=="passive":
		var rows=Balance.passive_metrics(node.class_id,int(str(node.id).right(2))-1,1)
		var title=str(rows[0][0]);var sign="−" if title.contains("감소") else "+"
		title=title.replace("패 조작 재사용 감소","패 조작 재사용").replace("21 정산 주사위 쿨 감소","21 정산→주사위 쿨").replace("주사위 중 시전 감소","주사위 시전").replace(" 감소","")
		return title+" "+sign+str(rows[0][1])
	if node.get("effect","")=="upgrade":return UPGRADE_LABELS.get(str(node.get("description","")),str(node.get("description",node.name)).get_slice(",",0).get_slice(". ",0))
	return str(Scaling.EFFECT_NAMES.get(node.get("effect",""),node.get("name",""))).replace("비전투 생명력 회복/초","비전투 회복/초").replace("기술 대기 감소","재사용 감소").replace("기본 공격 대기 감소","평타 대기 감소")+" "+Scaling.passive_text(node,1)

static func shape_rows(p:Dictionary,node:Dictionary,rank:int,damage:float,max_hp:float)->Array:
	if not active(node):return []
	var job=node.get("runtime","")=="job"
	var original:Dictionary=node.get("icon_node",node)
	var profile=Balance.profile(p,original,rank,damage,max_hp,p.get("skill_ranks",{}).get(original.id+"_upgrade",0)>0) if job else Scaling.profile(original,rank,preload("res://scripts/active_skills.gd").bonuses(p))
	var source:Dictionary=profile.node if job else profile
	var attack_mode=mode(node);var rows=[]
	if not job:return rows # Legacy Scaling.metrics already includes its exact geometry.
	if Balance.damaging(attack_mode) and source.get("radius",0)>0 and not Reach.job_shape(attack_mode).is_empty():
		rows.append(["효과 반경",Scaling.number(float(source.radius))+"칸"])
	elif source.get("range",0)>0 and Balance.damaging(attack_mode):rows.append(["사거리",Scaling.number(float(source.range))+"칸"])
	if rank==0:
		for row in rows:row[1]="미습득"
	return rows

static func headline_rows(rows:Array)->Array:
	var result=[]
	var meaningful=rows.filter(func(row):return not(str(row[1]) in ["0","0.0","0.00","0%","0.0%"] and str(row[2]) in ["0","0.0","0.00","0%","0.0%"]))
	# Damage/healing, reach, and recast tell the player the next rank's main result.
	for category in [["피해","회복","보호막","공격력","소환수 타격","치명타","무력화"],["반경","사거리","타격 수","대상 수","이동 거리"],["재사용 시간","지속시간","공격 속도","기력"]]:
		var found=false
		for word in category:
			for row in meaningful:
				if row not in result and str(row[0]).contains(word):result.append(row);found=true;break
			if found:break
	for row in meaningful:
		if result.size()>=3:break
		if row not in result:result.append(row)
	return result

static func compact_metric(label:String)->String:
	return label.replace("1회 기본 피해","타격 피해").replace("기본 피해 / 타격","타격 피해").replace("발사·타격·대상 수","타격·대상 수").replace("시전당 무력화","무력화").replace("효과 반경","반경").replace("재사용 시간","재사용")
