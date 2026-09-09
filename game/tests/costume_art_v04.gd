extends SceneTree
const Art = preload("res://scripts/costume_art_v04.gd")
var checks = 0
var failures: Array = []

func _initialize(): run.call_deferred()

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func color_tests():
	# Byte boundaries exercise the strict normalized threshold, plus colors from
	# cyan hair, dark outlines, purple hair and pre-existing alpha.
	var colors = [Color8(0,0,255), Color8(63,63,166), Color8(64,0,255), Color8(0,64,255),
		Color8(0,0,165), Color8(0,190,255), Color8(70,30,180), Color8(20,20,40),
		Color8(255,0,255), Color8(166,89,166), Color8(166,90,166), Color8(165,0,255),
		Color8(255,0,165), Color8(230,190,230), Color8(210,225,255,111)]
	var source = Image.create(colors.size(), 1, false, Image.FORMAT_RGBA8)
	for i in colors.size(): source.set_pixel(i, 0, colors[i])
	var before = source.get_data()
	for key in ["blue", "magenta"]:
		var keyed = Art._keyed_image(source, key)
		check(keyed != null and keyed.get_format() == Image.FORMAT_RGBA8, key + " RGBA result")
		for i in colors.size():
			var expected_key = i in ([0,1] if key == "blue" else [8,9])
			var actual = keyed.get_pixel(i, 0)
			check(actual.r8 == colors[i].r8 and actual.g8 == colors[i].g8 and actual.b8 == colors[i].b8, key + " RGB preserved " + str(i))
			check(actual.a8 == (0 if expected_key else colors[i].a8), key + " correct alpha " + str(i))
	check(source.get_data() == before, "key conversion never changes its source Image")
	check(Art._keyed_image(source, "unknown") == null, "unknown key is rejected")
	var mipmapped = Image.create(16,16,false,Image.FORMAT_RGBA8)
	mipmapped.fill(Color8(0,190,255))
	mipmapped.generate_mipmaps()
	var mip_keyed = Art._keyed_image(mipmapped,"blue")
	check(mip_keyed!=null and not mip_keyed.has_mipmaps() and mip_keyed.get_pixel(0,0)==mipmapped.get_pixel(0,0),"imported mipmap image yields exact base-level RGBA")
	check(mipmapped.has_mipmaps(),"imported source mipmaps remain unchanged")

func motion_tests():
	check(Art.index_for({}, 0) == 15 and Art.index_for({}, 4.9) == 15, "idle always uses frame 15")
	for i in 4:
		check(Art.index_for({"dir":Vector2.RIGHT}, float(i) / 8.0) == i, "walk frame " + str(i))
		check(Art.index_for({"dir":Vector2.RIGHT,"sprint":true}, float(i) / 12.0) == i, "sprint frame " + str(i))
		for motion in ["cleave","shoot","cast","spin"]:
			check(Art.index_for({"motion":motion,"motion_time":1.0-(i+0.1)/4.0,"motion_duration":1.0}, 0) == 4+i, motion+" normal "+str(i))
		for motion in ["slam","shoot_high","cast_high"]:
			check(Art.index_for({"motion":motion,"motion_time":1.0-(i+0.1)/4.0,"motion_duration":1.0}, 0) == 8+i, motion+" strong "+str(i))
	check(Art.index_for({"dodge_time":0.2}, 0)==12 and Art.index_for({"dodge_time":0.1}, 0)==13, "dodge phases")
	check(Art.index_for({"charge_time":0.1},0)==8 and Art.index_for({"charge_time":0.8},0)==9, "charge phases")
	check(Art.index_for({"hurt_time":0.1,"dodge_time":0.2,"charge_time":0.9},0)==14,"hurt overrides dodge and charge")
	for motion in ["dash","leap","blink"]:
		check(Art.index_for({"motion":motion,"motion_time":0.8,"motion_duration":1.0},0)==12,motion+" early dodge")
		check(Art.index_for({"motion":motion,"motion_time":0.1,"motion_duration":1.0},0)==13,motion+" late dodge")
	check(Art.index_for({"motion_time":0.2,"motion_duration":0.0},0) in range(4,8),"zero motion duration bounded")

