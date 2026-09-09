extends SceneTree
const A=preload("res://scripts/abyss_catalog.gd")
const Benchmark=preload("res://tests/job_benchmark.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	preload("res://scripts/content.gd").initialize_jobs()
	var report={"scenario":"30 second real rotation; stationary single target; 15 jobs at levels 30/60/100, allocated stats and level appropriate unique +3 gear. No incoming AI; TTK is an estimate and does not include travel, evasion, boss armor or player execution.","floors":[],"jobs":[]}
	for f in range(1,101):
		var c=A.config(f);var basic=A.enemy_stats(c.mobs[0],f);var elite=A.enemy_stats(c.elite,f);var boss=A.enemy_stats(c.boss,f,true)
		check(elite.health>basic.health*2 and boss.health>elite.health*3,"hierarchy floor "+str(f))
		check(basic.xp>0 and boss.xp>basic.xp*10,"reward scaling")
		report.floors.append({"floor":f,"level":c.level,"biome":c.name,"normal_hp":basic.health,"normal_damage":basic.damage,"elite_hp":elite.health,"boss_hp":boss.health if c.raid else 0,"boss_damage":boss.damage if c.raid else 0,"boss_name":c.title if c.raid else ""})
	for level in [30,60,100]:
		for job in Benchmark.LOADOUTS:
			var sample=Benchmark.measure(job,1,123,level,true);var c=A.config(level);var boss=A.enemy_stats(c.boss,level,true)
			var dps=sample.damage/30.;var ttk=boss.health/maxf(dps,.1);var hits=sample.max_hp/(boss.damage*(1.-sample.mitigation))
			check(sample.damage>0 and sample.casts>0,"job can fight at tier "+job+str(level))
			check(ttk>=35 and ttk<600,"raid requires sustained combat but remains attainable "+job+str(level))
			check(hits>2 and hits<20,"unavoided boss blows dangerous "+job+str(level))
			report.jobs.append({"level":level,"job":job,"dps":snappedf(dps,.1),"estimated_boss_seconds":snappedf(ttk,.1),"unavoided_boss_hits_to_lose_hp":snappedf(hits,.1),"player_hp":sample.max_hp,"defense":sample.defense,"attack":sample.attack})
	FileAccess.open("res://../artifacts/floor-balance-v02.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("FLOOR_BALANCE_V02_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
