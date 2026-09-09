extends RefCounted
# Only effects implemented by constellation_effects.gd may be advertised here.
# Values are shared with combat via SkillBuild.effects; original skills stay intact.
const MINORS={
	"skill_damage":["날카로운 별","스킬 피해 +1%",.01,"skill_power"],
	"skill_range":["먼 별의 궤도","스킬 사거리 +2%",.02,"range"],
	"skill_radius":["넓어지는 궤적","스킬 효과 반경 +2%",.02,"skill_radius"],
	"skill_haste":["빠른 순환","스킬 재사용 시간 -1%",.01,"skill_haste"],
	"skill_discount":["고른 호흡","스킬 소모 기력 -1%",.01,"skill_discount"],
	"skill_duration":["머무는 별빛","스킬 지속시간 +2%",.02,"slow_duration"],
	"move_speed":["가벼운 발걸음","이동 속도 +1%",.01,"speed"],
	"attack_speed":["손끝의 박자","기본 공격 속도 +1%",.01,"attack_haste"],
	"stagger_power":["흔들리는 균형","스킬 무력화 피해 +1.5%",.015,"stun_duration"],
	"support_power":["따뜻한 별","지원 스킬 위력 +1.5% · 회복·보호막·강화·소환",.015,"health_regen"]}
const NOTABLES={
	"followup_damage":["교차 타격","다른 스킬의 실제 적중 후 4초 안에 다음 공격기 피해 +12%",.12,"서로 다른 공격기를 번갈아 사용하면 효과를 얻습니다.","같은 기술 반복이나 빗나간 기술로는 연결이 시작되지 않습니다.","skill_power"],
	"stagger_followup":["붕괴의 연결","다른 스킬 후 다음 시전의 무력화 피해 +15%",.15,"무력화가 높은 기술 앞에 다른 기술을 연결하세요.","같은 기술을 반복하면 연결 보너스를 받지 못합니다.","stun_duration"],
	"execute_damage":["빈틈의 끝","생명력이 30% 미만인 적에게 공격기 피해 +15%",.15,"큰 공격을 적의 마지막 생명력 구간에 남겨 두세요.","생명력 30% 이상인 적에게는 추가 피해가 없습니다.","execute"],
	"efficiency_followup":["호흡 조절","다른 스킬 후 다음 시전의 소모 기력 -10%",.10,"저렴한 기술을 거쳐 큰 기술의 기력 부담을 낮춥니다.","같은 기술 연속 시전에는 할인이 없습니다.","skill_discount"],
	"mobility_refund":["회수하는 발걸음","회피 후 3초 안에 다음 공격기의 첫 적중에서 지불 기력 15% 회수",.15,"회피로 위치를 잡은 직후 기술을 적중시키세요.","빗나가거나 회피 후 3초가 지나면 기력을 돌려받지 못합니다.","dodge_discount"],
	"slow_on_followup":["멈춰 세우기","다른 스킬 연결 후 첫 적중에 0.7초 감속",.7,"감속을 먼저 만들면 제어 상태 피해 기술과 연결됩니다.","첫 적중만 발동하며 일반 기절·보스 무력화와는 별도입니다.","slow_duration"],
	"support_followup":["응답의 일격","비공격 기술 후 5초 안에 다음 공격기 피해 +15%",.15,"회복·방어·지원 기술을 공격 순환에 섞으세요.","공격기만 연속 사용하면 보너스가 없습니다.","skill_power"],
	"guard_on_followup":["되받는 보호","다른 스킬 연결 후 첫 적중에 최대 HP 3% 보호막을 2초간 생성",.03,"다른 공격을 연결하며 잠깐의 보호를 얻습니다.","여러 적이나 다단 적중으로 보호막을 반복 생성하지 않습니다.","defense"],
	"control_damage":["붙잡힌 약점","감속 또는 속박 상태인 적에게 공격기 피해 +15%",.15,"감속·속박을 부여하는 기술과 강한 공격을 연결하세요.","제어 상태가 없는 적에게는 추가 피해가 없습니다.","elite_damage"],
	"heal_on_followup":["회복의 리듬","다른 스킬 연결 후 첫 적중에 최대 HP 1% 회복",.01,"서로 다른 공격을 이어 작은 회복을 누적합니다.","같은 기술 반복과 추가 타격으로 중복 회복하지 않습니다.","health_regen"]}
