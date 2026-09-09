# 바닥 타일 통합 — V0.5 release integration

이번 배포 대상은 V0.5다. 기능 개발 중 생성된 `*_v04` 파일명과 독립 검사명은 기존 호출 계약을 유지하기 위해 그대로 둔다.

원본: `D:/SSRPG/RPG2/art/tiles/fantasy-tiles-20260909`. 완료 README와 원본 PNG·실제 게임 캡처를 비교해 기존 저주파 노이즈 지면을 새 원화 재질로 교체한다.

실제 사용하는 파일만 `game/assets/floor_tiles_v04`에 둔다. `ground.png`는 1536×1024 원본의 바이트 사본이며 SHA256은 `53122ee4ab0894b320b63e7ffea4591d5fd6a5751adc0a15bd7dc8599e730877`이다. 6개 512×512 재료(풀·석재·모래·얼음·용암·대리석)를 모두 사용한다. 벽 원화, 물리 TileSet, 예제 프로젝트, 생성 중간파일은 게임에 복사하지 않는다. 원본의 `generation.json`에 생성 프롬프트 및 원본 위치가 있다.

`floor_tile_art_v04.gd`가 catalog의 10개 던전 바이옴 및 마을·튜토리얼 매핑을 읽고 `forest_environment.rebuild`에서 실제 ShaderMaterial에 원화와 패널을 연결한다. `forest_ground.gdshader`는 기존 96×48 이소메트릭 월드 좌표 및 통행 마스크를 그대로 읽는다. 재질은 5논리칸마다 거울 반복하고 16px 안쪽만 선형 샘플링해 이웃 패널이 섞이지 않는다. 이미지 픽셀은 변경하지 않는다. 카메라·원근·지형 생성·통행 충돌은 변경하지 않는다.

`forest.ground_evidence()`는 실제 바닥 draw 횟수와 ShaderMaterial의 atlas·패널·shader 경로를 보고한다. 자동 검사에는 이 데이터와 실제 FullHD 캡처를 함께 사용한다. draw 횟수는 그리기 명령을 다시 제출한 횟수이며 게임 프레임 수가 아니다.

검증 결과: `floor_tiles_v04` **7,777 PASS**(원본 해시·100층 매핑·샘플 영역·경계·충돌 불변), `floor_tiles_visual_v04` **102 PASS / 실제 1920×1080 캡처 14장**(10바이옴·1.6배 확대 3장·숲 입구 1장, 실제 GPU 재질 반복·시간 안정성·크로마·세부 변화). 렌더 후 전체 캡처 14장의 단색 파랑/마젠타 9×9 블록 검사는 0건이며 `artifacts/floor-tiles-v04-visual-report.json`에 기록한다. 대표 숲·기계·빙하 및 확대/입구 PNG를 직접 열어 길·재료 선명도·경계·프레임 가장자리를 확인했다. 원본 6재료를 재활용하므로 반복 무늬 자체는 존재하지만 경계 불연속이나 시간에 따른 반짝임은 없다.

기존 회귀 검사도 통과했다: `forest_stability` 정렬 변화 0 및 부드러운 가림, `dungeon_entry_v04` **2,403 PASS / 222,111 실제 이동 틱**, `battle_camera_v04` **5,390 PASS**. 이 결과는 소스 게임의 검사이며 최종 V0.5 Windows EXE 검증은 별도 배포 검사에서 수행한다.
