extends SceneTree
const DB=preload("res://scripts/game_database.gd")
const Content=preload("res://scripts/content.gd")
const Build=preload("res://scripts/skill_build.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	DB.reset_cache();var started=Time.get_ticks_usec();var prepared=DB.snapshot();var prepared_ms=(Time.get_ticks_usec()-started)/1000.
	check(DB.cache_origin=="prepared","runtime actually loads prepared data")
	check(Content.CLASSES.size()==20,"cold prepared snapshot initializes all live jobs")
	for node in prepared.constellations:
		check(not Build.definition(node.id).is_empty(),"cold cache keeps live build definition "+node.id)
	var prepared_json=JSON.stringify(prepared)
	DB.reset_cache();started=Time.get_ticks_usec();var live=DB.snapshot(false,false);var live_ms=(Time.get_ticks_usec()-started)/1000.
	check(DB.cache_origin=="live","management bypass builds from source")
	check(JSON.stringify(live)==prepared_json,"all prepared rows and runtime Variant types match live catalog")
	var path=ProjectSettings.globalize_path("res://../runtime/codex-cache-broken.bin")
	for bytes in [PackedByteArray(),"bad format".to_utf8_buffer(),DB.prepared_bytes(live).slice(0,128)]:
		var file=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
		check(DB.read_prepared(path).is_empty(),"damaged cache rejected before decompression")
	check(DB.read_prepared(path+".missing").is_empty(),"missing cache falls back")
	DB.reset_cache();check(DB.snapshot().equipment.size()==2500 and DB.cache_origin=="prepared","reset restores prepared fast path")
	print("CODEX_CACHE_V053 checks=%d failures=%d prepared_ms=%.3f live_ms=%.3f"%[checks,failures.size(),prepared_ms,live_ms])
	quit(0 if failures.is_empty() else 1)
