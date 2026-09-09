# 사용 에셋과 제작 기록

현재 게임이 참조하는 파일과 SHA256은 `RUNTIME_FILES.json`에 기록한다. 원본 추출 전체와 사용하지 않는 시안·폰트·음원은 업로드하지 않는다.

- GAT: 사용자가 제공한 Combat Sprites 폴더의 19개 PNG, 37개 외형. 원본 픽셀 유지, 프레임 영역과 발 위치만 메타데이터로 관리. 일부 외형을 NPC 5명과 코스튬 6종으로 재사용한다.
- SRPG: 선택한 캐릭터 프레임을 스텔라이브 선택형 코스튬으로 사용한다.
- KoongyaAdventure: 선택한 숲 배경 이미지를 타이틀에 사용한다.
- Sephiria: 선택한 WAV 37개를 BGM·전투·UI·발소리에 매칭한다. 원래 FMOD 이벤트 믹싱이나 루프 포인트를 그대로 복원한 것은 아니다.
- 폰트: 사용자가 제공한 DNFBitBitv2.zip의 TTF와 DNFForgedBlade.zip의 Medium TTF. 폰트 파일을 변경하지 않았다.
- AI 제작: Codex 내장 image_gen 도구 사용. CLI/API 우회 없이 생성했다. PNG 원본을 그대로 복사하고 알파/마젠타 키와 AtlasTexture로 소비한다.

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
