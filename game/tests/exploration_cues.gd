extends SceneTree
const Dungeon=preload("res://scripts/dungeon.gd")
const Cues=preload("res://scripts/exploration_cues.gd")
var checks=0
var failures=[]
class Sight:
	var allowed={}
	func sees(pos:Vector2)->bool:return allowed.has(pos)
class View:
	var vision=Sight.new()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():
	var art=preload("res://scripts/exploration_trace_art.gd")
	for key in ["ore","herbs","supplies","magic","blood","tracks"]:
		var texture=art.texture(key)
		check(texture.atlas!=null and texture.region.size.x>0,"actual fragment atlas region "+key)
		check(texture.atlas.get_image().detect_alpha()!=Image.ALPHA_NONE,"ground fragments have actual alpha transparency "+key)
	for depth in range(1,101):
		var map=Dungeon.new(9241+depth*191,"forest" if depth<=10 else "cave",depth)
		if depth%10==0:check(map.exploration_cues.is_empty(),"raid has no optional branch traces");continue
		var cells=map.floor_cells.duplicate();var sites=map.exploration_sites.duplicate(true)
		check(Cues.generate(map)==map.exploration_cues,"deterministic traces across peers")
		check(map.floor_cells==cells and map.exploration_sites==sites,"traces do not widen map or change rewards")
		check(map.exploration_cues.size()==4,"four useful branches")
		for cue in map.exploration_cues:
			var site=sites.filter(func(row):return row.room==cue.room)[0]
			check(cue.trace==Cues.signature(site).trace,"trace corresponds to actual destination")
			check(not cue.has("name") and not cue.has("text"),"no explanatory world caption")
			check(cue.marks.size()>=2 and cue.marks.size()<=Cues.MARKS,"bounded short trace B%d room %d count %d"%[depth,cue.room,cue.marks.size()])
			for i in range(cue.marks.size()):
				var mark=cue.marks[i]
				check(map.walkable(mark.pos),"every visible trace is on floor")
				if i>0:check(map.line_clear(cue.marks[i-1].pos,mark.pos),"trace follows connected visible corridor")
			var view=View.new();view.vision.allowed[cue.marks[-1].pos]=true
			check(Cues.visible_marks(view,cue).size()==1,"each mark obeys sight even when branch start hidden")
			view.vision.allowed.clear();check(Cues.visible_marks(view,cue).is_empty(),"no marks leak through fog")
	check(Cues.signature({"kind":"challenge"}).trace=="tracks","large tracks consistently lead to optional elite challenge")
	check(Cues.signature({"kind":"gather","material":"seed"}).trace=="herbs","seed location teaches plant trace")
	check(Cues.signature({"kind":"gather","material":"ore"}).trace=="ore","ore location teaches mineral trace")
	print("EXPLORATION_CUES checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
