extends SceneTree
const Prepared=preload("res://scripts/prepared_art_v05.gd")
const Costumes=preload("res://scripts/costume_art_v04.gd")
var checks=0
var failures=0
func check(value:bool,label:String):
	checks+=1
	if not value:failures+=1;printerr("FAIL ",label)
func _initialize():run.call_deferred()
func run():
	Prepared.initialize()
	check(Prepared.entries.size()==41,"all 35 costume and 6 equipment source sheets")
	var old_ms=0.;var new_ms=0.
	for identity in Prepared.entries:
		var row=Prepared.entries[identity]
		check(FileAccess.get_sha256(row.source)==row.source_sha256,"unchanged source "+identity)
		check(FileAccess.get_sha256(row.path)==row.sha256,"cache file SHA "+identity)
		var source=Costumes._source_image(row.source)
		var start=Time.get_ticks_usec()
		var original=Costumes._padded_image(Costumes._keyed_image(source,row.key))
		old_ms+=float(Time.get_ticks_usec()-start)/1000.
		start=Time.get_ticks_usec()
		var texture=Prepared.texture(row.source,row.key)
		new_ms+=float(Time.get_ticks_usec()-start)/1000.
		check(texture!=null,"native prepared texture "+identity)
		if texture==null:continue
		var actual=texture.get_image()
		check(actual.get_size()==original.get_size(),"same dimensions and padding "+identity)
		check(actual.get_data()==original.get_data(),"every RGBA byte identical "+identity)
		check(texture.get_meta("prepared_source")==row.source,"original asset identity "+identity)
	print("PREPARED_ART_V05_TIMING legacy_key_ms=",old_ms," prepared_decode_upload_ms=",new_ms)
	print("PREPARED_ART_V05_TESTS checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
