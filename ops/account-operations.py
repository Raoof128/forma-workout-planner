#!/usr/bin/env python3
"""Private-host encrypted backups and bounded operational monitoring.

Configuration and signing keys must be root-only files outside the checkout.
Only ciphertext leaves the host. No database contents are printed.
"""
import collections
from contextlib import contextmanager
import datetime as dt
import hashlib
import hmac
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request


def run(argv, **kwargs):
    return subprocess.run(argv, check=True, capture_output=True, **kwargs).stdout


def validate_restore(database, archive):
    if not re.fullmatch(r'forma_restore_[A-Za-z0-9_]+', database):
        raise ValueError('Restore must use a separate forma_restore_ database')
    if not re.fullmatch(r'archives/forma-(staging|production)-\d{8}T\d{6}Z\.dump\.age', archive):
        raise ValueError('Invalid encrypted archive name')


def verify_archive(manifest, contents):
    validate_restore('forma_restore_validation', manifest['archive'])
    if not hmac.compare_digest(hashlib.sha256(contents).hexdigest(), manifest['sha256']):
        raise ValueError('Encrypted archive checksum mismatch')


def security_signals(events):
    signals = set()
    immediate = {'sign_in_lockout', 'mfa_lockout', 'email_suppressed', 'gateway_rejected'}
    for event in events:
        if event.get('event') in immediate:
            signals.add(event['event'])
    if sum(e.get('event') == 'sign_in_failure' for e in events) > 50:
        signals.add('sign_in_failures')
    actors = collections.Counter(e.get('actor') for e in events if e.get('event') == 'account_changed')
    if any(value > 20 for value in actors.values()):
        signals.add('account_changed')
    return signals


class Store:
    def __init__(self, config):
        self.config = config

    def request(self, method, key, body=b''):
        c = self.config
        host = c['account'] + '.r2.cloudflarestorage.com'
        path = '/' + c['bucket'] + '/' + urllib.parse.quote(key, safe='/~')
        now = dt.datetime.now(dt.timezone.utc)
        stamp, day = now.strftime('%Y%m%dT%H%M%SZ'), now.strftime('%Y%m%d')
        digest = hashlib.sha256(body).hexdigest()
        headers = {'host': host, 'x-amz-content-sha256': digest, 'x-amz-date': stamp}
        signed = ';'.join(sorted(headers))
        canonical = '\n'.join([method, path, '', ''.join(k + ':' + headers[k] + '\n' for k in sorted(headers)), signed, digest])
        scope = day + '/auto/s3/aws4_request'
        string = '\n'.join(['AWS4-HMAC-SHA256', stamp, scope, hashlib.sha256(canonical.encode()).hexdigest()])
        secret = ('AWS4' + c['secretAccessKey']).encode()
        for part in [day, 'auto', 's3', 'aws4_request']:
            secret = hmac.new(secret, part.encode(), hashlib.sha256).digest()
        signature = hmac.new(secret, string.encode(), hashlib.sha256).hexdigest()
        headers['Authorization'] = f"AWS4-HMAC-SHA256 Credential={c['accessKeyId']}/{scope}, SignedHeaders={signed}, Signature={signature}"
        request = urllib.request.Request('https://' + host + path, data=body if method == 'PUT' else None, headers=headers, method=method)
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.read()


def db_command(config, *args):
    return ['docker', 'exec', '-i', config.get('dbContainer', config['project'] + '-db-1'), 'sh', '-c',
                'export PGPASSWORD="$(cat "$POSTGRES_PASSWORD_FILE")"; exec "$@"',
                'sh', *args]


def db(config, *args, input=None):
    return run(db_command(config, *args), input=input)


def sql(config, statement, database='forma', snapshot=None):
    if snapshot:
        if not re.fullmatch(r'[0-9A-Fa-f]+-[0-9A-Fa-f]+-[0-9A-Fa-f]+', snapshot):
            raise ValueError('Invalid database snapshot')
        statement = f"BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY; SET TRANSACTION SNAPSHOT '{snapshot}'; {statement}; COMMIT;"
    return db(config, 'psql', '-h', '127.0.0.1', '-U', 'forma_bootstrap', '-d', database,
              '-qAt', '-v', 'ON_ERROR_STOP=1', '-c', statement).decode().strip()


