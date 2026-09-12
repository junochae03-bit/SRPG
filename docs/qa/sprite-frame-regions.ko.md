# 캐릭터 프레임 경계 수정 — 2026-09-13

직업 기본·2차 외형에서 사각 격자 밖으로 나온 화살·갈고리·지팡이·검광이 이웃 동작에 들어가는 오류를 수정했다. 20개 직업 경로(rogue/thief 공유), 고유 원본 19장·304프레임을 분석했으며 11개 직업의 76프레임에 보정이 적용된다. 기존 코스튬 및 미등록 V06 후보 시트는 이번 원본 분석 대상이 아니다.

## 구현

- `game/data/sprite_frame_regions.json`은 원본 좌표와 발 기준점, 필요할 때만 비사각 영역을 구성하는 가로 구간을 저장한다.
- `game/scripts/sprite_frame_regions.gd`는 원본 텍스처를 사용하는 AtlasTexture/MeshTexture를 캐시한다. PNG 픽셀을 수정하거나 새 그림 파일로 재저장하지 않는다.
- GatArt.frame에서 영역을 적용한 뒤 기존 CharacterPresentation 비율을 적용한다. 공격 시간·프레임 인덱스·몸 높이·발사점·판정 좌표는 유지한다. 일반 보정은 원본 좌표계의 발 기준점도 그대로 유지한다.
- CharacterPreview와 CombatHUD에 MeshTexture의 경계·초상화 자르기 호환 처리를 추가했다. MeshTexture는 CPU 이미지 조회와 AtlasTexture를 통한 영역 자르기를 지원하지 않으므로 메시 영역 자체를 자른다. [Godot MeshTexture 문서](https://docs.godotengine.org/en/stable/classes/class_meshtexture.html)

## 원본 겹침과 대체

탱커(검 끝/옆 머리), 룬소드(룬 끝/옆 머리), 헌터(세로로 붙은 두 동작)는 원본 확인 후 지정한 경계로 분리했다. 자동 성분 분석만으로 분리했다고 주장하지 않는다.

리퍼의 9·10번 프레임은 원본 사슬이 옆 캐릭터 머리카락 위로 연결되어 있다. 잘린 머리카락을 복원했다고 주장하지 않으며, 런타임에서 9→8(준비), 10→6(휘두르기)의 온전한 기존 포즈를 사용한다. 강공격 시간과 원래 인덱스는 유지한다. 고유 사슬 동작을 되살리려면 해당 원화 재제작이 필요하다.

## 검증

감사 도구는 Pillow·NumPy·SciPy가 설치된 Python을 사용한다. 이번 환경에서는 `C:/Python314/python.exe -X utf8 tools/audit_runtime_sprite_regions.py --check`로 원본 해시와 영역 소유권을 다시 확인했다. Godot 렌더 검사와 별개의 읽기 검사이며 PNG를 수정하지 않는다.

- `python tools/audit_runtime_sprite_regions.py --check`: 원본 SHA-256, 저장된 좌표·검사 기록 일치, 보정 영역의 이웃 전경 혼입 0 및 소유 전경 누락 0 확인. 리퍼 두 대체 프레임은 별도 표시한다.
- `sprite_frame_regions graphics`: **1,233 checks / 0 failures**. 모든 직업 프레임의 높이·타이밍·기준점·캐시·미리보기·초상화 호환을 검사했다. GPU 픽셀 검사로 저격수 화살 원본 좌표 `(1005,498)`이 기존 복귀 프레임에는 보이고 발사 프레임에서는 잘리지만, 보정 후에는 발사 프레임에만 보이는 것을 확인했다.
- `character_presentation_v054`: **7,286 checks / 0 failures**, 등록 외형 90개 경로의 비율·방향·발사점 계약 확인.
- `combat_polish_v053 graphics`: **213 checks / 0 failures**, UI 호환 변경 후 다시 통과. 테스트가 사용하는 격리 저장 경로에서 실행했다.
- `character_runtime_gallery graphics`: 90개 경로, 좌우 방향, 네 상태 GPU 캡처 성공. 직업 페이지의 발사·복귀·강공격 화면을 육안 확인했다.

전후 증거: `runtime/sprite-frame-regions/before-after.png`. 검사 기록: `runtime/sprite-frame-regions/verification.json`, `docs/qa/sprite-frame-regions.json`.

이번 결과는 프로젝트 소스에 반영한 수정이다. 배포 실행 파일을 재빌드한 결과는 아니다. 새 JSON은 기존 export include_filter `*.json`에 포함된다.
