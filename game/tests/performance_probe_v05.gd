extends SceneTree
func _initialize():
	var game=preload("res://tests/performance_main_v05.gd").new()
	root.add_child.call_deferred(game)
