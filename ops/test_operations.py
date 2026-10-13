import importlib.util
import pathlib
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


if __name__ == '__main__':
    unittest.main()
