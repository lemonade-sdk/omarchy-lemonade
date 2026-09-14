import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "posix", "Requires a Linux shell")
class LocalServerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.folder = Path(self.temp.name)
        self.bin = self.folder / "bin"
        self.bin.mkdir()
        self.log = self.folder / "commands"
        self.env = {
            **os.environ,
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "XDG_RUNTIME_DIR": str(self.folder),
            "COMMAND_LOG": str(self.log),
            "INSTALLED": "0",
            "SYSTEM_UNIT": "1",
            "USER_UNIT": "1",
            "SYSTEM_ACTIVE": "0",
            "USER_ACTIVE": "0",
            "USER_ENABLED": "0",
            "PACMAN_FAIL": "0",
        }
        bash_env = self.folder / "bash-env"
        bash_env.write_text(
            'command() { if [[ "$*" == "-v lemond" ]]; then return 1; fi; builtin command "$@"; }\n'
        )
        self.env["BASH_ENV"] = str(bash_env)
        self.stub(
            "pacman",
            """
if [[ $1 == -Q ]]; then [[ $INSTALLED == 1 ]]; exit; fi
printf 'pacman %s\n' "$*" >> "$COMMAND_LOG"
[[ $PACMAN_FAIL == 0 ]]
""",
        )
        self.stub(
            "sudo",
            """
printf 'sudo %s\n' "$*" >> "$COMMAND_LOG"
exec "$@"
""",
        )
        self.stub(
            "systemctl",
            """
scope=SYSTEM
if [[ $1 == --user ]]; then scope=USER; shift; fi
case $1 in
    show) key=${scope}_UNIT; if [[ ${!key} == 1 ]]; then echo loaded; else echo not-found; fi ;;
    is-active) key=${scope}_ACTIVE; [[ ${!key} == 1 ]] ;;
    is-enabled) [[ $scope == USER && $USER_ENABLED == 1 ]] ;;
    *) printf 'systemctl %s %s\n' "$scope" "$*" >> "$COMMAND_LOG" ;;
esac
""",
        )

    def tearDown(self):
        self.temp.cleanup()

    def stub(self, name, body):
        file = self.bin / name
        file.write_text("#!/usr/bin/env bash\n" + body)
        file.chmod(0o755)

    def run_action(self, action, answer="y\n\n"):
        return subprocess.run(
            ["bash", str(ROOT / "scripts/local-server.sh"), action],
            env=self.env,
            input=answer,
            capture_output=True,
            text=True,
            timeout=10,
        )

    def commands(self):
        return self.log.read_text() if self.log.exists() else ""

    def test_probe_is_read_only_and_reports_missing_installation(self):
        result = self.run_action("probe")
        self.assertEqual(result.returncode, 0, result.stderr)
        state = json.loads(result.stdout)
        self.assertTrue(state["arch"])
        self.assertFalse(state["installed"])
        self.assertTrue(state["systemUnit"])
        self.assertEqual(self.commands(), "")

    def test_cancelling_does_not_install_or_start(self):
        self.assertEqual(self.run_action("install", "n\n\n").returncode, 0)
        self.assertEqual(self.commands(), "")

    def test_install_delegates_to_pacman_and_packaged_service(self):
        result = self.run_action("install")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("sudo pacman -Syu --needed lemonade-server", self.commands())
        self.assertIn("sudo systemctl enable --now lemond.service", self.commands())

    def test_failed_install_never_starts_service(self):
        self.env["PACMAN_FAIL"] = "1"
        self.assertNotEqual(self.run_action("install").returncode, 0)
        self.assertNotIn("systemctl", self.commands())

    def test_start_only_uses_existing_service(self):
        self.env["INSTALLED"] = "1"
        self.assertEqual(self.run_action("start").returncode, 0)
        self.assertIn("sudo systemctl start lemond.service", self.commands())
        self.assertNotIn("pacman", self.commands())
        self.assertNotIn("enable", self.commands())

    def test_existing_running_user_service_is_not_restarted(self):
        self.env.update(INSTALLED="1", USER_ACTIVE="1")
        self.assertEqual(self.run_action("start").returncode, 0)
        self.assertEqual(self.commands(), "")

    def test_enabled_user_service_is_preferred(self):
        self.env.update(INSTALLED="1", USER_ENABLED="1")
        self.assertEqual(self.run_action("start").returncode, 0)
        self.assertIn("systemctl USER start lemond.service", self.commands())
        self.assertNotIn("sudo", self.commands())

    def test_unmanaged_installation_does_not_spawn_a_daemon(self):
        self.env.update(INSTALLED="1", SYSTEM_UNIT="0", USER_UNIT="0")
        self.assertNotEqual(self.run_action("start").returncode, 0)
        self.assertEqual(self.commands(), "")

    def test_unknown_action_cannot_execute_commands(self):
        self.assertEqual(self.run_action("start; echo nope").returncode, 2)
        self.assertEqual(self.commands(), "")


if __name__ == "__main__":
    unittest.main()