func legacy_shader_padding_tests():
	var regex = RegEx.new()
	regex.compile("pixels\\.x == ([0-9]+)\\.0 && pixels\\.y == ([0-9]+)\\.0")
	var known_sizes: Array = []
	for matched in regex.search_all(FileAccess.get_file_as_string("res://shaders/gat_chroma.gdshader")):
		known_sizes.append(Vector2i(int(matched.get_string(1)),int(matched.get_string(2))))
	check(not known_sizes.is_empty(),"legacy shader size conditions read")
	for size in [Vector2i(1254,1254),Vector2i(1774,887)]:
		var source = Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
		var pink = Color8(236,80,224)
		source.fill(pink)
		var keyed = Art._keyed_image(source,"blue")
		var padded = Art._padded_image(keyed)
		check(padded.get_size()==size+Vector2i.ONE,"right/bottom padding dimensions "+str(size))
		check(padded.get_size() not in known_sizes,"RGBA dimensions bypass legacy shader key branch "+str(size))
		check(padded.get_pixel(0,0)==pink and padded.get_pixel(size.x-1,size.y-1)==pink,"legitimate magenta/pink survives padding "+str(size))
		check(source.get_size()==size and source.get_pixel(size.x-1,size.y-1)==pink,"source size and color unchanged "+str(size))
		var transparent = true
		for x in padded.get_width(): transparent = transparent and padded.get_pixel(x,size.y).a8==0
		for y in padded.get_height(): transparent = transparent and padded.get_pixel(size.x,y).a8==0
		check(transparent,"entire added right/bottom border is transparent "+str(size))

func packed_resource_test():
	# An exported PNG path can exist only as a .remap to a packed Texture2D.
	# This temporary pack has no raw PNG, exercising that exact loading branch.
	var folder = ProjectSettings.globalize_path("res://../runtime/costume-art-v04-packed/"+str(Time.get_ticks_usec()))
	check(DirAccess.make_dir_recursive_absolute(folder)==OK,"packed fixture directory")
	var source = Image.create(2,1,false,Image.FORMAT_RGBA8)
	source.set_pixel(0,0,Color8(0,0,255))
	source.set_pixel(1,0,Color8(220,60,230))
	var texture_path = folder.path_join("texture.res")
	check(ResourceSaver.save(ImageTexture.create_from_image(source),texture_path)==OK,"packed fixture texture saved")
	var remap_path = folder.path_join("texture.png.remap")
	var file = FileAccess.open(remap_path,FileAccess.WRITE)
	check(file!=null,"packed fixture remap open")
	if file==null: return
	file.store_string('[remap]\npath="res://costume_art_v04_fixture/texture.res"\n')
	file.close()
	var pack_path = folder.path_join("costume-art-v04-fixture.pck")
	var pack = PCKPacker.new()
	check(pack.pck_start(pack_path)==OK,"packed fixture begins")
	check(pack.add_file("res://costume_art_v04_fixture/texture.res",texture_path)==OK,"packed Texture2D added")
	check(pack.add_file("res://costume_art_v04_fixture/texture.png.remap",remap_path)==OK,"packed PNG remap added")
	check(pack.flush()==OK,"packed fixture flushed")
	check(ProjectSettings.load_resource_pack(pack_path),"packed fixture mounted")
	var virtual_png = "res://costume_art_v04_fixture/texture.png"
	check(not FileAccess.file_exists(virtual_png),"packed fixture contains no original PNG")
	var loaded = Art._source_image(virtual_png)
	check(loaded!=null and loaded.get_size()==source.get_size(),"PNG path loads imported packed Texture2D")
	if loaded!=null:
		check(loaded.get_pixel(1,0)==source.get_pixel(1,0),"packed Texture2D preserves original colors")
		var converted = Art._keyed_image(loaded,"blue")
		check(converted.get_pixel(0,0).a8==0 and converted.get_pixel(1,0)==source.get_pixel(1,0),"packed fallback supports correct chroma removal")

