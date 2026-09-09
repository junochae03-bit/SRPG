extends RefCounted
# The mouse lives in the same unzoomed canvas coordinates as draw_actor.
# Register the exact render transform; never infer the head's world position
# from its screen Y coordinate, and never read/decompress texture pixels here.
static func register(frames:Dictionary,enemy:Dictionary,local_rect:Rect2,transform:Transform2D):
	frames[int(enemy.id)]={"rect":local_rect,"transform":transform,"pos":enemy.pos,"depth":frames.size()}

static func target_at(mouse_canvas:Vector2,enemies:Dictionary,frames:Dictionary,origin:Vector2,map)->Dictionary:
	var best={};var best_depth=-1
	for id in frames:
		var enemy:Dictionary=enemies.get(id,{})
		if enemy.is_empty() or enemy.get("hp",0)<=0:continue
		var frame:Dictionary=frames[id]
		# A stale record after a portal/teleport cannot redirect the next click.
		if frame.pos.distance_to(enemy.pos)>2.:continue
		var transform:Transform2D=frame.transform
		if absf(transform.determinant())<.0001:continue
		var local:Vector2=transform.affine_inverse()*mouse_canvas
		var rect:Rect2=frame.rect
		# Full body, including feet. Trim only the outer transparent corners;
		# overlapping actors choose the last rendered (frontmost) body.
		if not rect.has_point(local):continue
		var uv=(local-rect.position)/rect.size
		if uv.y<.14 and (uv.x<.12 or uv.x>.88):continue
		if not map.line_clear(origin,enemy.pos):continue
		if int(frame.depth)>best_depth:best=enemy;best_depth=int(frame.depth)
	return best

static func direction(mouse_canvas:Vector2,ground_target:Vector2,origin:Vector2,enemies:Dictionary,frames:Dictionary,map)->Vector2:
	var target=target_at(mouse_canvas,enemies,frames,origin,map)
	return origin.direction_to(target.pos if not target.is_empty() else ground_target)
