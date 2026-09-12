extends SceneTree
const Dungeon=preload("res://scripts/dungeon.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func reachable(links:Array,start:int,end:int)->bool:
	var queue=[start];var visited={start:true}
	for node in queue:
		if node==end:return true
		for link in links:
			if link[0]==node and not visited.has(link[1]):visited[link[1]]=true;queue.append(link[1])
	return false
func _initialize():
	for seed in [77,884,2026]:
		for floor_number in range(1,101):
			if floor_number%10==0:continue
			var map=Dungeon.new(seed+floor_number*7919,"cave",floor_number)
			for pair in [[0,1],[1,4],[4,7],[7,8]]:check(map.connections.has(pair),"forward spine independent of optional rewards")
			for wing in [2,3,5,6]:
				check(reachable(map.connections,0,wing) and reachable(map.connections,wing,8),"every optional room rejoins forward without retracing an edge")
				var rewarded=map.exploration_sites.any(func(site):return site.room==wing)
				check(rewarded or map.encounters.any(func(enemy):return enemy.room==wing and enemy.role=="elite"),"optional wing has supplies, material, shrine or elite reward")
			check(map.exploration_sites.filter(func(site):return site.kind=="rest")[0].room==4,"recovery on forward route")
			check(map.exploration_cues.size()==4,"each wing has local environmental cue")
			for cue in map.exploration_cues:
				check(map.walkable(cue.pos) and cue.pos.distance_to(map.rooms[cue.room])>4.,"cue appears before entering its destination")
			check(not reachable(map.connections,8,0),"graph does not force full ring around entrance")
	print("DUNGEON_EXPLORATION_ROUTES checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
