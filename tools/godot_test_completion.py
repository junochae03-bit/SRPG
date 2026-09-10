"""테스트별 실제 완료 표식을 검사하며 출력에 없는 검사 수는 만들지 않습니다."""
import re


_STANDARD = """
removed_assets appearance_matching_v04 appearance_v041 audio_shutdown_v04 battle_camera_v04
character_creation_v04 character_dialogue_ui_v04 client_flow_v051 codex_ui_v03
costume_session_v04 database_metadata_v05 database_v03 database_v04 dungeon_v02
environment_v04 equipment_v02 expansion_ui floor_balance_v02 hud_layout_v04
inventory_grid inventory_ui job_balance job_ui loot_v04 monsters_v05 polish_v05
prepared_art_v05 progression_v02 single_player skill_build_session_v04
skill_build_v04 skill_tree_ui_v04 skill_vfx skills_v01 skills_v04 stagger_ui_v03
ui_legibility_v04 ui_v01 ui_v02 visual_skill_vfx wardrobe_shop_ui_v05 wardrobe_v05
""".split()
_PLAIN = """
art_registry_v05 combat_feedback_v052 combat_reach_v052 combat_reach_visual_v052
dungeon_entry_visual_v04 dungeon_variety_v052 dungeon_variety_visual_v052
enemy_hit_geometry_v05 floor_tiles_v04 floor_tiles_visual_v04 inventory_expansion_v052
jobs keyboard_ui_v051 performance_environment_v05 performance_ui_v05 qa_combat_v052
hud_world_labels_v052
qa_inventory_v052 qa_save_v052 qa_skill_rejection_v052 settings_v052 skill_clarity_v052 town_clarity_ui_v052
town_renewal_visual_v052 town_services_v052 training_ground_v052
""".split()
COUNTED_PREFIXES = {name: name.upper() + "_TESTS" for name in _STANDARD}
COUNTED_PREFIXES.update({name: name.upper() for name in _PLAIN})
COUNTED_PREFIXES.update({
    "combat": "COMBAT_TESTS",
    "rules": "RULE_TESTS",
    "expansion_v05": "V05_TESTS",
    "icons": "ICON_MODEL_TESTS",
    "equipment_art": "EQUIPMENT_ART_MODEL",
    "visual_icons": "ICON_VISUAL_TESTS",
    "visual_equipment_art": "EQUIPMENT_ART_VISUAL",
})
_STATUS_PREFIXES = {
    "boss_stagger_v03": "BOSS_STAGGER_V03",
    "constellation_combat_v04": "CONSTELLATION_COMBAT_V04",
    "dungeon_entry_v04": "DUNGEON_ENTRY_V04",
}
_SPECIAL_PATTERNS = {
    "forest_stability": r"FOREST_STABILITY_PASS fixed_changes=0 smooth_fade=PASS",
    "legacy_save": r"LEGACY_SAVE_PASS level=\d+ items=\d+ gold=\d+",
    "database_world_rules_v052": r"DATABASE_WORLD_RULES_V052 failures=(?P<failures>\d+)",
    "costume_render_v04": r"COSTUME_RENDER_V04 frames=[1-9]\d* failures=(?P<failures>\d+)",
    "environment_visual_v04": r"ENVIRONMENT_VISUAL_V04_PASS captures=[1-9]\d*",
    "visual_v01": r"VISUAL_V01_PASS",
    "visual_v05": r"VISUAL_V05_PASS",
    "visual_jobs": r"VISUAL_JOBS_PASS",
    "job_benchmark": r"JOB_BENCHMARK_PASS",
}
_COUNTS = r"checks=(?P<checks>\d+) failures=(?P<failures>\d+)(?:[ \t]+[^\r\n]+)?"
_PATTERNS = {name: re.escape(prefix) + " " + _COUNTS for name, prefix in COUNTED_PREFIXES.items()}
_PATTERNS.update({name: prefix + " PASS " + _COUNTS for name, prefix in _STATUS_PREFIXES.items()})
_PATTERNS["costume_art_v04"] = r"COSTUME_ART_V04_TESTS scope=(?:full_catalog|fixtures) " + _COUNTS
_PATTERNS.update(_SPECIAL_PATTERNS)
SUPPORTED_TESTS = frozenset(_PATTERNS)


def completion_evidence(test: str, output: str, returncode: int) -> dict:
    """종료 코드·오류·완전한 완료 줄을 모두 확인하고 실제 보고된 수만 반환합니다."""
    if test not in _PATTERNS:
        raise ValueError("완료 표식이 등록되지 않은 테스트: " + test)
    if returncode != 0:
        raise ValueError(f"테스트 종료 코드 오류: {test} ({returncode})")
    if any(token in output for token in ("ERROR:", "SCRIPT ERROR", "WARNING:")):
        raise ValueError("엔진 오류 또는 경고가 있는 테스트: " + test)
    if re.search(r"\bFAIL\b", output):
        raise ValueError("실패 표식이 있는 테스트: " + test)
    # 정상 완료 줄 뒤에 렌더 오류나 다른 실패 요약이 붙어도 통과시키지 않습니다.
    for value in re.findall(r"\b(?:failures|errors|render_errors)\s*=\s*([^\s]+)", output):
        if not value.isdecimal() or int(value) != 0:
            raise ValueError("실패 또는 오류 수가 0이 아닌 테스트: " + test)
    # 줄 끝이 없는 출력은 마지막 표식 중간에서 끊긴 로그일 수 있습니다.
    lines = [line.rstrip("\r\n") for line in output.splitlines(keepends=True) if line.endswith("\n")]
    matches = [(line, re.fullmatch(_PATTERNS[test], line)) for line in lines]
    matches = [(line, match) for line, match in matches if match is not None]
    if len(matches) != 1:
        raise ValueError("완전한 완료 표식이 없거나 중복된 테스트: " + test)
    marker, match = matches[0]
    failures = int(match.groupdict().get("failures") or 0)
    if failures:
        raise ValueError(f"테스트 실패: {test} ({failures})")
    markers = [marker]
    # 이 테스트는 수치 요약 다음에 최종 렌더 완료 표식을 따로 출력합니다.
    if test == "visual_skill_vfx":
        final = "VISUAL_SKILL_VFX_PASS"
        if lines.count(final) != 1 or lines.index(final) <= lines.index(marker):
            raise ValueError("스킬 효과의 최종 렌더 완료 표식이 없습니다.")
        markers.append(final)
    return {"checks": int(match.groupdict().get("checks") or 0), "markers": markers}