def fingerprint(config, database='forma', snapshot=None):
    # Fingerprints cover every table without exposing its rows or identifiers.
    tables = sql(config, "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename", database, snapshot).splitlines()
    values = []
    for table in tables:
        if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', table):
            raise ValueError('Unexpected table name')
        statement = f'''SELECT md5(coalesce(string_agg(to_jsonb(t)::text, E'\\n' ORDER BY to_jsonb(t)::text), '')) FROM "{table}" t'''
        values.append(table + ':' + sql(config, statement, database, snapshot))
    return hashlib.sha256('\n'.join(values).encode()).hexdigest()


@contextmanager
def exported_snapshot(config):
    process = subprocess.Popen(db_command(config, 'psql', '-h', '127.0.0.1', '-U', 'forma_bootstrap', '-d', 'forma', '-qAt', '-v', 'ON_ERROR_STOP=1'),
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        process.stdin.write('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;\nSELECT pg_export_snapshot();\n')
        process.stdin.flush()
        snapshot = process.stdout.readline().strip()
        if not re.fullmatch(r'[0-9A-Fa-f]+-[0-9A-Fa-f]+-[0-9A-Fa-f]+', snapshot):
            raise RuntimeError('Could not export a consistent backup snapshot')
        yield snapshot
    finally:
        try:
            process.communicate('ROLLBACK;\n', timeout=15)
        except Exception:
            process.kill()
            process.wait()


def verify_restored(manifest, actual_fingerprint, project):
    if manifest.get('project') != project or manifest.get('databaseFingerprint') != actual_fingerprint:
        raise ValueError('Restore differs from signed backup-time integrity evidence')


def container_healthy(name):
    try:
        data = json.loads(run(['docker', 'inspect', name], timeout=15))[0]
        return bool(data['State']['Running'] and data['State'].get('Health', {}).get('Status', 'healthy') == 'healthy')
    except Exception:
        return False


def backup(config):
    store = Store(config)
    stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    key = f"archives/{config['project']}-{stamp}.dump.age"
    with tempfile.TemporaryDirectory(prefix='forma-backup-') as directory:
        archive = pathlib.Path(directory) / 'archive.age'
        with exported_snapshot(config) as snapshot:
            expected_fingerprint = fingerprint(config, snapshot=snapshot)
            dump = subprocess.Popen(db_command(config, 'pg_dump', '-h', '127.0.0.1', '-U', 'forma_bootstrap', '-d', 'forma', '-Fc', '--no-owner', '--no-privileges', '--snapshot=' + snapshot), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                encrypted = subprocess.run([config['age'], '-r', config['recipient'], '-o', str(archive)], stdin=dump.stdout, capture_output=True, timeout=120)
                dump.stdout.close()
                dump.communicate(timeout=120)
                if dump.returncode or encrypted.returncode:
                    raise RuntimeError('Database dump or encryption failed')
            finally:
                if dump.poll() is None:
                    dump.kill()
                    dump.wait()
        if archive.stat().st_size > 64 * 1024 * 1024:
            raise RuntimeError('Encrypted archive exceeds initial-host backup capacity; review capacity')
        contents = archive.read_bytes()
        manifest = {'archive': key, 'sha256': hashlib.sha256(contents).hexdigest(), 'createdAt': stamp,
                    'project': config['project'], 'databaseFingerprint': expected_fingerprint}
        manifest_bytes = (json.dumps(manifest, sort_keys=True) + '\n').encode()
        manifest_file = pathlib.Path(directory) / 'manifest.json'
        manifest_file.write_bytes(manifest_bytes)
        signature = run(['openssl', 'pkeyutl', '-sign', '-rawin', '-inkey', config['signingKey'], '-in', str(manifest_file)])
        store.request('PUT', key, contents)
        store.request('PUT', key + '.json', manifest_bytes)
        store.request('PUT', key + '.sig', signature)
        # Read the real uploaded objects before recording success.
        verify_archive(json.loads(store.request('GET', key + '.json')), store.request('GET', key))
        if store.request('GET', key + '.sig') != signature:
            raise RuntimeError('Uploaded signature differs')
        store.request('PUT', 'latest.json', manifest_bytes)
        print(json.dumps({'encryptedOffHostBackup': True, 'signatureUploaded': True, 'archive': key}))
        return key


def restore(config, key, identity_file):
    database = 'forma_restore_' + dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    validate_restore(database, key)
    store = Store(config)
    contents = store.request('GET', key)
    manifest_bytes = store.request('GET', key + '.json')
    manifest = json.loads(manifest_bytes)
    if manifest.get('archive') != key:
        raise ValueError('Signed archive name differs from requested backup')
    verify_archive(manifest, contents)
    with tempfile.TemporaryDirectory(prefix='forma-restore-') as directory:
        root = pathlib.Path(directory)
        for name, data in [('archive.age', contents), ('manifest.json', manifest_bytes), ('manifest.sig', store.request('GET', key + '.sig'))]:
            (root / name).write_bytes(data)
        run(['openssl', 'pkeyutl', '-verify', '-pubin', '-rawin', '-inkey', config['verificationKey'], '-in', str(root / 'manifest.json'), '-sigfile', str(root / 'manifest.sig')])
        db(config, 'createdb', '-h', '127.0.0.1', '-U', 'forma_bootstrap', database)
        try:
            decrypted = subprocess.Popen([config['age'], '-d', '-i', identity_file, str(root / 'archive.age')], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            restored = subprocess.run(db_command(config, 'pg_restore', '-h', '127.0.0.1', '-U', 'forma_bootstrap', '-d', database, '--exit-on-error', '--no-owner', '--no-privileges'), stdin=decrypted.stdout, capture_output=True)
            decrypted.stdout.close()
            decrypted.communicate(timeout=120)
            if decrypted.returncode or restored.returncode:
                raise RuntimeError('Decryption or isolated restore failed')
            verify_restored(manifest, fingerprint(config, database), config['project'])
            print(json.dumps({'offHostRestoreVerified': True, 'signedSnapshotMatches': True, 'liveDatabaseNotTargeted': True}))
        finally:
            db(config, 'dropdb', '-h', '127.0.0.1', '-U', 'forma_bootstrap', database)


def alert(config, signals, test=False):
    if not signals:
        return
    subject = '[FORMA OPERATIONS' + (' TEST' if test else '') + '] ' + config['project']
    text = 'FORMA requires attention.\n\nSignals: ' + ', '.join(sorted(signals)) + '\n\nCheck the private host logs and docs/security/incident-response.md. No member data is included.'
    body = json.dumps({'from': {'name': 'FORMA Operations', 'address': config['emailFrom']}, 'to': config['alertTo'], 'subject': subject, 'text': text,
                       'html': '<div style="font:16px Arial;background:#f5f7ef;padding:32px;color:#242a20"><h1>FORMA operations</h1><p>' + text.replace('\n', '<br>') + '</p></div>'}).encode()
    request = urllib.request.Request(f"https://api.cloudflare.com/client/v4/accounts/{config['account']}/email/sending/send", data=body,
        headers={'Authorization': 'Bearer ' + config['emailToken'], 'Content-Type': 'application/json'}, method='POST')
    with urllib.request.urlopen(request, timeout=30) as response:
        result = json.load(response)
    accepted = result.get('result', {})
    if not result.get('success') or config['alertTo'] not in accepted.get('queued', []) + accepted.get('delivered', []):
        raise RuntimeError('Operations alert was not accepted')
    print(json.dumps({'alertAccepted': True, 'signals': sorted(signals), 'test': test}))


def monitor(config):
    state_file = pathlib.Path(config['stateFile'])
    previous = json.loads(state_file.read_text()) if state_file.exists() else {'failures': 0, 'lastAlert': {}}
    signals = set()
    statuses = []
    for service in ['api', 'db', 'cloudflared']:
        statuses.append(container_healthy(config['project'] + '-' + service + '-1'))
    previous['failures'] = 0 if all(statuses) else previous['failures'] + 1
    if previous['failures'] >= 2:
        signals.add('backend_unhealthy')
    # Trusted local API probe includes database connectivity via /healthz.
    probe = subprocess.run(['docker', 'exec', config['project'] + '-api-1', 'node', '-e',
        "fetch('http://127.0.0.1:3000/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"], capture_output=True, timeout=15)
    if probe.returncode:
        previous['healthFailures'] = previous.get('healthFailures', 0) + 1
        if previous['healthFailures'] >= 2:
            signals.add('database_or_api_unhealthy')
    else:
        previous['healthFailures'] = 0
    logs = subprocess.run(['docker', 'logs', '--since', '5m', '--tail', '5000', config['project'] + '-api-1'], capture_output=True, timeout=15)
    events = []
    for line in (logs.stdout + logs.stderr).decode(errors='replace').splitlines():
        try:
            event = json.loads(line)
            if event.get('msg') == 'auth email suppressed by budget':
                events.append({'event': 'email_suppressed'})
            elif event.get('event'):
                events.append(event)
        except ValueError:
            continue
    signals.update(security_signals(events))
    pglogs = subprocess.run(['docker', 'logs', '--since', '5m', '--tail', '500', config['project'] + '-db-1'], capture_output=True, timeout=15)
    if re.search(rb'password authentication failed|too many clients|remaining connection slots', pglogs.stdout + pglogs.stderr):
        signals.add('database_auth_or_connection_limit')
    tunnel = subprocess.run(['docker', 'logs', '--since', '5m', '--tail', '500', config['project'] + '-cloudflared-1'], capture_output=True, timeout=15)
    if b'Registered tunnel connection' not in tunnel.stdout + tunnel.stderr and re.search(rb'ERR.*(failed|error)', tunnel.stdout + tunnel.stderr):
        signals.add('tunnel_error')
    try:
        manifest = json.loads(Store(config).request('GET', 'latest.json'))
        age = dt.datetime.now(dt.timezone.utc) - dt.datetime.strptime(manifest['createdAt'], '%Y%m%dT%H%M%SZ').replace(tzinfo=dt.timezone.utc)
        if age > dt.timedelta(hours=26):
            signals.add('backup_overdue')
    except Exception:
        signals.add('backup_unavailable')
    disk = os.statvfs(config['directory'])
    if disk.f_bavail / disk.f_blocks < 0.15:
        signals.add('disk_capacity')
    now = dt.datetime.now(dt.timezone.utc).timestamp()
    fresh = {s for s in signals if now - previous['lastAlert'].get(s, 0) > 3600}
    alert(config, fresh)
    for signal in fresh:
        previous['lastAlert'][signal] = now
    state_file.write_text(json.dumps(previous))
    os.chmod(state_file, 0o600)
    print(json.dumps({'monitorSignals': sorted(signals), 'healthy': not signals}))


def main():
    os.umask(0o077)
    config_file, command = sys.argv[1:3]
    config = json.loads(pathlib.Path(config_file).read_text())
    if command == 'backup':
        try:
            backup(config)
        except Exception:
            alert(config, {'backup_failed'})
            raise
    elif command == 'restore':
        restore(config, sys.argv[3], sys.argv[4])
    elif command == 'monitor':
        monitor(config)
    elif command == 'test-alert':
        alert(config, {'launch_delivery_test'}, test=True)
    else:
        raise ValueError('Unknown operations command')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Do not print subprocess output or exception bodies containing secrets.
        print('FORMA operations failed: ' + type(error).__name__, file=sys.stderr)
        sys.exit(1)
