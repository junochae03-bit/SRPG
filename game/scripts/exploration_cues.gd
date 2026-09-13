extends RefCounted
const Rooms=preload("res://scripts/exploration_rooms.gd")
const Art=preload("res://scripts/environment_art.gd")
static func generate(map)->Array:
	if map.floor_number<=0 or map.raid_arena:return []
	var cues=[]
	for wing in [2,3,5,6]:
		var junction=1 if wing<4 else 4
		var direction=Vector2(map.rooms[junction]).direction_to(Vector2(map.rooms[wing]))
		var position=Vector2(map.rooms[junction])+direction*(map.room_radii[junction]-2.)
		if not map.walkable(position):position=Vector2(map.rooms[junction])+direction*3.
		var sites=map.exploration_sites.filter(func(site):return site.room==wing)
		var kind="danger" if sites.is_empty() else str(sites[0].kind)
		var art="ruins_rubble";var name="깊게 패인 발자국"
		if kind=="gather":art=Rooms.SITE_ART[sites[0].material];name="광석 조각" if sites[0].material=="ore" else "떨어진 씨앗"
		elif kind=="shrine":art="ruins_obelisk";name="희미한 마력"
		elif kind=="cache":art="flood_shipwreck_crate";name="흩어진 보급품"
		if not sites.is_empty() and not sites[0].get("event","").is_empty():
			match sites[0].event:
				"herbalist":art="autumn_berry_shrub";name="흩어진 약초"
				"sealed_supplies":art="ruins_rubble";name="떨어진 쇠장식"
				"blood_altar":art="ruins_obelisk";name="붉게 물든 흔적"
				"echo_shrine":art="nebula_astral_lantern";name="가늘게 울리는 소리"
		cues.append({"pos":position,"direction":direction,"room":wing,"kind":kind,"art":art,"name":name})
	return cues
static func draw(game,cue:Dictionary):
	if not game.vision.sees(cue.pos):return
	var data=Art.frame(cue.art);var height=26. if cue.kind!="shrine" else 34.
	for step in range(2):
		var at=game.world_point(cue.pos+cue.direction*float(step)*1.2)
		var scale=(height-float(step)*6.)/float(data.height)
		game.draw_texture_rect(data.texture,Rect2(at-data.foot*scale,data.texture.get_size()*scale),false,Color(.85,.82,.72,.85))
	var p=game.session.state.players.get(game.session.local_id,{})
	if not p.is_empty() and p.pos.distance_to(cue.pos)<3.5 and game.dungeon.line_clear(p.pos,cue.pos):
		var at=game.world_point(cue.pos)
		game.text_at(at+Vector2(0,38),cue.name,15,Color("efdfb1"),true)
