extends RefCounted
## Short visible traces teach destination types without captions or route overlays.
const Art=preload("res://scripts/exploration_trace_art.gd")
const Navigation=preload("res://scripts/exploration_shortcuts.gd")
const MARKS=5
const SPACING=1.8
static func signature(site:Dictionary)->Dictionary:
	var profile={"kind":str(site.get("kind","danger")),"trace":"tracks"}
	match profile.kind:
		"gather":profile.trace="herbs" if site.material=="seed" else "ore"
		"shrine":profile.trace="magic"
		"cache":profile.trace="supplies"
	match site.get("event",""):
		"herbalist":profile.trace="herbs"
		"sealed_supplies":profile.trace="supplies"
		"blood_altar":profile.trace="blood"
		"echo_shrine":profile.trace="magic"
	return profile
static func generate(map)->Array:
	if map.floor_number<=0 or map.raid_arena:return []
	var cues=[];var graph=Navigation.navigation(map)
	var rng=RandomNumberGenerator.new();rng.seed=map.seed_value+902731
	for wing in [2,3,5,6]:
		var junction=1 if wing<4 else 4
		var path=graph.get_point_path(map.rooms[junction],map.rooms[wing])
		var sites=map.exploration_sites.filter(func(site):return site.room==wing)
		var cue=signature({} if sites.is_empty() else sites[0])
		var length=0.
		for index in range(1,path.size()):length+=path[index-1].distance_to(path[index])
		var marks=[];var travelled=0.
		var next=minf(maxf(3.,float(map.room_radii[junction])-2.),maxf(2.,length-9.))
		for index in range(1,path.size()):
			travelled+=path[index-1].distance_to(path[index])
			if Vector2(path[index]).distance_to(Vector2(map.rooms[wing]))<4.5:continue
			var before_turn=not marks.is_empty() and index+1<path.size() and not map.line_clear(marks[-1].pos,Vector2(path[index+1]))
			if travelled<next and not before_turn:continue
			var direction=Vector2(path[index]-path[index-1]).normalized()
			var position=Vector2(path[index])+direction.orthogonal()*rng.randf_range(-.45,.45)
			if not map.walkable(position) or not map.line_clear(Vector2(path[index]),position):position=Vector2(path[index])
			if not marks.is_empty() and not map.line_clear(marks[-1].pos,position):position=Vector2(path[index])
			# End a local trace before a blind turn instead of bridging its wall.
			if not marks.is_empty() and not map.line_clear(marks[-1].pos,position):break
			marks.append({"pos":position,"direction":direction,"index":marks.size(),"width":rng.randf_range(36.,48.),"rotation":rng.randf_range(-.45,.45)})
			next=travelled+SPACING*rng.randf_range(.75,1.4)
			if marks.size()==MARKS:break
		if marks.is_empty():continue
		cue.merge({"pos":marks[0].pos,"direction":marks[0].direction,"room":wing,"marks":marks})
		cues.append(cue)
	return cues
static func visible_marks(game,cue:Dictionary)->Array:
	return cue.marks.filter(func(mark):return game.vision.sees(mark.pos))
static func draw(game,cue:Dictionary):
	for mark in visible_marks(game,cue):
		var at=game.world_point(mark.pos)
		if at.distance_to(game.screen_center())>1100:continue
		var facing=(game.world_point(mark.pos+mark.direction)-at).angle()
		var texture=Art.texture(cue.trace)
		var dimensions=texture.get_size()*(float(mark.width)/texture.get_width())
		# Rotate debris clusters, not full-size bushes, crates or destination props.
		var rotation=float(mark.rotation)
		if cue.trace=="tracks":rotation+=facing+PI*.75
		game.draw_set_transform(at,rotation)
		game.draw_texture_rect(texture,Rect2(-dimensions*.5,dimensions),false,Color(1,1,1,.92))
		game.draw_set_transform(Vector2.ZERO)
static func configuration()->Dictionary:
	return {"maximum_branches":4,"maximum_marks_per_branch":MARKS,"spacing_tiles":SPACING,"spacing_variation":[.75,1.4],"lateral_variation_tiles":.45,"art_catalog":Art.CATALOG,"fragment_width_pixels":[36,48],"art_variation":"seeded_scale_rotation_and_walkable_offset","placement":"short_actual_walkable_route_at_junction","destination_mapping":"stable_material_event_or_elite_trace","captions":false,"visibility":"each_mark_current_sight_only","collision":"none","enemy_or_reward_reveal":false,"tutorial_and_raid":false}
