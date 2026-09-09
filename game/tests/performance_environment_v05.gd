extends SceneTree
const Forest=preload("res://scripts/forest_environment.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const Art=preload("res://scripts/environment_art.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
var checks=0
var failures:Array=[]

class Host extends Node2D:
	var camera_pos=Vector2.ZERO
	var anchor=Vector2(763,460)
	var session={"connected":true,"local_id":1,"state":{"players":{1:{"pos":Vector2.ZERO}}}}
	func screen_center()->Vector2:return anchor
	func world_point(pos:Vector2)->Vector2:return Dungeon.iso(pos)-camera_pos+anchor

func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)

func original_props(renderer,curated:bool=true)->Array:
	var result:Array=[];var ids=Art.available_ids(renderer.map.zone,renderer.map.floor_number)
	var allowed=Art.ids(renderer.map.zone,renderer.map.floor_number);var candidate_index=0
	var rng=RandomNumberGenerator.new();rng.seed=renderer.map.seed_value+419
	for x in range(-10,Dungeon.SIZE+12,3):
		for y in range(-10,Dungeon.SIZE+12,3):
			var pos=Vector2(x,y)
			if not renderer.clear_for_prop(pos):continue
			var id=ids[candidate_index%ids.size()];candidate_index+=1
			var prop={"pos":pos,"art_id":id,"size":Art.height(id)*rng.randf_range(.92,1.08),"flip":rng.randf()<.5}
			if not curated or id in allowed:result.append(prop)
	return result

func reference_alpha(host:Host,renderer,previous:Array,delta:float):
	var player=host.session.state.players[1]
	var body=host.world_point(player.pos)-Vector2(0,52)
	for i in range(renderer.props.size()):
		var prop=renderer.props[i];var data=Art.frame(prop.art_id);var scale=prop.size/data.height
		var rect=Rect2(host.world_point(prop.pos)-data.foot*scale,data.texture.get_size()*scale)
		var covered=prop.pos.x+prop.pos.y>player.pos.x+player.pos.y-1.0 and rect.has_point(body)
		previous[i]=Forest.approach_alpha(previous[i],.25 if covered else 1.,delta)

func original_visible(host:Host,renderer)->Array:
	var view=(host.get_viewport().canvas_transform.affine_inverse()*host.get_viewport().get_visible_rect()).grow(300.)
	var result:Array=[]
	for prop in renderer.props:
		if view.has_point(host.world_point(prop.pos)):result.append(prop.render_id)
	return result

