# V0.4 캐릭터 코스튬 인계

기존 생성 스프라이트 **33종·528프레임**을 읽는 런타임 팩과 Godot reader를 준비했다. 원본33 PNG를 보존하며, 민트 여름·은기사의 겹친 일반공격6/7만 별도 교체2포즈 PNG로 대체한다. 게임이 참조하는 이미지는 원본33장+교체2장=35장이다.

메인 담당이 Content·생성 화면·GatArt·인벤토리·HUD 연결과 실제 EXE 최종 검사를 수행한다. 이 작업에서는 main.gd, content.gd, 글로벌 gat_chroma.gdshader, 생성·인벤토리 UI를 수정하지 않았다. 커밋·푸시는 메인에서 진행한다.

## 런타임 파일과 API

- `game/assets/costume_v04/catalog.json`: 33종 사전. 키는 `mint-summer` 같은 안정된 ID다. `name`은 한글 의상명, `group`은 캐릭터 색 계열이다.
- `game/assets/costume_v04/*.png`: 실제 참조35장. 원본은RGB 키 배경을 그대로 유지한다.
- `game/scripts/costume_art_v04.gd`: 원본을 읽어 메모리에서만 RGBA 처리하고 캐시한다.

```gdscript
const CostumeArt = preload("res://scripts/costume_art_v04.gd")
var p = {"costume_id": "mint-summer"}
var frame = CostumeArt.frame(p, time)
if not frame.is_empty():
    var scale = 112.0 / frame.height
    draw_texture_rect(frame.texture,
        Rect2(-frame.foot * scale, frame.texture.get_size() * scale), false)
```

| 호출 | 결과 |
| --- | --- |
| `catalog()` | 읽기용33종 Dictionary. 호출자가 변경하지 않는다. 이미지 로드는 하지 않는다. |
| `ids()` | 정렬된 ID Array |
| `recognizes(id)` | 해당 코스튬 존재 여부 |
| `id_for(p)` | `costume_id → costume → skin_id → custom_skin` 순서로 실제 인식되는 문자열 ID를 선택. avatar/class는 코스튬으로 해석하지 않는다. |
| `has_sprite(p)` | 위 규칙으로 인식 가능한지 확인 |
| `index_for(p, time)` | 현재 행동 프레임0~15 |
| `frame(p, time)` | `{texture: AtlasTexture, foot: Vector2, height: float, animated: true, index, costume_id, action, sheet, frame_source_path}`. 미인식/로드 실패는 빈 사전. |
| `portrait(p)` | 대기15에서 얼굴을 잘라 캐시한 AtlasTexture. 미인식은null. |
| `reset_cache(reload_catalog=false)` | 명시적인 재로딩·테스트용. 매프레임 호출하지 않는다. |

`frame_source_path`는 실제 선택된 PNG의 `res://` 경로다. 민트6/7은 `*-attacks-v04.png`를 반환한다. 나머지14프레임은 원본시트를 반환한다. 프레임 rect는 선택된sheet의 좌표다.

## 표시 크기와 발 기준

프레임마다 `body_height`에 자세를 고려한 등가 서기 키를 기록했다. 표시배율은 항상 `112 / frame.height`다. 공격을 숙였다는 이유로 bbox 높이에 맞춰 확대하지 않는다. 이동이 대기보다 크게 그려진 시트는 이동 프레임에 별도 등가 키를 써서 크기 변화를 줄였다.

`foot`는 그림 전체의 아래 중앙이 아니라 보이는 신발의 접지점이다. 양발을 디딘 자세는 지지면의 두 신발 사이, 한 발을 든 자세는 지지발을 골랐다. 검기·우산·빗자루·손·꼬리끝은 발 기준에서 제외했다. 예를 들어 민트한복6의검, 고딕13의우산끝, 토끼무대13의장갑을 피벗으로 사용하지 않는다.

수작업 원본 좌표 근사이며, 특히 가려진 회피 발은 낮은 신뢰도와 추정 오차를 문서에 남겼다. 모든528개 피벗이 프레임 안에 있고 실제reader 캡처에서 큰 접지 오류는 보이지 않았다. 그림의 체형 자체와 걷기4장의 자세 차이는 원화를 따르며, 새로운 4방향/8방향 걷기 그림을 추가한 것은 아니다.

## 행동 연결

| 상태 | 프레임 |
| --- | --- |
| 대기 | 15 고정 |
| 이동 | 0~3, 보통8fps / sprint12fps |
| 일반공격 | 4~7 |
| 강공격 | 8~11 |
| 차지 | 초반8 / 0.45초 이후9 |
| 회피 | 12~13 |
| 피격 | 14 |

