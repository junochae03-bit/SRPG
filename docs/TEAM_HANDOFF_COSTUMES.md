# 코스튬 원화·아틀라스 인계

확인일: 2026-09-09. 실제 조사 위치는 `D:/SSRPG/RPG2/art/skins/`입니다. 이 문서는 준비된 자산을 확인한 인계 자료이며, 게임 파일 복사·등록·배포를 수행한 기록이 아닙니다.

**완성 원화는 6묶음, PNG 22장, 시트당 16포즈로 총 352포즈 구성입니다.** 이 중 19장에 측정한 아틀라스 JSON이 있으며 304개 영역을 재검증했습니다. 첫 민트 3장은 원화만 있고 분할 좌표가 없습니다. 22장 모두 1254 × 1254 RGB PNG로, 알파 채널이 없습니다.

`raven-reference-20260909`는 현재 제작 중이므로 완료 수량과 검증에서 제외했습니다. 이후 생기는 파일은 이번 인계 결과에 포함하지 않습니다.

## 준비된 묶음

| 묶음 | PNG / 포즈 | 아틀라스 | 배경 키 | 문서·패키지 |
| --- | ---: | ---: | --- | --- |
| mint | 3 / 48 | 0 | 마젠타 | [폴더 설명](D:/SSRPG/RPG2/art/skins/mint-reference-20260909/README.ko.md) · [ZIP](D:/SSRPG/RPG2/art/skins/mint-reference-20260909.zip) |
| pink | 3 / 48 | 3 | 파랑 | [폴더 설명](D:/SSRPG/RPG2/art/skins/pink-reference-20260909/README.ko.md) · [ZIP](D:/SSRPG/RPG2/art/skins/pink-reference-20260909.zip) |
| lavender | 3 / 48 | 3 | 파랑 | [폴더 설명](D:/SSRPG/RPG2/art/skins/lavender-reference-20260909/README.ko.md) · [ZIP](D:/SSRPG/RPG2/art/skins/lavender-reference-20260909.zip) |
| aqua | 4 / 64 | 4 | 마젠타 | [폴더 설명](D:/SSRPG/RPG2/art/skins/aqua-reference-20260909/README.ko.md) · [ZIP](D:/SSRPG/RPG2/art/skins/aqua-reference-20260909.zip) |
| crimson | 4 / 64 | 4 | 파랑 | [폴더 설명](D:/SSRPG/RPG2/art/skins/crimson-reference-20260909/README.ko.md) · [ZIP](D:/SSRPG/RPG2/art/skins/crimson-reference-20260909.zip) |
| silvercat | 5 / 80 | 5 | 파랑 | [폴더 설명](D:/SSRPG/RPG2/art/skins/silvercat-reference-20260909/README.ko.md) · [ZIP](D:/SSRPG/RPG2/art/skins/silvercat-reference-20260909.zip) |

각 묶음의 `PROMPTS.md`에 내장 image_gen 생성 프롬프트와 사용자 참고 이미지 경로가 있습니다. 민트는 `BACKGROUND-PROMPTS.md`, 보라색은 `EYE-CORRECTIONS.md`, 붉은색은 `LAYOUT-CORRECTIONS.md`에 추가 편집 프롬프트가 있습니다. PNG는 편집 가능한 레이어 원본이 아닌 최종 선택 래스터 시트입니다.

## 시트별 미리보기와 실제 프레임 크기

아래 ID는 **파일 식별자**입니다. 기존 게임 코스튬 ID로 등록되지 않았습니다. PNG 링크가 원본 미리보기이며, 별도 애니메이션 GIF나 게임 내 미리보기 실행기는 없습니다. 크기 범위는 각 시트의 16개 `rect`에 기록된 폭과 높이의 최솟값–최댓값입니다.

