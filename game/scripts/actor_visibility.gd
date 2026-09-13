extends RefCounted
## Only actors drawn in front of the local player's body become translucent.
const COVER_ALPHA=.42
const TRANSITION_SPEED=5.
var player_body=Rect2()
var targets:Dictionary={}
var alphas:Dictionary={}
func reset():
	player_body=Rect2();targets.clear();alphas.clear()
func begin_frame():
	player_body=Rect2();targets.clear()
func player(bounds:Rect2):
	# Ignore hair/weapon corners; keep torso and feet readable in a crowd.
	player_body=Rect2(bounds.position+bounds.size*Vector2(.2,.1),bounds.size*Vector2(.6,.88))
func opacity(id:int,bounds:Rect2)->float:
	var covered=player_body.has_area() and bounds.intersection(player_body).get_area()>player_body.get_area()*.12
	targets[id]=COVER_ALPHA if covered else 1.
	if not alphas.has(id):alphas[id]=targets[id]
	return alphas[id]
func tick(delta:float):
	for id in alphas.keys():
		if not targets.has(id):alphas.erase(id)
		else:alphas[id]=move_toward(alphas[id],targets[id],maxf(0.,delta)*TRANSITION_SPEED)