우선순위는 피격 → 회피 → 차지 → 공격motion → 이동 → 대기다. `slam/shoot_high/cast_high`는 강공격, `dash/leap/blink`는 회피, 나머지 공격motion은 일반공격이다. `motion_time`과 `motion_duration`의 진행도로 프레임을 고른다. 현재기본 로더처럼4번을 통상대기로 쓰지 않는다.

## 키색과 실색 보존

마젠타 10종(mint/aqua/cobalt), 파랑 23종을 구분한다. reader는 PNG를 처음 읽을 때 한 번만 키색의 알파를 0으로 만들고 RGB는 바꾸지 않는다. `_source_image`는 raw PNG가 있으면 바이트로 읽고, export에 raw PNG가 없으면 imported Texture2D의 `get_image()`로 읽는다. 원본 파일이나 투명화된 별도 PNG를 저장하지 않는다.

기존 글로벌 shader는 텍스처 크기로 마젠타 시트를 식별한다. 이미 RGBA인 코스튬이 다시 키처리되지 않도록 우측·하단에 투명 1px을 메모리에서만 더한다. 원본 1254×1254는 1255×1255, 교체 1774×887은 1775×888이 되어 현재 shader의 크기 조건에서 빠진다. 모든 원본 픽셀·rect·foot는 제자리이며 표시 형상도 그대로다. 글로벌 shader를 변경하거나 패딩을 제거하면 해당 회귀시험을 다시 실행해야 한다.

실제 원화 19시트에서 흰 의상, 푸른 눈, 보라 머리, 분홍 머리, 코발트 머리 줄무늬 109개 내부 표본을 확보했다. 예를 들어 cobalt의 [11,59,238]은 잘못된 파랑 키라면 사라지지만 해당 마젠타 키에서는 보존된다. 표본과 raven 홍채의 1,053픽셀 ROI에서 내부 키 충돌은 발견하지 못했다. 샘플 좌표·RGB·예상 RGBA는 `docs/costume_v04/calibration/color-samples.json`에 있다. 경계 픽셀의 원화 선색과 키색 잔여물 구분은 이 내부색 검사와 별개다.

## 검증과 재현

Godot 4.6에서 전체 reader 검사와 실제 GPU 캡처를 수행했다. 마지막 판정·횟수는 `runtime/costume-art-v04-final.log`와 `runtime/costume-v04-review/pack-verification.json`, `render-results.json`을 기준으로 한다.

최종 전체 reader 검사: **6,957개 체크, 실패 0, 종료 코드 0**. 실제 색 표본은 19시트의 109개 모두 예상 RGBA와 정확히 같고 기록된 19시트 해시도 일치했다. 원본 없는 PCK의 import fallback 시험과 35 PNG·528프레임 전수 검사도 포함한다.

```powershell
& 'C:\Python314\python.exe' '.\tools\costume_v04\build_pack.py'
& 'C:\Python314\python.exe' '.\tools\costume_v04\costume_pack_v04.py'
& 'D:\SSRPG\RPG2\tools\godot\Godot_v4.6-stable_win64_console.exe' --headless --path '.\game' --log-file '.\runtime\costume-art-v04-final.log' --script res://tests/costume_art_v04.gd
& 'C:\Python314\python.exe' '.\tools\costume_v04\run_costume_capture_v04.py'
```

빌드 재현에는 기존 `D:/SSRPG/RPG2/art/skins`를 입력으로 쓴다. 배포 게임에는 이 입력 폴더나 Python이 필요하지 않다.

검사 항목:

- 33종·528프레임·35참조 PNG, 모든 rect·피벗 범위, 같은 시트 내 참조 rect 겹침 없음.
- 민트 교체 이미지는 6/7만 참조하며 두 그림 사이에 최소 223px 빈 여백. 나머지 14포즈 원본 보존.
- 원본 33 PNG SHA가 이전 검사 매니페스트와 같고 35 PNG 모두 출처 해시와 일치.
- 메모리 RGBA, 키색 경계값, RGB/알파, 투명 패딩, 캐시, 대기·공격·회피 매핑과 portrait.
- 원본 PNG 없이 `.png.remap → packed Texture2D`만 있는 실제 PCK로 export fallback 확인.
- 실제 reader와 현재 global shader로 33종 전체 528프레임 GPU 렌더, 실패 0. `runtime/costume-v04-review/*.png`를 육안 확인했다. 검사용 카드가 회피 포즈를 덮던 부분은 카드 여백과 그리기 순서를 수정한 후 재캡처했다.