| 파일 ID | 의상 | 미리보기 | 아틀라스 | 실제 rect 폭 × 높이 범위(px) |
| --- | --- | --- | --- | --- |
| `mint-hanbok` | 민트 한복·꽃 장식 | [PNG](D:/SSRPG/RPG2/art/skins/mint-reference-20260909/mint-hanbok-sheet.png) | 없음 | 미측정 |
| `mint-silver-knight` | 백은 갑옷·민트 망토 | [PNG](D:/SSRPG/RPG2/art/skins/mint-reference-20260909/mint-silver-knight-sheet.png) | 없음 | 미측정 |
| `mint-summer` | 하트 고글·여름 재킷 | [PNG](D:/SSRPG/RPG2/art/skins/mint-reference-20260909/mint-summer-sheet.png) | 없음 | 미측정 |
| `pink-beret-gunner` | 검은 베레모·전투복 | [PNG](D:/SSRPG/RPG2/art/skins/pink-reference-20260909/pink-beret-gunner-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/pink-reference-20260909/pink-beret-gunner-atlas.json) | 205–305 × 202–303 |
| `pink-black-veil-hanbok` | 검은 베일 한복 | [PNG](D:/SSRPG/RPG2/art/skins/pink-reference-20260909/pink-black-veil-hanbok-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/pink-reference-20260909/pink-black-veil-hanbok-atlas.json) | 216–291 × 216–284 |
| `pink-bunny-hoodie` | 분홍 토끼 후드 | [PNG](D:/SSRPG/RPG2/art/skins/pink-reference-20260909/pink-bunny-hoodie-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/pink-reference-20260909/pink-bunny-hoodie-atlas.json) | 201–284 × 221–315 |
| `lavender-sailor` | 여름 세일러 | [PNG](D:/SSRPG/RPG2/art/skins/lavender-reference-20260909/lavender-sailor-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/lavender-reference-20260909/lavender-sailor-atlas.json) | 194–293 × 214–306 |
| `lavender-shrine-maiden` | 무녀복 | [PNG](D:/SSRPG/RPG2/art/skins/lavender-reference-20260909/lavender-shrine-maiden-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/lavender-reference-20260909/lavender-shrine-maiden-atlas.json) | 182–294 × 212–312 |
| `lavender-winter-hanbok` | 겨울 한복·털 망토 | [PNG](D:/SSRPG/RPG2/art/skins/lavender-reference-20260909/lavender-winter-hanbok-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/lavender-reference-20260909/lavender-winter-hanbok-atlas.json) | 184–325 × 206–303 |
| `aqua-goggles-explorer` | 고글 탐험복 | [PNG](D:/SSRPG/RPG2/art/skins/aqua-reference-20260909/aqua-goggles-explorer-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/aqua-reference-20260909/aqua-goggles-explorer-atlas.json) | 176–316 × 190–286 |
| `aqua-pajama` | 파자마 | [PNG](D:/SSRPG/RPG2/art/skins/aqua-reference-20260909/aqua-pajama-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/aqua-reference-20260909/aqua-pajama-atlas.json) | 170–315 × 212–297 |
| `aqua-rabbit-stage` | 토끼 무대복 | [PNG](D:/SSRPG/RPG2/art/skins/aqua-reference-20260909/aqua-rabbit-stage-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/aqua-reference-20260909/aqua-rabbit-stage-atlas.json) | 152–278 × 231–313 |
| `aqua-winter-hanbok` | 겨울 한복·흰 패딩 | [PNG](D:/SSRPG/RPG2/art/skins/aqua-reference-20260909/aqua-winter-hanbok-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/aqua-reference-20260909/aqua-winter-hanbok-atlas.json) | 197–299 × 203–291 |
| `crimson-black-dress` | 검은 드레스 | [PNG](D:/SSRPG/RPG2/art/skins/crimson-reference-20260909/crimson-black-dress-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/crimson-reference-20260909/crimson-black-dress-atlas.json) | 224–319 × 203–300 |
| `crimson-black-jacket` | 검정 재킷 | [PNG](D:/SSRPG/RPG2/art/skins/crimson-reference-20260909/crimson-black-jacket-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/crimson-reference-20260909/crimson-black-jacket-atlas.json) | 211–341 × 209–306 |
| `crimson-pastel-rabbit` | 파스텔 토끼복 | [PNG](D:/SSRPG/RPG2/art/skins/crimson-reference-20260909/crimson-pastel-rabbit-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/crimson-reference-20260909/crimson-pastel-rabbit-atlas.json) | 215–315 × 210–286 |
| `crimson-rose-gothic` | 장미 고딕·우산·날개 | [PNG](D:/SSRPG/RPG2/art/skins/crimson-reference-20260909/crimson-rose-gothic-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/crimson-reference-20260909/crimson-rose-gothic-atlas.json) | 246–330 × 215–299 |
| `silvercat-black-uniform` | 검은 제복 | [PNG](D:/SSRPG/RPG2/art/skins/silvercat-reference-20260909/silvercat-black-uniform-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/silvercat-reference-20260909/silvercat-black-uniform-atlas.json) | 165–248 × 213–311 |
| `silvercat-blossom-hanbok` | 벚꽃 한복 | [PNG](D:/SSRPG/RPG2/art/skins/silvercat-reference-20260909/silvercat-blossom-hanbok-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/silvercat-reference-20260909/silvercat-blossom-hanbok-atlas.json) | 191–279 × 198–290 |
| `silvercat-pink-maid` | 핑크 메이드 | [PNG](D:/SSRPG/RPG2/art/skins/silvercat-reference-20260909/silvercat-pink-maid-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/silvercat-reference-20260909/silvercat-pink-maid-atlas.json) | 218–280 × 198–279 |
| `silvercat-street` | 스트리트 | [PNG](D:/SSRPG/RPG2/art/skins/silvercat-reference-20260909/silvercat-street-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/silvercat-reference-20260909/silvercat-street-atlas.json) | 186–258 × 223–282 |
| `silvercat-summer-resort` | 여름 리조트 | [PNG](D:/SSRPG/RPG2/art/skins/silvercat-reference-20260909/silvercat-summer-resort-sheet.png) | [JSON](D:/SSRPG/RPG2/art/skins/silvercat-reference-20260909/silvercat-summer-resort-atlas.json) | 229–288 × 199–289 |

