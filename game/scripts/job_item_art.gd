extends RefCounted
const JOBS=["tank","swordsman","runesword","summoner","elementalist","healer","sniper","hunter","explorer","thief","reaper","gambler","infighter","breaker","martialist","interact"]
static var cache={}
static func texture(job:String)->AtlasTexture:
	if not cache.has(job):
		var index=JOBS.find(job);var atlas=load("res://assets/icons/job-weapons-v02.png");var cell=atlas.get_width()/4.
		var tex=AtlasTexture.new();tex.atlas=atlas;tex.region=Rect2(index%4*cell,int(index/4)*cell,cell,cell);tex.filter_clip=true;cache[job]=tex
	return cache[job]
