# 벤치마킹 구현 근거와 남은 범위

2026-09-13 기준. 사용자 목표는 두 선택 목록의 모든 항목이다. **선택 표시는 완료 표시가 아니다.** 아래 `구현·로컬 검증`도 외부 회선 장시간 QA나 전체 목표 완료를 뜻하지 않는다. Dungeon Settlers 46개와 Stoneshard 14개는 겹치므로 60개의 독립 시스템으로 합산하지 않는다.

선택 원본: `D:/SSRPG/DungeonSettlers_extracted/SELECTED_BENCHMARKS.ko.md`, `D:/SSRPG/Stoneshard_benchmark/SELECTED_BENCHMARKS.ko.md`.

실행·인계 기록: [탐사 개선](EXPLORATION_REWORK.ko.md), [협동 기반](COOP_FOUNDATION.ko.md), `docs/qa/`의 검증 JSON. 표의 코드명은 `game/scripts/`, 테스트명은 `game/tests/` 기준이다. 표의 항목을 그대로 전체 완료 증거로 사용하지 않고 실제 코드·결과와 대조한다.

기반 N1/N2/N3: 최대 6인 방장 권위·직접 주소 연결·개인 메뉴/인벤토리·저장 ACK·공유 층 이동은 로컬 검증했다. 원정 재접속·분리 귀환·지연/손실/외부 장시간·직업 조합 밸런스가 남아 있다. 현재 변경은 협동 프로토콜 13으로 구분한다. 이전 규칙의 클라이언트는 버전 검사에서 참가를 거절한다. 자동 매칭·아군 AI 동료·턴제·미선택 항목은 추가하지 않는다.

## Dungeon Settlers

