# 일반 몬스터 29종 런타임 인수인계

아트 완성 29종만 독립 모듈에 등록했다. `game/data/monster_ecology_v071.json`은 정본 `normal_monster_expansion/catalog.json`의 출현 261행·전용 드롭 87행을 변환한다. 계수 재조정과 공용 런타임 호출부 수정은 하지 않았다. 데이터의 `module_ready_main_hooks_required` 상태는 실제 전투 연결 완료를 뜻하지 않는다.

## 메인 연결 순서

1. `World.ENEMIES`를 사용하여 Dungeon/EncounterRoles/Simulation을 만들기 전에 `Ecology.inject_definitions(World.ENEMIES)`를 호출한다. 충돌은 전체 무변경으로 반환하므로 `ok`를 확인한다. 동일 정의 재호출은 안전하다. 모듈은 World/Content/Attacks를 preload하지 않는다.
2. 기존 EncounterRoles와 위험도 배치가 끝난 `map.encounters`에 `Ecology.replace_candidates(map.encounters, floor_number, generation_seed, World.ENEMIES)`를 한 번 호출한다. 반환 배열을 사용한다. 기존 normal 슬롯의 kind/combat_role만 변경하며 좌표·개수·정예·수호자·레이드·위험도 증원은 보존한다. 원래 지역 4종 각각 10% 슬롯을 유지하고 미완성 11종 슬롯은 원래 후보로 둔다. 최소~최대 무리, 그룹 2종 이하, 원거리 1마리 이하, 천적 혼합 금지 위반 시 해당 변경 그룹 전체를 원래대로 되돌린다. 조건에 따른 실출현 감소는 재분배하지 않는다.
3. spawn 시 `Ecology.stats(kind, floor)`가 비어 있지 않으면 그 결과를 enemy에 병합하고 hp/max_hp를 health로 맞춘다. 이 분기에는 `Abyss.enemy_stats`를 적용하지 않는다. 정본 출현행에 이미 층별 계수가 적용되어 있으므로 재계산·속도 2.8 제한은 수치를 변경한다. 기존 위험도 보정은 기존 위치에서 한 번만 적용한다. 신규 이름은 정의 name을 유지한다.
4. Simulation 소유 인스턴스 `var monster_ecology = Ecology.new(self)`를 만들고 서버 프레임마다 `monster_ecology.tick(delta)`를 한 번 호출한다. 새 windup을 시작하기 **전에** `begin(enemy, target.pos)`를 호출한다. true 반환이면 기존 windup/attack_areas 초기화를 실행하지 않는다. 호출부는 공격 거리·타깃·cooldown 판단을 계속 담당한다.
5. Simulation이 windup을 감소시킨 뒤 0이 된 프레임에 `release(enemy)`를 호출한다. true 반환이면 기존 일반 몬스터 release 및 고정 cooldown/attack_motion 대입을 건너뛴다. module은 정본 windup, cooldown, recovery를 사용한다. Simulation은 cooldown/windup/attack_motion을 기존처럼 프레임당 한 번 감소시키며, `Ecology.recovering(enemy)` 동안 이동·새 공격을 진행하지 않는다. module.tick은 이 세 타이머를 감소시키지 않는다.
6. 죽음·강직·강제취소·맵 이동 시 `cancel(enemy)`를 연결한다. tick도 hp/stun/stagger 상태로 취소하지만 명시 취소는 같은 프레임의 잔류를 제거한다. 지연타격/탄환은 독립 대기열과 공격 토큰으로 관리하므로 기존 MonsterAttacks.zones에는 중복 등록하지 않는다. module.telegraphs()를 기존 경고 영역 스냅샷에 추가하고 projectile_snapshots()를 신규 탄환 표시 경로에 전달한다. 기존 attack_areas는 windup 경고용이다.
7. eligible 개인별 보상 처리에서 `roll_drops(kind, rng)`를 한 번 굴린 후 기존 `loot_tables.item(row)` 및 owner 지정 경로를 사용한다. risk/hunter chance_bonus는 전달하지 않는다. spawn stats가 제공하는 `species_drop_materials`를 enemy에 유지하면 기존 exploration_material_rewards.enemy의 중복 제외 입력과 연결된다. 기존 몬스터 재료 테이블까지 함께 굴리지 않는다. 장비를 유지하려는 경우에만 `equipment_rows(kind, floor, loot_tables.tables)`의 정본 baseline 장비 행을 별도 기존 장비 정책으로 처리한다.

## 실제 구현과 제한

물리 피해는 기존 `MonsterAttacks.impact/damage`에 위임하므로 기존 방어·회피·반사·사망 처리를 사용한다. 구조화된 DB shape/range/windup/cooldown/recovery/multiplier가 기준이다. DB에 없는 공격폭은 각 행의 physical_mapping.basis로 기존 물리 패턴 기본값을 명시했다. cone 반각 .8, target circle 반경 1, two_bites 반경 .55·간격 .25·배율 .5, dash 반폭 .58, projectile 반폭 .18이다.

projectile은 DB 속도와 사거리로 실제 이동하며 .16타일 구간으로 벽과 플레이어/소환수 교차를 확인한다. 접촉 시 한 번 충돌하고 끝난다. short_dash는 기존 돌진 방식과 같이 해제 프레임에 경로를 이동하되 .16타일 구간으로 벽을 확인하고 실제 도달점까지만 공격한다. 다단 물기는 시전 시작에 잠근 지점에 두 번 적용한다. 큰 delta에서도 탄환이 대상을 건너뛰지 않도록 구간을 나눈다.

속성 피해·저항·약점·상태 이상, 몬스터 크기별 물리 충돌/피격 반경은 **미적용**이다. 값은 not_applied에 보존한다. 스프라이트 몸체 크기와 실제 피격 반경을 같은 것으로 표시하지 않는다. 독립 테스트의 ImpactRecorder는 피해 전달 호출을 기록하며 통합 Simulation의 최종 체력 변화·네트워크 표시까지 검증한 것으로 간주하지 않는다.

## 전용 검증

```powershell
python tools/build_monster_ecology_data_v071.py --check
python tools/validate_monster_ecology_data_v071.py
& D:/SSRPG/RPG2/tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path game --script res://tests/monster_ecology_v071.gd
```

엔진 실행은 메인 검사 슬롯에서 직렬로 수행한다. 최종 실행 결과는 `monster_ecology_runtime_v071.validation.json`에 별도 기록한다.
