extends RefCounted
const Data=preload("res://scripts/exploration_crafting_data.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
const Content=preload("res://scripts/content.gd")
static func item(recipe:Dictionary,id:String)->Dictionary:
	var result=Equipment.make(recipe.type,int(recipe.tier),int(recipe.rarity),str(recipe.existing_equipment_id),str(recipe.affix),recipe.job,false)
	result.id=id
	if not id.begins_with("@"):Equipment.Special.generate(result,id)
	return result
static func quote(p:Dictionary,key:String)->Dictionary:
	var q={"title":"장비 제작","cost":0,"materials":{},"result":"","reason":"","icon":"smith","item":{},"operation":"craft_equipment","extra":{"recipe":key}}
	if not Data.recipes().has(key):q.reason="제작할 장비를 선택하세요.";return q
	var row=Data.recipes()[key];q.item=item(row,"@craft-preview");q.title=q.item.name;q.cost=int(row.gold);q.materials=row.materials.duplicate()
	q.result=Equipment.GRADES[int(q.item.rarity)]+" · 강화 +0\n"+Equipment.restriction_text(q.item)+"\n"+Equipment.option_text(q.item)
	if p.level<int(row.level):q.reason="LV.%d부터 제작"%row.level;return q
	q.reason=Equipment.reason(p,q.item)
	if not q.reason.is_empty():return q
	if p.gold<q.cost:q.reason="금화 %d G 부족"%(q.cost-p.gold);return q
	for material in row.materials:
		if p.materials.get(material,0)<row.materials[material]:q.reason=Content.MATERIALS[material]+" 부족";return q
	var staged=p.duplicate(true)
	consume(staged,row)
	if not Inventory.add_gear(staged,q.item):q.reason="완성품을 보관할 가방 공간이 필요합니다."
	return q
static func consume(p:Dictionary,row:Dictionary):
	p.gold-=int(row.gold)
	for key in row.materials:
		p.materials[key]-=int(row.materials[key])
		if p.materials[key]==0:p.bag_positions.erase("@mat:"+key)
static func use(sim,p:Dictionary,request:Dictionary)->bool:
	if request.size()!=3 or request.get("facility")!="smith" or request.get("operation")!="craft_equipment" or not request.get("recipe") is String:return false
	var q=quote(p,request.recipe)
	if not q.reason.is_empty():sim.notice(p.id,q.reason);return false
	var row=Data.recipes()[request.recipe];var staged=p.duplicate(true)
	var id="craft-"+str(Time.get_ticks_usec())+"-"+str(sim.serial)
	consume(staged,row)
	var output=item(row,id)
	if not Inventory.add_gear(staged,output):return false
	for key in ["gold","materials","bag_positions","inventory"]:p[key]=staged[key]
	sim.serial+=1;sim.dirty[p.id]=true;sim.notice(p.id,output.name+" 제작 완료")
	return true
