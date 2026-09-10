extends SceneTree
const C=preload("res://scripts/content.gd")
const N=preload("res://scripts/content_names.gd")
const E=preload("res://scripts/equipment_catalog.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func run():
	var original=preload("res://scripts/skill_catalog.gd").NODES.duplicate(true)
	var jobs=JSON.parse_string(FileAccess.get_file_as_string("res://data/jobs/catalog.json"))
	original.merge(jobs.nodes)
	C.initialize_jobs();N.initialize()
	var seen={}
	for cls in C.CLASSES:
		for i in range(C.SKILLS[cls].size()):
			var node=C.SKILLS[cls][i];var before=original[cls][i].duplicate(true);var after=node.duplicate(true)
			check(N.data.skills.has(node.id) and node.name==N.data.skills[node.id],"원기술 이름 연결: "+node.id)
			before.erase("name");after.erase("name")
			check(before==after,"원기술 수치·조건 보존: "+node.id)
		for node in C.Build.nodes_for(cls):
			check(node.name==N.data.skills[node.id],"트리 이름 일치: "+node.id)
			check(not seen.has(node.name),"서로 다른 노드의 이름 구분: "+node.id);seen[node.name]=true
	check(seen.size()==1510,"원기술·별자리 전체 이름")
	var base_names={}
	for cls in C.CLASSES:
		for tier in range(10):
			for grade in range(5):
				var item=E.make("sword",tier,grade,"name-test","none",cls)
				check(item.base_name==N.data.equipment["weapon:"+cls+":"+str(tier)],"무기 이름")
				check(item.bonus==tier*6+grade*4+4 and item.job_lock==cls,"무기 수치·착용 조건")
				base_names[item.base_name]=true
	for family in E.FAMILY_NAMES:
		for slot in C.SLOTS:
			if slot=="weapon":continue
			for tier in range(10):
				var item=E.make(slot,tier,2,"old-save","vigor",family)
				check(item.base_name==N.data.equipment[slot+":"+family+":"+str(tier)],"방어구 이름")
				base_names[item.base_name]=true
				item.upgrade=3;item.name="예전 저장 이름 +3";item.base_name="예전 저장 이름"
				var before=item.duplicate(true);E.normalize(item,{"class_id":family})
				for key in ["id","bonus","rarity","tier","upgrade","affix","family","job_lock","required_level"]:check(item[key]==before[key],"기존 장비 수치 보존: "+key)
				check(item.name.ends_with(" +3") and item.base_name==N.data.equipment[slot+":"+family+":"+str(tier)],"기존 장비 새 이름·강화 유지")
	check(base_names.size()==500,"장비 기본 조합 이름 500개")
	print("CONTENT_NAMES checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
