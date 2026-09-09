extends RefCounted
const Content=preload("res://scripts/content.gd")
const Progression=preload("res://scripts/progression.gd")
const POINTS=10
const CLASSES=["warrior","ranger","mage","rogue","fighter"]
const DESCRIPTIONS={"warrior":"검과 강인한 방어로\n전선을 지키는 근접 전사", "ranger":"활과 기동력으로\n거리를 벌리는 원거리 사수", "mage":"범위 마법과 제어로\n전장을 다루는 마법사", "rogue":"날렵한 단검과 교란으로\n빈틈을 노리는 도적", "fighter":"권격과 돌진으로\n적을 몰아붙이는 격투가"}
const PRESETS={"warrior":[4,3,1,2,0],"ranger":[4,1,1,4,0],"mage":[0,2,2,1,5],"rogue":[4,1,2,3,0],"fighter":[4,3,1,2,0]}
static func suggested(class_id:String)->Dictionary:
	var result={};var keys=Progression.NAMES.keys();var values=PRESETS.get(class_id,PRESETS.warrior)
	for i in range(keys.size()):result[keys[i]]=values[i]
	return result
static func reason(sheet:Dictionary)->String:
	Content.initialize_jobs()
	if not sheet.get("name") is String:return "이름을 입력해 주세요."
	var name=sheet.name.strip_edges()
	if name.length()<1 or name.length()>16:return "이름은 1~16자로 입력해 주세요."
	for index in range(name.length()):
		if name.unicode_at(index)<32 or name.unicode_at(index)==127:return "이름에 줄바꿈이나 제어 문자를 사용할 수 없습니다."
	if sheet.get("class_id","") not in CLASSES:return "기본 직업을 선택해 주세요."
	if sheet.get("avatar","")!="auto" or sheet.get("costume","none")!="none":return "새 모험가는 직업 기본 외형으로 시작합니다."
	if not Content.appearance_allowed(sheet.class_id,sheet.avatar,sheet.get("costume","none")):return "선택한 직업에 맞는 외형을 골라 주세요."
	if not sheet.get("stats") is Dictionary:return "초기 능력치를 배분해 주세요."
	var spent=0
	for key in sheet.stats:
		var value=sheet.stats[key]
		if key not in Progression.NAMES or (not value is int and not value is float) or not is_finite(float(value)) or value<0 or value!=floor(value):return "올바른 능력치 값을 입력해 주세요."
		spent+=int(value)
	if spent!=POINTS:return "초기 능력치 %d점을 모두 배분해 주세요. (남은 점수 %d)"%[POINTS,POINTS-spent]
	return ""
static func player_data(sheet:Dictionary)->Dictionary:
	if not reason(sheet).is_empty():return {}
	var stats={}
	for key in Progression.NAMES:stats[key]=int(sheet.stats.get(key,0))
	var inventory=[];var equipment={}
	for type in ["sword","head","chest","feet"]:
		var item=preload("res://scripts/equipment_catalog.gd").make(type,0,0,"starter-"+type,"none",sheet.class_id)
		inventory.append(item);equipment[item.slot]=item.id
	return {"schema_version":7,"skill_build_version":2,"constellation_allocations":{},"creation_points":POINTS,"name":sheet.name.strip_edges(),"class_id":sheet.class_id,"avatar":"auto","costume":"none","owned_appearances":[],"stats":stats,"tutorial_done":false,"inventory":inventory,"equipment":equipment,"equipped":equipment.weapon,"training_given":true}
