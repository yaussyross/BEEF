import contextlib
import importlib.util
import io
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('acceptance', Path(__file__).parents[1] / 'closed_test_acceptance.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class FixtureClient:
    def __init__(self): self.calls = []; self.login = 0; self.messages = {}
    def request(self, path, **kwargs):
        self.calls.append((path, kwargs))
        if path == '/api/login' and kwargs.get('expected') != (403,):
            self.login += 1
            return 200, {'accessToken': 'synthetic-secret-token', 'user': {'id': str(self.login)}}
        if path == '/api/threads': return 201, {'thread': {'id': 'synthetic-thread'}}
        if path.endswith('/messages') and kwargs.get('body'):
            key = kwargs['body']['client_message_id']; duplicate = key in self.messages
            self.messages[key] = True
            return (200 if duplicate else 201), {'message': {'id': key}, 'duplicate': duplicate}
        return kwargs.get('expected', (200,))[0], {}

class AcceptanceTests(unittest.TestCase):
    def test_setup_is_pinned_and_never_outputs_credentials(self):
        client = FixtureClient(); out = io.StringIO()
        values = iter(['synthetic-setup-key-0000000000000000'] + ['synthetic-private-password'] * 4)
        with contextlib.redirect_stdout(out): module.run(True, client, lambda _: next(values))
        self.assertNotIn('synthetic-setup-key', out.getvalue())
        self.assertNotIn('synthetic-private-password', out.getvalue())
        self.assertNotIn('synthetic-secret-token', out.getvalue())
        registrations = [k for p, k in client.calls if p == '/api/register']
        self.assertEqual(len(registrations), 4)
        self.assertEqual({r['body']['email'] for r in registrations}, set(module.EMAILS))
        self.assertEqual(sum(bool(r.get('setup')) for r in registrations), 2)
        self.assertTrue(any(k.get('upgrade') and k.get('token') for _, k in client.calls))

    def test_real_client_constructs_tls_upgrade_and_closes_without_logging(self):
        class Response:
            status = 101
            def getheader(self, name):
                return module.base64.b64encode(module.hashlib.sha1((connection.headers['Sec-WebSocket-Key'] + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
        class Connection:
            closed = False
            def request(self, method, path, headers): self.headers = headers
            def getresponse(self): return Response()
            def close(self): self.closed = True
        connection = Connection()
        with patch.object(module.http.client, 'HTTPSConnection', return_value=connection) as factory:
            status, _ = module.Client().request('/api/ws', expected=(101,), token='synthetic-private-token', upgrade=True)
        self.assertEqual(status, 101)
        self.assertEqual(connection.headers['Connection'], 'Upgrade')
        self.assertTrue(connection.closed)
        self.assertEqual(factory.call_args.args, ('beef-synthetic-staging.onrender.com',))

    def test_redirect_is_refused_before_forwarding(self):
        with self.assertRaises(module.CheckFailed):
            module.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://attacker.test')

    def test_short_setup_key_stops_before_registration(self):
        client = FixtureClient()
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(module.CheckFailed):
            module.run(True, client, lambda _: 'short')
        self.assertFalse(any(p == '/api/register' for p, _ in client.calls))

if __name__ == '__main__': unittest.main()