민트 3종은 README에 이웃 칸 여백까지 뻗는 검·검기 효과와 비균등 배치가 명시되어 있습니다. 동일 크기의 4 × 4 격자로 자동 분할할 수 있다고 판단하지 않았으며, 개별 영역 측정이 추가로 필요합니다.

## 16포즈 행·열과 액션

왼쪽부터 오른쪽, 위에서 아래 순서이며 인덱스는 0부터 시작합니다. 행·열도 JSON에서는 0부터 시작합니다.

| 표시 행 | 1열 | 2열 | 3열 | 4열 |
| --- | --- | --- | --- | --- |
| 1행 | 0 이동 | 1 이동 | 2 이동 | 3 이동 |
| 2행 | 4 일반 공격 | 5 일반 공격 | 6 일반 공격 | 7 일반 공격 |
| 3행 | 8 강한 공격 | 9 강한 공격 | 10 강한 공격 | 11 강한 공격 |
| 4행 | 12 회피 | 13 회피 | 14 피격 | 15 대기 |

민트는 검 공격, pink는 권총 사격, lavender는 금빛 마법, aqua는 얼음 마법, crimson은 꽃잎 마법, silvercat은 발바닥 모양 마법 계열입니다. 캐릭터와 소품·효과가 한 PNG에 함께 그려져 있으며 분리된 무기나 VFX 레이어가 아닙니다. 방향별 걷기 4행 시트가 아니라 오른쪽 사선 시점의 행동 포즈 구성입니다. 실제 루프 연결과 속도는 런타임에서 확인해야 합니다.

JSON의 `action_map`은 pink에서 `move / normal_shot / power_shot / dodge / hurt / idle`, 나머지 16개 JSON에서 `move / basic_spell / strong_spell / dodge / hurt / idle`입니다. 민트에는 JSON 액션 맵이 없습니다. 기존 엔진의 `attack` 키에 대한 변환 규칙은 아직 정하지 않았습니다.

## 좌표·발 기준점·크로마키 계약

- `frames[].rect = [x, y, width, height]`는 원본 PNG 좌상단 기준 정수 좌표이고 오른쪽·아래 끝은 포함하지 않습니다. `cell_rect`는 포즈 구분을 위해 잡은 셀 영역입니다. 실제 그림 영역 `rect`를 사용하고, 원본을 균등 4등분하지 마세요.
- `origin_bottom_center = [width / 2, height]`, `origin_sheet = [x + width / 2, y + height]`입니다. 둘 다 **그림 영역의 기하학적 바닥 중앙 추정값**이며 발·몸 중심에 맞춘 피벗이 아닙니다. 귀·꼬리·옷자락·무기·마법 효과에 따라 영역 중심이 달라집니다.
- 프레임마다 실제 발 위치를 보정하고 의상별 공통 몸 크기로 배율을 맞춘 뒤 이동·공격·회피를 재생해 확인해야 합니다. JSON의 `origin_*`가 기존 GAT 메타데이터의 `foot`와 자동 호환되지는 않습니다.
- 파란 배경 키 후보: 정규화 채널 기준 `R < 0.25 && G < 0.25 && B > 0.65`. 마젠타 키 후보: `R > 0.65 && B > 0.65 && G < 0.35`. 생성 배경은 한 RGB 값으로 완전히 고정되지 않았습니다.
- 현재 확인한 `RPG2/game/shaders/gat_chroma.gdshader`는 마젠타 조건만 처리합니다. 따라서 파란 배경 15개 시트는 해당 셰이더만으로 투명해지지 않습니다. 의상색 보존을 확인하면서 배경 제거 또는 키별 처리 연결이 필요합니다.
- 측정한 셀 경계는 모두 배경으로 비어 있지만 최저 여백은 2px입니다. 필터링·아틀라스 경계 번짐·추가 패딩은 게임에서 검증하지 않았습니다.

