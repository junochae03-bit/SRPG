extends SceneTree
const Art=preload("res://scripts/skill_motion_art_v06.gd")
const Gat=preload("res://scripts/gat_art.gd")
const Iso=preload("res://scripts/dungeon.gd")
var checks=0
var failures=[]

class ActorGallery:
	extends "res://scripts/main.gd"
	var samples=[]
	var drawn=[]
	func _ready():
		# Isolate the production actor renderer from UI, sessions, saves and simulation.
		session={"local_id":1,"connected":false}
		set_process(false);set_physics_process(false);set_process_input(false)
	func _draw():
		drawn.clear()
		for p in samples:
			session.local_id=p.id
			actor_visibility.reset()
			# Inherited production method performs frame selection, pivot, source
			# facing, locked aim, actor transform and texture rendering unchanged.
			draw_actor({"type":"hero","data":p})
			drawn.append(p.id)
			var at=world_point(p.pos)
			draw_line(at+Vector2(-120,25),at+Vector2(120,25),Color("6b8679"))
			var direction=Iso.iso(p.motion_aim).normalized()
			var start=at+Vector2(0,50)
			var end=start+direction*90
			draw_line(start,end,Color("ffcf67"),2.)
			draw_line(end,end-direction*12+Vector2(0,-6),Color("ffcf67"),2.)
			draw_line(end,end-direction*12+Vector2(0,6),Color("ffcf67"),2.)

func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)

func _initialize():run.call_deferred()

func run():
	root.borderless=true;root.size=Vector2i(1600,900)
	root.canvas_transform=Transform2D.IDENTITY
	RenderingServer.set_default_clear_color(Color("253337"))
	var gallery=ActorGallery.new();gallery.material=Gat.material();root.add_child(gallery)
	var labels=Control.new();root.add_child(labels)
	var row=0
	var records=[]
	for cls in ["rogue","thief"]:
		for index in [2,10]:
			for side in [-1.,1.]:
				var at=Vector2(450 if side<0 else 1150,170+row*210)
				var aim=Vector2(side,-side).normalized()
				var p={"id":records.size()+1,"class_id":cls,"avatar":"auto","costume":"none",
					"pos":Iso.from_iso(at-gallery.screen_center()),"aim":aim,"dir":Vector2.ZERO,"hp":100,
					"motion":"cleave","motion_time":.3,"motion_duration":.5,
					"motion_aim":aim,"motion_aim_motion":"cleave","motion_aim_duration":.5,
					"skill_motion":{"class_id":cls,"skill_id":"facing_visual_fixture","row":int(index/4),
						"windup":false,"duration":.5,"motion":"cleave"}}
				var frame=Gat.frame(p,0.)
				check(frame.get("presentation_id","")=="skill_motion_v06:thief" and frame.index==index,"production reader release "+cls+str(index))
				check(frame.source_facing==(-1. if index==2 else 1.),"selected source direction")
				gallery.samples.append(p)
				var label=Label.new()
				label.text="%s / release %d / aim %s"%[cls,index,"LEFT" if side<0 else "RIGHT"]
				label.position=at+Vector2(-165,-153);labels.add_child(label)
				records.append({"class_id":cls,"index":index,"screen_side":side,"source_facing":frame.source_facing})
			row+=1
	gallery.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	check(gallery.drawn.size()==8,"all eight samples traversed inherited main.draw_actor")
	var folder="res://../runtime/skill-motion-facing-v071"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	check(root.get_texture().get_image().save_png(folder+"/release-left-right.png")==OK,"saved actual actor GPU capture")
	var file=FileAccess.open(folder+"/verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":"inherited main.gd draw_actor","samples":records},"\t"));file.close()
	gallery.queue_free();labels.queue_free();await process_frame
	print("SKILL_MOTION_FACING_VISUAL_V071 checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
