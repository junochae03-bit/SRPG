"""엔진을 실행하지 않고 종료 표식 판정을 검증합니다."""
import ast
from pathlib import Path
import unittest

from godot_test_completion import COUNTED_PREFIXES, SUPPORTED_TESTS, completion_evidence


class CompletionTests(unittest.TestCase):
    def test_registered_tests_have_contracts(self):
        """실제 검증 목록에 새 테스트가 추가되면 완료 표식도 함께 등록해야 합니다."""
        source = ast.parse(Path(__file__).with_name("verify_v01.py").read_text("utf8"))
        registered = set()
        for node in ast.walk(source):
            if isinstance(node, ast.For) and isinstance(node.target, ast.Name) and node.target.id == "test" and isinstance(node.iter, ast.List):
                registered.update(value.value for value in node.iter.elts if isinstance(value, ast.Constant))
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "run" and node.args and isinstance(node.args[0], ast.Constant):
                registered.add(node.args[0].value)
        self.assertEqual(registered, SUPPORTED_TESTS)

    def test_standard_counter_summaries(self):
        for name, prefix in COUNTED_PREFIXES.items():
            with self.subTest(name=name):
                suffix = "VISUAL_SKILL_VFX_PASS\n" if name == "visual_skill_vfx" else ""
                evidence = completion_evidence(name, prefix + " checks=17 failures=0 captures=4\n" + suffix, 0)
                self.assertEqual(evidence["checks"], 17)
                self.assertTrue(evidence["markers"])

    def test_status_and_scope_summaries(self):
        for name, marker in [
            ("boss_stagger_v03", "BOSS_STAGGER_V03 PASS"),
            ("constellation_combat_v04", "CONSTELLATION_COMBAT_V04 PASS"),
            ("dungeon_entry_v04", "DUNGEON_ENTRY_V04 PASS"),
            ("costume_art_v04", "COSTUME_ART_V04_TESTS scope=full_catalog"),
        ]:
            with self.subTest(name=name):
                self.assertEqual(completion_evidence(name, marker + " checks=21 failures=0\n", 0)["checks"], 21)

    def test_reports_without_counter_never_invent_checks(self):
        reports = {
            "forest_stability": "FOREST_STABILITY_PASS fixed_changes=0 smooth_fade=PASS",
            "legacy_save": "LEGACY_SAVE_PASS level=5 items=4 gold=57",
            "database_world_rules_v052": "DATABASE_WORLD_RULES_V052 failures=0",
            "costume_render_v04": "COSTUME_RENDER_V04 frames=528 failures=0",
            "environment_visual_v04": "ENVIRONMENT_VISUAL_V04_PASS captures=8",
            "visual_v01": "VISUAL_V01_PASS",
            "visual_v05": "VISUAL_V05_PASS",
            "visual_jobs": "VISUAL_JOBS_PASS",
            "job_benchmark": "JOB_BENCHMARK_PASS",
        }
        for name, line in reports.items():
            with self.subTest(name=name):
                self.assertEqual(completion_evidence(name, line + "\n", 0), {"checks": 0, "markers": [line]})

    def test_empty_partial_and_wrong_test_output_fail_closed(self):
        for output in ["", "Godot Engine v4.6\n", "RULE_TESTS checks=7\n", "RULE_TESTS checks=7 failures=", "RULE_TESTS checks=7 failures=0", "RULE_TESTS checks=7 failures=0oops\n", "COMBAT_TESTS checks=7 failures=0\n", "참고 RULE_TESTS checks=7 failures=0\n"]:
            with self.subTest(output=output), self.assertRaises(ValueError):
                completion_evidence("rules", output, 0)

    def test_explicit_failures_and_engine_errors_are_rejected(self):
        good = "RULE_TESTS checks=7 failures=0\n"
        for output in [good.replace("failures=0", "failures=1"), good + "추가 failures=9\n", good + "render_errors=1\n", good + "errors=-1\n", good + "FAIL\n", good + "ERROR: 종료 오류\n", good + "SCRIPT ERROR: 오류\n", good + "WARNING: 경고\n", good * 2]:
            with self.subTest(output=output), self.assertRaises(ValueError):
                completion_evidence("rules", output, 0)
        with self.assertRaises(ValueError):
            completion_evidence("rules", good, 1)

    def test_database_failure_cannot_pass_without_checks_field(self):
        for output in ["", "DATABASE_WORLD_RULES_V052\n", "DATABASE_WORLD_RULES_V052 failures=2\n"]:
            with self.subTest(output=output), self.assertRaises(ValueError):
                completion_evidence("database_world_rules_v052", output, 0)

    def test_visual_requires_its_final_success_marker(self):
        for output in ["CAPTURE jobs-summoner-pet.png\n", "VISUAL_JOBS_", "VISUAL_JOBS_PASS"]:
            with self.subTest(output=output), self.assertRaises(ValueError):
                completion_evidence("visual_jobs", output, 0)
        summary = "VISUAL_SKILL_VFX_TESTS checks=21 failures=0 render_errors=0\n"
        for output in [summary, "VISUAL_SKILL_VFX_PASS\n" + summary]:
            with self.subTest(output=output), self.assertRaises(ValueError):
                completion_evidence("visual_skill_vfx", output, 0)

    def test_unregistered_test_is_rejected(self):
        with self.assertRaises(ValueError):
            completion_evidence("unknown", "UNKNOWN_PASS\n", 0)


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(CompletionTests)
    result = unittest.TextTestRunner().run(suite)
    print(f"GODOT_COMPLETION_TESTS tests={result.testsRun} failures={len(result.failures)} errors={len(result.errors)}")
    raise SystemExit(0 if result.wasSuccessful() else 1)
