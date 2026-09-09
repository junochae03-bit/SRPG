# V0.4 배경·몬스터 팩 통합

2026-09-09. 사용자의 준비된 아트 전체 적용 요청에 따라 완료된 4개 팩을 게임에 연결했다. 배경 장식 108개, 일반 몬스터 외형 18종, 레이드 외형 6종을 사용한다. 몬스터는 종별 대기·공격 키 포즈 2장으로 총 48프레임이다. 원본 PNG 30장은 바이트 단위로 보존했고 원본 ZIP·미리보기·독립 Godot 프로젝트는 게임 에셋에 복사하지 않았다.

## 실제 적용

| 층 / 지역 | 배경 테마 | 몬스터 외형 |
| --- | --- | --- |
| 꽃바람 숲 튜토리얼 / B1–10 | forest + bamboo 성소 | 기존 몬스터 |
| 햇살 마을 | forest + ruins | 기존 NPC·건물 유지 |
| B11–20 | cave | 기존 몬스터 |
| B21–30 | flood + ruins + desert 왕릉 | 집게게·앵무조개·거북, B30 닻 기사 |
| B31–40 | spore + marsh | 귀뚜라미·나방·두꺼비, B40 균사 히드라 |
| B41–50 | lava + dragon 둥지 | 도롱뇽·달팽이·코뿔소, B50 용암 용 |
| B51–60 | snow + ice 빙궁 | 기존 몬스터 |
| B61–70 | machine | 톱니 바퀴·박격포·주조 오우거, B70 공성 기계 |
| B71–80 | autumn | 기존 몬스터 |
| B81–90 | nebula + sky 신전 | 수정 전갈·갑오징어·가오리, B90 별고래 |
| B91–100 | core + graveyard 묘지 | 룬 거머리·마도서·산양, B100 왕관 망령 |

`environment_art.gd`가 테마·소스 영역·발 기준점을 읽고 `forest_environment.gd`가 실제 지도에 배치한다. 배경 팩은 장식 원화이며, 바닥은 기존 지도 마스크와 지면 셰이더로 그린다. 보행 가능 칸 주변 5×5 영역과 출발점 6칸·출구 4칸을 비우고 고정 정렬과 부드러운 가림 투명도를 유지한다. 장식 스프라이트 크기를 충돌체로 해석하지 않는다. `draw_prop`는 화면에 그린 ID를 선택적 `record_art_usage` 훅에 기록한다.

`world_art.gd`의 `variant_frame`은 층·전투 상태로 대기/공격 프레임을 선택한다. 같은 종은 두 포즈에 같은 몸체 배율과 개별 발 기준점을 쓴다. 일반 몬스터는 기존 `World.display_height` 체급, 레이드는 대기 몸체 기준 월드 335px다. 공격 포즈 전체 영역이 더 크더라도 몸체를 다시 축소하지 않는다. 정지 키 포즈를 새 보행 애니메이션으로 설명하지 않는다. 큰 공격 포즈가 상단 HUD 뒤로 잘리던 문제는 실제 `update_battle_camera`의 전투 줌·초점으로 보정한다. 지면을 3200×1800으로 확장하고 장식 가시 범위도 현재 캔버스 변환을 따르므로 줌 시 화면 가장자리가 비지 않는다.

일반 몬스터의 전투 종류 ID·AI·수치·드랍 연결을 유지하면서 층별 표시명만 외형에 맞춘다. 예를 들어 용암층의 `orc_champion`은 `lava_obsidian_rhino` 외형과 ‘흑요각 코뿔소’ 표시명을 사용한다. 레이드 이름과 진행 ID는 기존 던전 설정을 따른다. DB의 `appearances`는 실제 아트 영역·발·표시명을 포함하며, 도감의 층 필터는 `monster_on_floor`를 통해 그 층의 외형을 보여 준다. 전체 층 검색의 기본형 기록과 ID는 그대로다.

1536×1024 원화는 마젠타에 가까운 픽셀만 키 처리한다. 배경 키 픽셀과 직접 맞닿은 가장자리에만 색 번짐을 보정하고 내부 보라 자수정·초록 장식·정점 색조·투명도를 보존한다. 프레임 영역은 512/768 고정 분할이 아닌 원본 manifest의 정수 `rect`와 crop 기준 `foot`을 사용한다.

## 재현 및 검증

작업 폴더는 저장소 루트, 런타임은 Godot 4.6 stable이다. `GODOT_EXE` 환경 변수를 설치 경로로 지정한다.

```powershell
$env:GODOT_EXE='D:\SSRPG\RPG2\tools\godot\Godot_v4.6-stable_win64_console.exe'
python tools/integrate_environment_v04.py --check
python tools/run_hidden_check.py environment_v04
python tools/run_hidden_check.py forest_stability
python tools/run_hidden_check.py database_v03
python tools/run_hidden_check.py environment_visual_v04 graphics
```

