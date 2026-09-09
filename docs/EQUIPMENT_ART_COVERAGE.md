# 개별 장비 스프라이트 검증

## 현재 V0.5 호환 검증 (작업 경로 SRPG-v04)

고정 완료 커밋 `be30d7b`의 6PNG·115좌표를 변경 없이 통합했다. 현재 로더는 CPU 메모리 RGBA 알파 처리와 오른쪽·아래쪽 1px 투명 패딩을 사용한다. 원본 RGB, PNG 해시, AtlasTexture의 원래 `rect`와 `source_path` 메타데이터를 유지한다. `GameDB.asset_texture`는 동일 장비 로더로 위임한다. 공통 셰이더나 기존 장비 수치·직업 제한·저장 스키마는 바꾸지 않았다.

현재 검증은 **16,649 모델 검사 / 2,500 장비 정의 / 115 이미지 / 60 직업별 허용 외형 사례**, **31 그래픽 검사 / FullHD 1920×1080 캡처 3장 / 오류·마젠타 잔여 0**이다. `AudioDirector.shutdown()`으로 테스트 음원 정리를 기다린다. 6장 전부의 imported-only 로딩이 원본 PNG 로딩과 동일한 메모리 RGBA 결과를 내는지 확인했으며, 실제 배포 EXE/PCK 검증은 root 최종 단계에 남아 있다.

원화 6장과 `items.json`, 프롬프트 매니페스트의 완료 커밋 바이트 일치도 확인했다. 원화 6장·갤러리 전체·가방·드롭 그림을 직접 검토했다. 결과는 `artifacts/equipment-art-verification.json`, 최종 로그는 `runtime/equipment-art-checks/20260909-225725-44020`이다. 미완성 테마 자산은 포함하지 않는다.

장비 로더의 `audit()`는 실제 sheet 로딩 방식·패딩 크기·해결 키·호환 요청·실패를 기록하고 `describe_texture()`는 화면이 소비한 AtlasTexture의 원본 경로·좌표를 확인한다. 기본 드랍 DB의 직업 변환 전 도끼 그림과 이전 저장의 도끼는 `legacy_appearance`로, 새 장비 리소스 누락은 `asset_failure`로 구분한다. 새 장비 2,500개는 모두 115개 새 그림으로 연결된다.

실제 저장 파서와 세션 진입을 거치는 대표 장비 6개 fixture도 검사했다. 가방 위치, 아이템 필드, 레벨·능력치·금화·외형과 스킬 상태가 그대로 유지된다. `tools/test_export_v01.py`는 최종 V0.5 EXE에서 이 6개 가방 그림과 기존 도감의 실제 썸네일, 6개 atlas의 imported-only PCK 로딩을 확인하도록 준비했다. 같은 EXE 검사에 10개 던전 환경의 실제 바닥 ShaderMaterial·원화 atlas·샘플 영역·draw 제출 증거도 포함했다. 이 EXE 검사는 아직 실행 전이며 root의 최종 패키지 단계에서 수행한다.

## 원본 작업본의 제작·검증 기록

아래 셰이더 전용 방식, 1440×900과 21:19 전체 회귀 숫자는 `SRPG-equipment` 인계 당시 기록이다. 현재 V0.4 통합 방식과 검증 결과는 위 항목을 따른다.

최종 범위는 무기·방어구·장신구의 실물 스프라이트 115개다. 대상은 `SRPG-equipment`, 기준 커밋 `9f56910`이다. 캐릭터 착용 의상·애니메이션·자동 외형 기능은 포함하지 않는다. 기존 아바타·코스튬 선택과 장비 능력치는 유지한다.

| 종류 | 개수 | 실제 장비 선택 기준 |
| --- | ---: | --- |
| 무기 | 60 | 20직업 × trail(0–2단계), adept(3–6), relic(7–9) |
| 방어구 | 50 | 5계열 × 머리·상의·손·다리·발 × trail(0–4), relic(5–9) |
| 장신구 | 5 | 0–1/2–3/4–5/6–7/8–9단계에 각 형태 |

