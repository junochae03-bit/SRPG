extends RefCounted
## One public condition per generated floor; independent of loot/geometry RNG.
const VERSION=1
const CONDITIONS={
 "still":{"name":"안정된 기류","sight":8,"noise_bonus":0,"gather_bonus":0,"risk":0,"detail":"시야 8칸 · 평소 소음"},
 "echo":{"name":"울리는 공동","sight":8,"noise_bonus":3,"gather_bonus":1,"risk":1,"detail":"소음 +3칸 · 채집 +1"},
 "mist":{"name":"마력 안개","sight":6,"noise_bonus":0,"gather_bonus":2,"risk":1,"detail":"시야 6칸 · 채집 +2"}
}
static func select(seed_value:int,depth:int)->Dictionary:
 var id="still"
 if depth>10 and depth%10!=0:
  var rng=RandomNumberGenerator.new();rng.seed=seed_value+depth*101+71933
  id=CONDITIONS.keys()[rng.randi_range(0,CONDITIONS.size()-1)]
 var result=CONDITIONS[id].duplicate(true);result["id"]=id
 if depth>0 and depth%10==0:result.name="보스 전장";result.detail="환경 변이 없음 · 보스 패턴 주의"
 return result
static func configuration()->Dictionary:
 return {"version":VERSION,"conditions":CONDITIONS.duplicate(true),"generation":"seed+floor*101+71933","scope":"shared_generated_floor","first_chapter":"still_only","raid":"no_variants","party_scaling":"independent_no_health_or_damage_multiplier","reward":"personal_gather_site_only","preview":"next_map_seed_before_departure","persistence":"regenerated_from_current_map_seed"}
