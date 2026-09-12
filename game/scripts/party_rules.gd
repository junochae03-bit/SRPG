extends RefCounted
const MAX_PLAYERS=6
const HEALTH_PER_GUEST=.65
const STAGGER_PER_GUEST=.45
const DOWN_SECONDS=20.
const RESCUE_SECONDS=3.
const RESCUE_RADIUS=1.8
const RESCUE_HEALTH=.35
const RESCUE_INVULNERABLE=1.
static func configuration()->Dictionary:
	return {"max_players":MAX_PLAYERS,"health_per_guest":HEALTH_PER_GUEST,"stagger_per_guest":STAGGER_PER_GUEST,"down_seconds":DOWN_SECONDS,"rescue_seconds":RESCUE_SECONDS,"rescue_radius":RESCUE_RADIUS,"rescue_health":RESCUE_HEALTH,"rescue_invulnerable":RESCUE_INVULNERABLE,"authority":"host","matchmaking":false,"join_zone":"town","world_pauses_for_personal_ui":false,"solo_pauses_for_personal_ui":true}
# More participants increase endurance, not unavoidable damage or enemy count.
static func health_factor(count:int)->float:return 1.+HEALTH_PER_GUEST*(clampi(count,1,MAX_PLAYERS)-1)
static func stagger_factor(count:int)->float:return 1.+STAGGER_PER_GUEST*(clampi(count,1,MAX_PLAYERS)-1)
static func rescale(sim):
	var count=clampi(sim.players.size(),1,MAX_PLAYERS)
	for e in sim.enemies.values():
		if e.get("training",false):continue
		if not e.has("solo_health"):e.solo_health=e.max_hp
		var fraction=clampf(float(e.hp)/maxf(1.,e.max_hp),0,1)
		var alive=e.hp>0
		e.max_hp=roundi(e.solo_health*health_factor(count));e.hp=maxi(1,roundi(e.max_hp*fraction)) if alive else 0
		if e.has("stagger"):
			var s=e.stagger;var old=float(e.get("party_stagger_factor",1.));var factor=stagger_factor(count)
			for key in ["max_value","check_max","value","check_value"]:s[key]=float(s[key])/old*factor
			e.party_stagger_factor=factor
