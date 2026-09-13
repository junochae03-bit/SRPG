# 코스튬 V06 동작 검수

검수 기준: 사용자가 지정한 부키 스프라이트 `docs/sprite_v06/proportion-reference.png`. 원본 PNG를 수정하지 않고 프레임 선택, 발 피벗과 재생 상태만 보정한다. 내부 목표 몸높이 112px를 유지하며 그림 자체의 머리·몸 비율을 다시 그린 것은 아니다.

## 실행 범위

- 플레이어 외형 30종: 대기와 단일 피격 자세, 총 60동작 / 87프레임 / 원본 30장. 대기는 지정된 중립 자세를 유지하다 5초 주기의 마지막 0.28초에 승인된 눈감기 자세를 사용한다.
- `aqua-rabbit-stage`, `lavender-shrine-maiden`, `pearlcat-sailor`는 표정·높이가 크게 바뀌는 대체 자세를 깜빡임에 넣지 않고 중립 자세를 유지한다.
- 나나 3종은 NPC 전용 구분을 유지하며 플레이어 reader가 빈 결과를 반환한다. 구매 여부·소유권·직업 제한은 기존 session 경로가 담당한다.
- 피격은 실제 `hurt_time > 0` 동안만 유지한다. 피격 종료 시 현재 전투 상태를 다시 읽는다. 쓰러짐·걷기·공격·차지·회피는 기존 V04 동작으로 돌아간다.

## 보정과 확인

- 신발 하단 8px의 지지 범위를 기준으로 발 중심을 계산했다. 빗자루·우산 끝은 전용 신발 구간으로 제외했다. 웅크린 피격 자세를 키우지 않도록 외형별 원본 몸높이는 고정한다.
- Godot GPU에서 대기 비교 6페이지, 피격 좌우 반전 6페이지를 확인했다. 일부 녹색 테두리를 발견해 공통 색키 처리 담당에 전달했다. 새 캐시로 대기/눈감기/피격 좌우 6페이지를 다시 확인했고, 눈에 띄던 녹색 테두리가 크게 개선됐다. 승인 프레임에서 이웃 포즈의 무기·몸 조각 혼입은 관찰되지 않았다.
- 원본 36장의 SHA256, 후보 989개의 RGBA crop SHA256과 사각형 경계를 검증한다. 원본 PNG는 덮어쓰지 않는다.
- 잘린 후보나 연결된 이웃 포즈를 일정 격자로 재구성하지 않는다. pose ID가 어긋난 히나 교복(대기23/24, 피격30)과 시로 여름(대기20/22, 피격27)도 명시적으로 지정한다.

| 외형 ID | 대기 pose ID | 피격 pose ID |
|---|---|---|
| amethyst-purple-dress | 24, 26 | 31 |
| amethyst-summer-shawl | 24, 25 | 31 |
| aqua-goggles-explorer | 24, 25 | 31 |
| aqua-pajama | 24, 25 | 31 |
| aqua-rabbit-stage | 24 | 31 |
| aqua-winter-hanbok | 24, 25 | 31 |
| cobalt-black-ribbon-maid | 24, 25 | 31 |
| cobalt-broom-maid | 24, 25 | 31 |
| cobalt-navy-hanbok | 24, 25 | 31 |
| crimson-black-dress | 24, 25 | 31 |
| crimson-black-jacket | 24, 26 | 31 |
| crimson-pastel-rabbit | 24, 25 | 31 |
| crimson-rose-gothic | 24, 25 | 31 |
| lavender-sailor | 24, 26 | 31 |
| lavender-shrine-maiden | 24 | 31 |
| lavender-winter-hanbok | 24, 25 | 31 |
| mint-hanbok | 24, 26 | 31 |
| mint-silver-knight | 24, 25 | 31 |
| mint-summer | 24, 25 | 31 |
| pearlcat-sailor | 24 | 31 |
| raven-black-punk | 24, 25 | 31 |
| raven-navy-hanbok | 24, 26 | 31 |
| raven-pink-dress | 24, 26 | 31 |
| raven-school-uniform | 23, 24 | 30 |
| raven-summer-resort | 24, 25 | 31 |
| silvercat-black-uniform | 24, 25 | 31 |
| silvercat-blossom-hanbok | 24, 26 | 31 |
| silvercat-pink-maid | 24, 25 | 31 |
| silvercat-street | 24, 25 | 31 |
| silvercat-summer-resort | 20, 22 | 27 |

## 미적용 이유와 기록

전체 ID/action별 후보·제외·미적용 이유는 `costume-expanded-v06-review.json`, 측정 설정은 `costume-expanded-v06-calibration.json`에 있다. `VISUAL_FAIL`은 실제 확인한 결함이고 `UNVERIFIED`/`PHASES_UNVERIFIED`는 검증되지 않은 부분이다. 미검수를 그림 불량으로 단정하지 않는다.

확인한 일부 걷기 시트는 0–7에서 같은 앞발 자세가 반복됐다. 공격 후보는 일부 프레임 제외·재분류 또는 복구 시트 때문에 단순 순차 재생으로 방출 시점을 정할 수 없으며 손/무기 방출 소켓도 아직 보정되지 않았다. 회피는 공중 이동과 착지 기준의 실제 타이머 연결이 미검수다. 잘못된 발사 위치를 다시 만들지 않도록 이 동작은 현재 승인하지 않는다.

## 재현

```text
C:/Python314/python.exe -X utf8 tools/build_costume_expanded_runtime_v06.py --review
C:/Python314/python.exe -X utf8 tools/build_costume_expanded_runtime_v06.py --review --check
Godot --path game --script res://tests/costume_expanded_v06.gd
Godot --path game --script res://tests/costume_expanded_v06.gd -- --review
Godot --path game --script res://tests/costume_expanded_v06.gd -- --hurt-review
```

실제 실행 메타데이터에는 승인 시퀀스가 참조하는 프레임과 원본만 남긴다. `--review`의 전체 후보는 `docs/qa/costume-expanded-v06-candidates.json`에 생성되며 일반 reader는 이를 읽지 않는다. 캡처는 `runtime/costume-expanded-v06/`에 저장한다.

최종 GPU 테스트: `COSTUME_EXPANDED_V06 checks=984 failures=0 costumes=33`. 캡처 `runtime/costume-expanded-v06/hurt-page-0..5.png`. 일반 builder `--check` 통과. 후보 전용 원본을 읽으면 실패하도록 모의한 새 체크아웃 검사도 승인 원본30장만 사용하여 통과했다. 일반 builder는 기존 docs 검수기록을 덮어쓰지 않는다. 메인 연결은 반영됐으며 전체 게임 회귀 검사는 통합 담당이 진행한다.