## 성능

새 reader 캐시/headless 측정(운영체제 파일 캐시는 통제하지 않음): 첫 스킨 273ms, 나머지 32종까지 portrait 준비 약 8.57초, 캐시된 portrait 33개 0.091ms, 완전 캐시 후 frame 1,000호출 약 6.9~7.9ms. 민트 patch 2장은 해당 프레임 첫 사용 시 별도로 로드된다. RGBA 순수 텍셀 메모리는 약 210.3MiB이며 엔진 부가비용은 제외했다.

생성·인벤토리 화면에서 33종을 한 번에 동기 준비하면 첫 진입이 지연된다. 메인 초기 로딩 화면에서 분산 준비하거나 화면에 보이는 항목부터 지연 로드하는 것이 필요하다. 캐시 후 정상 플레이 경로에서는 PNG를 다시 읽거나 키처리하지 않는다. 측정 파일은 `runtime/costume-art-v04-performance.json`이다.

## 원본·문서 위치

런타임 자산 폴더에는 35 PNG와 catalog(+Godot import)만 둔다. 재현 Python은 `tools/costume_v04/`, 수동 보정·기존 좌표·프롬프트·원본 해시는 `docs/costume_v04/`에 둔다. 생성 수정은 built-in image_gen을 사용했고 선택 결과와 프롬프트는 `docs/costume_v04/PROMPTS.ko.md`에 남겼다. 이전 감사 ZIP과 RPG2/art 원본은 덮어쓰지 않았다.

폴더 정리 후 재빌드한 catalog는 문서 경로 필드만 바뀌었으며, 모든 런타임 필드가 정리 전과 정확히 같음을 비교했다. 최종 catalog SHA-256은 `8b35996899db1cd185f3fa2aff8a20c6e7333b7fa0fe4691c8c0524ec7bff7b6`이다.

전체 캐릭터의 UI 선택·세이브·전투·EXE 파일 소비 검사는 메인 담당의 최종 통합검사에서 확인한다. 본 인계는 런타임 팩/reader/API/독립 렌더 검사 범위다.

## 직업별 외형 매칭 추가 인계

`docs/costume_v04/CLASS_MATCHING.json`의 `entries[costume_id].allowed_base_classes`를 선택 목록 필터의 근거로 제공했다. 실제 33종·528프레임을 다시 보고 무기와 일반·강공격 모션으로 분류했다. 원화나 reader, catalog는 변경하지 않았다.

플레이어용은 검사 3종(민트), 마법사 27종, 격투가 1종이며 궁수·도적 신규 매칭은 없다. 토끼 무대복은 닫힌 장갑의 가드·직선 펀치와 얼음 시전이 모두 있어 마법사·격투가에 중복된다. 따라서 플레이어 클래스별 합계는 31이며 실제 선택 가능 의상은 30종이다. 빗자루 메이드는 물리 쓸기와 구름 마법이 섞여 있어 마법사만 중간 신뢰도로 허용했다.

핑크 권총 3종은 현재 직업과 무기가 맞지 않는다. 저격수·헌터는 활을 사용하며 탐험가는 채찍·로프 기반 근접 제어다. 거너가 없는 현재 20직업에서 권총을 억지로 허용하지 않는다. 최신 요청에 따라 `runtime_role: town_npc`, `allowed_classes: []`, `allowed_base_classes: []`, `permitted_jobs: []`를 명시하고 비전투 마을 방문 NPC로 소비한다. 플레이어 생성·장비 선택에서는 숨긴다. 이로써 33종 원화를 모두 보존하고 플레이어 30종·마을 NPC 3종으로 사용한다.

전 직업 허용은 없다. 단검 그림이 없는 신규 팩에 도적을 억지로 매칭하지 않았다. 각 의상에 관찰 프레임·허용 이유·다른 직업의 제외 이유와 출처 해시를 담았다. 최종 필터·저장·직업 변경·NPC 연결은 메인 담당이 수행한다.

기존 GAT addition 24종도 12시트·96프레임을 별도로 확인했다. `docs/costume_v04/GAT_CLASS_MATCHING_PROPOSAL.json`과 최종 `CLASS_MATCHING.json`의 `gat_addition_proposals`에 검사 6·마법사 14·도적 2·보류 2의 제안을 담았다. `gat_addition_06_1`의 리본 무기와 `gat_addition_10_1`의 방패/건틀릿 경계 장비는 보수적으로 보류했다. GAT의 4프레임은 신규 16프레임의 행동 구분과 다르므로 일반·강공격 전용 프레임으로 오인하지 않았다.
