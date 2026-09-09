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
	# Keep the authored paper grain and a narrow rim; oversized corner flourishes
	# must never compete with labels or dropdown entries.
	var patch=128 if kind=="paper" else 64
	var factor=(minf(corner,6.0) if kind=="paper" else corner)/float(patch);frame.scale=Vector2.ONE*factor;frame.size=control.size/factor
	frame.patch_margin_left=patch;frame.patch_margin_right=patch;frame.patch_margin_top=patch;frame.patch_margin_bottom=patch
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.show_behind_parent=true;control.add_child(frame)
	control.resized.connect(func():frame.size=control.size/factor)
	if control is OptionButton:style_popup(control.get_popup())
	return frame

static func style_popup(popup:PopupMenu):
	if popup.has_meta("thin_paper_popup"):return
	popup.set_meta("thin_paper_popup",true)
	popup.max_size=Vector2i(640,440)
	var inset=StyleBoxEmpty.new()
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:inset.set_content_margin(side,14)
	popup.add_theme_stylebox_override("panel",inset)
	popup.add_theme_stylebox_override("hover",StyleBoxEmpty.new())
	popup.add_theme_constant_override("v_separation",10)
	popup.add_theme_font_size_override("font_size",18)
	popup.add_theme_color_override("font_color",Color("29434a"))
	popup.add_theme_color_override("font_hover_color",Color("95632f"))
	# Retire earlier custom backgrounds while preserving the popup's own items.
	for child in popup.get_children():
		if child is CanvasLayer and child.layer==-1:child.hide()
	var layer=CanvasLayer.new();layer.layer=-1;popup.add_child(layer)
	var paper=Control.new();paper.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(paper)
	decorate(paper,"paper",4)
	popup.size_changed.connect(func():paper.size=Vector2(popup.size))
	popup.about_to_popup.connect(func():paper.size=Vector2(popup.size))
	popup.set_meta("thin_paper_background",paper)
static func picture(parent:Node,tex:Texture2D,at:Vector2,dimensions:Vector2)->TextureRect:
	var image=TextureRect.new();image.position=at;image.size=dimensions;image.texture=tex;image.material=icon_material(tex);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(image);return image
static func icon_material(tex:Texture2D)->ShaderMaterial:
	if tex is AtlasTexture and tex.atlas!=null:
		var path=tex.atlas.resource_path
		if path.contains("/icons/wood-") or path.contains("/assets/equipment/"):
			return preload("res://scripts/gat_art.gd").material()
	return null
static func panel(parent:Node,at:Vector2,dimensions:Vector2,kind:String="paper",corner:float=24)->Control:
	var surface=Control.new();surface.position=at;surface.size=dimensions;surface.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(surface);decorate(surface,kind,corner);return surface