func run():
	root.size=Vector2i(1920,1080)
	var host=Host.new();root.add_child(host);var renderer=Forest.new(host)
	var all_ids:Dictionary={};var expected_ids:Dictionary={};var original_count=0;var retained_count=0;var faded=0
	for floor_number in range(0,102):
		var floor_id=mini(floor_number,100)
		var zone="town" if floor_number==101 else "forest" if floor_id==0 else Abyss.config(floor_id).terrain
		if floor_number==101:floor_id=0
		var map=Dungeon.new(20260909+floor_number,zone,floor_id);renderer.rebuild(map)
		var old=original_props(renderer);original_count+=old.size();retained_count+=renderer.props.size()
		var unfiltered=original_props(renderer,false)
		for id in Art.ids(zone,floor_id):expected_ids[id]=true
		check(old.size()<=unfiltered.size(),"curation leaves rejected prop positions empty without replacement")
		if Art.ids(zone,floor_id).size()<Art.available_ids(zone,floor_id).size():check(old.size()<unfiltered.size(),"curated biome has strictly fewer decoration candidates")
		var legacy_by_position={}
		for prop in unfiltered:legacy_by_position[prop.pos]=prop
		check(old.all(func(prop):return legacy_by_position.get(prop.pos,{})==prop),"curation preserves accepted source position scale and flip")
		var by_position:Dictionary={};var old_ids:Dictionary={};var kept_ids:Dictionary={}
		for prop in old:by_position[prop.pos]=prop;old_ids[prop.art_id]=true
		check(renderer.props.size()==ceili(old.size()*.55),"45 percent density reduction floor %d"%floor_number)
		check(renderer._geometry.size()==renderer.props.size(),"one immutable geometry per retained decoration")
		var expected_alpha:Array=[]
		for i in range(renderer.props.size()):
			var prop=renderer.props[i];var original=by_position[prop.pos];var geometry=renderer._geometry[i];var frame=Art.frame(prop.art_id)
			var scale=prop.size/frame.height;var rect=Rect2(-frame.foot*scale,frame.texture.get_size()*scale)
			check(prop.art_id==original.art_id and prop.size==original.size and prop.flip==original.flip and prop.render_id==i,"retained artwork/scale/flip and stable ordering unchanged")
			check(geometry.point==Dungeon.iso(prop.pos) and geometry.texture==frame.texture and geometry.local_rect==rect and geometry.shadow_radius==prop.size*.19,"cached sprite/shadow geometry equals old draw arguments")
			check(geometry.bounds==Rect2(Dungeon.iso(prop.pos)+rect.position,rect.size) and renderer.clear_for_prop(prop.pos),"unflipped coverage rectangle and entrance clearance unchanged")
			expected_alpha.append(1.);kept_ids[prop.art_id]=true;all_ids[prop.art_id]=true
		check(kept_ids.size()==old_ids.size(),"each biome decoration identity remains represented")
		var immutable=renderer.props.duplicate(true)
		# Walk through decorative bounds (including flipped sprites), teleport the
		# camera far from the player, and change raid framing/viewport zoom.
		for step in range(18):
			var index=(step*17)%renderer.props.size();var prop=renderer.props[index];var bounds=renderer._geometry[index].bounds
			var body=bounds.position+bounds.size*Vector2(.5,.67)
			var player_pos=Dungeon.from_iso(body+Vector2(0,52)) if step%3!=2 else map.spawn
			host.session.state.players[1].pos=player_pos
			host.camera_pos=Dungeon.iso(player_pos)+Vector2(12000,-9000) if step%4==0 else Dungeon.iso(player_pos)+Vector2(step*.37,-step*.63)
			host.anchor=Vector2(763,340 if step%2==0 else 460)
			var zoom=[1.,1.6,2.4,3.][step%4]
			root.canvas_transform=Transform2D(Vector2(zoom,0),Vector2(0,zoom),host.anchor*(1.-zoom))
			var delta=[0.,1./144.,1./60.,.075][step%4]
			reference_alpha(host,renderer,expected_alpha,delta);renderer.update_camera(delta)
			var same=true
			for i in range(expected_alpha.size()):
				if absf(renderer.props[i].alpha-expected_alpha[i])>.000001:same=false
				if renderer.props[i].alpha<.99:faded+=1
			check(same,"coverage fade equals original during movement/camera/zoom floor %d step %d"%[floor_number,step])
			check(renderer.visible_props().map(func(a):return a.data.render_id)==original_visible(host,renderer),"padded viewport culling and ordering equal original")
		for i in range(renderer.props.size()):
			var current=renderer.props[i].duplicate();current.alpha=1.
			check(current==immutable[i],"camera updates never mutate layout or source IDs")
	check(all_ids.size()==expected_ids.size() and all_ids.keys().all(func(id):return expected_ids.has(id)) and faded>0,"curated scenery identities retained and actual coverage exercised")
	check(all_ids.size()<Art.catalog.objects.size() and Art.catalog.objects.size()==108,"available registry is preserved without forcing unused art into scenes")
	# Rebuilding the same seed restores alpha and creates the identical sparse
	# arrangement without carrying geometry from the previous biome.
	var snapshot=renderer.props.duplicate(true)
	for prop in snapshot:prop.alpha=1.
	renderer.rebuild(renderer.map)
	check(renderer.props==snapshot,"rebuild resets alpha with deterministic density/geometry")
	var saved_cache=Art.cache.duplicate();Art.cache.clear()
	host.camera_pos=Vector2(40000,40000);host.session.state.players[1].pos=Vector2(1000,1000)
	for prop in renderer.props:prop.alpha=.25
	for step in range(120):renderer.update_camera(1./60.);renderer.visible_props()
	check(Art.cache.is_empty(),"camera and culling require no per-frame Art.frame lookup or texture acquisition")
	check(renderer.props.all(func(prop):return prop.alpha>.99999),"offscreen foliage recovers smoothly after player moves away")
	Art.cache=saved_cache
	var before_alpha=renderer.props.map(func(prop):return prop.alpha)
	host.session.state.players.clear();renderer.update_camera(.1)
	check(renderer.props.map(func(prop):return prop.alpha)==before_alpha,"missing local player leaves fades unchanged")
	host.session.state.players[1]={"pos":renderer.map.spawn};host.session.connected=false;renderer.update_camera(.1)
	check(not renderer.terrain.visible,"disconnected terrain remains hidden")
	host.session.connected=true
	# Report isolation timing rather than asserting a machine-dependent budget.
	var reference_times:Array=[];var cached_times:Array=[];var alpha=renderer.props.map(func(prop):return prop.alpha)
	for sample in range(7):
		var started=Time.get_ticks_usec()
		for frame in range(90):reference_alpha(host,renderer,alpha,1./60.);original_visible(host,renderer)
		reference_times.append((Time.get_ticks_usec()-started)/90.)
		started=Time.get_ticks_usec()
		for frame in range(90):renderer.update_camera(1./60.);renderer.visible_props()
		cached_times.append((Time.get_ticks_usec()-started)/90.)
	reference_times.sort();cached_times.sort()
	print("ENVIRONMENT_CPU_ISOLATION props=",renderer.props.size()," original_geometry_us=",reference_times[3]," cached_geometry_us=",cached_times[3]," retained_ratio=",float(retained_count)/original_count)
	root.canvas_transform=Transform2D.IDENTITY;host.queue_free();await process_frame
	print("PERFORMANCE_ENVIRONMENT_V05 checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
