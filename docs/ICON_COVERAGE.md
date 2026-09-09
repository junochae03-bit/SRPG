# 시맨틱 아이콘 커버리지와 검증

대상 작업본: `publish/SRPG-icons` (작업 시작 기준 커밋 `e01b80f`). 이 문서는 검사 범위와 재현 방법을 기록한다. 실행 결과는 `artifacts/icon-verification.json`, 실제 스킬별 매핑은 `artifacts/icon-skill-coverage.json`에 생성한다. 검증 도구 작성 단계에서는 성공을 미리 표시하지 않는다.

## 아이콘 원본과 잘라내기 규칙

`game/assets/icons/semantic_catalog.json`이 고유 키와 원본 위치를 정한다. 총 7종 시트, 시트당 24개, 전체 168개다. 원본은 `wood-{sheet}.png`, 1536×1024 PNG이며 RGB와 RGBA를 모두 지원한다.

| 시트 | 개수 | 의미 범위 |
| --- | ---: | --- |
| interface | 24 | 닫기·확인·검색·필터·저장·설정·도움말 등 공통 조작 |
| inventory | 24 | 장비 슬롯·재화·재료·장착·판매·강화·제작 |
| combat | 24 | 능력치·공격·방어·치명타·사거리·무력화·충전 |
| status | 24 | 회복·보호막·상태 이상·반격·표식·소환·룬·연계 |
| identity | 24 | 직업 20종·몬스터·엘리트·보스·스킬 |
| adventure | 24 | 마을·이동·퀘스트·시설·장착 구성·포인트·빈 슬롯·알 수 없음 |
| abilities | 24 | 무기·원소·카드·주사위·사슬·덫·이동·소환수·직업 자원 |

`sheets[].frames`가 있으면 해당 `[x, y, width, height]`를 실제 이미지 영역으로 사용한다. 없으면 6열×4행, 256픽셀 정규 격자를 사용한다. 검사기는 키 중복, 영역 누락·겹침·원본 밖 잘라내기를 실패로 처리한다. 생성 원본의 배치 오차는 이미지 리샘플링이 아니라 명시된 영역으로 다룬다.

최종 자산은 같은 아틀라스 위치를 유지한 채 배경만 순수 마젠타로 생성 편집한 원본을 사용한다. `GatArt.material()`의 기존 `gat_chroma.gdshader`가 1536×1024 아틀라스의 마젠타를 실제 렌더링 단계에서 제거한다. 종이색·크림색은 도형 내부의 그림으로 유지한다. RGB/RGBA 크로마 원본을 모두 허용하며 알파 채널을 필수로 요구하지 않는다. 검사기는 투명 픽셀과 크로마 픽셀 비율을 각각 기록하고 원본을 덮어쓰거나 보정하지 않는다. 초기 가짜 체크무늬나 불투명 종이색 배경 타일로 수행했던 검사 결과는 이 최종 크로마 자산의 합격 근거로 재사용하지 않는다.

## 스킬 매핑 감사

현재 정의는 20개 직업, 총 610개 노드다. 스킬마다 서로 다른 그림을 강제하지 않는다. 의미가 같은 효과는 같은 시맨틱 키를 공유하며, 180개 전직 강화 노드는 대상 스킬과 같은 아이콘을 사용한다.

| 분류 | 직업 | 노드 | 액티브 | 강화 |
| --- | --- | ---: | ---: | ---: |
| 기존 기초 | warrior, ranger, mage | 각 50 / 총 150 | 총 36 | 0 |
| 전직 | tank, runesword, swordsman, summoner, elementalist, healer, sniper, hunter, explorer, thief, reaper, gambler, infighter, breaker, martialist | 각 30 / 총 450 | 총 180 | 총 180 |
| 추가 기초 | rogue, fighter | 각 5 / 총 10 | 총 8 | 0 |
| 합계 | 20직업 | **610** | **224** | **180** |

`tests/icons.gd`는 모든 노드에 `IconArt.key_for_skill(node)`와 `IconArt.skill(node)`를 호출한다. 선언된 키가 실제 반환 텍스처와 일치하고, 텍스처가 168개 라이브러리 캐시 중 하나이며, `unknown`이나 `skill_empty`가 아닌지 검사한다. 예외 노드나 누락을 허용하는 목록은 없다. 강화 노드의 대상 참조와 텍스처 동일성도 확인한다.

생성되는 `icon-skill-coverage.json`에는 610개 각각의 직업, ID, 이름, 효과, 모드, 아이콘 키를 기록한다. `aliases`는 하나의 아이콘을 공유하는 실제 스킬 ID 목록이다. 이 목록은 의미적 공유를 검토하기 위한 것으로 공유 자체가 실패 조건은 아니다. 알 수 없는 외부 키와 빈 슬롯은 정상적인 UI 상태이므로 별도 폴백 경로를 검사한다.

## 실행 방법

작업 폴더에서 Python과 Pillow, Godot 4.6을 사용한다. `GODOT_EXE`를 지정하거나 기존 `engine_path.py` 탐색 규칙을 따른다. 개발 환경의 보조 위치 `D:/SSRPG/RPG2/tools/godot/Godot_v4.6-stable_win64.exe`도 지원한다.

```powershell
python tools/check_icons.py --assets-only
python tools/check_icons.py --import-only
python tools/check_icons.py --skip-render
python tools/check_icons.py
```

| 명령 | 수행 범위 |
| --- | --- |
| `--assets-only` | 원본 PNG·카탈로그·잘라내기 영역·픽셀 검사. Godot 실행 없음 |
| `--import-only` | 자산 검사와 Godot 프로젝트 import |
| `--skip-render` | 자산·import·610개 스킬 및 라이브러리 모델 검사 |
| 플래그 없음 | 모든 검사와 실제 Godot 갤러리·UI·전투 스크린샷 13장 |

