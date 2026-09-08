extends SceneTree
const Dungeon=preload("res://scripts/dungeon.gd")
const Forest=preload("res://scripts/forest_environment.gd")
func _initialize():run.call_deferred()
func run():
	var host=Node2D.new();root.add_child(host)
	var forest=Forest.new(host);var map=Dungeon.new(20261045);forest.rebuild(map)
	var previous=[];var changes=0;var changing_pairs=0
	var stable_previous=[];var fixed_changes=0
	for step in range(200):
		var actors=[]
		for i in range(forest.props.size()):actors.append({"type":"scenery","data":forest.props[i],"index":i})
		actors.append({"type":"hero","data":{"pos":map.spawn+Vector2(float(step)*0.04,0)},"index":-1})
		actors.sort_custom(func(a,b):return a.data.pos.x+a.data.pos.y<b.data.pos.x+b.data.pos.y)
		var order=[]
		for actor in actors:
			if actor.index>=0:order.append(actor.index)
		if not previous.is_empty() and previous!=order:
			changes+=1
			for i in range(order.size()):
				if order[i]!=previous[i]:changing_pairs+=1
		previous=order
		actors.sort_custom(Forest.actor_before)
		var stable=[]
		for actor in actors:
			if actor.index>=0:stable.append(actor.index)
		if not stable_previous.is_empty() and stable_previous!=stable:fixed_changes+=1
		stable_previous=stable
	print("FOREST_BASELINE static_order_changes=",changes," changed_positions=",changing_pairs," props=",forest.props.size())
	assert(changes>0,"baseline must reproduce reported ordering defect")
	assert(fixed_changes==0,"static foliage must never reorder while player moves")
	var alpha=1.0
	for i in range(60):
		var next=Forest.approach_alpha(alpha,0.28,1.0/60.0)
		assert(absf(next-alpha)<0.10,"fade must not pop")
		alpha=next
	assert(alpha<0.281)
	print("FOREST_STABILITY_PASS fixed_changes=",fixed_changes," smooth_fade=PASS")
	host.queue_free();await process_frame;quit()
