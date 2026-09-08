extends RefCounted
const NODES = {
	"warrior": [
		{
			"id": "blade",
			"name": "검술 수련",
			"effect": "damage",
			"value": 2,
			"description": "공격력 +2 / 랭크",
			"parents": [],
			"column": 0,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "heavy_training",
			"name": "묵직한 일격",
			"effect": "heavy_power",
			"value": 0.15,
			"description": "강공격 피해 +15% / 랭크",
			"parents": [
				"blade",
				"warrior_defense_v05"
			],
			"column": 0,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "blade_wave",
			"name": "초승달 검기",
			"effect": "active",
			"value": 0,
			"description": "F · 관통하는 검기를 발사 · 강화마다 피해 +20%",
			"parents": [
				"heavy_training",
				"warrior_attack_haste_v05"
			],
			"column": 0,
			"tier": 2,
			"action": "skill_f",
			"parent_mode": "any"
		},
		{
			"id": "edge",
			"name": "길어진 검날",
			"effect": "melee_range",
			"value": 0.18,
			"description": "근접 사거리 +0.18 / 랭크",
			"parents": [
				"blade_wave",
				"warrior_skill_haste_v05"
			],
			"column": 0,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "sunburst",
			"name": "빛나는 검기",
			"effect": "skill_power",
			"value": 0.25,
			"description": "모든 직업 기술 피해 +25% / 랭크",
			"parents": [
				"edge",
				"warrior_skill_radius_v05"
			],
			"column": 0,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "vitality",
			"name": "튼튼한 심장",
			"effect": "health",
			"value": 12,
			"description": "최대 체력 +12 / 랭크",
			"parents": [],
			"column": 1,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "guard",
			"name": "단단한 수비",
			"effect": "defense",
			"value": 1,
			"description": "받는 피해 -1 / 랭크",
			"parents": [
				"vitality",
				"blade"
			],
			"column": 1,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "whirlwind",
			"name": "꽃바람 회전",
			"effect": "active",
			"value": 0,
			"description": "V · 세 번 회전하며 주변 공격 · 강화마다 피해 +20%",
			"parents": [
				"guard",
				"heavy_training"
			],
			"column": 1,
			"tier": 2,
			"action": "skill_v",
			"parent_mode": "any"
		},
		{
			"id": "ironheart",
			"name": "강철 심장",
			"effect": "health",
			"value": 15,
			"description": "최대 체력 +15 / 랭크",
			"parents": [
				"whirlwind",
				"blade_wave"
			],
			"column": 1,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "bulwark",
			"name": "불굴의 수비",
			"effect": "defense",
			"value": 2,
			"description": "받는 피해 -2 / 랭크",
			"parents": [
				"ironheart",
				"edge"
			],
			"column": 1,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "resolve",
			"name": "가벼운 발걸음",
			"effect": "dodge_discount",
			"value": 3,
			"description": "회피 기력 소모 -3 / 랭크",
			"parents": [],
			"column": 2,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "swift",
			"name": "힘찬 걸음",
			"effect": "speed",
			"value": 0.1,
			"description": "이동 속도 +0.1 / 랭크",
			"parents": [
				"resolve",
				"vitality"
			],
			"column": 2,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "rush",
			"name": "햇살 돌진",
			"effect": "active",
			"value": 0,
			"description": "C · 돌진 경로의 적을 타격 · 강화마다 피해 +20%",
			"parents": [
				"swift",
				"guard"
			],
			"column": 2,
			"tier": 2,
			"action": "skill_c",
			"parent_mode": "any"
		},
		{
			"id": "secondwind",
			"name": "다시 숨쉬기",
			"effect": "stamina_regen",
			"value": 2,
			"description": "초당 기력 회복 +2 / 랭크",
			"parents": [
				"rush",
				"whirlwind"
			],
			"column": 2,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "radiance",
			"name": "찬란한 궤적",
			"effect": "skill_radius",
			"value": 0.18,
			"description": "범위 기술 반경 +0.18 / 랭크",
			"parents": [
				"secondwind",
				"ironheart"
			],
			"column": 2,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "warrior_fan",
			"name": "유성 검무",
			"effect": "active",
			"value": 0,
			"description": "부채꼴 투사체 · 랭크마다 위력 +20%",
			"mode": "fan",
			"count": 5,
			"power": 1.0,
			"cost": 18,
			"cooldown": 5,
			"fx": "warrior_fan",
			"sound": "heavy",
			"parents": [],
			"column": 3,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "warrior_burst",
			"name": "대지 가르기",
			"effect": "active",
			"value": 0,
			"description": "조준 지점 강타 · 랭크마다 위력 +20%",
			"mode": "burst",
			"count": 1,
			"power": 2.8,
			"cost": 25,
			"cooldown": 9,
			"fx": "warrior_burst",
			"sound": "heavy",
			"parents": [
				"warrior_fan",
				"resolve"
			],
			"column": 3,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "warrior_field",
			"name": "빛의 검진",
			"effect": "active",
			"value": 0,
			"description": "지속 범위 공격과 둔화 · 랭크마다 위력 +20%",
			"mode": "field",
			"count": 4,
			"power": 0.65,
			"cost": 30,
			"cooldown": 12,
			"fx": "warrior_field",
			"sound": "heavy",
			"parents": [
				"warrior_burst",
				"swift"
			],
			"column": 3,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "warrior_chain",
			"name": "연쇄 검격",
			"effect": "active",
			"value": 0,
			"description": "가까운 적 사이 연쇄 타격 · 랭크마다 위력 +20%",
			"mode": "chain",
			"count": 4,
			"power": 1.2,
			"cost": 25,
			"cooldown": 10,
			"fx": "warrior_chain",
			"sound": "heavy",
			"parents": [
				"warrior_field",
				"rush"
			],
			"column": 3,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "warrior_pull",
			"name": "자력의 검",
			"effect": "active",
			"value": 0,
			"description": "적을 끌어당긴 뒤 공격 · 랭크마다 위력 +20%",
			"mode": "pull",
			"count": 1,
			"power": 1.6,
			"cost": 20,
			"cooldown": 8,
			"fx": "warrior_pull",
			"sound": "heavy",
			"parents": [
				"warrior_chain",
				"secondwind"
			],
			"column": 3,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "warrior_heal",
			"name": "회복의 맹세",
			"effect": "active",
			"value": 0,
			"description": "최대 체력 비례 즉시 회복 · 랭크마다 위력 +20%",
			"mode": "heal",
			"count": 1,
			"power": 1.2,
			"cost": 25,
			"cooldown": 14,
			"fx": "warrior_heal",
			"sound": "heavy",
			"parents": [],
			"column": 4,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "warrior_barrier",
			"name": "황금 방벽",
			"effect": "active",
			"value": 0,
			"description": "잠시 받는 피해 감소 · 랭크마다 위력 +20%",
			"mode": "barrier",
			"count": 1,
			"power": 0.8,
			"cost": 28,
			"cooldown": 16,
			"fx": "warrior_barrier",
			"sound": "heavy",
			"parents": [
				"warrior_heal",
				"warrior_fan"
			],
			"column": 4,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "warrior_haste",
			"name": "전장의 함성",
			"effect": "active",
			"value": 0,
			"description": "잠시 공격·이동 가속 · 랭크마다 위력 +20%",
			"mode": "haste",
			"count": 1,
			"power": 0.35,
			"cost": 25,
			"cooldown": 16,
			"fx": "warrior_haste",
			"sound": "heavy",
			"parents": [
				"warrior_barrier",
				"warrior_burst"
			],
			"column": 4,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "warrior_nova_ring",
			"name": "태양의 고리",
			"effect": "active",
			"value": 0,
			"description": "주변 두 번 범위 공격 · 랭크마다 위력 +20%",
			"mode": "nova_ring",
			"count": 2,
			"power": 1.5,
			"cost": 35,
			"cooldown": 14,
			"fx": "warrior_nova_ring",
			"sound": "heavy",
			"parents": [
				"warrior_haste",
				"warrior_field"
			],
			"column": 4,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "warrior_critical_v05",
			"name": "정밀 검끝",
			"effect": "critical",
			"value": 0.02,
			"description": "치명타 확률 +2% / 랭크",
			"parents": [
				"warrior_nova_ring",
				"warrior_chain"
			],
			"column": 4,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "warrior_critical_damage_v05",
			"name": "치명적인 틈",
			"effect": "critical_damage",
			"value": 0.1,
			"description": "치명타 배율 +10% / 랭크",
			"parents": [],
			"column": 5,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "warrior_lifesteal_v05",
			"name": "흡혈 검날",
			"effect": "lifesteal",
			"value": 0.01,
			"description": "명중 피해의 1% 회복 / 랭크",
			"parents": [
				"warrior_critical_damage_v05",
				"warrior_heal"
			],
			"column": 5,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "warrior_execute_v05",
			"name": "처형인의 눈",
			"effect": "execute",
			"value": 0.08,
			"description": "체력 30% 이하 적 피해 +8% / 랭크",
			"parents": [
				"warrior_lifesteal_v05",
				"warrior_barrier"
			],
			"column": 5,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "warrior_thorns_v05",
			"name": "가시 갑옷",
			"effect": "thorns",
			"value": 2,
			"description": "피격 시 근접 적에게 2 반사 / 랭크",
			"parents": [
				"warrior_execute_v05",
				"warrior_haste"
			],
			"column": 5,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "warrior_health_regen_v05",
			"name": "고요한 호흡",
			"effect": "health_regen",
			"value": 0.4,
			"description": "비전투 초당 체력 +0.4 / 랭크",
			"parents": [
				"warrior_thorns_v05",
				"warrior_nova_ring"
			],
			"column": 5,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "warrior_potion_power_v05",
			"name": "응급 약학",
			"effect": "potion_power",
			"value": 8,
			"description": "물약 회복량 +8 / 랭크",
			"parents": [],
			"column": 6,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "warrior_xp_bonus_v05",
			"name": "전투 기록",
			"effect": "xp_bonus",
			"value": 0.03,
			"description": "획득 경험치 +3% / 랭크",
			"parents": [
				"warrior_potion_power_v05",
				"warrior_critical_damage_v05"
			],
			"column": 6,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "warrior_gold_bonus_v05",
			"name": "전리품 감각",
			"effect": "gold_bonus",
			"value": 0.04,
			"description": "획득 금화 +4% / 랭크",
			"parents": [
				"warrior_xp_bonus_v05",
				"warrior_lifesteal_v05"
			],
			"column": 6,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "warrior_dodge_duration_v05",
			"name": "잔영 보법",
			"effect": "dodge_duration",
			"value": 0.02,
			"description": "회피 무적 시간 +0.02초 / 랭크",
			"parents": [
				"warrior_gold_bonus_v05",
				"warrior_execute_v05"
			],
			"column": 6,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "warrior_sprint_discount_v05",
			"name": "지구력 훈련",
			"effect": "sprint_discount",
			"value": 1.5,
			"description": "달리기 초당 기력 소모 -1.5 / 랭크",
			"parents": [
				"warrior_dodge_duration_v05",
				"warrior_thorns_v05"
			],
			"column": 6,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "warrior_heavy_discount_v05",
			"name": "무게의 이해",
			"effect": "heavy_discount",
			"value": 1,
			"description": "강공격 기력 소모 -1 / 랭크",
			"parents": [],
			"column": 7,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "warrior_skill_discount_v05",
			"name": "집중 호흡",
			"effect": "skill_discount",
			"value": 1,
			"description": "직업 기술 기력 소모 -1 / 랭크",
			"parents": [
				"warrior_heavy_discount_v05",
				"warrior_potion_power_v05"
			],
			"column": 7,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "warrior_projectile_speed_v05",
			"name": "검기 가속",
			"effect": "projectile_speed",
			"value": 0.5,
			"description": "투사체 속도 +0.5 / 랭크",
			"parents": [
				"warrior_skill_discount_v05",
				"warrior_xp_bonus_v05"
			],
			"column": 7,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "warrior_slow_duration_v05",
			"name": "냉철한 추격",
			"effect": "slow_duration",
			"value": 0.2,
			"description": "둔화 지속 시간 +0.2초 / 랭크",
			"parents": [
				"warrior_projectile_speed_v05",
				"warrior_gold_bonus_v05"
			],
			"column": 7,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "warrior_stun_duration_v05",
			"name": "충격 전달",
			"effect": "stun_duration",
			"value": 0.1,
			"description": "기절 지속 시간 +0.1초 / 랭크",
			"parents": [
				"warrior_slow_duration_v05",
				"warrior_dodge_duration_v05"
			],
			"column": 7,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "warrior_knockback_v05",
			"name": "밀어붙이기",
			"effect": "knockback",
			"value": 0.08,
			"description": "명중 시 밀어내기 +0.08칸 / 랭크",
			"parents": [],
			"column": 8,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "warrior_elite_damage_v05",
			"name": "거인 사냥꾼",
			"effect": "elite_damage",
			"value": 0.05,
			"description": "보스 피해 +5% / 랭크",
			"parents": [
				"warrior_knockback_v05",
				"warrior_heavy_discount_v05"
			],
			"column": 8,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "warrior_damage_v05",
			"name": "강철 악력",
			"effect": "damage",
			"value": 1,
			"description": "공격력 +1 / 랭크",
			"parents": [
				"warrior_elite_damage_v05",
				"warrior_skill_discount_v05"
			],
			"column": 8,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "warrior_health_v05",
			"name": "불굴의 생명",
			"effect": "health",
			"value": 8,
			"description": "최대 체력 +8 / 랭크",
			"parents": [
				"warrior_damage_v05",
				"warrior_projectile_speed_v05"
			],
			"column": 8,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "warrior_stamina_v05",
			"name": "심호흡",
			"effect": "stamina",
			"value": 5,
			"description": "최대 기력 +5 / 랭크",
			"parents": [
				"warrior_health_v05",
				"warrior_slow_duration_v05"
			],
			"column": 8,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "warrior_defense_v05",
			"name": "갑옷 숙련",
			"effect": "defense",
			"value": 1,
			"description": "받는 피해 -1 / 랭크",
			"parents": [],
			"column": 9,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "warrior_attack_haste_v05",
			"name": "재빠른 손목",
			"effect": "attack_haste",
			"value": 0.015,
			"description": "기본 공격 간격 -0.015초 / 랭크",
			"parents": [
				"warrior_defense_v05",
				"warrior_knockback_v05"
			],
			"column": 9,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "warrior_skill_haste_v05",
			"name": "전술의 순환",
			"effect": "skill_haste",
			"value": 0.15,
			"description": "직업 기술 재사용 -0.15초 / 랭크",
			"parents": [
				"warrior_attack_haste_v05",
				"warrior_elite_damage_v05"
			],
			"column": 9,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "warrior_skill_radius_v05",
			"name": "넓은 보폭",
			"effect": "skill_radius",
			"value": 0.08,
			"description": "기술 범위 +0.08칸 / 랭크",
			"parents": [
				"warrior_skill_haste_v05",
				"warrior_damage_v05"
			],
			"column": 9,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "warrior_skill_power_v05",
			"name": "빛의 완성",
			"effect": "skill_power",
			"value": 0.04,
			"description": "직업 기술 피해 +4% / 랭크",
			"parents": [
				"warrior_skill_radius_v05",
				"warrior_health_v05"
			],
			"column": 9,
			"tier": 4,
			"parent_mode": "any"
		}
	],
	"ranger": [
		{
			"id": "archery",
			"name": "명사수",
			"effect": "damage",
			"value": 2,
			"description": "공격력 +2 / 랭크",
			"parents": [],
			"column": 0,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "focus",
			"name": "먼 시야",
			"effect": "range",
			"value": 0.6,
			"description": "원거리 사거리 +0.6 / 랭크",
			"parents": [
				"archery",
				"ranger_defense_v05"
			],
			"column": 0,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "piercing_shot",
			"name": "한줄기 바람",
			"effect": "active",
			"value": 0,
			"description": "F · 여러 적을 꿰뚫는 화살 · 강화마다 피해 +20%",
			"parents": [
				"focus",
				"ranger_attack_haste_v05"
			],
			"column": 0,
			"tier": 2,
			"action": "skill_f",
			"parent_mode": "any"
		},
		{
			"id": "pierce",
			"name": "관통 화살",
			"effect": "pierce",
			"value": 1,
			"description": "일반 화살 관통 대상 +1 / 랭크",
			"parents": [
				"piercing_shot",
				"ranger_skill_haste_v05"
			],
			"column": 0,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "volley",
			"name": "바람의 노래",
			"effect": "skill_power",
			"value": 0.25,
			"description": "모든 직업 기술 피해 +25% / 랭크",
			"parents": [
				"pierce",
				"ranger_skill_radius_v05"
			],
			"column": 0,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "endurance",
			"name": "긴 호흡",
			"effect": "stamina",
			"value": 10,
			"description": "최대 기력 +10 / 랭크",
			"parents": [],
			"column": 1,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "fleet",
			"name": "숲의 걸음",
			"effect": "speed",
			"value": 0.12,
			"description": "이동 속도 +0.12 / 랭크",
			"parents": [
				"endurance",
				"archery"
			],
			"column": 1,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "arrow_rain",
			"name": "잎새 소나기",
			"effect": "active",
			"value": 0,
			"description": "V · 조준 지점에 세 번 화살비 · 강화마다 피해 +20%",
			"parents": [
				"fleet",
				"focus"
			],
			"column": 1,
			"tier": 2,
			"action": "skill_v",
			"parent_mode": "any"
		},
		{
			"id": "quickdraw",
			"name": "빠른 시위",
			"effect": "attack_haste",
			"value": 0.04,
			"description": "기본 공격 간격 -0.04초 / 랭크",
			"parents": [
				"arrow_rain",
				"piercing_shot"
			],
			"column": 1,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "eagle",
			"name": "매의 비행",
			"effect": "projectile_speed",
			"value": 1.5,
			"description": "화살과 탄환 속도 +1.5 / 랭크",
			"parents": [
				"quickdraw",
				"pierce"
			],
			"column": 1,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "hunter",
			"name": "숲의 생명",
			"effect": "health",
			"value": 10,
			"description": "최대 체력 +10 / 랭크",
			"parents": [],
			"column": 2,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "rolling",
			"name": "바람 같은 몸",
			"effect": "dodge_discount",
			"value": 2,
			"description": "회피 기력 소모 -2 / 랭크",
			"parents": [
				"hunter",
				"endurance"
			],
			"column": 2,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "retreat_shot",
			"name": "도약 사격",
			"effect": "active",
			"value": 0,
			"description": "C · 뒤로 도약하며 세 발 사격 · 강화마다 피해 +20%",
			"parents": [
				"rolling",
				"fleet"
			],
			"column": 2,
			"tier": 2,
			"action": "skill_c",
			"parent_mode": "any"
		},
		{
			"id": "breath",
			"name": "고른 숨결",
			"effect": "stamina_regen",
			"value": 2,
			"description": "초당 기력 회복 +2 / 랭크",
			"parents": [
				"retreat_shot",
				"arrow_rain"
			],
			"column": 2,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "precision",
			"name": "정밀 조준",
			"effect": "heavy_power",
			"value": 0.12,
			"description": "강공격 피해 +12% / 랭크",
			"parents": [
				"breath",
				"quickdraw"
			],
			"column": 2,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "ranger_fan",
			"name": "깃털 다발",
			"effect": "active",
			"value": 0,
			"description": "부채꼴 투사체 · 랭크마다 위력 +20%",
			"mode": "fan",
			"count": 5,
			"power": 1.0,
			"cost": 18,
			"cooldown": 5,
			"fx": "ranger_fan",
			"sound": "bow",
			"parents": [],
			"column": 3,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "ranger_burst",
			"name": "폭발 화살",
			"effect": "active",
			"value": 0,
			"description": "조준 지점 강타 · 랭크마다 위력 +20%",
			"mode": "burst",
			"count": 1,
			"power": 2.8,
			"cost": 25,
			"cooldown": 9,
			"fx": "ranger_burst",
			"sound": "bow",
			"parents": [
				"ranger_fan",
				"hunter"
			],
			"column": 3,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "ranger_field",
			"name": "가시 덫",
			"effect": "active",
			"value": 0,
			"description": "지속 범위 공격과 둔화 · 랭크마다 위력 +20%",
			"mode": "field",
			"count": 4,
			"power": 0.65,
			"cost": 30,
			"cooldown": 12,
			"fx": "ranger_field",
			"sound": "bow",
			"parents": [
				"ranger_burst",
				"rolling"
			],
			"column": 3,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "ranger_chain",
			"name": "도탄 사격",
			"effect": "active",
			"value": 0,
			"description": "가까운 적 사이 연쇄 타격 · 랭크마다 위력 +20%",
			"mode": "chain",
			"count": 4,
			"power": 1.2,
			"cost": 25,
			"cooldown": 10,
			"fx": "ranger_chain",
			"sound": "bow",
			"parents": [
				"ranger_field",
				"retreat_shot"
			],
			"column": 3,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "ranger_pull",
			"name": "바람 올가미",
			"effect": "active",
			"value": 0,
			"description": "적을 끌어당긴 뒤 공격 · 랭크마다 위력 +20%",
			"mode": "pull",
			"count": 1,
			"power": 1.6,
			"cost": 20,
			"cooldown": 8,
			"fx": "ranger_pull",
			"sound": "bow",
			"parents": [
				"ranger_chain",
				"breath"
			],
			"column": 3,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "ranger_heal",
			"name": "숲의 응급처치",
			"effect": "active",
			"value": 0,
			"description": "최대 체력 비례 즉시 회복 · 랭크마다 위력 +20%",
			"mode": "heal",
			"count": 1,
			"power": 1.2,
			"cost": 25,
			"cooldown": 14,
			"fx": "ranger_heal",
			"sound": "bow",
			"parents": [],
			"column": 4,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "ranger_barrier",
			"name": "잎새 방패",
			"effect": "active",
			"value": 0,
			"description": "잠시 받는 피해 감소 · 랭크마다 위력 +20%",
			"mode": "barrier",
			"count": 1,
			"power": 0.8,
			"cost": 28,
			"cooldown": 16,
			"fx": "ranger_barrier",
			"sound": "bow",
			"parents": [
				"ranger_heal",
				"ranger_fan"
			],
			"column": 4,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "ranger_haste",
			"name": "매의 집중",
			"effect": "active",
			"value": 0,
			"description": "잠시 공격·이동 가속 · 랭크마다 위력 +20%",
			"mode": "haste",
			"count": 1,
			"power": 0.35,
			"cost": 25,
			"cooldown": 16,
			"fx": "ranger_haste",
			"sound": "bow",
			"parents": [
				"ranger_barrier",
				"ranger_burst"
			],
			"column": 4,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "ranger_nova_ring",
			"name": "회오리 사격",
			"effect": "active",
			"value": 0,
			"description": "주변 두 번 범위 공격 · 랭크마다 위력 +20%",
			"mode": "nova_ring",
			"count": 2,
			"power": 1.5,
			"cost": 35,
			"cooldown": 14,
			"fx": "ranger_nova_ring",
			"sound": "bow",
			"parents": [
				"ranger_haste",
				"ranger_field"
			],
			"column": 4,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "ranger_critical_v05",
			"name": "매의 눈",
			"effect": "critical",
			"value": 0.02,
			"description": "치명타 확률 +2% / 랭크",
			"parents": [
				"ranger_nova_ring",
				"ranger_chain"
			],
			"column": 4,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "ranger_critical_damage_v05",
			"name": "급소 관통",
			"effect": "critical_damage",
			"value": 0.1,
			"description": "치명타 배율 +10% / 랭크",
			"parents": [],
			"column": 5,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "ranger_lifesteal_v05",
			"name": "생명의 화살",
			"effect": "lifesteal",
			"value": 0.01,
			"description": "명중 피해의 1% 회복 / 랭크",
			"parents": [
				"ranger_critical_damage_v05",
				"ranger_heal"
			],
			"column": 5,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "ranger_execute_v05",
			"name": "사냥의 마무리",
			"effect": "execute",
			"value": 0.08,
			"description": "체력 30% 이하 적 피해 +8% / 랭크",
			"parents": [
				"ranger_lifesteal_v05",
				"ranger_barrier"
			],
			"column": 5,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "ranger_thorns_v05",
			"name": "가시 외투",
			"effect": "thorns",
			"value": 2,
			"description": "피격 시 근접 적에게 2 반사 / 랭크",
			"parents": [
				"ranger_execute_v05",
				"ranger_haste"
			],
			"column": 5,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "ranger_health_regen_v05",
			"name": "숲의 숨결",
			"effect": "health_regen",
			"value": 0.4,
			"description": "비전투 초당 체력 +0.4 / 랭크",
			"parents": [
				"ranger_thorns_v05",
				"ranger_nova_ring"
			],
			"column": 5,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "ranger_potion_power_v05",
			"name": "약초 지식",
			"effect": "potion_power",
			"value": 8,
			"description": "물약 회복량 +8 / 랭크",
			"parents": [],
			"column": 6,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "ranger_xp_bonus_v05",
			"name": "정찰 기록",
			"effect": "xp_bonus",
			"value": 0.03,
			"description": "획득 경험치 +3% / 랭크",
			"parents": [
				"ranger_potion_power_v05",
				"ranger_critical_damage_v05"
			],
			"column": 6,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "ranger_gold_bonus_v05",
			"name": "채집꾼의 눈",
			"effect": "gold_bonus",
			"value": 0.04,
			"description": "획득 금화 +4% / 랭크",
			"parents": [
				"ranger_xp_bonus_v05",
				"ranger_lifesteal_v05"
			],
			"column": 6,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "ranger_dodge_duration_v05",
			"name": "깃털 회피",
			"effect": "dodge_duration",
			"value": 0.02,
			"description": "회피 무적 시간 +0.02초 / 랭크",
			"parents": [
				"ranger_gold_bonus_v05",
				"ranger_execute_v05"
			],
			"column": 6,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "ranger_sprint_discount_v05",
			"name": "장거리 주행",
			"effect": "sprint_discount",
			"value": 1.5,
			"description": "달리기 초당 기력 소모 -1.5 / 랭크",
			"parents": [
				"ranger_dodge_duration_v05",
				"ranger_thorns_v05"
			],
			"column": 6,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "ranger_heavy_discount_v05",
			"name": "활시위 절약",
			"effect": "heavy_discount",
			"value": 1,
			"description": "강공격 기력 소모 -1 / 랭크",
			"parents": [],
			"column": 7,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "ranger_skill_discount_v05",
			"name": "고른 호흡",
			"effect": "skill_discount",
			"value": 1,
			"description": "직업 기술 기력 소모 -1 / 랭크",
			"parents": [
				"ranger_heavy_discount_v05",
				"ranger_potion_power_v05"
			],
			"column": 7,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "ranger_projectile_speed_v05",
			"name": "순풍 사격",
			"effect": "projectile_speed",
			"value": 0.5,
			"description": "투사체 속도 +0.5 / 랭크",
			"parents": [
				"ranger_skill_discount_v05",
				"ranger_xp_bonus_v05"
			],
			"column": 7,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "ranger_slow_duration_v05",
			"name": "차가운 덫",
			"effect": "slow_duration",
			"value": 0.2,
			"description": "둔화 지속 시간 +0.2초 / 랭크",
			"parents": [
				"ranger_projectile_speed_v05",
				"ranger_gold_bonus_v05"
			],
			"column": 7,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "ranger_stun_duration_v05",
			"name": "덫의 충격",
			"effect": "stun_duration",
			"value": 0.1,
			"description": "기절 지속 시간 +0.1초 / 랭크",
			"parents": [
				"ranger_slow_duration_v05",
				"ranger_dodge_duration_v05"
			],
			"column": 7,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "ranger_knockback_v05",
			"name": "밀어내는 화살",
			"effect": "knockback",
			"value": 0.08,
			"description": "명중 시 밀어내기 +0.08칸 / 랭크",
			"parents": [],
			"column": 8,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "ranger_elite_damage_v05",
			"name": "대물 사냥",
			"effect": "elite_damage",
			"value": 0.05,
			"description": "보스 피해 +5% / 랭크",
			"parents": [
				"ranger_knockback_v05",
				"ranger_heavy_discount_v05"
			],
			"column": 8,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "ranger_damage_v05",
			"name": "안정된 조준",
			"effect": "damage",
			"value": 1,
			"description": "공격력 +1 / 랭크",
			"parents": [
				"ranger_elite_damage_v05",
				"ranger_skill_discount_v05"
			],
			"column": 8,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "ranger_health_v05",
			"name": "야생의 체력",
			"effect": "health",
			"value": 8,
			"description": "최대 체력 +8 / 랭크",
			"parents": [
				"ranger_damage_v05",
				"ranger_projectile_speed_v05"
			],
			"column": 8,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "ranger_stamina_v05",
			"name": "풍부한 호흡",
			"effect": "stamina",
			"value": 5,
			"description": "최대 기력 +5 / 랭크",
			"parents": [
				"ranger_health_v05",
				"ranger_slow_duration_v05"
			],
			"column": 8,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "ranger_defense_v05",
			"name": "가죽 숙련",
			"effect": "defense",
			"value": 1,
			"description": "받는 피해 -1 / 랭크",
			"parents": [],
			"column": 9,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "ranger_attack_haste_v05",
			"name": "민첩한 장전",
			"effect": "attack_haste",
			"value": 0.015,
			"description": "기본 공격 간격 -0.015초 / 랭크",
			"parents": [
				"ranger_defense_v05",
				"ranger_knockback_v05"
			],
			"column": 9,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "ranger_skill_haste_v05",
			"name": "기회의 순환",
			"effect": "skill_haste",
			"value": 0.15,
			"description": "직업 기술 재사용 -0.15초 / 랭크",
			"parents": [
				"ranger_attack_haste_v05",
				"ranger_elite_damage_v05"
			],
			"column": 9,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "ranger_skill_radius_v05",
			"name": "넓은 조망",
			"effect": "skill_radius",
			"value": 0.08,
			"description": "기술 범위 +0.08칸 / 랭크",
			"parents": [
				"ranger_skill_haste_v05",
				"ranger_damage_v05"
			],
			"column": 9,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "ranger_skill_power_v05",
			"name": "숲의 축복",
			"effect": "skill_power",
			"value": 0.04,
			"description": "직업 기술 피해 +4% / 랭크",
			"parents": [
				"ranger_skill_radius_v05",
				"ranger_health_v05"
			],
			"column": 9,
			"tier": 4,
			"parent_mode": "any"
		}
	],
	"mage": [
		{
			"id": "arcana",
			"name": "별의 지식",
			"effect": "damage",
			"value": 2,
			"description": "공격력 +2 / 랭크",
			"parents": [],
			"column": 0,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "charge",
			"name": "마력 응축",
			"effect": "heavy_power",
			"value": 0.12,
			"description": "강공격 피해 +12% / 랭크",
			"parents": [
				"arcana",
				"mage_defense_v05"
			],
			"column": 0,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "frost_nova",
			"name": "서리 꽃",
			"effect": "active",
			"value": 0,
			"description": "F · 주변을 얼리고 적을 둔화 · 강화마다 피해 +20%",
			"parents": [
				"charge",
				"mage_attack_haste_v05"
			],
			"column": 0,
			"tier": 2,
			"action": "skill_f",
			"parent_mode": "any"
		},
		{
			"id": "chill",
			"name": "남겨진 서리",
			"effect": "slow_duration",
			"value": 0.3,
			"description": "서리 둔화 지속 +0.3초 / 랭크",
			"parents": [
				"frost_nova",
				"mage_skill_haste_v05"
			],
			"column": 0,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "starnova",
			"name": "별무리의 주인",
			"effect": "skill_power",
			"value": 0.25,
			"description": "모든 직업 기술 피해 +25% / 랭크",
			"parents": [
				"chill",
				"mage_skill_radius_v05"
			],
			"column": 0,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "reservoir",
			"name": "마력 그릇",
			"effect": "stamina",
			"value": 10,
			"description": "최대 기력 +10 / 랭크",
			"parents": [],
			"column": 1,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "flow",
			"name": "순환하는 별",
			"effect": "skill_haste",
			"value": 0.3,
			"description": "직업 기술 대기 -0.3초 / 랭크",
			"parents": [
				"reservoir",
				"arcana"
			],
			"column": 1,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "thunder",
			"name": "벼락 별",
			"effect": "active",
			"value": 0,
			"description": "V · 조준 지점 낙뢰와 짧은 기절 · 강화마다 피해 +20%",
			"parents": [
				"flow",
				"charge"
			],
			"column": 1,
			"tier": 2,
			"action": "skill_v",
			"parent_mode": "any"
		},
		{
			"id": "storm",
			"name": "퍼지는 별빛",
			"effect": "skill_radius",
			"value": 0.18,
			"description": "범위 기술 반경 +0.18 / 랭크",
			"parents": [
				"thunder",
				"frost_nova"
			],
			"column": 1,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "conduct",
			"name": "마력 전도",
			"effect": "damage",
			"value": 3,
			"description": "공격력 +3 / 랭크",
			"parents": [
				"storm",
				"chill"
			],
			"column": 1,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "ward",
			"name": "별빛 보호",
			"effect": "health",
			"value": 12,
			"description": "최대 체력 +12 / 랭크",
			"parents": [],
			"column": 2,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "barrier",
			"name": "마력 외투",
			"effect": "defense",
			"value": 1,
			"description": "받는 피해 -1 / 랭크",
			"parents": [
				"ward",
				"reservoir"
			],
			"column": 2,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "blink",
			"name": "반짝 걸음",
			"effect": "active",
			"value": 0,
			"description": "C · 짧게 순간이동하며 별빛 폭발 · 강화마다 피해 +20%",
			"parents": [
				"barrier",
				"flow"
			],
			"column": 2,
			"tier": 2,
			"action": "skill_c",
			"parent_mode": "any"
		},
		{
			"id": "meditation",
			"name": "고요한 마음",
			"effect": "stamina_regen",
			"value": 2,
			"description": "초당 기력 회복 +2 / 랭크",
			"parents": [
				"blink",
				"thunder"
			],
			"column": 2,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "wisdom",
			"name": "익숙한 주문",
			"effect": "attack_haste",
			"value": 0.04,
			"description": "기본 공격 간격 -0.04초 / 랭크",
			"parents": [
				"meditation",
				"storm"
			],
			"column": 2,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "mage_fan",
			"name": "삼중 별탄",
			"effect": "active",
			"value": 0,
			"description": "부채꼴 투사체 · 랭크마다 위력 +20%",
			"mode": "fan",
			"count": 5,
			"power": 1.0,
			"cost": 18,
			"cooldown": 5,
			"fx": "mage_fan",
			"sound": "nova",
			"parents": [],
			"column": 3,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "mage_burst",
			"name": "운석 낙하",
			"effect": "active",
			"value": 0,
			"description": "조준 지점 강타 · 랭크마다 위력 +20%",
			"mode": "burst",
			"count": 1,
			"power": 2.8,
			"cost": 25,
			"cooldown": 9,
			"fx": "mage_burst",
			"sound": "nova",
			"parents": [
				"mage_fan",
				"ward"
			],
			"column": 3,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "mage_field",
			"name": "눈꽃 폭풍",
			"effect": "active",
			"value": 0,
			"description": "지속 범위 공격과 둔화 · 랭크마다 위력 +20%",
			"mode": "field",
			"count": 4,
			"power": 0.65,
			"cost": 30,
			"cooldown": 12,
			"fx": "mage_field",
			"sound": "nova",
			"parents": [
				"mage_burst",
				"barrier"
			],
			"column": 3,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "mage_chain",
			"name": "연쇄 번개",
			"effect": "active",
			"value": 0,
			"description": "가까운 적 사이 연쇄 타격 · 랭크마다 위력 +20%",
			"mode": "chain",
			"count": 4,
			"power": 1.2,
			"cost": 25,
			"cooldown": 10,
			"fx": "mage_chain",
			"sound": "nova",
			"parents": [
				"mage_field",
				"blink"
			],
			"column": 3,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "mage_pull",
			"name": "중력 소용돌이",
			"effect": "active",
			"value": 0,
			"description": "적을 끌어당긴 뒤 공격 · 랭크마다 위력 +20%",
			"mode": "pull",
			"count": 1,
			"power": 1.6,
			"cost": 20,
			"cooldown": 8,
			"fx": "mage_pull",
			"sound": "nova",
			"parents": [
				"mage_chain",
				"meditation"
			],
			"column": 3,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "mage_heal",
			"name": "달빛 치유",
			"effect": "active",
			"value": 0,
			"description": "최대 체력 비례 즉시 회복 · 랭크마다 위력 +20%",
			"mode": "heal",
			"count": 1,
			"power": 1.2,
			"cost": 25,
			"cooldown": 14,
			"fx": "mage_heal",
			"sound": "nova",
			"parents": [],
			"column": 4,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "mage_barrier",
			"name": "수정 결계",
			"effect": "active",
			"value": 0,
			"description": "잠시 받는 피해 감소 · 랭크마다 위력 +20%",
			"mode": "barrier",
			"count": 1,
			"power": 0.8,
			"cost": 28,
			"cooldown": 16,
			"fx": "mage_barrier",
			"sound": "nova",
			"parents": [
				"mage_heal",
				"mage_fan"
			],
			"column": 4,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "mage_haste",
			"name": "시간 가속",
			"effect": "active",
			"value": 0,
			"description": "잠시 공격·이동 가속 · 랭크마다 위력 +20%",
			"mode": "haste",
			"count": 1,
			"power": 0.35,
			"cost": 25,
			"cooldown": 16,
			"fx": "mage_haste",
			"sound": "nova",
			"parents": [
				"mage_barrier",
				"mage_burst"
			],
			"column": 4,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "mage_nova_ring",
			"name": "천체 공명",
			"effect": "active",
			"value": 0,
			"description": "주변 두 번 범위 공격 · 랭크마다 위력 +20%",
			"mode": "nova_ring",
			"count": 2,
			"power": 1.5,
			"cost": 35,
			"cooldown": 14,
			"fx": "mage_nova_ring",
			"sound": "nova",
			"parents": [
				"mage_haste",
				"mage_field"
			],
			"column": 4,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "mage_critical_v05",
			"name": "별의 정밀함",
			"effect": "critical",
			"value": 0.02,
			"description": "치명타 확률 +2% / 랭크",
			"parents": [
				"mage_nova_ring",
				"mage_chain"
			],
			"column": 4,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "mage_critical_damage_v05",
			"name": "초신성 핵",
			"effect": "critical_damage",
			"value": 0.1,
			"description": "치명타 배율 +10% / 랭크",
			"parents": [],
			"column": 5,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "mage_lifesteal_v05",
			"name": "생명 전환",
			"effect": "lifesteal",
			"value": 0.01,
			"description": "명중 피해의 1% 회복 / 랭크",
			"parents": [
				"mage_critical_damage_v05",
				"mage_heal"
			],
			"column": 5,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "mage_execute_v05",
			"name": "황혼의 마침표",
			"effect": "execute",
			"value": 0.08,
			"description": "체력 30% 이하 적 피해 +8% / 랭크",
			"parents": [
				"mage_lifesteal_v05",
				"mage_barrier"
			],
			"column": 5,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "mage_thorns_v05",
			"name": "수정 파편",
			"effect": "thorns",
			"value": 2,
			"description": "피격 시 근접 적에게 2 반사 / 랭크",
			"parents": [
				"mage_execute_v05",
				"mage_haste"
			],
			"column": 5,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "mage_health_regen_v05",
			"name": "명상",
			"effect": "health_regen",
			"value": 0.4,
			"description": "비전투 초당 체력 +0.4 / 랭크",
			"parents": [
				"mage_thorns_v05",
				"mage_nova_ring"
			],
			"column": 5,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "mage_potion_power_v05",
			"name": "연금 지식",
			"effect": "potion_power",
			"value": 8,
			"description": "물약 회복량 +8 / 랭크",
			"parents": [],
			"column": 6,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "mage_xp_bonus_v05",
			"name": "마법 연구",
			"effect": "xp_bonus",
			"value": 0.03,
			"description": "획득 경험치 +3% / 랭크",
			"parents": [
				"mage_potion_power_v05",
				"mage_critical_damage_v05"
			],
			"column": 6,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "mage_gold_bonus_v05",
			"name": "보물 탐지",
			"effect": "gold_bonus",
			"value": 0.04,
			"description": "획득 금화 +4% / 랭크",
			"parents": [
				"mage_xp_bonus_v05",
				"mage_lifesteal_v05"
			],
			"column": 6,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "mage_dodge_duration_v05",
			"name": "차원 잔향",
			"effect": "dodge_duration",
			"value": 0.02,
			"description": "회피 무적 시간 +0.02초 / 랭크",
			"parents": [
				"mage_gold_bonus_v05",
				"mage_execute_v05"
			],
			"column": 6,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "mage_sprint_discount_v05",
			"name": "공중 보행",
			"effect": "sprint_discount",
			"value": 1.5,
			"description": "달리기 초당 기력 소모 -1.5 / 랭크",
			"parents": [
				"mage_dodge_duration_v05",
				"mage_thorns_v05"
			],
			"column": 6,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "mage_heavy_discount_v05",
			"name": "안정된 충전",
			"effect": "heavy_discount",
			"value": 1,
			"description": "강공격 기력 소모 -1 / 랭크",
			"parents": [],
			"column": 7,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "mage_skill_discount_v05",
			"name": "마력 절약",
			"effect": "skill_discount",
			"value": 1,
			"description": "직업 기술 기력 소모 -1 / 랭크",
			"parents": [
				"mage_heavy_discount_v05",
				"mage_potion_power_v05"
			],
			"column": 7,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "mage_projectile_speed_v05",
			"name": "별빛 가속",
			"effect": "projectile_speed",
			"value": 0.5,
			"description": "투사체 속도 +0.5 / 랭크",
			"parents": [
				"mage_skill_discount_v05",
				"mage_xp_bonus_v05"
			],
			"column": 7,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "mage_slow_duration_v05",
			"name": "영구 동토",
			"effect": "slow_duration",
			"value": 0.2,
			"description": "둔화 지속 시간 +0.2초 / 랭크",
			"parents": [
				"mage_projectile_speed_v05",
				"mage_gold_bonus_v05"
			],
			"column": 7,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "mage_stun_duration_v05",
			"name": "잔류 전류",
			"effect": "stun_duration",
			"value": 0.1,
			"description": "기절 지속 시간 +0.1초 / 랭크",
			"parents": [
				"mage_slow_duration_v05",
				"mage_dodge_duration_v05"
			],
			"column": 7,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "mage_knockback_v05",
			"name": "중력 반발",
			"effect": "knockback",
			"value": 0.08,
			"description": "명중 시 밀어내기 +0.08칸 / 랭크",
			"parents": [],
			"column": 8,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "mage_elite_damage_v05",
			"name": "거신 해석",
			"effect": "elite_damage",
			"value": 0.05,
			"description": "보스 피해 +5% / 랭크",
			"parents": [
				"mage_knockback_v05",
				"mage_heavy_discount_v05"
			],
			"column": 8,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "mage_damage_v05",
			"name": "마력 집중",
			"effect": "damage",
			"value": 1,
			"description": "공격력 +1 / 랭크",
			"parents": [
				"mage_elite_damage_v05",
				"mage_skill_discount_v05"
			],
			"column": 8,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "mage_health_v05",
			"name": "생명의 서",
			"effect": "health",
			"value": 8,
			"description": "최대 체력 +8 / 랭크",
			"parents": [
				"mage_damage_v05",
				"mage_projectile_speed_v05"
			],
			"column": 8,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "mage_stamina_v05",
			"name": "내면의 샘",
			"effect": "stamina",
			"value": 5,
			"description": "최대 기력 +5 / 랭크",
			"parents": [
				"mage_health_v05",
				"mage_slow_duration_v05"
			],
			"column": 8,
			"tier": 4,
			"parent_mode": "any"
		},
		{
			"id": "mage_defense_v05",
			"name": "마법 방호",
			"effect": "defense",
			"value": 1,
			"description": "받는 피해 -1 / 랭크",
			"parents": [],
			"column": 9,
			"tier": 0,
			"parent_mode": "any"
		},
		{
			"id": "mage_attack_haste_v05",
			"name": "즉시 시전",
			"effect": "attack_haste",
			"value": 0.015,
			"description": "기본 공격 간격 -0.015초 / 랭크",
			"parents": [
				"mage_defense_v05",
				"mage_knockback_v05"
			],
			"column": 9,
			"tier": 1,
			"parent_mode": "any"
		},
		{
			"id": "mage_skill_haste_v05",
			"name": "시간 연구",
			"effect": "skill_haste",
			"value": 0.15,
			"description": "직업 기술 재사용 -0.15초 / 랭크",
			"parents": [
				"mage_attack_haste_v05",
				"mage_elite_damage_v05"
			],
			"column": 9,
			"tier": 2,
			"parent_mode": "any"
		},
		{
			"id": "mage_skill_radius_v05",
			"name": "궤도 확장",
			"effect": "skill_radius",
			"value": 0.08,
			"description": "기술 범위 +0.08칸 / 랭크",
			"parents": [
				"mage_skill_haste_v05",
				"mage_damage_v05"
			],
			"column": 9,
			"tier": 3,
			"parent_mode": "any"
		},
		{
			"id": "mage_skill_power_v05",
			"name": "천문학의 완성",
			"effect": "skill_power",
			"value": 0.04,
			"description": "직업 기술 피해 +4% / 랭크",
			"parents": [
				"mage_skill_radius_v05",
				"mage_health_v05"
			],
			"column": 9,
			"tier": 4,
			"parent_mode": "any"
		}
	]
}