| 항목 | 상태 | 현재 근거 | 남은 범위/연결 검증 |
| --- | --- | --- | --- |
| C01 벽 충돌을 유도하는 보스 | 구현·로컬 검증 | monster_attacks.gd / raid_engagement | 외부 6인 장시간 패턴 체감 검증 |
| C02 역할이 다른 적 조합 | 부분 | encounter_roles.gd·enemy_support.gd·enemy_tactics.gd / 초기 접근 방향 역할 편성·치유 시전/중단·공유 회복 상한; [상세](ENEMY_ROLE_SUPPORT.ko.md) | 여러 무리 직접 조우 시 합류 밀도·직업 조합별 공략 시간·외부 6인 실전 검증 |
| C03 대응법이 다른 적 방어 | 구현·로컬 검증 | 갑피·겹 보호막·방어 자세, 20직업 기본/강공격 단독120경로·실제 연타/출혈/무력화·상태 표시; [상세](ENEMY_DEFENSE_COUNTERS.ko.md) | 상호 공격·회피 플레이의 최종 난도·직업 조합·외부 혼전 가독성 |
| C04 위치와 대가가 있는 스킬 | 부분 | player_combat.gd·job_combat.gd·tactical_tools.gd / combat·tactical_tools | 스킬의 거리·자세 조건/대가 전달; 직접 설치 함정·투척물은 SC08에서 연결 |
| C05 적·시체 조사와 도감 연결 | 구현·로컬 검증 | enemy_inspection.gd·enemy_inspection_panel.gd / combat_information·combat_information_visual·6인 ENet | 실제 연속 조작/혼잡도 체감 검증; 시체 그림 대신 소형 조사 표식 사용 |
| C06 공격 방향·범위와 시야 밖 위협 안내 | 구현·로컬 검증 | telegraph_priority.gd·danger_hud.gd·visible_telegraphs.gd / telegraph_priority·telegraph_priority_visual·dungeon_vision_visual | 외부 6인 장기 전투의 예고 체감/성능 검증; 합성 카메라/배치 검사와 구분 |
| C08 위치 선점과 도발 역할 | 부분 | 기존 taunt_owner·taunt_time 전투 상태 | 플레이어 간 도발·위치 선점과 솔로 방어의 조합별 밸런스 |
| C09 전투 결과에 반응하는 특수 효과 | 부분 | 직업·장비 효과, 패배/맵 전환 초기화 기반 | 저체력·피격·층당 효과별 개인 귀속과 모든 초기화 경로 검증 |
| C10 다운된 동료 구조 | 구현·로컬 검증 | party_rules.gd / coop_rules·실제 ENet | 지연·중도 이탈 상황의 구조 실전 검증 |
| E01 목적이 다른 선택 방 | 구현·로컬 검증 | exploration_rooms.gd·exploration_challenge.gd·exploration_cues.gd / 개별 시야의 지면 파편, 동일 분기에서 목적지까지 입력 이동; [환경 흔적](EXPLORATION_TRACES.ko.md) | 자유 탐사 재미·선택 밀도·처음 방문한 사람의 단서 추론 플레이 평가 |
| E02 소지품·상태에 반응하는 사건 | 구현·로컬 검증 | exploration_events.gd의 약초·도구·생명력·기력 선택 / 모델·실제 UI·개인별 6인 ENet; [상세](EXPLORATION_EVENTS.ko.md) | 재접속 시 이용 기록 보존·장기 탐사에서 사건 반복/경제 체감 |
| E03 필요 재료를 찾아가는 채집 | 구현·로컬 검증 | expedition_goals.gd·exploration_rooms.gd / expedition_goals | 연구·제작 목표와 연결(G01/G03); 길드·생산 목표 연동은 후속 |
| E04 귀환 또는 추가 도전 | 부분 | 선택 정예 도전·공동 다음 층·공동 귀환 | 개별 귀환·잔류자·재접속의 원정 상태 정책/실행 |
| E05 원정별 환경 변화 | 구현·로컬 검증 | expedition_environment.gd / expedition_environment·실제 ENet 안개 | 지역 의뢰 결과와의 변화 연결은 SQ03에서 후속 |
| E06 중간 정비·휴식 지점 | 부분 | 주 경로 휴식 지점 / exploration_rooms | 거점 위치 이동과 그곳의 정비 기능·잔류자 처리 |
| E07 재방문 구간 건너뛰기 | 구현·로컬 검증 | local_session.gd·coop_session.gd·exploration_shortcuts.gd / expedition_brief·발견 후 전진 지름길·실제 6인 입력 이동 | 재접속/분리 귀환과 결합된 이동 검증 |
| E08 방 배치의 지역·단계·가중치 분리 | 구현·로컬 검증 | dungeon_regions.gd·dungeon.gd·expedition_risk.gd / dungeon_exploration_routes·expedition_risk | 실제 플레이의 구역별 밀도와 이동 비용 검증 |
| E09 출발 전 준비 검사 | 구현·로컬 검증 | expedition_brief.gd·expedition_brief_panel.gd / expedition_brief | 새로운 보급/내구도 정책 추가 시 준비 검사 확장 |
| E10 귀환 성과와 다음 행동 연결 | 부분 | expedition_journal.gd / expedition_journal·ENet | 개인/파티 성과와 다음 행동 연결·재접속 (현재 기록은 세션 한정) |
| G01 부족한 것에 반응하는 목표 추천 | 구현·로컬 검증 | research_journey.gd·expedition_goals.gd / 실제 연구·제작 재료/선행 기반 추천, 부족 재료별 목적지 전환; [상세](RESEARCH_JOURNEY.ko.md) | 이후 길드·생산 기능 추가 시 목표 연동 |
| G02 전리품으로 마을 기능 해금 | 구현·로컬 검증 | town_research.gd·town_research_panel.gd / 개인 재료 투자·6종 실제 제작 해금·개인 저장; [상세](TOWN_RESEARCH.ko.md) | 시설 외형/대사(G09) 연결 및 장기 경제 검증 |
| G03 첫 탐사와 귀환을 잇는 목표 | 구현·로컬 검증 | 연구 목표→채집→초반 정제→연구→실제 첫 제작→다음 탐사 선택·포털 안내 / research_journey·visual·6인 ENet | 외부 다인 장시간 진행 차이 검증, 초반 장기 경제 체감 |
| G04 연구 선행 조건과 다음 연구 예약 | 구현·로컬 검증 | 3개 시설/6개 연구·공통 3칸 예약·선행/취소 환급·접속 시간·진행 저장 / town_research·실제 6인 ENet | 원정 재접속과 결합된 검증; 생산 큐(O02)는 별도 |
| G05 연구 검색과 결과 이동 | 구현·로컬 검증 | 현재 시설 연구명·정식 제작물명 검색·선행 연구 이동·해금 제작 / town_research_visual | 전체 시설을 아우르는 검색은 후속 확장 가능; 현재 시설 범위로 검증 |
| G06 조직 등급에 따른 기능 확장 | 구현·로컬 검증 | guild_progression.gd·guild_board.gd / 개인 평판 3등급, 실제 정예·수문장 의뢰와 탐사·공략 보급의 권위 잠금·해금; [상세](GUILD_PROGRESSION.ko.md) | 지역 결과·시설 성장(G09/SQ03), 외부 장기 경제·밸런스 |
| G07 학습 조건과 사용 조건 구분 | 부분 | 스킬 투자 조건과 사용 판정 기반 | 학습/사용 조건을 공통 결과로 구분해 표시 |
| G08 결과 미리보기와 유지 항목 선택 | 부분 | service_quote.gd·town_services.gd | 재련 유지 옵션·확정 비용·접속 종료 처리 |
| G09 시설 성장의 외형·대사 반영 | 미완료 | 기존 시설 그림·NPC 대화 | 성장/해금에 따른 외형·대사 변경 |
| U01 고정·연결 툴팁 | 미완료 | 일반 툴팁·도감 | 툴팁 고정·연결·개인 메뉴 중 실시간 협동 유지 |
| U02 능력치 기여분과 출처 | 부분 | player_stats.gd·combat_stats.gd | 장비·스킬·버프별 기여분과 실제 계산 출처 |
| U03 사용 실패 사유 통일 | 부분 | notice·quote.reason·stack_failure_reason | 학습·사용·거래 실패 코드/표시의 공통 계약 |
| U04 알림에서 해결 화면 이동 | 부분 | 귀환 결과에서 실제 시설 위치로 안내 | 개인 알림에서 관련 해결 화면으로 직접 이동 |
| U05 최초 상황별 도움말 | 부분 | 기본 튜토리얼 진행 기록 | 상황별 최초 도움말 저장·반복 억제 |
| U06 스택 절반·수량 분할 | 미완료 | inventory_model.gd의 단일 종류 묶음 | 수량/절반 분할·개인 소유/중복 이동 처리 |
| U07 거래·제작 실패 보호와 안내 | 부분 | staged 거래·중복 요청·퇴장 저장 ACK / ENet | 새 제작 큐·분할·재접속까지 같은 보호 적용 |
| U08 키 재지정과 충돌 안내 | 구현·로컬 검증 | 키 재지정·중복 교환·저장 / keyboard_ui_v051 | 신규 조작 추가 시 같은 충돌 안내 연결 |
| U09 UI·툴팁 크기 별도 조절 | 미완료 | 해상도 조절은 독립 배율이 아님 | UI와 툴팁의 개별 배율·전 해상도 잘림 검증 |
| U10 음량 채널·백그라운드 음소거 | 미완료 | music/effects 두 음량 채널 | 실제 환경/UI 별도 채널·비활성 음소거 |
| U11 저장 호환성과 변경 손실 안내 | 부분 | save v7 파싱·백업·쓰기 실패/퇴장 ACK | 원정/개인 저장·호환·변경 손실 안내 전 경로 |
| O01 목표 수량 일괄 제작 | 구현·로컬 검증 | town_operations.gd / target_crafting | 제작 큐 도입 후 목표 수량과 연결 |
| O02 제작 큐와 반복 방식 | 미완료 | 즉시 일괄 제작은 제작 큐가 아님 | 작업대 큐·횟수/반복·재료 예약·저장/취소 |
| O03 자동 소모품 허용·정책 복사 | 미완료 | 직접 사용·퀵슬롯의 consumables.gd | 개인 자동 소비 임계/허용·정책 복사 |
| O04 개별 창고 보관 정책 | 미완료 | 가방은 별도 창고가 아님 | 개인 창고·품목 필터·정책 복사 |
| O07 전투와 파밍 부담 별도 설정 | 미완료 | 파티 인원 보정·원정 환경 기반 | 전투 난도와 파밍 부담의 별도 세션 설정 |
| O08 생존 보급·체류 압박 | 미완료 | stamina는 전투 기력 | 별도 보급·체류 압박과 귀환 선택 |
| O09 장비 마모와 수리 | 미완료 | 강화/재련은 내구도 수리가 아님 | 장비 마모 사건·내구도·견적·수리 |