## 기존 ID 매핑과 적용 담당

`RPG2/game`와 `publish/SRPG/game`의 `.gd / .json / .tres / .tscn`에서 이번 22개 파일 ID·접두사를 검색했으며 신규 자산 참조를 찾지 못했습니다. 두 작업본의 `scripts/content.gd`에서 확인한 기존 ID는 다음과 같습니다.

- `none`, `traveler`, `witch`, `starlight`, `celestial`
- `gat_addition_01_1`, `gat_addition_05_2`, `gat_addition_10_2`, `gat_addition_11_2`, `gat_addition_12_1`, `gat_addition_02_2`

`assets/costumes/animations.json`은 기존 코스튬의 프레임 경로 목록이고 `scripts/gat_art.gd`는 GAT의 `rect / foot / body_height` 경로를 읽습니다. 이번 독립 JSON을 읽는 어댑터, 기존 ID와의 대응표, 저장 데이터 마이그레이션, 도감·DB 등록은 없습니다. 이름이나 색상이 비슷하다는 이유로 기존 ID를 대응시키지 않았습니다.

이 스킨 제작 범위에서는 별도 장비 아이콘·착용 레이어·아이템 ID별 장비 스프라이트 산출물을 확인하지 못했습니다. 시트 안에 그려진 검·권총·우산은 캐릭터 원화 일부입니다. 장비 스프라이트 작업을 담당한다고 볼 근거는 없으며 다른 장비 작업의 완료 여부는 이 문서가 보증하지 않습니다.

원화 전체와 게임 코드 동기화·ID 등록·런타임 적용·git push는 메인 작업에서 결정합니다. 공유받은 도감/DB·보스 무력화 V0.3 경로는 `D:/SSRPG/publish/SRPG-v03`, 브랜치는 `feature/codex-stagger-v03`, 전달받은 Main V0.2 기준은 `6e6e6bb`입니다. 이는 전달 문맥이며 이 조사에서 V0.3 작업본이나 git 연결을 변경하지 않았습니다.

## 이번 확인 결과

완료 확인에는 completion-verification 절차를 적용했습니다. Pillow/numpy로 PNG를 읽기만 하고 JSON과 대조했으며, ZIP도 열어 내부 파일을 확인했습니다. 자산 픽셀은 수정하지 않았습니다.

| 확인 항목 | 결과 |
| --- | --- |
| PNG 파일 열기·실제 크기·모드 | 22/22개, 1254 × 1254 RGB, 키 후보 픽셀 존재 |
| 아틀라스 원본 SHA-256·크기·모드·키 픽셀 수 | 19/19개 현재 PNG와 일치 |
| 프레임 개수·영역별 비배경 픽셀 수 | 19 × 16 = 304개, JSON과 일치 |
| 지정 키 기준 전체 비배경 픽셀 포함 | 10,989,825개, 각 픽셀을 정확히 한 프레임이 포함 |
| 모든 셀 경계의 그림 침범 여부 | 19/19개 경계 공백 확인 |
| 임시 원점 계산 | 304개 모두 기하학적 바닥 중앙 공식과 일치 |
| PROVENANCE 기록과 현재 PNG 해시 | 기록이 있는 19/19개 일치 |
| 별도 생성 원본 파일까지 재대조 | 원본 파일명이 기록된 lavender/aqua/crimson/silvercat 16/16개 일치 |
| 기존 ZIP 무결성·현재 폴더 파일 일치 | 6/6개 통과 |
| 기존 게임의 신규 ID 연결 | 검사한 두 게임 폴더에서 참조 확인 못함 |

pink 3종의 PROVENANCE에는 선택 원본 파일명이 없어 당시 생성 원본까지 재추적하지 않았고, 현재 PNG와 기록된 SHA는 일치합니다. 민트에는 PROVENANCE/아틀라스가 없으므로 현재 파일 해시를 아래에 기록했습니다.

