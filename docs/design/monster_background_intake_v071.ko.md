# V0.7.1 몬스터·배경 원화 인수 대조

확인 시각: 2026-09-13T19:08:22.151621+09:00. 공용 코드·DB 수정과 엔진 실행 없이 현재 소스를 대조했다.

추가40종 = 신규 제작20종 + 기존 원화 재사용20종이다. 재사용20종 중12외형은 V0.7에 이미 있으므로 원화 재반입에서 제외하고 신규 전투종 ID 등록만 별도로 다룬다. 나머지8종과 신규20종, 총28외형이 외부팩에 있다. 현재 전투 ID 등록은40종 모두 미반영이다.

신규20종의 80포즈는 완성되어 원본/manifest/ZIP를 확인했다. 원본20PNG는 전부 RGB 마젠타이며 RGBA 원본이나 별도 RGBA 파생본 납품은 확인되지 않았다. 현재 공통 magenta_narrow 렌더 캐시를 활용할 수 있지만 원본 형식 요구 완료와 게임 연결 검증을 구분해야 한다.

재사용20종은9종 포즈 적합,11종16포즈가 새 생태계 패턴과 달라 보완이 남아 있다. 이16포즈는 신규80포즈에 포함되지 않았다. 두팩의 동일 reuse_review는 한 번만 집계했다.

## 추가40종 정확한 매칭

| ID | 구분 | 크기 배율 | 새 패턴 포즈 보완 |
|---|---|---:|---|
| thorn_maw | 외부 기존8 | 2 | windup, impact |
| briar_stag | 외부 기존8 | 3 | windup |
| forest_spore_millipede | 신규20 완성팩 | 1.2 | 없음 |
| forest_root_shrew | 신규20 완성팩 | 0.5 | 없음 |
| geode_pangolin | 외부 기존8 | 3 | windup, impact |
| bone_serpent | 외부 기존8 | 2 | 없음 |
| crystal_salt_mite | 신규20 완성팩 | 0.5 | 없음 |
| crystal_echo_gecko | 신규20 완성팩 | 1.2 | 없음 |
| flood_rustclaw_crab | V0.7 외형 재사용 | 2 | 없음 |
| flood_bell_nautilus | V0.7 외형 재사용 | 2 | 없음 |
| flood_silt_skater | 신규20 완성팩 | 1.2 | 없음 |
| flood_reed_eel | 신규20 완성팩 | 2 | 없음 |
| spore_blade_cricket | V0.7 외형 재사용 | 2 | 없음 |
| spore_lantern_moth | V0.7 외형 재사용 | 1.2 | 없음 |
| spore_compost_slug | 신규20 완성팩 | 1.2 | 없음 |
| spore_hook_mantis | 신규20 완성팩 | 2 | 없음 |
| lava_coal_salamander | V0.7 외형 재사용 | 2 | 없음 |
| lava_vent_snail | V0.7 외형 재사용 | 2 | impact |
| lava_ash_hopper | 신규20 완성팩 | 0.5 | 없음 |
| lava_slag_mole | 신규20 완성팩 | 2 | 없음 |
| frost_penguin | 외부 기존8 | 1.2 | windup, impact |
| rime_lynx | 외부 기존8 | 2 | impact |
| ice_moss_hare | 신규20 완성팩 | 0.5 | 없음 |
| ice_frost_louse | 신규20 완성팩 | 1.2 | 없음 |
| machine_saw_wheel | V0.7 외형 재사용 | 2 | windup, impact |
| machine_mortar_tripod | V0.7 외형 재사용 | 2 | 없음 |
| machine_oil_tick | 신규20 완성팩 | 0.5 | 없음 |
| machine_copper_crow | 신규20 완성팩 | 1.2 | 없음 |
| moss_owlbear | 외부 기존8 | 3 | impact |
| grave_lantern | 외부 기존8 | 1.2 | windup, impact |
| twilight_sap_bat | 신규20 완성팩 | 0.5 | 없음 |
| twilight_bark_isopod | 신규20 완성팩 | 1.2 | 없음 |
| nebula_quartz_scorpion | V0.7 외형 재사용 | 2 | 없음 |
| nebula_comet_cuttlefish | V0.7 외형 재사용 | 2 | 없음 |
| nebula_dust_ray | 신규20 완성팩 | 2 | 없음 |
| nebula_prism_worm | 신규20 완성팩 | 1.2 | 없음 |
| core_rune_leech | V0.7 외형 재사용 | 1.2 | impact |
| core_bound_grimoire | V0.7 외형 재사용 | 1.2 | impact |
| core_seal_beetle | 신규20 완성팩 | 1.2 | 없음 |
| core_ink_hound | 신규20 완성팩 | 2 | 없음 |

## 크기·타이밍

