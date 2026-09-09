# 배경 스프라이트 인계 — 6개 테마 / 36종

2026-09-09 · 수신 작업 트리 `D:/SSRPG/publish/SRPG-v03` · 확인한 HEAD `6e6e6bb`

배경 원화 제작과 원본/좌표 검사는 완료했다. 후속 검사에서 독립 팩의 실제 Godot GPU 렌더와 36개 미리보기를 확인했다. 현재 게임에 자동 연결하지 않은 독립 아트 팩이다. 이번 담당 범위는 배경 36종이며 **장비 스프라이트, 부위·직업·등급 매핑은 포함하지 않았다**.

## 파일 위치

- 원본 팩: [D:/SSRPG/RPG2/art/backgrounds/biomes-20260909](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/CONTENTS.ko.md)
- 전체 ZIP: [biomes-20260909.zip](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909.zip)
- 좌표 원본: [atlas_manifest.json](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/atlas_manifest.json)
- 인계용 전체 경로/좌표/생태권 JSON: [TEAM_HANDOFF_ENVIRONMENT.json](TEAM_HANDOFF_ENVIRONMENT.json)
- 실제 생성·수정 프롬프트와 원본 파일: [generation.json](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/generation.json), 제작 도구는 내장 `image_gen`.
- 사용 안내: [README.ko.md](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/README.ko.md)

모든 PNG는 1536×1024 RGB이며 마젠타 색상 키 배경이다. PNG 자체에 알파 채널은 없다. 원본 PNG를 수정하지 않고 AtlasTexture로 참조한다.

| art_theme | 테마 | 원본 시트 | SHA256 |
|---|---|---|---|
| `forest` | 꽃바람 숲 | [sheets/forest.png](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/sheets/forest.png) | `c3beba3599f958cb3861a95849ca596e15488f625cf29a54bdf4ba24a85cdfb3` |
| `cave` | 수정 동굴 | [sheets/cave.png](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/sheets/cave.png) | `31aeca39ea5d25ec9f36aaa1f3a1cad4785ce023f55ae86d4f090fa45483aa3c` |
| `ruins` | 고대 유적 | [sheets/ruins.png](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/sheets/ruins.png) | `bc4f93cc30fabe265b3a0080918f74a643aebddc316677f12fb05a975b707d8f` |
| `autumn` | 황금 단풍 숲 | [sheets/autumn.png](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/sheets/autumn.png) | `bf46f4b57b21b8c0542898be453e4aa0a4097097c77b18f14af2947fd37e3e52` |
| `snow` | 푸른 설원 | [sheets/snow.png](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/sheets/snow.png) | `863a72bd776de1fab57cae3f346702a6a0123da4d1091306b25a045d23f7b166` |
| `marsh` | 안개 늪지 | [sheets/marsh.png](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/sheets/marsh.png) | `da60035ed3f220b01dea809709199e5a6ff847450b201b5f2fa9239126a705c2` |

## 셀·아틀라스·발 기준점

`source_cell`은 오브젝트를 분리하는 원본 시트 영역이고 `atlas_rect`는 여백을 제외한 실제 그림 영역이다. 둘 다 `[x, y, width, height]` 픽셀이다. 각 행의 열 경계가 달라 **고정 512×512로 자르지 않는다**. 최종 소비에는 각 오브젝트의 `atlas_rect`를 사용한다. 전체 시트의 과거 `columns` 값 대신 `row_columns` 또는 개별 `source_cell`을 사용한다.

`foot`은 잘라낸 `atlas_rect` 내부 좌표다. 그림 하단 4%의 x 중앙값과 마지막 그림 행 y를 기준으로 추정했으며, 물리 충돌 원점이나 시각적으로 최종 승인된 발 위치는 아니다. 제공된 Sprite2D는 `centered=false`, `offset=-foot`, `texture_filter=1`로 설정되어 있다. 직접 그리기에서는 `world_point - foot * scale`을 사용한다.

아래 ID마다 팩의 `atlases/<asset_id>.tres`, `sprites/<asset_id>.tscn`가 한 쌍으로 있다. JSON에는 두 파일의 절대 경로가 모두 포함된다. 번호는 위 행 왼쪽부터 1–3, 아래 행 왼쪽부터 4–6이다.

