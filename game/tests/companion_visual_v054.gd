extends SceneTree
class Canvas extends Node2D:
	var phase=0
	func world_point(point:Vector2)->Vector2:return point
	func _draw():
		draw_rect(Rect2(0,0,1920,1080),Color("c0d3bd"))
		var art=preload("res://scripts/job_art.gd")
		var actor=art.frame({"class_id":"summoner"},0.)
		var scale=112./actor.height
		draw_texture_rect(actor.texture,Rect2(Vector2(110,470)-actor.foot*scale,actor.texture.get_size()*scale),false)
		for i in range(5):
			var point=Vector2(290+i*265,470)
			art.pets(self,{"class_id":"hunter" if i==0 else "summoner","job_state":{"pets":[{"kind":i-1,"pos":point,"moving":phase in [1,2],"cd":.8 if phase==3 else 0.,"facing":-1. if phase==2 else 1.}]}},phase/7.)
			draw_line(point-Vector2(100,0),point+Vector2(100,0),Color("41634f"),2.)
func _initialize():run.call_deferred()
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	var canvas=Canvas.new();canvas.material=preload("res://scripts/gat_art.gd").material();root.add_child(canvas)
	var failures=0
	for phase in range(4):
		canvas.phase=phase;canvas.queue_redraw()
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var name="companions-v054"+("" if phase==0 else "-"+str(phase))+".png"
		var result=root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/"+name))
		if result!=OK:failures+=1
	print("COMPANION_VISUAL_V054 checks=4 failures=",failures);quit(0 if failures==0 else 1)