const KEYS={
	"echo":["메아리","직접 피해 70% + 0.35초 뒤 같은 위치에 원시전 피해 40%의 추가 타격","재사용 시간 +15%. 움직인 적은 메아리를 피할 수 있습니다.","범위 공격과 제어 기술을 연결해 같은 위치에 적을 붙잡으세요.","fan"],
	"focus":["단일 결의","시전당 한 대상만 공격하며 피해 +25%","소모 기력 +25%. 한 시전으로 여러 적을 맞힐 수 없습니다.","보스 하나에 집중하는 기술 순환에 적합합니다.","shot"],
	"momentum":["회피의 탄력","회피 후 3초 안에 다음 공격기 피해 +25%, 시전 시간 절반","모든 공격기의 소모 기력 +10%. 회피 뒤 타이밍을 놓치면 강화가 없습니다.","회피로 공격 위치를 잡고 시전 시간이 긴 공격을 연결하세요.","blink"],
	"warrior_wave":["검기의 확장","직접 피해 75% + 첫 적중에서 전방으로 원시전 총량 35%의 파동","소모 기력 +15%. 직접 피해가 감소합니다.","적을 한 방향에 모아 근접 공격과 전방 파동을 함께 적중시키세요.","fan"],
	"warrior_reprise":["수호의 반주","비공격 기술 후 5초 안에 다음 공격은 직접 50% + 자기 위치 파동 70%","지원 위력 -20%. 준비 없이 공격하면 반주 파동이 없습니다.","방어·지원 뒤 적에게 접근해 자기 위치 파동을 맞히세요.","guard"],
	"ranger_chain":["갈라지는 사냥길","직접 피해 70% + 새 표적 최대 2명에게 각각 원시전 피해 25% 연쇄","같은 표적을 다시 방문하지 않습니다. 단일 보스에게는 직접 피해 감소가 남습니다.","여러 적이 모인 곳에서 새로운 표적으로 연쇄를 이어 가세요.","chain"],
	"ranger_snare":["지연하는 사냥","직접 피해 40% + 첫 적중 위치에 1초 뒤 원시전 피해 80% 폭발","재사용 시간 +25%. 폭발 전에 이동한 적은 피해를 피할 수 있습니다.","덫·감속·속박으로 폭발 위치에 적을 묶어 두세요.","trap"],
	"mage_burn":["잔열의 계약","직접 피해 60% + 첫 적중 표적에 4초 동안 원시전 피해 총 40%","즉시 피해가 감소하는 대신 소모 기력 -10%.","한 번 적중시킨 뒤 거리를 유지하며 지속 피해를 활용하세요.","field"],
	"mage_relay":["문장의 중계","비공격 기술 위치에 5초 문장. 다음 공격은 직접 50% + 문장 위치 폭발 70%","지원 위력 -20%. 적을 문장 위치에 두지 못하면 폭발을 맞히기 어렵습니다.","지원 기술의 시전 위치를 정하고 다음 공격으로 문장을 깨우세요.","burst"],
	"rogue_contract":["교차 낙인","첫 적중에 4초 낙인. 다른 공격기가 소비하면 그 시전의 해당 표적 피해 +50%","항상 공격기 피해 -10%. 같은 기술은 자기 낙인을 소비할 수 없습니다.","서로 다른 공격기로 낙인 생성과 소비를 나누세요.","mark"],
	"rogue_venom":["독의 회수","직접 피해 60% + 4초간 독 40%. 이동기·회피로 남은 독을 즉시 폭발","항상 소모 기력 +15%. 독 회수에는 대상과의 위치·시야 조건이 필요합니다.","독을 부여한 뒤 가까운 위치에서 회피·이동기로 피해를 앞당기세요.","bleed"],
	"fighter_flurry":["추적 연무","공격 총량을 0.18초 간격의 이동 추적 3타로 변환, 시전 시간 절반","총 피해 -10%. 추가 타격은 원시전 피해·무력화 예산을 나눠 사용합니다.","이동하는 적에게 가까이 붙어 여러 타격을 끝까지 이어 가세요.","combo"],
	"fighter_crush":["압축 파쇄","공격 총량을 한 번에 압축하고 총 피해 +20%","효과 반경 -20%, 준비 시간 +0.45초.","감속·제어 뒤 좁은 범위의 묵직한 한 방을 맞히세요.","charge"]}
const MINOR_ROUTES=[
	["skill_damage","skill_radius","skill_haste","skill_range","skill_duration","stagger_power"],
	["skill_damage","attack_speed","skill_discount","stagger_power","skill_haste","skill_range"],
	["move_speed","skill_haste","skill_discount","attack_speed","skill_radius","skill_range"],
	["support_power","skill_duration","skill_radius","stagger_power","skill_discount","move_speed"],
	["skill_damage","skill_duration","support_power","skill_range","attack_speed","skill_haste"]]