| asset_id | 이름 | 칸 | source_cell | atlas_rect | foot |
|---|---|---:|---|---|---|
| `forest_oak_tree` | 참나무 | 1 | `0, 0, 545, 572` | `42, 40, 466, 530` | `233.0, 529` |
| `forest_birch_tree` | 자작나무 | 2 | `545, 0, 436, 572` | `582, 19, 358, 544` | `187.0, 543` |
| `forest_mossy_boulders` | 이끼 바위 | 3 | `981, 0, 555, 572` | `1023, 203, 476, 354` | `265.0, 353` |
| `forest_flower_shrub` | 꽃 덤불 | 4 | `0, 572, 498, 452` | `48, 630, 418, 338` | `216.0, 337` |
| `forest_hollow_log` | 속 빈 통나무 | 5 | `498, 572, 580, 452` | `531, 663, 493, 276` | `136.5, 275` |
| `forest_signpost` | 나무 표지판 | 6 | `1078, 572, 458, 452` | `1180, 576, 299, 415` | `98.0, 414` |
| `cave_cyan_crystals` | 청색 수정 | 1 | `0, 0, 537, 524` | `50, 38, 435, 467` | `214.0, 466` |
| `cave_stalagmites` | 석순 | 2 | `537, 0, 469, 524` | `590, 31, 378, 487` | `147.0, 486` |
| `cave_amethyst_geode` | 자수정 정동 | 3 | `1006, 0, 530, 524` | `1045, 137, 458, 374` | `291.0, 373` |
| `cave_glowing_mushrooms` | 발광 버섯 | 4 | `0, 524, 525, 500` | `44, 568, 451, 408` | `184.0, 407` |
| `cave_ore_boulders` | 광석 바위 | 5 | `525, 524, 505, 500` | `556, 607, 443, 362` | `183.0, 361` |
| `cave_mine_arch` | 갱도 지지대 | 6 | `1030, 524, 506, 500` | `1062, 529, 445, 449` | `339.0, 448` |
| `ruins_ivy_arch` | 덩굴 아치 | 1 | `0, 0, 554, 545` | `40, 56, 446, 437` | `106.0, 436` |
| `ruins_obelisk` | 오벨리스크 | 2 | `554, 0, 464, 545` | `646, 38, 261, 460` | `130.0, 459` |
| `ruins_broken_column` | 부서진 기둥 | 3 | `1018, 0, 518, 545` | `1121, 52, 337, 442` | `138.0, 441` |
| `ruins_wall_corner` | 돌담 모서리 | 4 | `0, 545, 561, 479` | `31, 604, 471, 351` | `350.0, 350` |
| `ruins_stone_basin` | 돌 수반 | 5 | `561, 545, 428, 479` | `623, 592, 310, 366` | `128.0, 365` |
| `ruins_rubble` | 석재 잔해 | 6 | `989, 545, 547, 479` | `1045, 641, 467, 305` | `176.0, 304` |
| `autumn_maple_tree` | 단풍나무 | 1 | `0, 0, 522, 521` | `39, 20, 459, 500` | `223.0, 499` |
| `autumn_ginkgo_tree` | 은행나무 | 2 | `522, 0, 482, 521` | `547, 20, 441, 500` | `211.0, 499` |
| `autumn_leafy_boulders` | 낙엽 바위 | 3 | `1004, 0, 532, 521` | `1021, 151, 485, 346` | `281.0, 345` |
| `autumn_berry_shrub` | 열매 덤불 | 4 | `0, 521, 527, 503` | `62, 577, 438, 378` | `211.0, 377` |
| `autumn_mushroom_stump` | 버섯 그루터기 | 5 | `527, 521, 533, 503` | `554, 627, 434, 325` | `181.0, 324` |
| `autumn_lantern_post` | 가을 등불 | 6 | `1060, 521, 476, 503` | `1144, 522, 279, 452` | `92.0, 451` |
| `snow_snow_fir` | 눈 전나무 | 1 | `0, 0, 523, 533` | `50, 20, 423, 502` | `205.0, 501` |
| `snow_frost_birch` | 서리 자작나무 | 2 | `523, 0, 487, 533` | `574, 21, 383, 497` | `219.0, 496` |
| `snow_ice_boulders` | 얼음 바위 | 3 | `1010, 0, 526, 533` | `1063, 182, 428, 338` | `226.0, 337` |
| `snow_snow_shrub` | 눈 덤불 | 4 | `0, 533, 533, 491` | `72, 646, 373, 318` | `172.0, 317` |
| `snow_snow_lantern` | 설원 등불 | 5 | `533, 533, 484, 491` | `638, 544, 262, 437` | `90.0, 436` |
| `snow_stone_cairn` | 눈 돌탑 | 6 | `1017, 533, 519, 491` | `1120, 614, 314, 349` | `195.0, 348` |
| `marsh_willow_tree` | 버드나무 | 1 | `0, 0, 529, 540` | `33, 32, 454, 482` | `226.5, 481` |
| `marsh_hollow_cypress` | 속 빈 고목 | 2 | `529, 0, 462, 540` | `571, 22, 388, 506` | `153.0, 505` |
| `marsh_fern_boulders` | 고사리 바위 | 3 | `991, 0, 545, 540` | `1023, 178, 484, 337` | `253.0, 336` |
| `marsh_cattails` | 부들 | 4 | `0, 540, 507, 484` | `47, 550, 406, 414` | `205.0, 413` |
| `marsh_shelf_mushrooms` | 선반 버섯 | 5 | `507, 540, 493, 484` | `562, 614, 390, 324` | `198.0, 323` |
| `marsh_boardwalk` | 나무 보행로 | 6 | `1000, 540, 536, 484` | `1049, 594, 446, 352` | `262.0, 351` |