정본은 normal_monster_expansion/size_assignments.json이다. 두 신규팩에 기록된 해시와 현재 정본 해시가 일치한다. 소형0.5, 중소형1.2, 중형2, 중대형3, 대형6, 초대형10배. 모든40종의 배정과 원화 메타데이터를 대조했다. 동일 기준 캐릭터의 고정 외곽 높이 × 배율 / 해당종 idle body_height를 모든 포즈에 공통 적용한다. 현재112px 기준 예시는0.5→56px,1.2→134.4px,2→224px,3→336px다. 기준 코스튬/포즈가 바뀔 때 재계산하지 않으며 예전64/96/120px는 참고값이다. 충돌·히트박스·사거리와 별개다. 현재 크기 배정은 리더 metadata에만 있고 World.display_height 기반 구 크기 정책이 여전히 쓰인다.

신규 시전·후딜·다타격 시간은 각 DB pattern 계약을 사용한다. 기존 리더의 release .35초를 신규40종 전체에 적용하지 않는다. 땃쥐는2타×0.5/간격.25초이며 하나의 impact 원화를 재사용할 수 있다. 눈토끼 impact는 몸 오른쪽/발차기 왼쪽 예외다. 고정anchor와 crop내foot를 혼용하지 않는다.

## 별도 후보와 배경

추가40종에도 속하지 않고 V0.7 외형에도 없는 기존 완성 원화16종은 아트 후보로만 기록했다: abyss_angler, abyss_urchin, acorn_slinger, bronze_centipede, chain_jailer, cinder_bison, coffin_mimic, coral_mantis, dune_djinn, dune_sphinx, glacier_walrus, glass_cobra, magnetic_orb, sand_mummy, snow_wisp, steam_scarecrow. 스폰 허가나 추가 제작 요구로 해석하지 않는다.

dungeon-renewal-20260910의 배경24종은 현재 환경 카탈로그에 모두 미등록이다. 저상 자연물 후보는 fern_nest/bramble_corner/geode_vein/cooled_slag/ice_reeds/dry_oasis 6개다. 나머지 시설·보급상자·난간류는 배치 목적이 맞는 장소에서 검토하며 자연 동굴에 무작위 추가하지 않는다. ice는 현재층 snow와 연결하고 ruins/desert는 현재100층 chapter목록에 없어 자동층매핑하지 않는다. 상세 ID·영역·출처·배치 제약은 JSON에 있다.

과거 biomes/fantasy-expansion/dungeon-expansion 배경은 각36종, 총108종이 이미 등록되어 중복 반입 대상에서 제외했다. 카탈로그 등록은 모든 소품의 실제 스폰을 뜻하지 않으며 LIVE_POOLS의 선별 정책을 유지한다.

## 납품 정본과 검사

- [normal-ecology-priority-20260913](<D:\SSRPG\RPG2\art\monsters\normal-ecology-priority-20260913/catalog.json>): ZIP SHA256 `7246e5f37c1e41edf9c9d94ffa312e4a12da0cafdfa4773a57dae1c5df5c5507`, 7,530,050 bytes, CRC 정상, manifest 45파일 확인.
- [normal-ecology-regional-20260913](<D:\SSRPG\RPG2\art\monsters\normal-ecology-regional-20260913/catalog.json>): ZIP SHA256 `1c07fbe1abc5d5e49e4a259207302a42c0436e44ef240672433c7f1332d1cb19`, 30,275,369 bytes, CRC 정상, manifest 122파일 확인.
- [monster-variety-20260910](<D:\SSRPG\RPG2\art\monsters\monster-variety-20260910/catalog.json>): ZIP SHA256 `dcac601abc16f30bdc5f0756af02608d19577a57e5d4c0835b14941369b0d871`, 17,541,205 bytes, CRC 정상, manifest 0파일 확인.
- [dungeon-renewal-20260910](<D:\SSRPG\RPG2\art\dungeons\dungeon-renewal-20260910/catalog.json>): ZIP SHA256 `b744517d37174e33446db1a6b34c0a3431af612aa2a06b98b7de4e63e94168de`, 21,207,551 bytes, CRC 정상, manifest 0파일 확인.

전체 기계 판독 인수표: [monster_background_intake_v071.json](<D:/SSRPG/publish/SRPG-v04/docs/design/monster_background_intake_v071.json>). 각40종의 원본 경로·SHA·4영역·기준점·전용크기·새패턴 계약을 포함한다.

이번에는 Godot·GPU·실제 전투·개인/6인 재생을 실행하지 않았다. 신규팩의 기존 Godot/육안검수 기록은 제작 당시 결과이며 이번 재검증으로 표기하지 않는다. 미완성 보스 추가12포즈·3차 전직은 이 일반몹 인수 범위에서 제외한다.
