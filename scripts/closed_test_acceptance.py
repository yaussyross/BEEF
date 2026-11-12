#!/usr/bin/env python3
"""Owner-run smoke test. Never run against staging from the restricted workspace.
Only the pinned host and two reserved fixtures; secrets remain in process memory.
"""
import argparse
import base64
import getpass
import hashlib
import http.client
import json
import secrets
import sys
import urllib.error
import urllib.request
import uuid

ORIGIN = 'https://beef-synthetic-staging.onrender.com'
EMAILS = ('fictional-adult-a@example.test', 'fictional-adult-b@example.test')

class CheckFailed(Exception):
    pass

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise CheckFailed('Redirect refused; credentials were not forwarded.')

class Client:
    def __init__(self):
        self.opener = urllib.request.build_opener(NoRedirect())

    def request(self, path, expected=(200,), body=None, token=None, setup=None, upgrade=False):
        if not path.startswith('/api/') and path not in ('/', '/healthz', '/readyz'):
            raise CheckFailed('Unexpected test path.')
        headers = {'Accept': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        if setup:
            headers['X-BEEF-Test-Setup-Key'] = setup
        if body is not None:
            headers['Content-Type'] = 'application/json'
        nonce = base64.b64encode(secrets.token_bytes(16)).decode() if upgrade else None
        if upgrade:
            headers.update({'Connection': 'Upgrade', 'Upgrade': 'websocket',
                            'Sec-WebSocket-Version': '13', 'Sec-WebSocket-Key': nonce})
        if upgrade:
            # urllib forces Connection: close, so use a TLS HTTP/1.1 handshake.
            # Owner-run only; no invocation of this network path in workspace/CI.
            connection = http.client.HTTPSConnection('beef-synthetic-staging.onrender.com', timeout=90)
            try:
                connection.request('GET', path, headers=headers)
                response = connection.getresponse()
                if response.status not in expected:
                    raise CheckFailed('Unexpected WebSocket handshake status.')
                if response.status == 101:
                    accept = base64.b64encode(hashlib.sha1((nonce + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
                    if response.getheader('Sec-WebSocket-Accept') != accept:
                        raise CheckFailed('Invalid WebSocket handshake.')
                return response.status, {}
            except CheckFailed:
                raise
            except Exception:
                raise CheckFailed('WebSocket connection failed; details suppressed.') from None
            finally:
                connection.close()
        req = urllib.request.Request(ORIGIN + path, headers=headers,
            data=json.dumps(body).encode() if body is not None else None)
        try:
            try:
                response = self.opener.open(req, timeout=90)
            except urllib.error.HTTPError as error:
                response = error
            with response:
                status = response.code
                if status not in expected:
                    raise CheckFailed('Unexpected HTTP status during acceptance; no response body logged.')
                if status == 101:
                    expected_accept = base64.b64encode(hashlib.sha1((nonce + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
                    if response.headers.get('Sec-WebSocket-Accept') != expected_accept:
                        raise CheckFailed('Invalid WebSocket handshake.')
                    return status, {}
                if status == 404:
                    return status, {}
                raw = response.read(1_000_001)
                if len(raw) > 1_000_000:
                    raise CheckFailed('Unexpected oversized response.')
                return status, json.loads(raw or b'{}')
        except CheckFailed:
            raise
        except Exception:
            raise CheckFailed('Connection or response validation failed; details suppressed.') from None


def run(setup=False, client=None, prompt=getpass.getpass):
    client = client or Client()
    client.request('/readyz')
    client.request('/', expected=(404,))
    client.request('/api/me', expected=(401,))
    client.request('/api/ws', expected=(401,), upgrade=True)
    client.request('/api/login', expected=(403,), body={'email': 'fictional-outsider@example.test', 'password': 'not-an-account-password'})
    print('PASS readiness, hidden landing, anonymous HTTP/WSS and outsider denial')
    setup_key = prompt('Temporary setup key (hidden): ') if setup else None
    if setup and not 32 <= len(setup_key) <= 256:
        raise CheckFailed('Setup key must contain 32–256 characters.')
    accounts = []
    for index, email in enumerate(EMAILS):
        password = prompt(f'Fixture {index + 1} password from your password manager (hidden): ')
        if len(password) < 12:
            raise CheckFailed('Use a password of at least 12 characters.')
        body = {'email': email, 'password': password, 'birthdate': '1990-06-15'}
        client.request('/api/register', expected=(403,), body=body)
        if setup:
            confirmation = prompt(f'Confirm fixture {index + 1} password (hidden): ')
            if password != confirmation:
                raise CheckFailed('Password confirmation differs.')
            # Conflict never resets a password or changes an existing account.
            client.request('/api/register', expected=(201, 409), body=body, setup=setup_key)
        _, account = client.request('/api/login', body={'email': email, 'password': password})
        client.request('/api/me', token=account['accessToken'])
        client.request('/api/ws', expected=(101,), token=account['accessToken'], upgrade=True)
        accounts.append(account)
    setup_key = None
    first, second = accounts
    _, created = client.request('/api/threads', expected=(201,), token=first['accessToken'], body={'other_user_id': second['user']['id']})
    path = '/api/threads/' + created['thread']['id'] + '/messages'
    for account in accounts:
        message = {'client_message_id': str(uuid.uuid4()), 'body': 'Synthetic staging acceptance greeting.'}
        _, sent = client.request(path, expected=(201,), token=account['accessToken'], body=message)
        _, replay = client.request(path, token=account['accessToken'], body=message)
        if sent['message']['id'] != replay['message']['id'] or replay.get('duplicate') is not True:
            raise CheckFailed('Message retry was not idempotent.')
    for account in accounts:
        client.request(path, token=account['accessToken'])
    print('PASS fixture login, authenticated WSS handshake, conversation and REST message retries')
    print('Smoke checks passed. Two-device reconnect, five-minute ratings, privacy, block/report and reviewer acceptance remain.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--setup', action='store_true', help='Create only the two approved fixtures using a privately entered temporary setup key')
    args = parser.parse_args()
    if not sys.stdin.isatty():
        print('Interactive terminal required; do not pipe secrets or run in CI.')
        return 2
    try:
        run(setup=args.setup)
        return 0
    except (CheckFailed, KeyboardInterrupt):
        print('Acceptance stopped. No credentials or response details were logged. Do not reset existing accounts to force success.')
        return 1
    except Exception:
        print('Acceptance stopped on unexpected data; details suppressed to protect credentials.')
        return 1
    finally:
        if args.setup:
            print('Remove BEEF_CLOSED_TEST_SETUP_KEY from Render Environment now, even if setup failed. Save and let its single deploy finish.')

if __name__ == '__main__':
    raise SystemExit(main())
