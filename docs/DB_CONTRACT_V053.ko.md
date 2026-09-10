# V0.5.3 데이터 인수 범위

관리 담당은 DB 관리다. 관리 DB 스키마 5, 게임 저장 형식 7, 스킬 빌드 형식 2를 유지한다. JSON/SQLite를 직접 수정하지 않고 실행 원본과 생성기를 수정한 뒤 재생성한다.

| 변경 | 원본 | 적용 범위 |
|---|---|---|
| 스킬·장비 표시 이름 | `game/data/content_names.json`, `content_names.gd` | 기존 고정 ID와 저장 기록 유지 |
| 네 가지 스킬 역할 | `skill_node_roles.gd` | `node_kind`, `effect_scope`, `target_active_id`, `concept_id`를 도감·스킬 지도·관리 DB에서 공유 |
| 스킬 밸런스 | `job_balance.gd`, `constellation_catalog.gd`, `constellation_effects.gd` | 지정 모듈은 대상 액티브에만 적용. 상세 변경은 `CHARACTER_BALANCE.ko.md` |
| 첫 튜토리얼 완료 | `local_session.gd`, `simulation.gd` | 최초 5킬 완료·LV.1이면 LV.2까지 부족한 XP를 지급. 일반 레벨업 경로 사용, 저장 실패/반복 시 중복 지급 없음 |
| 튜토리얼 장비 | `simulation.gd` | 꽃바람 숲 0층 일반 적 신규 드랍만 tier0. 기존 장비·정예·보스·던전 규칙 유지 |
| 여관 소규모 보급 | `town_operations.gd` | `inn:resupply_small`, 물약 5개까지 부족분 보충, 10G+부족분×15G. 20개 보급도 유지 |
| 도감 사전 준비 | `game_database.gd`, `game/data/codex-v053.bin` | 관리 DB와 같은 실행 원본에서 만든 도감 전용 캐시. 개인 저장을 포함하지 않음 |

도감 캐시는 STDB 헤더, 압축 전 길이, SHA-256, ZSTD 페이로드로 구성된다. 런타임의 직업·스킬 정의 초기화는 캐시와 별도로 보장한다. 누락/손상 캐시는 실행 원본 생성으로 돌아간다. 관리용 아트 레지스트리는 캐시의 일부가 아니며 원본 조회에서 생성한다.

`tools/build_database.py`는 캐시를 재사용하지 않고 실행 원본을 새로 생성한다. `--check`는 JSON·SQLite·캐시를 각각 비교하므로 오래된 캐시를 기준으로 새 캐시를 검증하지 않는다. 배포의 도감 바이너리와 개발용 SQLite는 서로 다른 용도이며 사용자가 수정할 정본은 실행 원본이다.

변경 규칙 회귀: `content_names`, `tree_balance`, `progression_rewards_v053`, `codex_cache_v053`, `database_v03/v04`, `database_metadata_v05`, `database_world_rules_v052`. 전체 등록은 `tools/verify_v01.py`에 있다. 실제 30분 진행/60분 성능은 모델 회귀와 별도이며 배포 완료 보고의 실행 파일 해시와 함께 인수한다.

가방 용량은 120칸이다. 저장 장비 배열의 허용 상한은 가방 120칸에 장착 7슬롯을 더한 127개이며, 가방 자체가 127칸인 것은 아니다. `tools/install_client.py`도 같은 경계를 사용한다. 설치 회귀는 127개 저장을 자르지 않고 원본 바이트 그대로 복사하며, 128개를 거부한다.

개인 기록의 최초 불러오기에서는 장비의 `name`·`base_name`을 현재 표시명 정본에 맞춰 정규화한다. 검증은 이 두 필드의 정확한 기대값과 나머지 장비 필드·능력치·재산·진행 보존을 함께 대조한다. 그 뒤 재저장·재시작의 영속 데이터 전체 일치와 원래 파일의 바이트 보존을 별도로 확인한다. 로컬 검증 보고는 `artifacts/personal-copy-v053.json`에 두며 개인 기록과 검증 산출물을 공개 DB ZIP에 넣지 않는다.

이번 범위 밖 V06 제작 중 원화는 보존하되 배포·DB 적용 목록에 넣지 않는다. 공개 DB 패키지에 개인 저장·원본 추출 폴더·실행 로그를 포함하지 않는다.