각 실행은 `runtime/icon-checks/<시간>-<프로세스>/`에 로그와 격리된 저장 폴더를 만든다. Godot에는 이 작업 폴더 안의 `--log-file`을 명시한다. 기존 플레이어 저장을 읽거나 변경하지 않는다. `ERROR:`, `SCRIPT ERROR`, `WARNING:` 또는 테스트 실패는 전체 실패다. 모델 실패 이후에도 독립적인 렌더 검사는 수행하되 최종 결과를 성공으로 바꾸지 않는다.

## 실제 렌더 검증과 산출물

`tests/visual_icons.gd`는 실제 Godot 렌더러를 사용한다. 다음 파일은 모형 이미지가 아니라 라이브러리 텍스처와 게임 UI를 그린 화면이다.

- `icons-gallery-24.png`, `icons-gallery-32.png`, `icons-gallery-48.png`: 각각 168개 전부를 해당 최대 변 길이로 실제 `GatArt.material()`을 적용해 렌더한다. 밝고 어두운 표면에서 크로마 제거와 그림 내부 크림색 보존을 함께 확인한다.
- `icons-skills-mage.png`, `icons-skills-gambler.png`, `icons-skills-summoner.png`: 대표적인 원소·카드·소환 스킬 트리와 선택 상세 정보.
- `icons-stats.png`, `icons-hud.png`, `icons-inventory.png`, `icons-portal.png`, `icons-codex.png`: 실제 능력치·전투 HUD·가방·이동·도감 화면.
- `icons-battle-check.png`, `icons-battle-down-empty.png`: 실제 100층 보스의 격노·무력화 집중·무력화 성공, 플레이어/보스 상태 아이콘, 5개 초과 상태 수, 전투 미니맵 및 봉인된 출구. 두 번째 화면에는 기초 전사의 배우지 않은 기본 스킬 F/V/C와 빈 Q/Z/X를 함께 표시한다.

스크린샷을 남기지 않는 직업도 포함하여 20개 직업의 트리를 모두 생성하고 렌더한다. UI 노드 수와 각 버튼의 시맨틱 텍스처 연결, 선택 상세 이미지, 여섯 HUD 슬롯의 그림을 확인한다. Godot 4.6 `Logger`를 통해 비동기 `_draw` 오류와 누락된 리소스도 수집한다. 화면 저장 크기는 1440×900이며 도구는 이전 실행의 오래된 PNG를 성공 근거로 사용하지 않는다.

갤러리 오른쪽 위의 색상 보정 표식도 아틀라스와 같은 1536×1024 검사 텍스처에 같은 GPU 셰이더를 적용한다. 마젠타 영역은 실제 바탕색으로 보이고 크림색 영역은 원래 RGB를 유지해야 한다. 세 갤러리 전체에서 밝은 마젠타 잔여 픽셀이 0인지 Godot 화면 읽기와 저장된 PNG 양쪽에서 검사한다. 이 검사는 셰이더 임계값을 복사한 단위 검사만으로 크림색 보존을 주장하는 대신 실제 출력 픽셀을 확인한다.

상태 모델 검사는 살아 있는 효과와 만료된 효과, 같은 의미의 중복 상태, 빈 actor·사망 actor, 보스의 무력화 상태를 포함한다. 추가로 실제 `job_combat` 버프/디버프 적용 및 `tick_player` 만료 처리 전후의 아이콘을 확인한다. 이 검사는 검사 데이터만 사용하며 게임 규칙을 바꾸지 않는다. 전투 화면도 기존 `stagger_ui_v03.gd`와 같은 상태 형식으로 구성하고 실제 임계치·무력화 전환 함수를 호출한다. 렌더 중 보스 상태가 변경되지 않는지도 검사한다.

## 자동 검사로 단정하지 않는 부분

원본 픽셀 검사는 크로마 분류 마스크를 계산하고, 임시 메모리 합성만으로 24·32·48픽셀에서 비어 있거나 거의 단색인 셀을 걸러낸다. 합성한 파생 이미지를 파일로 저장하지 않는다. 사람에게 무슨 뜻으로 보이는지, 비슷한 표식을 즉시 구분할 수 있는지, 작은 크기에서 장식이 기호를 가리는지는 자동 수치만으로 판단하지 않는다. 완전히 같은 픽셀의 영역은 `icon-asset-audit.json`의 `duplicate_pixel_groups`에 별도로 보고한다.

최종 검토자는 세 갤러리의 168개 전부와 UI 화면에서 실제 가독성, 잘라내기, 옆 타일 침범, 크로마 가장자리와 크림색 디테일 보존, 기존 UI와의 조화를 확인해야 한다. 이번 검사는 전 UI의 모든 hover·pressed·disabled·해상도·입력장치 조합을 열거하지 않는다. 텍스트 라벨과 도구 설명을 유지하는지 검사하며, 아이콘만으로 의미를 전달한다고 가정하지 않는다.

## 실행 결과 기록

도구 문법 검사와 실행 환경 정보는 작업 결과에 기록한다. 최종 합격 수치·화면 검토·잔여 제약은 root가 실제 `icon-verification.json` 및 화면을 확인한 뒤 갱신한다. 생성 파일이 있다는 사실만으로 실행 성공을 표시하지 않는다.

최종 실행 결과(2026-09-09): python tools/check_icons.py PASS — 168 icons / 610 skills / 20 classes / 13 captures; python tools/verify_v01.py PASS — 52,156 checks. 크로마 마젠타 잔여 없음, 크림색 보존 확인. 전용 로그 runtime/icon-checks/20260909-202513-7100. 최종 HUD에서 네모 배경 제거와 나무 토큰 실루엣 확인.