원본 팩이 갱신되면 `python tools/integrate_environment_v04.py`로 같은 카탈로그와 사본을 재생성한다. `--check`는 소스 PNG SHA, 런타임 사본 바이트, 원본 manifest SHA, 영역·발 범위 및 생성 JSON의 오래된 상태를 검사한다. 새 리소스는 Godot에서 import한 뒤 그래픽 검사를 실행한다.

| 검사 | 확인 결과 |
| --- | --- |
| 원본·사본·카탈로그 검사 | 30시트 / 108장식 / 18일반종 / 6보스 / 48키포즈 PASS |
| `environment_v04` | 29,691 검사, 실패 0. 모든 100층과 마을·튜토리얼, 108장식 전부 사용, 18종·6보스 도달, 이름·도감 대응 확인 |
| `forest_stability` | 고정 순서 변경 0, 부드러운 가림 PASS |
| `database_v03` | 13,089 검사, 실패 0 |
| `environment_visual_v04 graphics` | NVIDIA OpenGL 실제 게임 1920×1080 PNG 22장, 오류 0, exit 0 |

GPU 출력은 로컬 `artifacts/environment-v04-*.png`다. 마을·튜토리얼, 10생태권, 6보스 전투 화면, 전체 장식·판타지 36장식·36일반키포즈·12보스키포즈 갤러리를 검토했다. 마젠타 배경이 제거되고 자수정 내부 보라, 눈 덮인 나뭇가지, 네뷸라 수정과 코어의 초록 빛이 남는다. 카메라 보정 후 B70 공격 팔 전체와 B30/B100 보스가 HUD 아래에 들어오고 확장 지면이 화면을 채우는 것을 확인했다. 첫 입구 이동 전수 검증은 별도 `dungeon_entry_v04` 담당이 수행한다. 최종 EXE·전체 gate·DB 생성물·릴리스 상태는 저장소 최종 검증 보고서를 따른다.

## 원본과 사용 파일

원본 4팩은 `D:/SSRPG/RPG2/art/backgrounds/biomes-20260909`, `D:/SSRPG/RPG2/art/dungeons/dungeon-expansion-20260909`, `D:/SSRPG/RPG2/art/dungeons/dungeon-bosses-20260909`, `D:/SSRPG/RPG2/art/backgrounds/fantasy-expansion-20260909`다. 마지막 팩도 완료 인계를 확인한 뒤 6시트·36장식 전부를 추가했다.

[ENVIRONMENT_V04_PROVENANCE.json](ENVIRONMENT_V04_PROVENANCE.json)에 30개 파일 각각의 원본·런타임 경로, SHA256, 바이트, 사용 객체 ID와 원본 manifest SHA256을 기록한다. 원본 manifest 지문은 다음과 같다.

| 팩 | manifest SHA256 |
| --- | --- |
| biomes | `e40826f27fe0b9e67dfeb19a90b7cb7f6be447c79b3468e23a414e5a0fc5770a` |
| expansion | `dcc254a2a5b914b2d32bc42d172dfef909824ccb7b7a774df27398a0d27a245d` |
| bosses | `f592c7041c238ffb6b475f4b92483fb0142f219ea090f22e6351c9738d8ca282` |
| fantasy | `4b3c0432794b9634870785b96b635e616a4ba3b90a39f4bc7f86efa6fe911071` |

실제 사용 PNG 30개(`game/` 기준):

```text
assets/environment/biomes-v04/forest.png
assets/environment/biomes-v04/cave.png
assets/environment/biomes-v04/ruins.png
assets/environment/biomes-v04/autumn.png
assets/environment/biomes-v04/snow.png
assets/environment/biomes-v04/marsh.png
assets/environment/biomes-v04/flood.png
assets/environment/biomes-v04/spore.png
assets/environment/biomes-v04/lava.png
assets/environment/biomes-v04/machine.png
assets/environment/biomes-v04/nebula.png
assets/environment/biomes-v04/core.png
assets/environment/biomes-v04/desert.png
assets/environment/biomes-v04/sky.png
assets/environment/biomes-v04/ice.png
assets/environment/biomes-v04/graveyard.png
assets/environment/biomes-v04/bamboo.png
assets/environment/biomes-v04/dragon.png
assets/world/dungeon-v04/flood-monsters.png
assets/world/dungeon-v04/spore-monsters.png
assets/world/dungeon-v04/lava-monsters.png
assets/world/dungeon-v04/machine-monsters.png
assets/world/dungeon-v04/nebula-monsters.png
assets/world/dungeon-v04/core-monsters.png
assets/world/dungeon-v04/flood-bosses.png
assets/world/dungeon-v04/spore-bosses.png
assets/world/dungeon-v04/lava-bosses.png
assets/world/dungeon-v04/machine-bosses.png
assets/world/dungeon-v04/nebula-bosses.png
assets/world/dungeon-v04/core-bosses.png
```

좌표·셀·발·종·포즈·기존 몬스터 ID 매핑의 런타임 원본은 `game/assets/environment/biomes-v04/catalog.json`과 `game/assets/world/dungeon-v04/catalog.json`이다. 독립 팩이 새로 완성되면 해당 팩의 완료 인계와 원본 검증을 먼저 확인한 뒤 매핑·검증 범위를 추가한다.