## Stoneshard 추가 선택

| 항목 | 상태 | 현재 근거 | 남은 범위/연결 검증 |
| --- | --- | --- | --- |
| SC05 소리로 적을 유인하는 전투 | 구현·로컬 검증 | enemy_awareness.gd·noise_feedback.gd·tactical_tools.gd의 전투/달리기/착지 소음·파티 상한·범위 안내 / 소음·도구 모델과 6인 ENet | 외부 회선 직업 조합 체감 검증 |
| SC06 위험 장판 회피·분산·추격하는 적 | 부분 | enemy_tactics.gd·enemy_awareness.gd / 관련 모델 | 외부 다인 전투의 도주 경로·분산/추격 밸런스 |
| SC08 함정·투척물로 만드는 전술 | 구현·로컬 검증 | 유인 돌·올가미 덫·화염병의 상점/가방/슬롯·예고·소유·설치 상한 / tactical_tools·tactical_tools_visual·6인 ENet; [상세](TACTICAL_TOOLS.ko.md) | 외부 6인 장시간 전투·직업별 도구 경제/전술 체감 검증 |
| SE01 주 목표 경로와 선택 탐사 분리 | 구현·로컬 검증 | 전진 주 경로·앞쪽 합류 보상 곁방 / dungeon_exploration_routes | 일반 플레이 탐사 선택 체감 |
| SE02 문틀 전투를 줄이는 넓은 공간 | 부분 | 넓은 통로·공동·우회 / dungeon_exploration_routes | 6인 실제 전투에서 문틀 봉쇄 지배 여부 |
| SE03 던전 종류별 다른 공간 규칙 | 구현·로컬 검증 | 10개 지역 문법·5개 공간군·단계 가중치·지역별 위험 상한 | 지역별 탐사 체감·동선 검증 |
| SE04 탐색으로 찾는 비밀방 | 구현·로컬 검증 | hidden_rooms.gd·exploration_shortcuts.gd / hidden_rooms_visual·거리 단축·공유 지형·실제 ENet; [상세](EXPLORATION_SHORTCUTS.ko.md) | 원정 재접속 시 발견 보존; 반복되는 발견·사건 종류 확장 |
| SE05 도구로 여는 추가 보상 구역 | 구현·로컬 검증 | 탐사 도구/선택 보관실·발견 후 전진 통로 / hidden_rooms·exploration_shortcuts·동시 개방 ENet | 원정 재접속 상태 보존 |
| SE07 출발 전에 얻는 던전 정보 | 구현·로컬 검증 | 규모·환경·실제 보스 패턴·몬스터 도감 / expedition_brief | 새 위험/보급 조건이 생기면 출발 정보 확장 |
| SE08 지역별 위험 상한과 선택 도전 | 구현·로컬 검증 | expedition_risk.gd·공유 출발 조건/준비 확인·역할 조합 증원·개인 보상 / expedition_risk·expedition_risk_visual·6인 ENet; [상세](EXPEDITION_RISK.ko.md) | 외부 6인 장기 밸런스·경제 체감; 발견·동선 개선의 완료 근거와 구분 |
| SE09 소문·지도에서 시작하는 탐사 | 구현·로컬 검증 | 지도/소문 목표·공동 발견/개인 보상 / expedition_goals·ENet | 원정 재접속 중간 단계 보존 |
| SS01 거점 위치를 정하는 원정 | 미완료 | 고정 중간 화로만 있음 | 거점 위치 선택·이동 동의·잔류·저장 귀속 |
| SQ01 의뢰 보상을 돈 또는 평판으로 선택 | 구현·로컬 검증 | 개인 금화·평판 선택과 공통 정수, 실제 정산 전후 영수증·다중 출력 실패 롤백·저장·6인 ENet / guild_progression·visual; [상세](GUILD_PROGRESSION.ko.md) | 계약 진행은 ENet에서 통제 호출, 실제 simulation.kill 연결은 별도 모델 검사; 외부 장기 경제 검증 |
| SQ03 의뢰 결과가 지역 상태에 반영 | 미완료 | 원정 시드 환경은 의뢰 결과 변화가 아님 | 의뢰 결과의 지역 위험·상점 변화와 귀속 |

## 자연동굴 배경 정리

[자연동굴 장식 정리](NATURAL_CAVE_DRESSING.ko.md)에서 반복 문틀·기둥·수레 등을 일반 산포에서 제외하고, 유해 네 종류를 층당 최대 5곳의 방 가장자리에 적용했다. 원화 108종은 보존하며 41종 적용·67종 available_catalog로 구분한다. 탐사 단서와 기능 장소를 가리지 않고 비밀 통로 개방 후에도 배치가 유지된다. 이 배경 변경으로 미완료 벤치마킹 상태나 집계 수를 올리지 않는다.
