# 사용 에셋과 제작 기록

현재 게임이 참조하는 파일과 SHA256은 `RUNTIME_FILES.json`에 기록한다. 원본 추출 전체와 사용하지 않는 시안·폰트·음원은 업로드하지 않는다.

- GAT: 사용자가 제공한 Combat Sprites 폴더의 19개 PNG, 37개 외형. 원본 픽셀 유지, 프레임 영역과 발 위치만 메타데이터로 관리. 일부 외형을 NPC 5명과 코스튬 6종으로 재사용한다. V0.4에서는 추가 외형 24개를 무기·동작 기준으로 검토했으며 실제 플레이어 선택 목록은 직업별 허용 규칙을 따른다.
- 과거 스텔랜덤디펜스 캐릭터 프레임과 쿵야 어드벤쳐 배경은 현재 프로젝트에서 제거했다. 타이틀은 프로젝트에서 제작한 동화책 원화를 사용한다.
- Sephiria: 선택한 WAV 37개를 BGM·전투·UI·발소리에 매칭한다. 원래 FMOD 이벤트 믹싱이나 루프 포인트를 그대로 복원한 것은 아니다.
- 폰트: 사용자가 제공한 DNFBitBitv2.zip의 TTF와 DNFForgedBlade.zip의 Medium TTF. 폰트 파일을 변경하지 않았다.
- AI 제작: Codex 내장 image_gen 도구 사용. CLI/API 우회 없이 생성했다. PNG 원본을 그대로 보존하고 알파/크로마 키와 AtlasTexture로 소비한다. V0.5의 장비·코스튬 41개 시트는 아래 준비 캐시를 통해 불러온다.

## 최종 생성 프롬프트

| 에셋 | 프롬프트 |
|---|---|
| 숲 오브젝트 | ENVIRONMENT_GENERATION_PROMPT.txt |
| 장비·전리품 | ITEM_SPRITE_GENERATION_PROMPT.txt |
| 기본 3직업 전투 모션 | MOTION_WARRIOR_PROMPT.txt, MOTION_RANGER_PROMPT.txt, MOTION_MAGE_PROMPT.txt, MOTION_CORRECTION_PROMPT.txt |
| 마을 건물 | TOWN_V05_PROMPT.txt, TOWN_CORRECTION_V05_PROMPT.txt |
| 보스 모션·체력바 | BOSS_MOTIONS_V05_PROMPT.txt, BOSS_BAR_V05_PROMPT.txt |
| 승인된 일반 9종 | MONSTERS_CLASSIC_V05_PROMPT.txt |
| 추가 일반 9종·엘리트 3종 | MONSTERS_EXPANSION_V05_PROMPT.txt |
| 스킬·패시브·기능 아이콘 72개 | ICONS_ACTIVE_V05_PROMPT.txt, ICONS_SUPPORT_V05_PROMPT.txt |

실사·식물 혼합 몬스터 등 반려된 시안은 현재 게임과 저장소에서 사용하지 않는다. 에셋 제공자의 별도 권리를 이 저장소의 코드 공개만으로 새로 부여하지 않는다.

## V0.1 UI 원화

