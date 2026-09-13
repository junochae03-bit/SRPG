extends SceneTree
const Motion=preload("res://scripts/skill_motion_art_v06.gd")
const Gat=preload("res://scripts/gat_art.gd")
var checks=0
var failures=[]
class Gallery extends Node2D:
	var samples=[]
	func _draw():
		for sample in samples:
			var at:Vector2=sample.at
			var f=sample.frame;var scale=112./float(f.height)
			draw_line(at+Vector2(-82,0),at+Vector2(82,0),Color("6b8679"))
			draw_texture_rect(f.texture,Rect2(at-f.foot*scale,f.texture.get_size()*scale),false)
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():run.call_deferred()
func run():
	root.borderless=true;root.size=Vector2i(1600,1000)
	RenderingServer.set_default_clear_color(Color("253337"))
	var gallery=Gallery.new();gallery.material=Gat.material();root.add_child(gallery)
	var labels=Control.new();root.add_child(labels)
	var classes=Motion.catalog().sprites.keys()
	for page in range(4):
		gallery.samples.clear()
		for child in labels.get_children():child.queue_free()
		for local in range(6):
			var index=page*6+local
			if index>=classes.size():break
			var cls=classes[index]
			var p={"class_id":cls,"avatar":"auto","costume":"none","aim":Vector2.RIGHT,"motion":"cleave","motion_time":0.,"motion_duration":1.}
			var label=Label.new();label.text=cls;label.position=Vector2(12,35+local*140);labels.add_child(label)
			gallery.samples.append({"at":Vector2(250,155+local*140),"frame":Gat.frame(p,0)})
			for phase in range(4):
				p.motion_time=1. if phase%2==0 else .3
				p.skill_motion={"class_id":cls,"skill_id":"review","row":0,"windup":phase<2,"duration":1.,"motion":"cleave"}
				p.job_state={"casting":{"node":{"id":"review"},"time":p.motion_time}} if phase<2 else {"casting":{}}
				var f=Gat.frame(p,0)
				check(f.get("skill_phase",-1)==phase,"gallery uses integrated reader "+cls)
				gallery.samples.append({"at":Vector2(510+phase*260,155+local*140),"frame":f})
		gallery.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://../artifacts/skill-motions-v06-page-%d.png"%page)==OK,"saved real GPU gallery")
	gallery.queue_free();labels.queue_free();await process_frame
	print("SKILL_MOTIONS_VISUAL_V06_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
