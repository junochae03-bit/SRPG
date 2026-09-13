extends RefCounted
const Progression=preload("res://scripts/progression.gd")
const Content=preload("res://scripts/content.gd")

static func total_xp(p:Dictionary)->int:
	var value=int(p.xp)
	for level in range(1,int(p.level)):value+=Progression.xp_required(level)
	return value

static func begin(p:Dictionary,floor_number:int,clock:float):
	p["expedition_journal"]={"id":str(Time.get_ticks_usec()),"first_floor":floor_number,"deepest_floor":floor_number,"elapsed":0.,"started_at":clock,"gold":p.gold,"xp":total_xp(p),"kills":p.kills,"materials":p.materials.duplicate(true),"gear":p.inventory.map(func(item):return item.id),"potions":p.potions,"cleared_floor":p.cleared_floor}

# Candidate-only transition. A failed disk commit cannot consume the live ledger.
static func transition(previous:Dictionary,next:Dictionary,from_floor:int,to_floor:int,clock:float):
	next["expedition_report"]=previous.get("expedition_report",{}).duplicate(true)
	if from_floor<=0:
		if to_floor>0:begin(next,to_floor,0.)
		return
	var journal=previous.get("expedition_journal",{}).duplicate(true)
	if journal.is_empty():return
	journal.elapsed+=maxf(0.,clock-float(journal.started_at));journal.started_at=0.
	if to_floor>0:
		journal.deepest_floor=maxi(int(journal.deepest_floor),to_floor)
		next["expedition_journal"]=journal
		return
	var materials={}
	for key in Content.MATERIALS:
		var difference=int(previous.materials.get(key,0))-int(journal.materials.get(key,0))
		if difference!=0:materials[key]=difference
	var gear=previous.inventory.filter(func(item):return item.id not in journal.gear)
	next["expedition_report"]={"id":journal.id,"first_floor":journal.first_floor,"deepest_floor":journal.deepest_floor,"elapsed":journal.elapsed,"gold_delta":int(previous.gold)-int(journal.gold),"xp":maxi(0,total_xp(previous)-int(journal.xp)),"kills":maxi(0,int(previous.kills)-int(journal.kills)),"materials_delta":materials,"gear_count":gear.size(),"potions_delta":int(previous.potions)-int(journal.potions),"unlocked":maxi(0,int(previous.cleared_floor)-int(journal.cleared_floor))}
	next.erase("expedition_journal")

static func recommendations(p:Dictionary)->Array:
	var rows=[]
	var objective=preload("res://scripts/expedition_goals.gd").describe(p)
	if not objective.is_empty() and objective.ready and objective.facility!="portal" and int(p.expedition_goal.stage)<3:
		var work=preload("res://scripts/expedition_goals.gd").work_status(p)
		rows.append({"facility":objective.facility,"title":objective.title+" 확보","detail":"모은 재료로 작업하기" if work.ready else work.reason})
	if not objective.is_empty() and int(p.expedition_goal.stage)==3:
		rows.append({"facility":"portal","title":"준비 완료 · B%d 다음 도전"%int(p.highest_floor),"detail":"새 장비와 보급으로 다음 탐사 선택"})
	var contract=p.get("guild_contract",{})
	if not contract.is_empty() and int(contract.progress)>=int(contract.target):
		rows.append({"facility":"guild","title":"완료한 의뢰","detail":"길드에서 토벌 보상 받기"})
	if p.potions<3 or p.hp<p.max_hp*.6:
		rows.append({"facility":"inn","title":"다음 원정 채비","detail":"생명력 회복 · 물약 보충"})
	var upgradeable=p.inventory.any(func(item):return int(item.get("upgrade",0))<5)
	if upgradeable and int(p.materials.get("ore",0))>0:
		rows.append({"facility":"smith","title":"가져온 광석 활용","detail":"대장간에서 강화 비용 확인"})
	if rows.size()<2:
		rows.append({"facility":"alchemy","title":"모은 재료 활용","detail":"연금술 조합식 확인"})
	rows.append({"facility":"portal","title":"B%d 다음 도전"%int(p.highest_floor),"detail":"던전 입구에서 다음 층과 보급 확인"})
	return rows.slice(0,3)

static func configuration()->Dictionary:
	return {"persistence":"current session only","scope":"per player","gold_and_materials":"net change after consumption and loss","gear":"new IDs still carried on return","time":"simulation time summed across floors","return":"successful dungeon to town transition","tutorial_included":false}