- `game/assets/ui/atelier-kit-v01.png`: 양피지 프레임, 가죽 슬롯, 등급별 금속 테두리, 초상 받침대, 두루마리, 문장 등 9개 구성 요소. [최종 프롬프트](UI_KIT_V01_PROMPT.txt)
- `game/assets/ui/facility-counters-v01.png`: 대장간·상점·연금술·길드·여관·원정의 문 작업 공간 6개. [최종 프롬프트](FACILITIES_V01_PROMPT.txt)
- 내장 image_gen이 만든 RGBA 원본을 변경 없이 복사했다. 이미지 재가공 없이 AtlasTexture 영역과 NinePatchRect로 소비한다. [원본 식별자·해시·적용 기록](UI_V01_PROVENANCE.json)
- Windows 패키지의 Godot 4.6 엔진은 [MIT 라이선스](GODOT_LICENSE.txt)와 [제3자 저작권 고지](GODOT_COPYRIGHT.txt)를 함께 제공한다. 공식 출처는 [Godot 4.6 소스](https://github.com/godotengine/godot/tree/4.6-stable)다.

## 직업 확장 이미지 (2026-09-09)

`game/assets/jobs/`는 이 대화에서 제작한 직업별 스프라이트·스킬 이펙트와 제공 원화 기반 파생 이미지다. `catalog.json`에 원본 시트 경로, 셀 위치, 발 기준점을 기록했다. 시프는 인형사 대체 콘셉트로 새로 생성했고, 소환수·사냥개 시트도 별도 생성했다. 당시 재사용한 스킬 아이콘은 V0.4에서 아래 나무 의미 아이콘 체계로 교체한다.

## V0.2 직업 무기·상호작용 아이콘

`game/assets/icons/job-weapons-v02.png`: 내장 image_gen으로 생성한 투명 RGBA 아틀라스(실제 1254×1254). 15개 전직 무기와 상호작용 손을 같은 화풍으로 제작했다. PNG를 재가공하지 않고 AtlasTexture로 표시한다. [최종 생성 프롬프트와 적용 경로](ART_V02.md).

## V0.3 도감·무력화·스킬 VFX

V0.3의 도감과 보스 무력화 HUD는 기존 양피지·금속 프레임·아이콘 원화를 재사용했다. `skill_vfx.gd`의 18계열 스킬 효과는 이 프로젝트의 별도 작업에서 만든 Godot CanvasItem 절차형 애니메이션이며 새로운 외부 그림을 사용하지 않는다. [VFX 인계](TEAM_HANDOFF_VFX.md), [V0.3 당시의 적용 구분](TEAM_INTEGRATION_V03.ko.md). 당시 연결하지 않았던 배경·코스튬 팩 가운데 V0.4가 사용하는 범위는 다음 항목과 현재 런타임 카탈로그를 따른다.

## V0.4 동화책 타이틀

`game/assets/ui/title-storybook-v04.png`: 내장 image_gen으로 만든 1586×992 숲·버섯·나무 팻말·책장 일러스트. PNG를 수정하지 않고 표시하며, 제목과 메뉴는 Godot와 DNF 폰트로 그린다. [최종 프롬프트·적용 기록](TITLE_ART_V04.md). 반려된 웅장한 풍경 시안은 포함하지 않는다. 성장 지도와 캐릭터 생성의 양피지·장식은 기존 UI 에셋을 유지하며, 외형 미리보기에는 선택한 GAT 또는 새 코스튬을 표시한다. 기존 마을 NPC 초상과 건물을 유지하면서 아래의 신규 NPC 원화 3종을 추가로 배치한다.

## V0.4 캐릭터 원화 33종과 전투 프레임

`game/assets/costume_v04/`는 별도 캐릭터 원화 작업에서 준비한 33개 시트와 민트 공격 교정 이미지 2장을 사용한다. 실제 용도는 **플레이어 코스튬 30종·마을 NPC 전용 3종**이다. 공통 reader가 읽는 시트당 16프레임, 총 **528프레임**에는 NPC 전용 원화의 포즈도 포함한다. 두 교정 이미지는 민트 여름복·은기사의 일반 공격 6·7번 프레임을 각각 교체한다. 교체 이미지를 코스튬 2종이나 추가 프레임으로 중복 계산하지 않는다.

- 프레임 순서: 이동 0–3, 일반 공격 4–7, 강공격 8–11, 회피 12–13, 피격 14, 대기 15.
- 원본 33시트는 보존한다. 교정 이미지도 내장 image_gen으로 제작했으며, 로컬에서 PNG 픽셀을 편집하지 않는다.
- [런타임 카탈로그](../game/assets/costume_v04/catalog.json)는 프레임별 소스 시트·영역·발 기준점·몸체 높이·배경 키를 기록한다. [제작 프롬프트](costume_v04/PROMPTS.ko.md)와 [35개 사용 이미지의 SHA256·제작 기록](costume_v04/PROVENANCE.json)을 함께 관리한다.
- `costume_art_v04.gd`는 V0.5에서 파랑·마젠타 키를 미리 제거한 RGBA gzip을 필요할 때 읽고 텍스처를 캐시한다. `frame`과 `portrait`로 실제 배우·상점 미리보기·가방 초상에 연결한다. 플레이어용 30종은 직업별 허용 목록 안에서 구매·착용 ID를 저장한다. 핑크 계열 3종은 기계도시 사절·유적 탐사원·유랑 사수로 마을에 배치하며 플레이어 선택은 거부한다.
- 자세별 몸체 높이와 지지발을 사용해 배율·피벗을 맞춘다. 코스튬 그림에 포함된 검·권총·우산 등의 모습은 개별 장비 아이템의 교체 레이어를 뜻하지 않는다.

[새 원화의 직업·무기 검토](costume_v04/CLASS_MATCHING.json)와 [추가 GAT 24개 검토](costume_v04/GAT_CLASS_MATCHING_PROPOSAL.json)를 `tools/build_appearance_matching_v04.py`가 [런타임 외형 규칙 57개](../game/assets/costume_v04/class_matching.json)로 변환한다. 무기·동작이 불명확해 허용 직업이 없는 외형은 플레이어 목록에서 제외한다. 상점·가방 목록과 실제 변경 명령에 같은 규칙을 적용하며, 직업 변경 시 비호환 외형만 기본 모습으로 되돌리고 구입 목록·장비·금화를 보존한다. 새 캐릭터의 생성 외형은 직업 기본 모습으로 고정한다.

V0.5 상인의 코스튬 탭에서 대체 기본 캐릭터는 500G, 코스튬은 1,200G에 구입한다. 구매가 곧 착용을 뜻하지 않으며, 가방에는 소유한 호환 외형만 나온다. 상점 도입 전 기록의 현재 외형은 소유 목록으로 이관한다. 사용자가 지정한 1~24자 표시 이름은 `sprite-names.json`에 별도로 저장한다. 이 별칭은 자산 ID·원본 카탈로그 이름·이미지·캐릭터 닉네임을 바꾸지 않으며, 개인별 소유권·별칭 파일을 원화 출처나 공개 DB에 포함하지 않는다.

이전 [코스튬 조사 인계](TEAM_HANDOFF_COSTUMES.md)의 22시트·미등록 상태는 조사 당시 기록이다. 현재 프레임 기준은 위의 33종 런타임 카탈로그와 [V0.4 코스튬 인계](TEAM_HANDOFF_COSTUMES_V04.md), 플레이어·NPC 구분은 최종 직업 검토를 따른다.

## V0.4 나무 의미 아이콘

아이콘 작업 기준 커밋은 `9f56910`이다. `game/assets/icons/wood-{interface,inventory,combat,status,identity,adventure,abilities}.png` **7시트·총 168개**를 사용한다. 둥근 갈색 나무 버튼과 크림색 기호, 금속 테두리 없는 형태를 채택했다. 168개가 시트마다 있는 것이 아니라 시트당 24개다.

원본은 1536×1024 마젠타 배경 PNG다. [semantic_catalog.json](../game/assets/icons/semantic_catalog.json)의 각 항목에 명시된 영역을 사용하며 고정 256칸으로 다시 자르지 않는다. [생성 프롬프트](ICON_ART_PROMPTS.json)와 [완료된 아이콘 작업 인계](TEAM_HANDOFF_ICONS.md)를 참조한다. 초기 종이색·체커보드 후보는 사용하지 않는다.

`icon_library.gd`의 의미 키를 스킬·기능·장비 부위·직업·상태에 대응시키고 표시 시 크로마를 제거한다. `audit()`는 요청한 키의 해석 결과와 알 수 없는 요청을 기록한다. 명시적인 빈칸·잠금 표시는 잘못된 키로 인한 폴백과 구분한다. 아이콘 작업본의 검증 기록은 해당 인계의 범위이며 V0.4 최종 EXE 검증 수치로 옮겨 적지 않는다.

기본 1920×1080 창에서 1600×900 논리 화면을 사용한다. 기본 가지의 스킬 기호 최소 48px·HUD 스킬 버튼 96px·가방 칸 64px로 원화 표시를 키웠다. 전체 지도에서는 기호 크기가 확대율에 따라 달라진다. 양피지·금속 소켓 원화는 그대로 사용하고 제목·버튼을 장식 안쪽으로 배치했다. 긴 아이템 이름과 옵션은 상세 스크롤, 긴 외형 목록은 최대 높이 440px의 팝업 스크롤로 표시한다.

## V0.4 장비 원화 115개

완료 커밋 `be30d7b`에서 무기 60개·방어구 50개·장신구 5개의 **PNG 6장과 명시된 115개 영역**을 선택 적용한다. [장비 인계](TEAM_HANDOFF_EQUIPMENT.md)와 [생성 프롬프트](EQUIPMENT_ART_PROMPTS.json)를 보존하고, `equipment_art.gd`가 직업·계열·부위·단계에 따라 기존 장비 정의의 표시 그림만 고른다. 그림 자체에는 원형 버튼 받침이 없으며 마젠타 배경은 표시할 때 제거한다. 후속 `theme-*.png` 미완성 작업은 포함하지 않는다.

## V0.5 장비·코스튬 로딩 캐시

최초 표시 때 GDScript로 시트 전체의 색 키를 처리하던 작업을 [prepare_render_cache.py](../tools/prepare_render_cache.py)의 빌드 단계로 옮겼다. **코스튬 원본 33장 + 교정 이미지 2장 + 장비 6장 = 41개**의 준비 파일을 [캐시 카탈로그](../game/assets/render_cache_v05/catalog.json)에 기록한다. 이 파일은 기존 그림을 읽기 위한 파생 캐시이며 새로운 캐릭터·장비·프레임으로 세지 않는다.

생성기는 reader와 같은 파랑·마젠타 조건으로 해당 픽셀의 알파만 0으로 만들고, 오른쪽·아래에 Godot `Color.TRANSPARENT`와 같은 투명 흰색 1px을 추가한다. RGBA8 결과를 gzip으로 저장하며 원본 PNG의 픽셀·프레임 영역·발 기준점은 바꾸지 않는다. 원본 파일 SHA256, 준비 gzip SHA256, 해제된 RGBA SHA256과 바이트 수를 각각 기록한다. [prepared_art_v05.gd](../game/scripts/prepared_art_v05.gd)가 필요한 파일만 해제하고 기존 `ImageTexture`로 반환한다. 개발용 원본 읽기 폴백도 남아 있다.

저장소에는 원본 PNG를 보존하고 배포 PCK에는 이 41개 PNG 대신 `.rgba.gz`를 포함한다. 관리 DB의 `art_assets.file_id`·`runtime_path`·`runtime_sha256`은 보존한 원본을 가리킨다. `render_cache_file_id`와 조회 뷰의 `render_path`·`render_sha256`은 실제 로딩 파일을 가리키며, 파생 파일의 출처는 원본 ID·해시·색 키·생성 도구와 연결된다. 캐시가 없는 자산에서는 두 경로가 같다. [게임 DB 안내](GAME_DATABASE.ko.md)에 재현 명령과 조회 예제를 적었다.

상점·키 설정 소비 경로를 반영한 관리 대상은 **1,700개 원화 영역·10,633개 사용/준비 관계**다. 파생 파일 41개를 포함한 파일 모델은 222개이며 영역 수는 증가하지 않는다. 최종 JSON·SQLite 수치와 해시는 재생성한 DB의 매니페스트에서 확인한다. 이 소스 검사와 캐시 바이트 검사는 전체 게임·EXE·배포 검증을 대신하지 않는다.

## V0.4 배경 108개와 몬스터 원화

새 바닥 원본은 `RPG2/art/tiles/fantasy-tiles-20260909`의 `sources/ground.png`다. 내장 image_gen으로 제작한 1536×1024 시트의 숲·석조 던전·사막·얼음·용암·천공 6재료를 바닥과 길에 사용한다. 원본 PNG는 보존하며 런타임 shader에서 월드 좌표와 반복 경계를 처리한다. 벽 원본·예제 프로젝트·미리보기·검사용 TileSet은 이번 바닥 사용에 필요하지 않아 배포하지 않는다. 파일·재료 영역·적용 생태계와 출처는 관리용 DB에도 등록한다.

[배경·몬스터 통합 기록](ENVIRONMENT_INTEGRATION_V04.ko.md)에 따라 기본 생태계·던전 확장·레이드·판타지 확장의 **4개 팩, 사용 PNG 30장**을 게임에 연결했다. 배경은 기존 72개와 판타지 확장 36개의 총 **108개 장식**이며, 새 일반 몬스터 외형은 **18종**, 레이드 외형은 **6종**이다.

배경 원본은 `RPG2/art/backgrounds/biomes-20260909`와 `fantasy-expansion-20260909`, 던전·레이드 원본은 `RPG2/art/dungeons/dungeon-expansion-20260909`와 `dungeon-bosses-20260909`다. 사용 PNG와 영역·발·테마는 [배경 카탈로그](../game/assets/environment/biomes-v04/catalog.json), [몬스터 카탈로그](../game/assets/world/dungeon-v04/catalog.json), [파일별 출처·해시 기록](ENVIRONMENT_V04_PROVENANCE.json)을 따른다. 원본 ZIP·미리보기·독립 Godot 프로젝트를 통째로 게임에 넣지 않는다.

배경 장식은 10개 생태계의 실제 보행 마스크 바깥에 배치한다. 출발점·출구·통행로의 여유 공간을 확보하고, 새 그림을 보행 충돌로 해석하지 않는다. 새 몬스터 외형은 침수·포자·용암·기계·성운·핵심의 6개 생태계에 대응하며, 각 종의 대기·공격 키 포즈 2장으로 총 **48프레임**이다. 나머지 4개 생태계는 기존 몬스터 원화를 사용한다. 몬스터 ID·AI·드랍·수치를 유지하고 층별 외형과 표시명을 연결한다.

최종 실행 파일은 `art_usage`에 실제 그린 코스튬·배경·몬스터 ID와 사용한 아이콘 키를 기록하도록 연결했다. 이 계측 자체는 검증 통과가 아니다. 허용 직업의 플레이어 코스튬 30종 저장 복원·NPC 전용 3종의 마을 배치·생태계 화면·크로마·폴백의 EXE 검사는 최종 [V0.5 검증 기록](VERIFICATION_V05.json)에서 확정한다.

## V0.5.2 수련장

`game/assets/town_v052/training-scarecrow.png`는 사용자의 수련장 요청으로 2026-09-10 내장 image_gen 도구에서 생성한 새 허수아비 원화다. 생성된 알파를 그대로 보존하며, 최종 프롬프트는 같은 폴더의 `PROVENANCE.md`에 기록한다. `training_art.gd`가 표시 높이 300과 몸체 조준 영역을 함께 사용한다. 마을 교관·코스튬 상점은 프로젝트에 포함된 기존 직업 원화를 재사용한다. 별도 제작 중인 V0.6 캐릭터·공격 모션팩과 미적용 몬스터팩은 이번 클라이언트에 넣지 않는다.