각 묶음 README의 제작 시 육안 확인 기록을 읽었습니다. 이번 인계 조사는 픽셀 영역·메타데이터·파일 무결성에 대한 재검증이며 352개 포즈의 형태 품질이나 애니메이션 연속성을 새로 보증하는 검사는 아닙니다. 투명 배경 처리, 발 피벗 보정, 게임 실행·재생, 장비 조합, 저장·불러오기, 빌드·배포는 수행하지 않았습니다.

## 부록: 프레임별 실제 rect 크기

각 칸의 네 쌍은 해당 행의 왼쪽부터 오른쪽 순서이며 단위는 px입니다. 위치 좌표와 프레임별 임시 원점은 해당 아틀라스 JSON을 사용합니다.

| 파일 ID | 0–3 폭×높이 | 4–7 폭×높이 | 8–11 폭×높이 | 12–15 폭×높이 |
| --- | --- | --- | --- | --- |
| `pink-beret-gunner` | 239×303, 229×302, 222×299, 238×303 | 248×282, 297×282, 250×282, 241×281 | 236×250, 235×259, 305×254, 235×252 | 284×206, 235×202, 205×249, 206×263 |
| `pink-black-veil-hanbok` | 235×282, 239×282, 242×281, 238×284 | 243×274, 282×276, 254×276, 245×276 | 249×247, 245×254, 291×254, 249×247 | 286×216, 248×229, 227×264, 216×276 |
| `pink-bunny-hoodie` | 220×313, 208×314, 231×314, 218×315 | 232×288, 284×284, 252×283, 236×284 | 228×258, 223×271, 274×267, 221×265 | 257×221, 248×231, 223×261, 201×276 |
| `lavender-sailor` | 221×306, 234×302, 229×301, 227×305 | 232×296, 285×292, 237×288, 208×295 | 207×276, 219×278, 293×275, 197×281 | 271×214, 243×226, 201×269, 194×276 |
| `lavender-shrine-maiden` | 226×312, 221×307, 219×312, 218×311 | 241×295, 293×291, 258×289, 203×292 | 222×275, 237×281, 294×272, 206×276 | 283×212, 237×214, 215×259, 182×256 |
| `lavender-winter-hanbok` | 223×303, 210×303, 219×301, 208×303 | 191×295, 300×291, 266×291, 225×292 | 215×272, 213×296, 325×275, 204×275 | 261×206, 238×227, 215×264, 184×269 |
| `aqua-goggles-explorer` | 200×279, 208×278, 201×279, 207×279 | 235×274, 292×266, 267×268, 182×269 | 220×236, 238×286, 316×247, 187×262 | 291×197, 217×190, 213×242, 176×254 |
| `aqua-pajama` | 187×294, 183×295, 179×295, 182×295 | 190×297, 279×293, 225×289, 170×294 | 214×262, 201×284, 315×273, 191×270 | 279×212, 228×215, 205×258, 171×276 |
| `aqua-rabbit-stage` | 169×310, 160×312, 166×313, 152×312 | 167×303, 278×302, 191×299, 152×302 | 192×272, 196×288, 273×283, 165×288 | 259×240, 197×231, 179×253, 152×264 |
| `aqua-winter-hanbok` | 208×291, 203×288, 200×289, 206×290 | 225×281, 287×274, 259×276, 204×280 | 216×239, 216×275, 299×258, 212×264 | 283×209, 233×203, 224×241, 197×270 |
| `crimson-black-dress` | 227×299, 226×299, 234×297, 233×300 | 265×291, 279×290, 282×284, 254×289 | 246×268, 258×276, 319×271, 246×269 | 297×205, 264×203, 224×250, 230×264 |
| `crimson-black-jacket` | 226×304, 216×306, 227×301, 219×304 | 238×290, 270×290, 306×290, 211×290 | 219×257, 278×271, 341×269, 233×267 | 273×215, 235×209, 219×259, 219×264 |
| `crimson-pastel-rabbit` | 238×284, 241×285, 239×284, 234×286 | 247×273, 315×274, 287×274, 232×274 | 233×257, 275×272, 308×260, 236×263 | 296×210, 280×211, 251×243, 215×271 |
| `crimson-rose-gothic` | 268×299, 259×299, 266×296, 260×298 | 246×285, 303×290, 297×285, 255×289 | 266×264, 269×278, 330×276, 252×274 | 282×215, 266×223, 249×236, 247×268 |
| `silvercat-black-uniform` | 182×310, 178×310, 179×311, 188×311 | 206×295, 177×294, 244×291, 176×293 | 196×283, 212×301, 248×281, 198×281 | 216×224, 221×213, 197×252, 165×260 |
| `silvercat-blossom-hanbok` | 201×290, 218×288, 216×288, 221×288 | 194×285, 268×284, 259×282, 198×283 | 222×279, 250×283, 275×278, 200×279 | 279×205, 252×198, 207×265, 191×271 |
| `silvercat-pink-maid` | 222×273, 228×274, 234×271, 229×272 | 259×273, 237×274, 280×271, 221×275 | 230×272, 236×279, 276×275, 225×272 | 266×210, 256×198, 241×256, 218×267 |
| `silvercat-street` | 190×273, 192×273, 186×273, 200×273 | 203×267, 233×265, 248×262, 205×264 | 202×258, 250×282, 258×257, 208×258 | 230×224, 235×223, 230×260, 199×263 |
| `silvercat-summer-resort` | 236×287, 238×287, 244×289, 244×287 | 237×274, 288×275, 279×272, 247×275 | 249×272, 255×279, 282×267, 249×268 | 259×203, 246×199, 242×255, 229×257 |

