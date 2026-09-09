extends SceneTree
const Camera=preload("res://scripts/battle_camera.gd")
const Sim=preload("res://scripts/simulation.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
const Art=preload("res://scripts/world_art.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func drawn_annotations(boss:Dictionary)->Array:
	var result=[]
	for index in 3:
		var sprite=Art.variant_frame(boss.kind,int(boss.get("floor",0)),boss.get("raid",false),index>0)
		var scale=1.0
		if sprite.is_empty():
			var at=["warden","golem","sentinel"].find(boss.kind)*3
			sprite=Art.frame("bosses",at+index);scale=335.0/Art.frame("bosses",at).height
		else:scale=335.0/sprite.height
		var height=sprite.texture.get_height()*scale
		# Reconstruct main/status_markers draw coordinates independently of Camera.
		# Five icons plus overflow text, including its outlined glyph margin.
		result.append(Rect2(-66,-height-64.5,136,21))
		# Three stars orbit +/-18px, with a 5px radius, at -height-26.
		result.append(Rect2(-23,-height-31,46,10))
	return result
func run():
	for floor_number in range(10,101,10):
		var sim=Sim.new(20260909+floor_number,Abyss.config(floor_number).terrain,floor_number)
		var p=sim.add_player(1,"Camera")
		var boss=sim.enemies.values().filter(func(e):return e.get("raid",false))[0]
		var markers=drawn_annotations(boss)
		var silhouette=Camera.silhouette(boss)
		for rect in markers:check(silhouette.encloses(rect),"every pose includes status row and stun stars B%d"%floor_number)
		for state in ["ready","check","down","immune"]:
			var staged=boss.duplicate(true);staged.stagger.state=state;staged.stun_time=3.0;staged.attack_motion=.2;staged.windup=1.0
			check(Camera.silhouette(staged)==silhouette,"status and attack changes cannot pulse zoom B%d %s"%[floor_number,state])
		for radius in [1.0,3.1,8.3]:
			for angle_index in 16:
				p.pos=boss.pos+Vector2.RIGHT.rotated(angle_index*TAU/16)*radius
				var before=JSON.stringify(boss)
				var frame=Camera.framing(p,[boss])
				check(frame.boss,"boss encounter")
				var screen=Rect2(Camera.SAFE.get_center()+(frame.bounds.position-frame.position)*frame.zoom,frame.bounds.size*frame.zoom)
				check(Camera.SAFE.grow(.1).encloses(screen),"all poses below meters and above quick items B%d r%.1f a%d"%[floor_number,radius,angle_index])
				for rect in markers:
					var marker_screen=Rect2(Camera.SAFE.get_center()+(Dungeon.iso(boss.pos)+rect.position-frame.position)*frame.zoom,rect.size*frame.zoom)
					check(Camera.SAFE.grow(.1).encloses(marker_screen),"status row and stun stars clear HUD B%d r%.1f a%d"%[floor_number,radius,angle_index])
				var anchor=Vector2(763,frame.anchor)
				var transform=Transform2D(Vector2(frame.zoom,0),Vector2(0,frame.zoom),anchor*(1.0-frame.zoom))
				var point=Dungeon.iso(p.pos)-frame.position+anchor
				var mouse=transform*point
				var aim=Dungeon.from_iso(transform.affine_inverse()*mouse-anchor+frame.position)
				check(aim.distance_to(p.pos)<.001,"mouse aiming remains in model coordinates")
				var ground=Rect2(transform*Vector2(-800,-450),Vector2(3200,1800)*frame.zoom)
				check(ground.encloses(Rect2(0,0,1600,900)),"ground fills viewport while zoomed")
				check(before==JSON.stringify(boss),"camera never changes combat")
		p.pos=boss.pos+Vector2(15,15)
		var normal=Camera.framing(p,[boss])
		check(not normal.boss and normal.zoom==1.0 and normal.position==Dungeon.iso(p.pos),"normal exploration camera restored")
	print("BATTLE_CAMERA_V04_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