const NOTABLE_ROUTES=[["followup_damage","stagger_followup"],["execute_damage","efficiency_followup"],["mobility_refund","slow_on_followup"],["support_followup","guard_on_followup"],["control_damage","heal_on_followup"]]
const FAMILY_KEYS={"warrior":["warrior_wave","warrior_reprise"],"ranger":["ranger_chain","ranger_snare"],"mage":["mage_burn","mage_relay"],"rogue":["rogue_contract","rogue_venom"],"fighter":["fighter_flurry","fighter_crush"]}
static func node_id(class_id:String,cluster:int,entry:String)->String:return "%s:star:%d:%s"%[class_id,cluster,entry]
static func nodes_for(class_id:String,job:Dictionary,originals:Array)->Array:
	var family=job.get("base",class_id);var keys=["echo","focus","momentum"]+FAMILY_KEYS[family];var result=[]
	var actives=originals.filter(func(n):return n.effect=="active")
	for cluster in range(5):
		var key=keys[cluster];var theme=KEYS[key][0];var anchor=actives[cluster%actives.size()]
		var gate=maxi(2,int(job.get("starter",false)==false and job.has("base"))*30)
		var entry_parents=[anchor.id]
		if cluster>0:entry_parents.append(node_id(class_id,cluster-1,"m2"))
		var parents={"m0":entry_parents,"m1":[node_id(class_id,cluster,"m0")],"m2":[node_id(class_id,cluster,"m0")],"n0":[node_id(class_id,cluster,"m1")],"m3":[node_id(class_id,cluster,"m2")],"m4":[node_id(class_id,cluster,"n0"),node_id(class_id,cluster,"m3")],"n1":[node_id(class_id,cluster,"m3")],"m5":[node_id(class_id,cluster,"n1"),node_id(class_id,cluster,"m4")],"key":[node_id(class_id,cluster,"n0"),node_id(class_id,cluster,"n1")]}
		for index in range(9):
			var entry=["m0","m1","m2","n0","m3","m4","n1","m5","key"][index];var type="keystone" if entry=="key" else "notable" if entry.begins_with("n") else "minor"
			var node={"id":node_id(class_id,cluster,entry),"class_id":class_id,"family":family,"effect":"constellation","type":type,"allocation_field":"constellation_allocations","max_rank":1,"cost":6 if type=="keystone" else 3 if type=="notable" else 1,"cluster":cluster,"cluster_name":theme,"index":index,"parents":parents[entry],"parent_mode":"all" if entry=="key" else "any","required_rank":1,"level":maxi(gate,25) if type=="keystone" else maxi(gate,10) if type=="notable" else gate,"exclusive_group":class_id+(":delivery" if cluster in [0,1] else ":family" if cluster in [3,4] else "") if type=="keystone" and cluster!=2 else "","exclusive_with":[],"tags":[theme,type],"synergy":"","tradeoff":"","effects":{}}
			if type=="minor":
				var effect=MINOR_ROUTES[cluster][int(entry.right(1))];var spec=MINORS[effect]
				node.name=spec[0]+" · "+theme;node.effects_text=spec[1];node.description=spec[1];node.effects[effect]=spec[2];node.icon_node={"effect":spec[3]};node.tags.append("성장")
			elif type=="notable":
				var effect=NOTABLE_ROUTES[cluster][int(entry.right(1))];var spec=NOTABLES[effect]
				node.name=spec[0];node.effects_text=spec[1];node.description=spec[1];node.effects[effect]=spec[2];node.synergy=spec[3];node.tradeoff=spec[4];node.icon_node={"effect":spec[5]};node.tags.append("연결 효과")
			else:
				var spec=KEYS[key];node.name=spec[0];node.effects_text=spec[1];node.description=spec[1]+". 공격기 변환이며 소환·비공격·패링 준비 기술의 전달 방식은 유지됩니다.";node.effects[key]=1.;node.tradeoff=spec[2];node.synergy=spec[3];node.icon_node={"runtime":"job","effect":"active","mode":spec[4],"index":cluster};node.tags.append("행동 변화")
				if family=="ranger" and cluster in [1,3]:
					node.exclusive_with=[node_id(class_id,3 if cluster==1 else 1,"key")];node.tradeoff+=" 단일 결의와 갈라지는 사냥길은 함께 선택할 수 없습니다."
			result.append(node)
	return result

static func effect_label(key:String)->String:
	if MINORS.has(key):return {"skill_damage":"스킬 피해","skill_range":"스킬 사거리","skill_radius":"스킬 반경","skill_haste":"재사용 시간 감소","skill_discount":"기력 절약","skill_duration":"스킬 지속시간","move_speed":"이동 속도","attack_speed":"기본 공격 속도","stagger_power":"스킬 무력화","support_power":"지원 위력"}[key]
	if NOTABLES.has(key):return NOTABLES[key][0]
	if KEYS.has(key):return KEYS[key][0]
	return key
