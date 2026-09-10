# 스킬트리 기준 캐릭터 밸런스

요청: 액티브·액티브 강화 모듈·캐릭터 행동 패시브·스탯 패시브를 구분하고, 기존 직업 개성과 여러 컨셉을 유지하며 실제 전투 수치를 조정한다.

범위는 20직업의 기존 1510노드 분류, 모듈 대상과 직업 컨셉의 DB 기록, SP 투자 효율과 직업 전투 계수 조정이다. 몬스터·장비·경제 수치, 스프라이트, 배포본 제작은 이번 조정 범위에 포함하지 않는다. 다른 작업의 제목 화면과 V06 파일을 보존한다. 기존 노드 ID·선행 조건·저장 배분은 유지한다.

1. [완료: 320개 합법 빌드, 전 SP 사용, 실제 피해 확인] `game/tests/tree_balance_benchmark.gd`에서 같은 직업·레벨·장비·SP·시드로 액티브 집중/모듈 집중/행동 패시브/스탯 패시브 투자 전략을 비교한다. 전직은 LV60/59SP, 기본직은 LV30/29SP. 30초 단일 및 5대상, 실제 기력·쿨타임·소환·지연 타격을 사용한다. 명령: `python tools/run_tree_balance.py before`. 320개 비교가 일반 단위검사 제한 60초를 넘겨 별도 측정 실행기를 사용한다. 결과의 모든 빌드가 `SkillBuild.validate_build`를 통과해야 한다. 사람 승인 체크포인트 없음.
2. [완료: 역할 3210·전투 6929·전후 각320개 통과] `skill_build.gd`와 별도 역할 카탈로그에 네 종류, 모듈 대상 액티브, 직업 컨셉을 부여한다. UI와 DB에서도 같은 분류를 사용한다. 비교 결과를 근거로 별자리 스탯과 직업 전투 계수를 조정하고 적용 전후 값을 문서에 기록한다. 명령: `python tools/run_hidden_check.py tree_balance`, `python tools/run_tree_balance.py after`, `job_balance`, `constellation_combat_v04`. 사람 승인 체크포인트 없음.
3. [완료: 전체 387921개 검사 및 DB --check 통과] 휴대용 DB를 재생성하고 전체 검증을 실행한다. 명령: `python tools/build_database.py`, `python tools/build_database.py --check`, `python tools/verify_v01.py`. 분류·모듈 격리·실제 비용·저장 호환성을 포함한다. 설계 목표와 실측 범위 및 미측정 파티/PvP 상황을 `docs/CHARACTER_BALANCE.ko.md`에 명시하고 공유 인수 기록으로 남긴다. 사람 승인 체크포인트 없음.

측정기는 적 AI와 입는 피해를 제거해 투자 효율을 비교한다. 회복·방어 직업을 순수 DPS와 같게 만드는 기준으로 사용하지 않는다. 생존 기능은 실제 회복·보호막·받는 피해 검사로 따로 확인하며, 이 측정으로 실전 승률을 주장하지 않는다.

전체 검증에서 이전 작명 변경에 따른 장비 이름 이관·한국어 이름 검색·긴 스킬 제목 표시 문제가 드러나 관련 UI와 회귀 검사도 보완했다. 전투 수치·장비 ID·능력치 보존 검사는 유지한다.

최종 증거: `docs/balance/verification.json`, `docs/balance/full-verification.json`. 소스·DB 적용 완료, 미커밋. 기존 개인 저장 원본 보존 확인.