## 기존 생태권과 새 아트의 연결 제안

아래 `chapter`·층·생태권·`terrain`은 현재 코드 값이고, 마지막 열은 **모두 미구현 아트 연결 제안**이다. `chapter=int((floor-1)/10)`이다. `autumn`, `snow`, `marsh`를 새로운 zone ID로 넘기면 안 된다. 도감/DB에 환경 분류를 추가할 경우 아트 테마를 별도 필드(`art_theme` 등)에 두고 기존 `chapter`와 `terrain`을 보존한다.

| chapter | 층 | 생태권 | 실제 terrain | 연결 제안 |
|---:|---|---|---|---|
| 0 | B1–10 | 뿌리 내린 동굴숲 | `forest` | forest 시트 전체 |
| 1 | B11–20 | 수정 광맥 | `cave` | cave 시트 전체 |
| 2 | B21–30 | 잠긴 회랑 | `ruins` | ruins 중심, marsh_boardwalk는 선택적 보조 |
| 3 | B31–40 | 포자 정원 | `forest` | marsh 고목·고사리·버섯, cave_glowing_mushrooms |
| 4 | B41–50 | 잿불 용암굴 | `cave` | 전용 용암 원화 없음; 기존 렌더 유지 |
| 5 | B51–60 | 빙하의 균열 | `cave` | snow_ice_boulders·snow_stone_cairn 중심 |
| 6 | B61–70 | 버려진 기계도시 | `ruins` | 전용 기계 원화 없음; ruins_rubble 등 석재 보조 |
| 7 | B71–80 | 황혼의 수림 | `forest` | autumn 시트 전체 |
| 8 | B81–90 | 성운의 공동 | `cave` | 전용 성운 원화 없음; cave 수정류 보조 |
| 9 | B91–100 | 뒤틀린 마력핵 | `ruins` | 전용 마력핵 원화 없음; ruins_obelisk 등 보조 |

근거: [abyss_catalog.gd](../game/scripts/abyss_catalog.gd:3), [world_catalog.gd](../game/scripts/world_catalog.gd:2), [local_session.gd](../game/scripts/local_session.gd:44), [GDD_V02.ko.md](GDD_V02.ko.md:11). 현재 허용 zone은 `town/forest/cave/ruins`다. 조사 시점에 환경 도감 전용 DB 스키마는 없으며 V0.3 계획의 도감 범위는 장비·몬스터·드랍·스킬이다.

## Godot 연결 시 필요한 처리