func fixture_tests():
	Art.reset_cache(true)
	Art._catalog_loaded = true
	var frames: Array = []
	for i in 16:
		frames.append({"index":i,"rect":[(i%4)*8,(i/4)*8,8,8],"foot":[4,7]})
	frames[6].sheet = "res://assets/costume_v04/fixture-patch.png"
	frames[6].body_height = 5.5
	Art._catalog_data = {"fixture":{"sheet":"res://assets/costume_v04/fixture.png","chroma_key":"blue","body_height":6.0,"frames":frames}}
	var source = Image.create(32,32,false,Image.FORMAT_RGBA8)
	source.fill(Color.WHITE)
	var base = ImageTexture.create_from_image(Art._padded_image(source))
	var patch = ImageTexture.create_from_image(Art._padded_image(source))
	Art._sheet_textures[Art._sheet_key("res://assets/costume_v04/fixture.png","blue")] = base
	Art._sheet_textures[Art._sheet_key("res://assets/costume_v04/fixture-patch.png","blue")] = patch
	check(Art.recognizes("fixture") and not Art.recognizes("missing"), "recognition")
	for field in Art.ID_FIELDS:
		check(Art.id_for({field:"fixture"}) == "fixture", "id compatibility " + field)
	check(Art.id_for({"costume_id":"missing","costume":"fixture"}) == "fixture", "unknown primary id falls back")
	check(Art.id_for({"avatar":"fixture","class_id":"fixture"}) == "", "avatar and class do not become costumes")
	check(Art.frame({},0).is_empty() and Art.portrait({}) == null, "unknown appearance gracefully falls back")
	var idle = Art.frame({"costume_id":"fixture"},0)
	check(idle.index==15 and idle.height==6.0 and idle.foot==Vector2(4,7),"entry height fallback and local foot")
	check(idle.texture==Art.frame({"costume_id":"fixture"},1).texture,"repeated frame reuses AtlasTexture")
	var changed = Art._frame_at("fixture",6)
	check(changed.height==5.5 and changed.texture.atlas==patch and changed.frame_source_path==frames[6].sheet,"per-frame sheet, source path and body height overrides")
	check(idle.texture.atlas==base and Art._frame_at("fixture",7).texture.atlas==base,"other frames retain base sheet")
	check(Art._sheet_textures.size()==2,"patch and original each cached once")
	check(Art.portrait({"costume_id":"fixture"})==Art.portrait({"costume_id":"fixture"}),"portrait cached")
	Art.reset_cache(true)

func full_catalog_tests():
	var data = Art.catalog()
	check(data.size()==33 and Art.ids().size()==33,"catalog contains all 33 costumes")
	var file_hashes: Dictionary = {}
	var sheet_keys: Dictionary = {}
	for id in Art.ids():
		var entry: Dictionary = data[id]
		check(entry.get("id",id)==id,"catalog id "+id)
		check(entry.get("frames",[]).size()==16,"16 frames "+id)
		if entry.get("frames",[]).size()!=16: continue
		check(entry.get("chroma_key","") in ["blue","magenta"],"recognized key "+id)
		for index in 16:
			var path = str(entry.frames[index].get("sheet",entry.sheet))
			var key = str(entry.frames[index].get("chroma_key",entry.chroma_key))
			sheet_keys[Art._sheet_key(path,key)] = {"path":path,"key":key}
			if not file_hashes.has(path) and FileAccess.file_exists(path): file_hashes[path]=FileAccess.get_sha256(path)
			var f = Art._frame_at(id,index)
			check(not f.is_empty(),id+" valid frame "+str(index))
			if f.is_empty(): continue
			check(f.texture is AtlasTexture and f.texture.atlas is ImageTexture,id+" memory atlas "+str(index))
			check(f.height>0 and is_finite(f.height),id+" body height "+str(index))
			check(f.foot.x>=0 and f.foot.y>=0 and f.foot.x<=f.texture.get_width() and f.foot.y<=f.texture.get_height(),id+" foot inside frame "+str(index))
			check(f.texture==Art._frame_at(id,index).texture,id+" cache "+str(index))
		check(Art.frame({"costume_id":id},0).get("index",-1)==15,id+" idle")
		check(Art.portrait({"costume_id":id})!=null,id+" portrait")
	for path in file_hashes:
		check(FileAccess.get_sha256(path)==file_hashes[path],"source PNG unchanged "+path)
	check(sheet_keys.size()==35,"33 originals plus 2 mint patch sheets are referenced")
	check(Art._sheet_textures.size()==sheet_keys.size(),"one converted texture per sheet and key")
	for cache_key in sheet_keys:
		if not Art._sheet_textures.has(cache_key): continue
		var source = Art._source_image(sheet_keys[cache_key].path)
		var keyed = Art._sheet_textures[cache_key].get_image()
		check(keyed!=null and keyed.get_format()==Image.FORMAT_RGBA8,"cached texture has real alpha "+cache_key)
		if source==null or keyed==null: continue
		check(keyed.get_size()==source.get_size()+Vector2i.ONE,"cached sheet includes one-pixel padding "+cache_key)
		# Independent sample positions include borders and interior costume pixels.
		for gy in 7:
			for gx in 7:
				var x = int((source.get_width()-1)*float(gx)/6.0)
				var y = int((source.get_height()-1)*float(gy)/6.0)
				var original = source.get_pixel(x,y)
				var pixel = keyed.get_pixel(x,y)
				var is_key = original.r<0.25 and original.g<0.25 and original.b>0.65 if sheet_keys[cache_key].key=="blue" else original.r>0.65 and original.b>0.65 and original.g<0.35
				check(pixel.r8==original.r8 and pixel.g8==original.g8 and pixel.b8==original.b8,"source RGB sample preserved "+cache_key+" "+str(gx)+","+str(gy))
				check(pixel.a8==(0 if is_key else original.a8),"source alpha sample correct "+cache_key+" "+str(gx)+","+str(gy))
	check(Art._failed_sheets.is_empty(),"no sheet load failures")
	check(Art._frame_textures.size()==33*16,"528 frame textures cached")

