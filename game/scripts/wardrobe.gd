extends RefCounted
const Content=preload("res://scripts/content.gd")
const Names=preload("res://scripts/sprite_names.gd")
static func options(class_id:String)->Array:
	var result=["base:"+class_id]
	var default_avatar=default_avatar_id(class_id)
	for id in Content.avatar_options(class_id):
		if id!="auto" and id!=default_avatar:result.append("avatar:"+id)
	for id in Content.costume_options(class_id):
		if id!="none":result.append("costume:"+id)
	return result
static func default_avatar_id(class_id:String)->String:
	var sheet={"class_id":class_id,"avatar":"auto","costume":"none"}
	# Runtime loads avoid introducing a Content -> Wardrobe -> art preload cycle.
	# Advanced jobs have their own default illustration, so their family GAT art
	# remains a distinct appearance and may still be sold.
	if load("res://scripts/job_art.gd").has_sprite(sheet):return ""
	return str(load("res://scripts/gat_art.gd").avatar(sheet))
static func valid_id(id:String)->bool:
	Content.initialize_jobs()
	var parts=id.split(":",true,1)
	if parts.size()!=2:return false
	match parts[0]:
		"base":return Content.CLASSES.has(parts[1])
		"avatar":return Content.AVATARS.has(parts[1])
		"costume":return Content.COSTUMES.has(parts[1]) and parts[1]!="none"
	return false
static func normalize(p:Dictionary,saved:Dictionary):
	var owned=[]
	for id in saved.get("owned_appearances",[]):
		if id is String and valid_id(id) and id not in owned:owned.append(id)
	# A pre-shop save keeps its equipped appearance at no charge.
	if not saved.has("owned_appearances"):
		if p.get("avatar","auto")!="auto":owned.append("avatar:"+p.avatar)
		if p.get("costume","none")!="none":owned.append("costume:"+p.costume)
	p["owned_appearances"]=owned
	if saved.has("owned_appearances"):
		if p.get("avatar","auto")!="auto" and "avatar:"+p.avatar not in owned:p.avatar="auto"
		if p.get("costume","none")!="none" and "costume:"+p.costume not in owned:p.costume="none"
static func owned(p:Dictionary,id:String)->bool:return id.begins_with("base:") or id in p.get("owned_appearances",[])
static func price(id:String)->int:return 0 if id.begins_with("base:") else 500 if id.begins_with("avatar:") else 1200
static func label(id:String)->String:
	Content.initialize_jobs()
	var key=id.get_slice(":",1)
	var fallback=Content.CLASSES.get(key,{"name":"모험가"}).name+" 기본 외형" if id.begins_with("base:") else str(Content.AVATARS.get(key,key)) if id.begins_with("avatar:") else str(Content.COSTUMES.get(key,key))
	return Names.display(id,fallback)
static func preview(p:Dictionary,id:String)->Dictionary:
	var result={"class_id":p.class_id,"avatar":"auto","costume":"none"}
	if id.begins_with("avatar:"):result.avatar=id.get_slice(":",1)
	elif id.begins_with("costume:"):result.costume=id.get_slice(":",1)
	return result
static func purchase(p:Dictionary,id:String)->bool:
	if id not in options(p.class_id) or owned(p,id) or int(p.gold)<price(id):return false
	p.gold-=price(id);p.owned_appearances.append(id);return true
static func equip(p:Dictionary,id:String)->bool:
	var legacy_default=id=="avatar:"+default_avatar_id(p.class_id) and id in p.get("owned_appearances",[])
	if (id not in options(p.class_id) and not legacy_default) or not owned(p,id):return false
	var value=preview(p,id);p.avatar=value.avatar;p.costume=value.costume;return true
static func owned_avatars(p:Dictionary)->Array:
	return Content.avatar_options(p.class_id).filter(func(id):return id=="auto" or owned(p,"avatar:"+id))
static func owned_costumes(p:Dictionary)->Array:
	return Content.costume_options(p.class_id).filter(func(id):return id=="none" or owned(p,"costume:"+id))
