# 장비 스프라이트 선택 적용 안내

## V0.5 통합 기준 (작업 경로 SRPG-v04)

`D:/SSRPG/publish/SRPG-v04`는 완료 커밋 `be30d7b0a75e0b7783c52c225bb2cab80df85a9d`의 PNG 6장, 115개 `items.json` 좌표, 프롬프트 원본을 바이트 그대로 사용한다. 미완성 `theme-*.png`, `themed-items.json`, 테마 문서는 포함하지 않았다. 아래 원본 인계의 셰이더 전용 처리는 당시 방식이며 현재 통합 로더는 다음과 같다.

- `EquipmentArt`가 최초 사용 때만 원본을 읽어 RGB를 보존하고 마젠타 픽셀의 알파만 메모리에서 0으로 만든다. 오른쪽·아래쪽 투명 1px 패딩으로 기존 공통 셰이더가 다시 색을 제거하지 않게 한다. PNG 파일과 원래 영역 좌표는 변경하지 않는다.
- 반환 AtlasTexture의 `source_path` 메타데이터를 `GameDB._texture_ref`가 기록한다. `GameDB.asset_texture`도 같은 장비 로더를 사용하므로 도감·가방·드롭이 동일 캐시를 소비한다. 메모리 RGBA 이미지에는 추가 크로마 재질이 필요 없다. 공통 셰이더는 변경하지 않았다.
- 원본 PNG가 없는 내보낸 PCK에서는 imported texture/remap으로 읽는다. 전용 모델 검사는 6장 전부의 imported-only 경로와 원본 경로의 RGBA 결과 일치, 115영역의 원본 RGB·알파 규칙, 직업별 허용 외형 60사례와 2,500 장비 수치 불변을 확인한다. 최종 EXE/PCK 실행 검증은 root 통합 단계에서 별도로 수행한다.
- FullHD 1920×1080 / 논리 1600×900을 검증하며, 그래픽 테스트 종료는 `AudioDirector.shutdown()`의 실제 플레이어 정리를 기다린다. 구 VFX·오디오 테스트와 전체 검증 도구를 덮어쓰지 않았다.

V0.5 전용 검사: 모델 **16,649 PASS**, 그래픽 **31 PASS**, 실제 캡처 **3장**, 렌더 오류와 갤러리 마젠타 잔여 **0**. 원본 6장과 전체 115종 갤러리·실제 가방·드롭 화면을 직접 확인했다. 결과는 `artifacts/equipment-art-verification.json`, 최종 로그는 `runtime/equipment-art-checks/20260909-225725-44020`이다. 아래의 21:19 전체 회귀 기록은 원본 장비 작업본의 기록이며 V0.4 전체 게이트·최종 배포 성공을 의미하지 않는다.

장비 로더의 `audit()`는 실제 sheet 로딩 방식·패딩 크기·해결 키·호환 요청·실패를 기록하고 `describe_texture()`는 화면이 소비한 AtlasTexture의 원본 경로·좌표를 확인한다. 기본 드랍 DB의 직업 변환 전 도끼 그림과 이전 저장의 도끼는 `legacy_appearance`로, 새 장비 리소스 누락은 `asset_failure`로 구분한다. 새 장비 2,500개는 모두 115개 새 그림으로 연결된다.

실제 저장 파서와 세션 진입을 거치는 대표 장비 6개 fixture도 검사했다. 가방 위치, 아이템 필드, 레벨·능력치·금화·외형과 스킬 상태가 그대로 유지된다. `tools/test_export_v01.py`는 최종 V0.5 EXE에서 이 6개 가방 그림과 기존 도감의 실제 썸네일, 6개 atlas의 imported-only PCK 로딩을 확인하도록 준비했다. 같은 EXE 검사에 10개 던전 환경의 실제 바닥 ShaderMaterial·원화 atlas·샘플 영역·draw 제출 증거도 포함했다. 이 EXE 검사는 아직 실행 전이며 root의 최종 패키지 단계에서 수행한다.

## 원본 작업본 인계 기록

완료 아이콘 커밋 `9f56910`에서 분리한 `feature/equipment-sprites` 작업본이다. 위치는 `D:/SSRPG/publish/SRPG-equipment`다. 최종 사용자 요청에 맞춰 개별 무기·방어구·장신구 그림만 제공한다.

## 산출물

`game/assets/equipment/`의 PNG 6장과 `items.json`이 115개 스프라이트를 구성한다.

- 무기 60개: `weapons-trail.png`, `weapons-adept.png`, `weapons-relic.png`; 20직업별 3단계.
- 방어구 50개: `armor-trail.png`, `armor-relic.png`; 5계열 × 머리·상의·장갑·하의·신발 × 2단계.
- 장신구 5개: `accessories.png`.

둥근 윤곽과 목재·천·가죽을 중심으로 그렸고 금속은 기능상 필요한 칼날 등에 한정했다. 그림은 원형 버튼 받침 없이 물체 자체다. 원본은 builtin image_gen으로 생성·편집했으며 최종 프롬프트와 출처는 `EQUIPMENT_ART_PROMPTS.json`에 있다.

PNG 배경은 마젠타 크로마키다. 기존 `gat_chroma.gdshader`와 `GatArt.material()`을 적용해 게임에서 투명하게 표시한다. 원본 PNG를 수정하거나 재샘플링하지 않았다. 실제 물체 간 빈 공간으로 구한 `items.json`의 `sheet`, `rect`를 사용해야 하며 고정 격자로 다시 자르지 않는다.

## 코드 계약

- 신규 `game/scripts/equipment_art.gd`: `key(item)`, `texture(item)`. 저장된 직업·계열·부위·단계로 이미지를 선택하고 AtlasTexture를 캐시한다. 파일 누락·미지원 키는 기존 그림으로 대체한다. 이전 저장 도끼 등 기본 직업의 다른 무기 종류도 기존 그림을 유지한다.
- 기존 `content.gd`: `icon_texture()` 시작에서 weapon/armor/accessory를 새 조회 함수로 연결하는 한 줄만 추가한다.
- 기존 `ui_art.gd`: `icon_material()`이 equipment 경로에도 기존 크로마 재질을 적용한다.

메인 개발 작업본의 기존 파일 전체를 덮어쓰지 말고 위 두 변경만 선택 적용한다. 원화 폴더·신규 조회 스크립트는 함께 복사한다. 장비 정의 2,500개의 수치·이름·제한·저장 데이터는 변경하지 않았다. 캐릭터 착용 외형·애니메이션·새 코스튬 기능은 포함하지 않는다.

## 확인

`tools/catalog_equipment_bounds.py`: 6장 원본 SHA256 불변, 115영역 PASS.
`tools/check_equipment_art.py`: 모델 16,152검사, 2,500장비 정의, 기존 외형·수치 보존60사례, 실제 화면3장 PASS. 최종 로그: `runtime/equipment-art-checks/20260909-211948-35536`.

미리보기는 `artifacts/equipment-items-gallery.png`, `equipment-bag.png`, `equipment-drops.png`다. 전용 결과는 `artifacts/equipment-art-verification.json`에 있다.

전체 회귀 `tools/verify_v01.py` PASS, 52,156검사. 로그: `runtime/v01-checks/20260909-211655`, 결과: `artifacts/v01_verification.json` (2026-09-09 21:19:04).

검증 도구의 `skill_vfx.gd`에는 장면 생성 직후 오디오를 중지하는 테스트 전용 정리3줄이 포함된다. 음소거 상태에서도 제목 음악 재생 객체가 생성되던 종료 경고를 방지하며 게임 오디오 동작과 기존13,173개 VFX 검사는 바꾸지 않는다.
