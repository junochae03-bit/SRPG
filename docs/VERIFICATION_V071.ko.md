# V0.7.1 검증 기록

전체 소스 게이트: **679,022개 검사, 187개 그룹, 실패 0**. 최종 런타임 파일의 SHA256과 Windows 빌드 입력이 일치한다.
실행 기록: `D:\SSRPG\publish\SRPG-v04\runtime\v01-checks\20260913-223144`. 완료시각: `2026-09-13 22:47:40`.

## 주요 통합 검사

| 검사 | 통과 |
| --- | ---: |
| integration_visual_v071 | 219 |
| equipment_special_stats | 299 |
| exploration_crafting_v071 | 36,731 |
| monster_ecology_v071 | 6,515 |
| monster_integration_v071 | 2,349 |
| monster_ecology_art_v071 | 1,604 |
| production_queue | 1,695 |
| revival_aftereffects | 62 |
| costume_session_v04 | 1,207 |
| skill_motion_facing_v071 | 553 |
| skill_motion_facing_visual_v071 | 18 |

실제 마우스 호버·펼침 메뉴 선택에서 어두운 배경과 밝은 글자 유지, 새 장비 옵션의 JSON 저장/복원 및 기존 장비 비재추첨, 29종 신규 몬스터의 승인된 포즈/조우/공격 연결을 확인했다. 도적·시프 방향 검사는 상속한 main.draw_actor의 8샘플이며 전체 스킬 플레이의 전수 검수로 확대하지 않는다.

## 협동·실행 파일·DB

- ENet 6개 독립 프로세스에서 개인 제작 예약/취소/산출물/완성 장비 저장, 중복 RPC의 단일 처리, 일곱 번째 접속 거절 및 프로토콜이 다른 구버전 차단을 확인했다.
- 네트워크 증거: `D:\SSRPG\publish\SRPG-v04\runtime\coop-check-1789302306340395000`. 검사 단계 간 대기 표식을 두어 다음 단계의 테스트용 재료/위치 변경이 이전 결과 확인을 앞지르지 않게 했다.
- export-check-v071.json은 배포 EXE/PCK를 별도 폴더로 복사한 실제 실행 결과다. 저장 이행·재실행·UI·직업·코스튬·지역 프레임과 원본 시트 제외를 확인했다.
- DB 생성 후 --check가 같은 JSON/SQLite/캐시를 재현함을 확인했다. SQLite integrity_check=ok, foreign_key_check=0, schema_version=6이다.
- QA 팀이 새 장비 옵션 8종의 소비·생성·캐시·저장 경로를 읽기 리뷰했고 추가 확정 P1/P2를 보고하지 않았다. 실제 실행 검사는 메인 기록과 구분한다.

## 배포 파일

| 파일 | 바이트 | SHA256 |
| --- | ---: | --- |
| StelRPG-V0.7.1-Database.zip | 4875953 | `9ae6a4be85132f91fc706681f6767b44ffe95919f8f7dcfd79a6ebe823574103` |
| StelRPG-V0.7.1-Level100-Test.zip | 2729 | `0b016d36aaa9d42eb58e8c8a7fea9c23cb7212673ff7731fb86c3e2671cae003` |
| StelRPG-V0.7.1-Windows.zip | 583303005 | `b5786fafb28962b62d005700b9bf6d821a0a48f5af632cebaf451ed994ef3897` |

100레벨 테스트 ZIP은 생성한 별도 기록만 포함한다. 일반 캐릭터 저장은 포함하지 않는다. D:/SRPG의 기존 세 슬롯은 보존하고 별도 테스트 바로가기를 설치했다.

## 남은 검증·범위

외부 회선 장시간 접속, 지연·손실·중도 이탈 및 장기 경제/직업 조합 플레이는 완료로 표시하지 않는다. 원정 재접속과 방장 이전은 이번 기능이 아니다. 신규 속성별 효과음의 전수 청취도 완료하지 않았다.

새로 확정된 H2 HUD·채집 중 위험·불필요한 탐사 개체 제거·자연 배치는 V0.7.2로 추적한다. 나머지 벤치마킹 미완료와 3차 전직 보류는 INTEGRATION_V071.ko.md 및 RELEASE_V071.ko.md를 따른다.
