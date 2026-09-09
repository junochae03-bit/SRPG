extends RefCounted
# Geometry policy only: damage, stamina, cast time and hit/stagger budgets stay
# in their existing profiles. These values feed both runtime and skill previews.
const BASE_AREA=["spin","rain","frost","thunder","blink","burst","field","pull","nova_ring"]
const RADIAL=["spin","charge_area","charge_spin","taunt"]
const GROUND_TARGET=["burst","root","slow","pull"]
static func base_radius(mode:String,value:float)->float:
	if mode not in BASE_AREA:return value
	return value*(1.5 if mode=="thunder" else 1.35 if mode=="blink" else 1.4)

static func job_radius(mode:String,job:String,value:float)->float:
	if mode in ["spin","charge_area","charge_spin"]:return maxf(3.2,value*1.5)
	if mode in ["field","burst"]:return maxf(3.5,value*1.4)*(1.1 if job=="elementalist" else 1.)
	if mode in ["trap","trap_bleed","settle_barrage"]:return maxf(2.8,value*1.4)
	if mode=="barrage" and job in ["sniper","hunter"]:return maxf(2.8,value*1.4)
	if mode in ["root","slow","pull","stun","taunt"]:return maxf(2.7,value*1.35)
	if mode=="finisher":return value*1.2
	return value

static func radial(mode:String)->bool:return mode in RADIAL

static func job_shape(mode:String)->String:
	if mode in RADIAL or mode in GROUND_TARGET or mode in ["field","trap","trap_bleed","barrage","combo","settle_barrage"]:return "circle"
	# Direct strikes retain their forward half-circle; shots and chains have
	# their own beam/projectile drawing and must not advertise a ground area.
	if mode in ["strike","mark","execute","heavy","heavy_execute","charge","charge_execute","uppercut","break_guard","finisher","bleed","blind","vulnerable","weaken","break_armor","stun"]:return "arc"
	return ""
