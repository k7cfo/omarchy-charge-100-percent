import json
from pathlib import Path
import subprocess
import tempfile
import unittest


CONTROLLER = Path(__file__).resolve().parents[1] / "scripts" / "charge-ctl"


class ChargePolicyTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.battery = self.root / "power" / "BAT0"
        self.ac = self.root / "power" / "AC"
        self.battery.mkdir(parents=True)
        self.ac.mkdir()
        self.set_file(self.ac, "type", "Mains")
        self.set_file(self.ac, "online", 1)
        self.set_file(self.battery, "capacity", 80)
        self.set_file(self.battery, "charge_control_start_threshold", 75)
        self.set_file(self.battery, "charge_control_end_threshold", 80)

    def set_file(self, directory, name, value):
        (directory / name).write_text(str(value) + "\n")

    def run_ctl(self, command, before="", check=True):
        # Source the real implementation, redirect only its I/O roots, then run
        # the real command. The privileged helper is never invoked in tests.
        script = '''source "$1"
POWER_SUPPLY="$2/power"
STATE_DIR="$2/state"
HELPER="$2/no-helper"
''' + before + '\nmain "$3" "${4:-}"\n'
        return subprocess.run(
            ["/usr/bin/bash", "-c", script, "test", str(CONTROLLER), str(self.root), *command],
            text=True, capture_output=True, check=check,
        )

    def status(self):
        return json.loads(self.run_ctl(["status", "--json"]).stdout)

    def assert_profile(self, start, end):
        status = self.status()
        self.assertEqual((status["start"], status["end"]), (start, end))
        self.assertEqual(status["mode"], "full" if end == 100 else "conserve")

    def test_full_holds_at_99_and_100_then_unplug_restores_conservation(self):
        self.run_ctl(["full"])
        self.assert_profile(99, 100)
        for capacity in (99, 100, 98, 100):
            self.set_file(self.battery, "capacity", capacity)
            self.run_ctl(["tick"])
            self.assert_profile(99, 100)
        self.set_file(self.ac, "online", 0)
        self.run_ctl(["tick"])
        self.assert_profile(75, 80)
        self.set_file(self.ac, "online", 1)
        self.run_ctl(["tick"])
        self.assert_profile(75, 80)

    def test_can_select_full_when_already_full(self):
        for capacity in (99, 100):
            self.run_ctl(["conserve"])
            self.set_file(self.battery, "capacity", capacity)
            self.run_ctl(["full"])
            self.assert_profile(99, 100)

    def test_rejects_full_while_unplugged(self):
        self.set_file(self.ac, "online", 0)
        result = self.run_ctl(["full"], check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Plug in AC", result.stderr)
        self.assert_profile(75, 80)

    def test_manual_conservation_ends_full_session(self):
        self.run_ctl(["full"])
        self.run_ctl(["conserve"])
        self.run_ctl(["tick"])
        self.assert_profile(75, 80)

    def test_failed_write_does_not_claim_full_mode(self):
        self.run_ctl(["conserve"])
        result = self.run_ctl(["full"], before="write_thresholds() { return 1; }", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.root / "state" / "mode").read_text().strip(), "conserve")
        self.assert_profile(75, 80)

    def test_status_reports_hardware_not_stale_mode(self):
        self.run_ctl(["full"])
        self.set_file(self.battery, "charge_control_start_threshold", 75)
        self.set_file(self.battery, "charge_control_end_threshold", 80)
        self.assert_profile(75, 80)
        self.run_ctl(["tick"])
        self.assert_profile(75, 80)
        self.assertEqual((self.root / "state" / "mode").read_text().strip(), "conserve")

    def test_status_reports_actual_hardware_charge_state(self):
        for state in ("Charging", "Full", "Not charging", "Discharging"):
            with self.subTest(state=state):
                self.set_file(self.battery, "status", state)
                self.assertEqual(self.status()["chargeState"], state)
        self.set_file(self.battery, "status", "<img src=untrusted>")
        self.assertEqual(self.status()["chargeState"], "Unknown")
        (self.battery / "status").unlink()
        self.assertEqual(self.status()["chargeState"], "Unknown")

    def test_unplug_during_full_write_restores_conservation(self):
        self.run_ctl(["full"], before='''
original=$(declare -f write_thresholds)
eval "${original/write_thresholds/original_write}"
write_thresholds() {
  original_write "$@"
  printf '0\\n' > "$POWER_SUPPLY/AC/online"
}
''')
        self.assert_profile(75, 80)


if __name__ == "__main__":
    unittest.main()
