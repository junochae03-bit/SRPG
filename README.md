# 스텔알피지

던전을 탐사하며 캐릭터를 성장시키는 Godot 4.6 기반 액션 RPG입니다. 싱글 플레이와 방장 포함 최대 6인의 주소 접속 협동을 지원합니다.

**현재 릴리스: [V0.6](https://github.com/junochae03-bit/SRPG/releases/tag/V0.6)**

Windows ZIP을 전부 압축 해제하고 `StelRPG.exe`를 실행하세요. Godot 설치는 필요하지 않습니다. 이전 기록은 기존 게임을 종료한 뒤 `saves` 폴더를 새 빌드에 복사하면 이어할 수 있습니다.

- [V0.6 변경사항](docs/RELEASE_V06.ko.md)
- [V0.6 배포 검증](docs/VERIFICATION_V06.ko.md)
- [조작·실행·저장 안내](docs/PLAY_CURRENT.ko.md)
- [QA 원본 21개 반영·검증](docs/QA_FEEDBACK_21.ko.md)
- [협동 구현과 미완료 범위](docs/COOP_FOUNDATION.ko.md)
- [게임 DB 관리](docs/DB_MANAGEMENT.ko.md)

소스 실행은 Godot 4.6에서 `game/project.godot`을 열거나 `Play.cmd`를 사용합니다. 전체 소스 검사는 `tools/verify_v01.py`로 수행합니다. Windows 내보내기와 실행 파일 검사는 각각 `tools/build_v01.py --version V0.6`, `tools/test_export_v01.py --version V0.6`입니다.

실행 파일·개인 저장·검사 산출물·미사용 제작 원본은 소스 커밋에 포함하지 않습니다. 협동은 주소 접속 방식이며 자동 매칭·자동 중계·방장 이전·원정 재접속은 제공하지 않습니다.