## 부록: 이번에 읽은 PNG SHA-256

| 파일 ID | SHA-256 |
| --- | --- |
| `mint-hanbok` | `4971c06409b32a814cea6784cd20450263fa080bba1c0b6905660ea0a24a344a` |
| `mint-silver-knight` | `d7c8530cafc4ebf7509bdb136533d52c971ac6e84cefc36cefa15882bbb6a0fc` |
| `mint-summer` | `6a57f04d50b2e9df1db35fd1a258ea77ebc1c264cbe8002496dd259ae71fe177` |
| `pink-beret-gunner` | `513119a2db90897e7be2716f024c0086cdf55fa2828aad884910c42fe7442aad` |
| `pink-black-veil-hanbok` | `1d40c4b3825eecaa7358ec7d0236f838dc3b759f558c8acdc9cbc6a1eb9b66c2` |
| `pink-bunny-hoodie` | `25b9b555faac1db096257154dca29522ab458f520322174685473172ec189129` |
| `lavender-sailor` | `bcae4f6178ab86c2a76fc7d1e65a525276550c66d7a2fbd972e266fdeffe6778` |
| `lavender-shrine-maiden` | `61c97fe967d977d5769d39097d01aac1edca025433950fcdbf9f0ef93b12af03` |
| `lavender-winter-hanbok` | `1706348a89df7af80c5c6c99488bc149a95d76f1ea92465b179407e422ed30c8` |
| `aqua-goggles-explorer` | `d2b0db9d9328615803af2319f8c33bf4ca5d198db57d0be6ab8d91b427108601` |
| `aqua-pajama` | `f735f329121728d2278d3e731c98b2a415f724e24ae188b0da963d6372726137` |
| `aqua-rabbit-stage` | `335c37486cf203e5793d9ad6809533fe3d29f7846503fdb5d88b92a78cd28075` |
| `aqua-winter-hanbok` | `780eb5b746cdd631e1bc28d7056dfb83fe33048f81d57e6cdf6cae42bde492cc` |
| `crimson-black-dress` | `53eaefede0fd0e9ab728e24831f69313ab46c7b318a10674ba9cca3f71d68fcb` |
| `crimson-black-jacket` | `a1d9c747730843de4a474e97220ff84a4fcb8461bbfa3e953f4cd726da8e5ccd` |
| `crimson-pastel-rabbit` | `a7f732e15056c6fe28cc6fc8ccd85773f5026f18c69cc0ed7dea2a0e0e72e45d` |
| `crimson-rose-gothic` | `e8ff9dfa38670211aa4d6812d6c7497a41eacb1cda075f76926326947dbd8597` |
| `silvercat-black-uniform` | `979ef0d99107479e3dfa163719a6f3de73a154f6c9636232a0b0ea0e847068bb` |
| `silvercat-blossom-hanbok` | `6b1fe0fd1a66acbb421ad318492462b1be3065b83735dd2645c6b833aaa5ca45` |
| `silvercat-pink-maid` | `4749725bd09b4b251b3aceb645c76d4ededd3faef6431eeaea351ead4ae224d8` |
| `silvercat-street` | `e6846ea94ff5f3a5ed6fee28f2c7862d63c2c47747c93926247c0052c6e426b6` |
| `silvercat-summer-resort` | `dda5a6e1e8f5ead8bbab607176b4ff5fcff7ade94506bb6da5b28b6ee4a8860d` |
