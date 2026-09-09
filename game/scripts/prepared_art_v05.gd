extends RefCounted
## Build-time byte-identical RGBA data, decompressed by the engine on demand.
const CATALOG="res://assets/render_cache_v05/catalog.json"
static var entries:Dictionary={}
static var initialized=false
static var loads:Dictionary={}

static func initialize():
	if initialized:return
	initialized=true
	if FileAccess.file_exists(CATALOG):
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
		if parsed is Dictionary:entries=parsed.get("entries",{})

static func descriptor(source:String,key:String)->Dictionary:
	initialize()
	return entries.get(source+"|"+key,{})

static func texture(source:String,key:String)->ImageTexture:
	var row=descriptor(source,key)
	if row.is_empty() or not FileAccess.file_exists(row.path):return null
	var packed=FileAccess.get_file_as_bytes(row.path)
	var raw=packed.decompress(int(row.rgba_bytes),FileAccess.COMPRESSION_GZIP)
	if raw.size()!=int(row.rgba_bytes):return null
	var image=Image.create_from_data(int(row.width),int(row.height),false,Image.FORMAT_RGBA8,raw)
	var result=ImageTexture.create_from_image(image)
	result.set_meta("prepared_source",source)
	result.set_meta("prepared_path",row.path)
	loads[source+"|"+key]=row.path
	return result
