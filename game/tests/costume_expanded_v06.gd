extends SceneTree
const Expanded=preload("res://scripts/costume_expanded_v06.gd")
const Legacy=preload("res://scripts/costume_art_v04.gd")
var checks=0
var failures=[]
var board:Node2D
var page=0
var ids=[]
var hurt_review=false
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func run():
	hurt_review="--hurt-review" in OS.get_cmdline_user_args()
	ids=Expanded.catalog().keys();ids.sort()
	check(ids.size()==33,"existing 33 appearance IDs")
	for id in ids:
		var entry=Expanded.catalog()[id]
		check(Legacy.recognizes(id),"unchanged identity "+id)
		var p={"costume":id,"avatar":"auto","class_id":"mage"}
		for state in [{"dir":Vector2.RIGHT},{"motion":"cast","motion_duration":.5,"motion_time":.2},{"motion":"cast_high","motion_duration":.5,"motion_time":.2},{"dodge_time":.2},{"hurt_time":.2},{"down_time":.2},{"charge_time":.5}]:
			var candidate=p.duplicate();candidate.merge(state,true)
			var expected=entry.role=="player_costume" and entry.sequences.has(Expanded.action_for(candidate))
			check(not Expanded.frame(candidate,0).is_empty() if expected else Expanded.frame(candidate,0).is_empty(),"approved action or V04 fallback "+id+str(state))
		for pose in entry.frames.keys():
			var f=Expanded._frame_at(id,int(pose))
			check(not f.is_empty(),"review frame available "+id+str(pose))
			if f.is_empty():continue
			check(f.foot.x>=0 and f.foot.y>0 and f.foot.x<=f.texture.get_width() and f.foot.y<=f.texture.get_height(),"support within frame "+id)
			check(f.texture==Expanded._frame_at(id,int(pose)).texture,"frame cache "+id)
		var public_frame=Expanded.frame(p,0)
		check(public_frame.is_empty() if entry.role=="town_npc" or not entry.sequences.has("idle") else not public_frame.is_empty(),"approved-only reader "+id)
		var referenced=[]
		for action in entry.sequences:
			check(entry.sequences[action].approved,"runtime approved-only sequence "+id+action)
			for pose in entry.sequences[action].poses:
				check(entry.frames.has(str(int(pose))),"runtime sequence exists "+id+str(pose))
				referenced.append(str(int(pose)))
		for pose in entry.frames:check(pose in referenced,"no unused candidate in runtime "+id+pose)
		if not public_frame.is_empty():
			check(Expanded.frame(p,4.8).pose_id==entry.idle_playback[-1],"explicit blink/neutral playback "+id)
			check(Expanded.frame(p,5.).pose_id==entry.idle_playback[0],"blink returns to rest "+id)
			check(Expanded.frame(p,NAN).pose_id==entry.idle_playback[0],"nonfinite idle time "+id)
			var hurt=p.duplicate();hurt.hurt_time=.15
			check(Expanded.frame(hurt,999.).pose_id==entry.sequences.hurt.poses[0],"hurt follows state not wall clock "+id)
			check(Expanded.frame(hurt,999.).index==14,"legacy hurt index contract "+id)
		check(p=={"costume":id,"avatar":"auto","class_id":"mage"},"reader never changes ownership/identity "+id)
	check(Expanded.frame({"costume":"unknown"},0).is_empty(),"unknown fallback")
	if "--review" in OS.get_cmdline_user_args() or hurt_review:
		# Inspection candidates stay outside res:// assets and production loading.
		var review_path="res://../docs/qa/costume-expanded-v06-candidates.json"
		check(FileAccess.file_exists(review_path),"run builder --review first")
		if not FileAccess.file_exists(review_path):quit(1);return
		Expanded.reset_cache(true)
		Expanded._data=JSON.parse_string(FileAccess.get_file_as_string(review_path)).entries
		Expanded._loaded=true
		root.size=Vector2i(1800,1200);root.content_scale_size=root.size
		board=Node2D.new();board.material=preload("res://scripts/gat_art.gd").material();board.draw.connect(draw_board);root.add_child(board)
		var folder=ProjectSettings.globalize_path("res://../runtime/costume-expanded-v06")
		DirAccess.make_dir_recursive_absolute(folder)
		for i in range(ceili(ids.size()/6.)):
			page=i;board.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
			var prefix="hurt" if hurt_review else "idle"
			check(root.get_texture().get_image().save_png(folder+"/"+prefix+"-page-%d.png"%page)==OK,"GPU review page "+str(page))
	print("COSTUME_EXPANDED_V06 checks=",checks," failures=",failures.size()," costumes=",ids.size())
	quit(0 if failures.is_empty() else 1)
func draw_board():
	board.draw_rect(Rect2(0,0,1800,1200),Color("29363d"))
	for slot in range(6):
		var n=page*6+slot
		if n>=ids.size():break
		var id=ids[n];var entry=Expanded.catalog()[id]
		var center=Vector2((slot%2)*900+450,int(slot/2)*400+310)
		board.draw_line(center-Vector2(440,0),center+Vector2(440,0),Color("719095"))
		var old=Legacy._frame_at(id,15)
		for j in range(5):
			var candidates=entry.sequences.idle.candidate_poses
			var pose=int(candidates[mini(j-1,candidates.size()-1)])
			if hurt_review:
				pose=int(entry.sequences.hurt.poses[0]) if j>=3 and not entry.sequences.hurt.poses.is_empty() else int(entry.idle_playback[-1] if j==2 else entry.idle_playback[0])
			var f=old if j==0 else Expanded._frame_at(id,pose)
			if f.is_empty():continue
			var factor=140./float(f.height);var at=center+Vector2((j-2)*170,0)
			var flip=hurt_review and j==4
			board.draw_set_transform(at,0,Vector2(-1 if flip else 1,1))
			board.draw_texture_rect(f.texture,Rect2(-f.foot*factor,f.texture.get_size()*factor),false)
			board.draw_set_transform(Vector2.ZERO)
			board.draw_circle(at,2,Color("ffdd22"))
		board.draw_string(ThemeDB.fallback_font,center+Vector2(-420,30),id,HORIZONTAL_ALIGNMENT_LEFT,850,18)
		board.draw_string(ThemeDB.fallback_font,center+Vector2(-420,53),("V04 | rest | blink | hurt R | hurt L " +str(entry.sequences.hurt.poses)) if hurt_review else "V04   |   V06 poses "+str(entry.sequences.idle.poses),HORIZONTAL_ALIGNMENT_LEFT,850,16)
