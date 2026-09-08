extends RefCounted
const BODY_HEIGHT=112.0
const AVATARS={"gat_role_tank_2":"warrior","gat_role_single_1":"ranger","gat_role_aoe_1":"mage"}
static var catalog:Dictionary={}
static var cache:Dictionary={}
static func initialize():
	if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motions/catalog.json"))
static func index_for(p:Dictionary,time:float)->int:
	if p.get("hurt_time",0)>0:return 14
	if p.get("dodge_time",0)>0:return 12 if p.dodge_time>.13 else 13
	if p.get("charge_time",-1)>=0:return 8 if p.charge_time<.45 else 9
	if p.get("motion_time",0)>0:
		var t=clampf(1-p.motion_time/maxf(.01,p.motion_duration),0,1)
		var step=mini(3,int(t*4))
		match p.get("motion",""):
			"slam","shoot_high","cast_high":return 8+step
			"dash","leap","blink":return [12,13,13,15][step]
			"spin":return [5,6,7,6][step]
			_:return 4+step
	if p.get("dir",Vector2.ZERO).length()>.1:return int(time*(12 if p.get("sprint",false) else 8))%4
	return 15 if fposmod(time,5)>4.7 else 4
static func frame(key:String,p:Dictionary,time:float)->Dictionary:
	initialize();var kind=AVATARS[key];var entry=catalog[kind];var index=index_for(p,time);var data=entry.frames[index]
	var id=kind+str(index)
	if not cache.has(id):
		var r=data.rect;var tex=AtlasTexture.new();tex.atlas=load(entry.sheet);tex.region=Rect2(r[0],r[1],r[2],r[3]);tex.filter_clip=true;cache[id]=tex
	return {"texture":cache[id],"height":float(entry.height),"foot":Vector2(data.foot[0],data.foot[1]),"index":index,"animated":true}
