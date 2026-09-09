extends RefCounted
static var data={}
static var cache={}
static func init():
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/catalog.json"))
static func texture(kind:String)->Texture2D:
	init()
	if not cache.has(kind):
		var atlas=AtlasTexture.new();atlas.atlas=load(data.kit);var r=data.frames[kind]
		atlas.region=Rect2(r[0],r[1],r[2],r[3]);atlas.filter_clip=true;cache[kind]=atlas
	return cache[kind]
static func facility(key:String)->Texture2D:
	init();var id="facility_"+key
	if not cache.has(id):
		var index=["smith","shop","alchemy","guild","inn","portal"].find(key)
		var atlas=AtlasTexture.new();atlas.atlas=load(data.facilities);atlas.region=Rect2(index%3*512,int(index/3)*512,512,512);atlas.filter_clip=true;cache[id]=atlas
	return cache[id]
static func decorate(control:Control,kind:String="paper",corner:float=18)->NinePatchRect:
	var frame=NinePatchRect.new();frame.texture=texture(kind)
	var factor=corner/64.0;frame.scale=Vector2.ONE*factor;frame.size=control.size/factor
	frame.patch_margin_left=64;frame.patch_margin_right=64;frame.patch_margin_top=64;frame.patch_margin_bottom=64
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.show_behind_parent=true;control.add_child(frame)
	control.resized.connect(func():frame.size=control.size/factor)
	return frame
static func picture(parent:Node,tex:Texture2D,at:Vector2,dimensions:Vector2)->TextureRect:
	var image=TextureRect.new();image.position=at;image.size=dimensions;image.texture=tex;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(image);return image
static func panel(parent:Node,at:Vector2,dimensions:Vector2,kind:String="paper",corner:float=24)->Control:
	var surface=Control.new();surface.position=at;surface.size=dimensions;surface.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(surface);decorate(surface,kind,corner);return surface
