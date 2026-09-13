extends SceneTree
const Visibility=preload("res://scripts/actor_visibility.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():
	var view=Visibility.new();var body=Rect2(100,100,100,140)
	view.begin_frame();check(view.opacity(1,body)==1.,"actors behind player remain opaque")
	view.player(body);check(view.opacity(2,body)==Visibility.COVER_ALPHA,"new foreground cover reveals player immediately")
	check(view.opacity(3,Rect2(500,500,100,140))==1.,"unrelated enemies stay opaque")
	view.begin_frame();view.player(body);view.opacity(2,Rect2(500,500,100,140));view.tick(.05)
	check(view.alphas[2]>Visibility.COVER_ALPHA and view.alphas[2]<1.,"opacity recovers smoothly")
	view.tick(.2);check(view.alphas[2]==1.,"clear body recovers full opacity")
	view.begin_frame();view.player(body);view.opacity(2,body);view.tick(.05)
	check(view.alphas[2]>Visibility.COVER_ALPHA and view.alphas[2]<1.,"existing enemy fades smoothly on overlap")
	view.tick(.2);check(view.alphas[2]==Visibility.COVER_ALPHA,"body stays readable during sustained overlap")
	view.begin_frame();view.tick(.1);check(view.alphas.is_empty(),"despawned and hidden actors release opacity cache")
	view.reset();check(view.player_body==Rect2() and view.targets.is_empty(),"portal resets presentation state")
	print("ACTOR_VISIBILITY checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
