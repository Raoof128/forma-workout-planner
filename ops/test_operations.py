import datetime as dt
import importlib.util
import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch

MODULE = pathlib.Path(__file__).with_name('account-operations.py')


class OperationsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('operations', MODULE)
        cls.ops = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.ops)

    def test_backup_tampering_is_rejected(self):
        import hashlib
        manifest = {'archive': 'archives/forma-production-20261013T000000Z.dump.age',
                    'sha256': hashlib.sha256(b'encrypted archive').hexdigest()}
        self.ops.verify_archive(manifest, b'encrypted archive')
        with self.assertRaises(ValueError):
            self.ops.verify_archive(manifest, b'changed archive')

    def test_restore_refuses_live_database_and_unsafe_archive(self):
        for name in ['forma', 'postgres', 'forma_restore_x; DROP DATABASE forma']:
            with self.assertRaises(ValueError):
                self.ops.validate_restore(name, 'archives/forma-production-20261013T000000Z.dump.age')
        with self.assertRaises(ValueError):
            self.ops.validate_restore('forma_restore_test', '../../secret')

    def test_sign_in_and_conflict_thresholds(self):
        events = [{'event': 'sign_in_failure', 'actor': 'a'}] * 51
        self.assertIn('sign_in_failures', self.ops.security_signals(events))
        self.assertNotIn('sign_in_failures', self.ops.security_signals(events[:50]))
        self.assertIn('account_changed', self.ops.security_signals(
            [{'event': 'account_changed', 'actor': 'a'}] * 21))
        self.assertNotIn('account_changed', self.ops.security_signals(
            [{'event': 'account_changed', 'actor': str(i)} for i in range(21)]))

    def test_immediate_signals(self):
        for event in ['sign_in_lockout', 'mfa_lockout', 'email_suppressed', 'gateway_rejected']:
            self.assertIn(event, self.ops.security_signals([{'event': event}]))

    def test_restore_integrity_uses_signed_backup_snapshot_not_live_data(self):
        manifest = {'project': 'forma-production', 'databaseFingerprint': 'f' * 64}
        self.ops.verify_restored(manifest, 'f' * 64, 'forma-production')
        with self.assertRaises(ValueError):
            self.ops.verify_restored(manifest, 'e' * 64, 'forma-production')
        with self.assertRaises(ValueError):
            self.ops.verify_restored(manifest, 'f' * 64, 'forma-staging')

    def test_missing_container_is_unhealthy_instead_of_crashing_monitor(self):
        with patch.object(self.ops, 'run', side_effect=RuntimeError('container missing')):
            self.assertFalse(self.ops.container_healthy('forma-production-api-1'))

    def test_tunnel_readiness_asks_cloudflared_not_its_logs(self):
        config = {'project': 'forma-production'}
        ready = unittest.mock.Mock(returncode=0)
        with patch.object(self.ops.subprocess, 'run', return_value=ready) as run:
            self.assertTrue(self.ops.tunnel_ready(config))
        command = run.call_args.args[0]
        self.assertEqual(command[:3], ['docker', 'exec', 'forma-production-api-1'])
        self.assertIn('http://cloudflared:20241/ready', command[-1])
        with patch.object(self.ops.subprocess, 'run', return_value=unittest.mock.Mock(returncode=1)):
            self.assertFalse(self.ops.tunnel_ready(config))
        with patch.object(self.ops.subprocess, 'run', side_effect=self.ops.subprocess.TimeoutExpired('docker', 15)):
            self.assertFalse(self.ops.tunnel_ready(config))

    def test_one_failed_tunnel_probe_does_not_alert(self):
        state = {}
        self.assertFalse(self.ops.tunnel_signal(state, ready=False))
        self.assertTrue(self.ops.tunnel_signal(state, ready=False))
        self.assertFalse(self.ops.tunnel_signal(state, ready=True))
        self.assertEqual(state['tunnelFailures'], 0)

    def test_tunnel_is_not_judged_while_api_container_is_down(self):
        previous = {'tunnelFailures': 1}
        probe = unittest.mock.Mock(return_value=False)
        self.assertFalse(self.ops.tunnel_judgement(previous, False, probe))
        probe.assert_not_called()
        self.assertEqual(previous['tunnelFailures'], 1)
        # Once the API runs again, a genuine second tunnel failure still alerts.
        self.assertTrue(self.ops.tunnel_judgement(previous, True, probe))
        self.assertEqual(previous['tunnelFailures'], 2)

    def test_api_probe_uses_readyz_not_liveness(self):
        command = self.ops.api_ready_command({'project': 'forma-production'})
        self.assertEqual(command[:3], ['docker', 'exec', 'forma-production-api-1'])
        self.assertIn('http://127.0.0.1:3000/readyz', command[-1])
        self.assertNotIn('healthz', command[-1])

    def test_stopped_api_container_is_detected(self):
        stopped = json.dumps([{'State': {'Running': False}}]).encode()
        with patch.object(self.ops, 'run', return_value=stopped):
            self.assertFalse(self.ops.container_running('forma-production-api-1'))
        with patch.object(self.ops, 'run', side_effect=RuntimeError('container missing')):
            self.assertFalse(self.ops.container_running('forma-production-api-1'))

    def test_failed_alert_send_still_persists_failure_counts(self):
        with tempfile.TemporaryDirectory() as directory:
            state_file = pathlib.Path(directory) / 'state.json'
            state_file.write_text(json.dumps({'failures': 1, 'lastAlert': {}}))
            config = {'project': 'forma-production', 'stateFile': str(state_file), 'directory': directory}
            stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
            healthy_probe = unittest.mock.Mock(returncode=0, stdout=b'', stderr=b'')
            with patch.object(self.ops, 'container_healthy', return_value=False), \
                    patch.object(self.ops, 'container_running', return_value=True), \
                    patch.object(self.ops, 'tunnel_ready', return_value=True), \
                    patch.object(self.ops.subprocess, 'run', return_value=healthy_probe), \
                    patch.object(self.ops.Store, 'request', return_value=json.dumps({'createdAt': stamp}).encode()), \
                    patch.object(self.ops, 'alert', side_effect=RuntimeError('mail provider down')):
                with self.assertRaises(RuntimeError):
                    self.ops.monitor(config)
            saved = json.loads(state_file.read_text())
        # The second consecutive failure is recorded even though its alert was not delivered,
        # and no suppression window opens, so the next run retries the alert.
        self.assertEqual(saved['failures'], 2)
        self.assertEqual(saved['lastAlert'], {})

    def test_a_hung_readiness_probe_still_counts_and_alerts(self):
        with tempfile.TemporaryDirectory() as directory:
            state_file = pathlib.Path(directory) / 'state.json'
            config = {'project': 'forma-production', 'stateFile': str(state_file), 'directory': directory}
            stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
            sent = []
            hung = self.ops.subprocess.TimeoutExpired(cmd='docker exec', timeout=15)
            for _ in range(2):
                with patch.object(self.ops, 'container_healthy', return_value=True), \
                        patch.object(self.ops, 'container_running', return_value=True), \
                        patch.object(self.ops, 'tunnel_ready', return_value=True), \
                        patch.object(self.ops.subprocess, 'run', side_effect=hung), \
                        patch.object(self.ops.Store, 'request', return_value=json.dumps({'createdAt': stamp}).encode()), \
                        patch.object(self.ops, 'alert', side_effect=lambda _config, signals: sent.append(set(signals))):
                    self.ops.monitor(config)
            saved = json.loads(state_file.read_text())
        # A wedged API that makes docker exec time out is a failed probe, not a crashed monitor run.
        self.assertEqual(saved['healthFailures'], 2)
        self.assertIn('database_or_api_unhealthy', sent[-1])

    def test_a_restarting_container_is_not_treated_as_running(self):
        restarting = json.dumps([{'State': {'Running': True, 'Status': 'restarting'}}]).encode()
        with patch.object(self.ops, 'run', return_value=restarting):
            self.assertFalse(self.ops.container_running('forma-production-api-1'))
        running = json.dumps([{'State': {'Running': True, 'Status': 'running'}}]).encode()
        with patch.object(self.ops, 'run', return_value=running):
            self.assertTrue(self.ops.container_running('forma-production-api-1'))


if __name__ == '__main__':
    unittest.main()