1. 원본 팩을 보존하고 새 작업 트리의 별도 에셋 하위 폴더에 필요한 PNG/리소스만 복사한다. 팩의 `project.godot`는 독립 미리보기용이므로 게임 프로젝트 파일을 대체하지 않는다.
2. `.tres/.tscn`의 `res://sheets/`, `res://atlases/`, `res://chroma_key.tres`와 머티리얼의 `res://chroma_key.gdshader`를 복사한 하위 폴더에 맞게 바꾼다. 직접 로드하는 소비자는 인계 JSON의 좌표로 AtlasTexture를 만들 수 있다.
3. [chroma_key.tres](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/chroma_key.tres)와 [chroma_key.gdshader](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/chroma_key.gdshader)를 적용한다. `key_distance=max(abs(sample_rgb-vec3(1,0,1)))`, `key_inner=0.15`, `key_outer=0.20`이며 최근접 샘플링을 사용한다. 넓은 빨강/파랑 임계값으로 대체하면 자수정 색을 제거할 수 있다. 보라색 결정면 보존은 독립 GPU 미리보기에서 확인했으며, 실제 게임 배치와 최종 표시 크기의 테두리 검사는 별도로 남아 있다.
4. 현재 [forest_environment.gd](../game/scripts/forest_environment.gd:15)는 기존 `forest_props.png`/`atlas_regions.json`만 읽는다. 기존 순서는 `oak,pine,rocks,shrub,sign,shelter`이고 신규 시트의 순서/의미와 다르므로 시트만 덮어쓰면 안 된다. 생태권별 선택 로직과 신규 foot 소비를 명시적으로 연결한다.
5. 현행 렌더의 기준점 `(width*0.5,height*0.97)`은 신규 `foot`과 다르다. [그리기 코드](../game/scripts/forest_environment.gd:129)를 연결할 때 둘 중 하나를 명확히 선택한다. 기존 cave의 모든 prop→rocks, ruins의 큰 나무→rocks 대체도 새 아트 매핑과 함께 검토한다.

## 검증과 미리보기

- 사전 인계 검증 기록: PNG 6개 규격/원본 SHA256 일치, 36개 영역의 범위·셀 여백, AtlasTexture 36개 및 Sprite2D 36개 파일 존재, ZIP 무결성 및 ZIP/현재 manifest 일치.
- 2026-09-09 후속 GPU 검증: 기존 `capture_preview.py`를 Godot 4.6에서 실행했다. import와 실제 렌더 모두 exit 0이며 `ERROR:`·`SCRIPT ERROR`가 없다. OpenGL 3.3 Compatibility / NVIDIA GeForce RTX 4070 SUPER에서 **36/36개 로드**, 실패 목록 없음, PNG 저장 오류 0.
- 실제 캡처: [preview-overview.png](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/preview-overview.png), 보고된 크기 **1288×1145**. 6개 테마의 36개 원화와 라벨이 모두 보이며 잘린 오브젝트는 관찰되지 않았다.
- 색상 키 확인: 큰 마젠타 배경 사각형은 제거되었고 순수 `#FF00FF` 픽셀은 0개다. 다만 `R≥204, G≤51, B≥204`인 근접 마젠타 픽셀이 76개 남아 있으며, 일부 잎·가는 가지 가장자리에서 자홍색 점이 보인다. 실제 게임 표시 크기에서 이 국소 테두리를 추가 확인해야 하므로 가장자리 품질까지 최종 승인한 것은 아니다.
- 자수정 보존: `cave_amethyst_geode`의 보라색 내부와 결정면이 렌더에서 유지되는 것을 확인했다. 해당 카드의 보라색 조건 픽셀은 3,868개다. 이 개수는 시각 검토 보조 자료이며 원화 전체의 색상 일치율을 뜻하지 않는다.
- 렌더 후 PNG 6개가 모두 1536×1024 RGB이고 SHA256이 기존 manifest와 일치함을 다시 검사했다. 원본 시트·셰이더·미리보기 소스·게임 코드를 변경하지 않았다. 전체 ZIP은 재작성하지 않았으므로 새 검증 PNG와 보고서는 위 독립 경로에서 확인한다.
- 로그: [validation/godot-import.log](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/validation/godot-import.log), [validation/godot-preview.log](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/validation/godot-preview.log). 이전 import 실패 로그 위치에는 이번 정상 실행 결과가 기록되었다.
- 보고서: [validation/preview_report.json](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/validation/preview_report.json), [validation/visual_review.json](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/validation/visual_review.json).
- 독립 미리보기 소스: [project.godot](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/project.godot), [preview.gd](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/preview.gd), [capture_preview.py](D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/capture_preview.py).

실행 권한이 있는 환경에서 기존 팩을 렌더하려면:

```powershell
python 'D:/SSRPG/RPG2/art/backgrounds/biomes-20260909/capture_preview.py' --engine 'D:/SSRPG/RPG2/tools/godot/Godot_v4.6-stable_win64_console.exe'
```

원본 생성 PNG와 기존 게임 파일은 이번 후속 검증에서 변경하지 않았다. 독립 팩의 예정 미리보기 경로와 `validation` 폴더에 검증 결과를 작성했고, 이 문서의 검증 상태를 갱신했다. 게임 연결 제안과 인계 JSON의 좌표·매핑은 유지했다.
