# 장비 스프라이트 제작 계획

이 문서는 `SRPG-equipment`의 원본 제작 계획과 당시 검증 기록이다. V0.4는 완료 커밋 `be30d7b`의 6PNG·115좌표를 변경 없이 사용하며, 메모리 RGBA 처리·패딩·DB 메타데이터·FullHD 통합 검증은 `TEAM_HANDOFF_EQUIPMENT.md`와 `EQUIPMENT_ART_COVERAGE.md`의 V0.4 항목을 따른다.

최종 사용자 요청: ‘무기 및 장비 방어구 스프라이트만 만들어줘’.
기준: 아이콘 완료 9f56910, 별도 작업본 D:/SSRPG/publish/SRPG-equipment (feature/equipment-sprites).

## 확정 범위
가방·도감·바닥 드롭용 개별 장비115개: 직업무기20×3단계=60, 방어구5계열×5부위×2단계=50, 장신구5.
캐릭터 착용 스프라이트와 외형 자동 전환은 최종 산출물에서 제외한다. 기존 외형 선택, 전투 수치, 저장 스키마를 유지한다.

## 스타일
원형 UI받침 없는 실제 물건 스프라이트. 둥근 윤곽, 따뜻한 목재·가죽·천, 크림색/차분한 녹색/갈색. 필요한 칼날과 작은 연결부만 절제한 금속.
원본은 builtin image_gen 생성/편집. 기존 Godot magenta chroma renderer로 투명 표시하며 원본 PNG 편집 없이 실제 개체 경계 metadata만 기록한다.

## 검증 단계
1. 원화6장 생성과 육안 확인 — 완료. 프롬프트: EQUIPMENT_ART_PROMPTS.json.
2. 실제 빈 공간을 이용한115개 영역 기록 및 원본 검사 — 완료. BOUNDS_PASS items=115, 원본6장 SHA256불변.
3. 장비2500개 정의의 이미지 조회/캐시/기존 외형·수치 불변 확인 — 완료. 전용 모델16,152검사, 기존 외형·수치 보존60사례, 이전 저장 도끼 호환성 포함.
4. 실제 게임 가방·드롭 화면과115개 갤러리 확인 — 완료. 3장 캡처, 렌더30검사, 오류/마젠타 잔여0, 육안 확인.
5. 전체 회귀 검증 및 인계 기록 — 완료. V01_GATE PASS 52,156검사(2026-09-09 21:19:04); 최종 장비 전용 검사도 재통과. 인계: TEAM_HANDOFF_EQUIPMENT.md.

검증 명령: tools/catalog_equipment_bounds.py, tools/check_equipment_art.py, tools/verify_v01.py.
엔진 실행은 root만 담당하며 로그와 테스트 저장은 작업본 runtime에 격리한다.
