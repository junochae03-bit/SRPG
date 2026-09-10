extends RefCounted
# 표시명만 관리한다. 저장 식별자와 전투 규칙은 기존 카탈로그가 소유한다.
const PATH="res://data/content_names.json"
static var data:Dictionary={}
static func initialize():
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
static func skill(id:String,fallback:String)->String:
	initialize();return data.skills.get(id,fallback)
static func rename_skills(skills:Dictionary):
	initialize()
	for nodes in skills.values():
		for node in nodes:node.name=skill(node.id,node.name)
static func rename_constellations(nodes:Array,class_id:String):
	initialize()
	for node in nodes:
		node.name=skill(node.id,node.name)
		if data.clusters.has(class_id):
			var old_theme=str(node.cluster_name)
			node.cluster_name=data.clusters[class_id][int(node.cluster)]
			for i in range(node.tags.size()):
				if node.tags[i]==old_theme:node.tags[i]=node.cluster_name
			if node.get("family","")=="ranger":
				node.tradeoff=str(node.tradeoff).replace("단일 결의와 갈라지는 사냥길은 함께 선택할 수 없습니다.",str(data.clusters[class_id][1])+"와 "+str(data.clusters[class_id][3])+"은 함께 선택할 수 없습니다.")
static func equipment(slot:String,owner:String,tier:int,fallback:String)->String:
	initialize();return data.equipment.get(slot+":"+owner+":"+str(tier),fallback)
