extends RefCounted
static var aliases:Dictionary={}
static var save_path=""
static var revision=0
static func valid_name(value:String)->bool:
	var name=value.strip_edges()
	if name.is_empty() or name.length()>24:return false
	for i in name.length():
		if name.unicode_at(i)<32 or name.unicode_at(i)==127:return false
	return true
static func configure(path:String):
	save_path=path;aliases={};revision+=1
	if not FileAccess.file_exists(path):return
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:return
	for key in parsed:
		if key is String and parsed[key] is String and valid_name(parsed[key]):aliases[key]=parsed[key]
static func display(id:String,fallback:String)->String:return str(aliases.get(id,fallback))
static func rename(id:String,value:String)->bool:
	if id.is_empty() or not valid_name(value) or save_path.is_empty():return false
	var next=aliases.duplicate();next[id]=value.strip_edges()
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var file=FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(next,"\t"));file.close()
	if DirAccess.rename_absolute(save_path+".tmp",save_path)!=OK:return false
	aliases=next;revision+=1;return true
