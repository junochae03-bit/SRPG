extends RefCounted
static var data={}
static var cache={}
static func initialize():
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/jobs/catalog.json"))
static func has_sprite(p:Dictionary)->bool:
	initialize();return p.get("costume","none")=="none" and p.get("avatar","auto")=="auto" and data.sprites.has(p.get("class_id",""))
static func texture(group:String,key:String,index:int)->AtlasTexture:
	initialize();var id=group+key+str(index)
	if not cache.has(id):
		var entry=data[group][key];var f=entry.frames[index];var atlas=AtlasTexture.new();atlas.atlas=load(entry.sheet);atlas.region=Rect2(f.rect[0],f.rect[1],f.rect[2],f.rect[3]);atlas.filter_clip=true;cache[id]=atlas
	return cache[id]
static func frame(p:Dictionary,time:float)->Dictionary:
	initialize();var key=p.class_id;var index=preload("res://scripts/combat_sprite_art.gd").index_for(p,time)
	if p.get("charge_time",-1)>=0 and key=="breaker":index=5
	var entry=data.sprites[key];var f=entry.frames[index]
	return {"texture":texture("sprites",key,index),"height":entry.body_height,"foot":Vector2(f.foot[0],f.foot[1]),"index":index,"animated":true}
static func render(game,e:Dictionary)->bool:
	initialize();var parts=str(e.get("fx","")).split(":")
	if parts.size()!=2 or not data.effects.has(parts[0]):return false
	var entry=data.effects[parts[0]];var row=clampi(int(parts[1]),0,entry.rows-1)
	var progress=clampf(1-e.life/e.max_life,0,1);var tex=texture("effects",parts[0],row*4+mini(3,int(progress*4)))
	var size=Vector2.ONE*clampf(e.get("radius",1.5)*70,60,220)
	game.draw_texture_rect(tex,Rect2(game.world_point(e.pos)-size*.5-Vector2(0,25),size),false)
	return true

static func pets(game,p:Dictionary,time:float):
	initialize()
	for pet in p.get("job_state",{}).get("pets",[]):
		var row=0 if p.class_id=="hunter" else clampi(int(pet.kind)+1,1,4)
		var key="hunter_wolf" if row==0 else "companions"
		var index=row*4+int(time*7)%4
		if row==0:index=3 if pet.get("cd",0.)>.5 else 1+int(time*7)%2 if pet.get("moving",false) else 0
		var f=data.effects[key].frames[index];var tex=texture("effects",key,index)
		var scale=(112. if row==0 else 224.)/float(f.body_height)
		game.draw_set_transform(game.world_point(pet.pos),0,Vector2(pet.get("facing",1.),1))
		game.draw_texture_rect(tex,Rect2(-Vector2(f.foot[0],f.foot[1])*scale,tex.get_size()*scale),false)
		game.draw_set_transform(Vector2.ZERO)

static func portrait(p:Dictionary)->AtlasTexture:
	initialize();var key=p.class_id;var id="portrait"+key
	if not cache.has(id):
		var entry=data.sprites[key];var f=entry.frames[4];var r=f.rect;var h=entry.body_height
		var tex=AtlasTexture.new();tex.atlas=load(entry.sheet);tex.region=Rect2(r[0]+clampf(f.foot[0]-h*.34,0,r[2]-h*.68),r[1]+maxf(0,f.foot[1]-h),h*.68,h*.68);tex.filter_clip=true;cache[id]=tex
	return cache[id]
