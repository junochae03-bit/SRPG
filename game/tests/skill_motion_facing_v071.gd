extends SceneTree
const Art=preload("res://scripts/skill_motion_art_v06.gd")
const Gat=preload("res://scripts/gat_art.gd")
const Presentation=preload("res://scripts/character_presentation.gd")
var checks=0
var failures=[]

func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)

func _initialize():run.call_deferred()

func run():
	# The source dagger tip is left of the foot in pose 2, right in pose 10.
	# Test those inspected directions after the actual GatArt reader and locked aim.
	for cls in ["rogue","thief"]:
		for side in [-1.,1.]:
			for index in range(16):
				var phase=index%4
				var remaining=.5 if phase%2==0 else .1
				var aim=Vector2(side,-side).normalized()
				var p={"class_id":cls,"avatar":"auto","costume":"none","aim":-aim,
					"motion":"cleave","motion_time":remaining,"motion_duration":.5,
					"motion_aim":aim,"motion_aim_motion":"cleave","motion_aim_duration":.5,
					"skill_motion":{"class_id":cls,"skill_id":"facing_fixture","row":index/4,
						"windup":phase<2,"duration":.5,"motion":"cleave"},
					"job_state":{"casting":{"node":{"id":"facing_fixture"},"time":remaining}}}
				var frame=Gat.frame(p,0.)
				var expected=-1. if index<4 else 1.
				check(frame.get("presentation_id","")=="skill_motion_v06:thief" and frame.index==index,"alias and selected phase "+cls+str(index))
				check(frame.source_facing==expected,"only left-facing first row corrected "+cls+str(index))
				var foot=Art.foot_for("thief",index)
				check(frame.foot==Vector2(foot[0],foot[1]) and frame.height==Art.body_height("thief"),"foot and body height preserved")
				check(Presentation.facing(p,frame.source_facing)==side*expected,"locked attack aim controls mirror")
				if index in [2,10]:
					var source_tip_direction=-1. if index==2 else 1.
					check(source_tip_direction*Presentation.facing(p,frame.source_facing)==side,"dagger release points toward attack "+cls+str(index))
	for id in Art.catalog().sprites:
		if id=="thief":continue
		for index in range(16):
			check(Art.source_facing_for(id,index)==1.,"other source directions unchanged "+id+str(index))
	var reaper_foot=Art.foot_for("reaper",2)
	check(Vector2(reaper_foot[0],reaper_foot[1]).is_equal_approx(Vector2(103.5,173)),"existing reaper boot override retained")
	print("SKILL_MOTION_FACING_V071 checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