6장 PNG 원본의 115개 crop 영역을 사용한다. 지원 크기는 기존 크로마 셰이더가 처리하는 1536×1024 또는 1254×1254다. 원본을 수정하거나 재샘플링하지 않고 JSON 경계와 기존 GatArt 크로마 셰이더로 표시한다. Python은 원본을 읽어 마젠타 분류·임시 메모리 합성만 수행하며 파생 이미지 파일을 만들지 않는다.

## 실행 방법

```powershell
python tools/check_equipment_art.py --assets-only
python tools/check_equipment_art.py --import-only
python tools/check_equipment_art.py --model-only
python tools/check_equipment_art.py
```

`--assets-only`는 Pillow를 통한 원본·경계·픽셀 검사다. `--model-only`는 자산·Godot import·2,500개 정의와 기존 캐릭터 선택 보존 검사까지 수행한다. 기본 실행은 실제 렌더 화면 3장까지 확인한다. 엔진은 `GODOT_EXE`, 기존 탐색 규칙 또는 개발용 `D:/SSRPG/RPG2/tools/godot/Godot_v4.6-stable_win64.exe`를 사용하며 root가 실행한다.

각 실행 로그와 검사 저장은 현재 작업본 `runtime/equipment-art-checks/` 및 `runtime/equipment-art-visual/`에 격리한다. 기존 플레이어 저장을 읽거나 변경하지 않는다. ERROR·SCRIPT ERROR·WARNING 또는 불완전한 테스트 표식은 실패다. 모델 실패 후에도 독립적인 렌더를 확인할 수 있으나 최종 실패를 숨기지 않는다.

## 검증 범위와 결과 파일

- 115개 아이템 영역·6개 원본의 존재, RGB/RGBA PNG와 지원 크기, 정수 crop 경계·겹침·원본 밖 잘라내기, 크로마 제거 뒤 빈 이미지 여부를 확인한다. 원본 해시·작은 크기 대비는 `artifacts/equipment-art-assets.json`에 남긴다.
- 도감의 2,500개 장비 정의 모두가 알려진 이미지 키를 사용하고 115개 변형이 모두 실제 정의에서 도달 가능한지 검사한다. 등급마다 다른 원화를 강제하지 않는다.
- `equipment_art.key/texture`, `Content.icon_texture`, 도감 텍스처의 원본 영역과 캐시를 대조한다. 호출 전후에 아이템의 이름·수치·옵션·제한이 바뀌지 않는지 확인한다. 전체 매핑은 `equipment-art-coverage.json`에 기록한다.
- 20직업 × 기존 외형 선택 3종(기본·기존 코스튬·기존 GAT 코스튬)의 실제 장비 상태에서 이미지 조회와 로컬/원격 스냅샷이 캐릭터 선택·저장 데이터·전투 수치를 바꾸지 않는지 검사한다.

실제 Godot 산출물은 `equipment-items-gallery.png`(115개 전체), `equipment-bag.png`(가방·장착칸·상세), `equipment-drops.png`(기존 캐릭터와 바닥 장비 드롭)다. 화면 크기는 1440×900이며 실제 GUI/게임 입력을 차단하고 렌더 오류를 Logger로 수집한다. 갤러리에 밝은 마젠타 잔여가 없어야 하며 이전 실행의 오래된 PNG를 성공 근거로 사용하지 않는다.

최종 합격은 `equipment-art-verification.json`으로 확인한다. 픽셀 수치만으로 장비의 의미·잘라내기 품질·작은 크기의 가독성을 판단하지 않으므로 원화 6장과 갤러리의 115개 전부 및 실제 UI 화면은 육안으로 함께 검토한다. 최종 자산 복사 후 검사를 재실행해야 하며 제작 중인 상태를 미리 성공으로 표시하지 않는다.

## 최종 결과

2026-09-09 최종 장비 검사 PASS: 모델16,152검사, 기존 외형60사례, 실제 렌더30검사와3장 캡처. 원화6장·115개 전체 갤러리·실제 가방·드롭 화면 육안 확인 완료. 로그는 `runtime/equipment-art-checks/20260909-211948-35536`이다. 전체 회귀도 52,156검사 PASS (`runtime/v01-checks/20260909-211655`).
