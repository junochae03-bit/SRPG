# V0.4 선택 통합 인계 — 나무 아이콘
기준 작업본: D:/SSRPG/publish/SRPG-icons, feature/semantic-icons, baseline e01b80f. 18계열 VFX는 V0.3에 이미 포함되어 이 작업에서 수정하지 않았다.

## 현재 완료본
- 최종 원화: game/assets/icons/wood-{interface,inventory,combat,status,identity,adventure,abilities}.png (+ .import). 7시트 ×24=168종, 1536×1024.
- 최종 방향: 사용자 첨부 참고의 둥근 갈색 나무 버튼과 크림색 기호. 금속 테두리 없음. 원화 배경은 #FF00FF 크로마키이고 기존 gat_chroma.gdshader가 제거한다. 앞선 종이색/체커보드 후보는 채택하지 않았다.
- game/assets/icons/semantic_catalog.json: 명시적 path와 각 항목의 frames. 고정256 격자로 자르지 말 것.
- 신규 game/scripts/icon_library.gd: texture(key), has_key(key), keys(), attach(button,key,size=24), picture(parent,key,at,size), draw(canvas,key,rect,tint). 안전한 unknown fallback, 캐시, 기존 GatArt.material 적용.
- 신규 game/scripts/status_markers.gd: 실제 남은 상태·버프만 표시, 중복 제거, 최대5개+추가개수.
- game/scripts/icon_art.gd: 모든610 스킬/20직업을 의미별키로 매핑. key_for_skill(node), skill, function_icon, action. 원소술사 분기/도박사 카드·주사위 수정. 예전 숫자 texture API 호출처 없음, 제거됨.

## 기존 파일 선택 적용
다른 V0.4 변경이 있으므로 아래 전체 파일을 덮어쓰지 말고 diff를 선택 적용한다.
- main.gd: SemanticIcons const; button에 마지막 선택 icon_key 인수; 메뉴/오디오/저장; 배우 변환복구 후 status_markers.draw; 출구/줍기/NPC 상호작용. 중복 NPC 안내 1회로 정리.
- skill_tree_ui.gd / inventory_panel.gd: 버튼·검색·필터·포인트·빈장비·비용·잠금 의미표시. 기존 레이아웃 변경과 충돌 시 새 좌표를 존중. 선행 표시와 연결선은 required_rank로 비교.
- town_panel.gd: 비용/상태/상점/제작/이동 아이콘, 잘못된 facility 방어. 정수 합성에는 essence, 레이드에는 boss.
- codex_panel.gd: 도감/탭/필터/검색/페이지 아이콘.
- inventory_item_ui.gd: 빈 슬롯 실제 장비그림 오용 수정, 착용/제한 배지, chroma material.
- combat_hud.gd / job_resource_hud.gd / boss_hud.gd / minimap.gd: 실제 게임 상태 기반 토큰. 빈 슬롯과 잠긴 슬롯 분리.
- action_circle.gd: 낡은 medallion 배경 제거, 새토큰 크기 조정, 크로마 material.
- hud_sprite_button.gd: 크로마 material.
- ui_art.gd: picture에 새 wood atlas면 크로마 material 적용하는 helper. 동적 TextureRect 교체 시도 갱신.

## 검증
최종 크로마 상태에서 python tools/check_icons.py PASS:
168 icons, 610 skills, 20 classes, 13 actual Godot captures.
artifacts/icon-verification.json, icon-skill-coverage.json, icon-asset-audit.json 참고.
24/32/48px 전체 갤러리, HUD/가방/스킬/도감/포털, 보스 무력화집중/성공·상태이상·빈/잠금 슬롯 확인.
최종 python tools/verify_v01.py 전체 회귀 PASS checks=52156. 이전 실행은 모든모델 통과 후 자동캡처에 외부입력 개입 발견; game/tests/visual_v01.gd 입력격리+실제시설열림 assert 강화. 최종 실행은 입력격리 및 시설열림 검증을 포함해 통과했다.
tools/catalog_icon_bounds.py는 원본픽셀을 읽어 영역JSON만 생성한다. 이미지 편집 없음.
원화 출처·프롬프트: docs/ICON_ART_PROMPTS.json.

## 다음 작업 (아직 적용하지 말 것)
사용자가 후속으로 다양한 장비 스프라이트를 요청했고 가방/바닥용과 착용외형 둘 다 선택했다. 현재 조사만 완료, 장비 신규 코드/원화는 아직 없다. 아이콘 완료 뒤 별도 파일군으로 제작한다. 기존 Content.icon_texture 장비그림 교체 및 새 착용 세트를 계획 중이며 메인 V0.4 통합본으로 섞어 안내하지 않는다.