func art_color_sample_tests():
	# These are artist-selected real costume pixels, not threshold-generated
	# fixtures. Compare exact expected RGBA at original source coordinates.
	var path = ProjectSettings.globalize_path("res://../docs/costume_v04/calibration/color-samples.json")
	check(FileAccess.file_exists(path),"real artwork color samples exist in docs")
	if not FileAccess.file_exists(path): return
	var document = JSON.parse_string(FileAccess.get_file_as_string(path))
	var samples = document.get("samples",[]) if document is Dictionary else document
	check(samples is Array,"real artwork sample array")
	if not samples is Array: return
	check(samples.size()==109,"all 109 artist-selected color samples present")
	var checked_sheets: Dictionary = {}
	var last_key = ""
	var cached_image: Image = null
	var exact_matches = 0
	for sample in samples:
		var valid = sample is Dictionary and sample.get("point",[]) is Array and sample.get("point",[]).size()==2 and sample.get("expected_rgba",[]) is Array and sample.get("expected_rgba",[]).size()==4
		check(valid,"real artwork sample has source point and expected RGBA")
		if not valid: continue
		var sheet = str(sample.get("sheet",""))
		var key = str(sample.get("key",""))
		var safe_source = not sheet.is_empty() and sheet==sheet.get_file() and not "/" in sheet and not "\\" in sheet and key in ["blue","magenta"]
		check(safe_source,"real artwork sample names a costume basename and valid key")
		if not safe_source: continue
		var source_path = "res://assets/costume_v04/"+sheet
		var cache_key = Art._sheet_key(source_path,key)
		if cache_key!=last_key:
			var texture = Art._sheet_texture(source_path,key)
			cached_image=texture.get_image() if texture!=null else null
			last_key=cache_key
		checked_sheets[sheet]=true
		var x=int(sample.point[0])
		var y=int(sample.point[1])
		# Last row/column is runtime-only transparent padding, never sample art.
		var in_source = cached_image!=null and x>=0 and y>=0 and x<cached_image.get_width()-1 and y<cached_image.get_height()-1
		check(in_source,"real artwork point lies within unpadded source "+sheet)
		if not in_source: continue
		var actual = cached_image.get_pixel(x,y)
		var expected: Array = sample.expected_rgba
		var matches = actual.r8==int(expected[0]) and actual.g8==int(expected[1]) and actual.b8==int(expected[2]) and actual.a8==int(expected[3])
		check(matches,"real artwork exact RGBA "+sheet+" @ "+str(x)+","+str(y)+" "+str(sample.get("semantic","")))
		if matches: exact_matches+=1
	# Artist-selected colors cover 19 sheets. The independent catalog test above
	# checks all 35 referenced PNGs, including unchanged before/after file hashes.
	check(checked_sheets.size()==19,"real artwork samples cover the 19 documented sheets")
	var summary: Dictionary = document.get("summary",{}) if document is Dictionary else {}
	check(int(summary.get("sampled_sheets",-1))==checked_sheets.size() and int(summary.get("interior_sample_count",-1))==samples.size(),"real artwork sample counts agree with documentation")
	var declared_hashes = document.get("source_sha256",{}) if document is Dictionary else {}
	check(declared_hashes is Dictionary and declared_hashes.size()==checked_sheets.size(),"document records one source hash per sampled sheet")
	if declared_hashes is Dictionary:
		for sheet in checked_sheets:
			check(declared_hashes.has(sheet) and FileAccess.get_sha256("res://assets/costume_v04/"+sheet)==str(declared_hashes.get(sheet,"")),"real artwork sampled source matches recorded SHA256 "+sheet)
	check(exact_matches==109,"all 109 real artwork colors and alpha preserved exactly")
	print("COSTUME_ART_V04_COLOR_SAMPLES samples=",samples.size()," sheets=",checked_sheets.size()," exact_rgba_matches=",exact_matches)

func run():
	color_tests()
	motion_tests()
	legacy_shader_padding_tests()
	packed_resource_test()
	fixture_tests()
	var fixtures_only = "--fixtures-only" in OS.get_cmdline_user_args()
	if not fixtures_only:
		full_catalog_tests()
		art_color_sample_tests()
	print("COSTUME_ART_V04_TESTS scope=", "fixtures" if fixtures_only else "full_catalog", " checks=", checks, " failures=", failures.size())
	Art.reset_cache(true)
	quit(0 if failures.is_empty() else 1)
