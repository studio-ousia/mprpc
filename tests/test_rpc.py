# -*- coding: utf-8 -*-

import gevent
from gevent import socket
from gevent.server import StreamServer

from nose.tools import *
from mock import Mock, patch

from mprpc.client import RPCClient
from mprpc.server import RPCServer
from mprpc.exceptions import RPCError

HOST = 'localhost'
PORT = 6000


class TestRPC(object):
    def setUp(self):
        class TestServer(RPCServer):
            def echo(self, msg):
                return msg

            def echo_delayed(self, msg, delay):
                gevent.sleep(delay)
                return msg

            def raise_error(self):
                raise Exception('error msg')

        self._server = StreamServer((HOST, PORT), TestServer)
        self._glet = gevent.spawn(self._server.serve_forever)

    def tearDown(self):
        self._glet.kill()

    @patch('mprpc.client.socket')
    def test_open_and_close(self, mock_socket):
        client = RPCClient(HOST, PORT)
        mock_socket_ins = Mock()
        mock_socket.create_connection.return_value = mock_socket_ins

        client.open()
        ok_(client.is_connected())

        mock_socket.create_connection.assert_called_once_with((HOST, PORT))

        client.close()

        ok_(mock_socket_ins.close.called)
        ok_(not client.is_connected())

    def test_open_with_timeout(self):
        client = RPCClient(HOST, PORT, timeout=5.0)

        client.open()

        eq_(5.0, client._socket.gettimeout())
        ok_(client.is_connected())

    def test_call(self):
        client = RPCClient(HOST, PORT)
        client.open()

        ret = client.call('echo', 'message')
        eq_('message', ret)

        ret = client.call('echo', 'message' * 100)
        eq_('message' * 100, ret)

    @raises(RPCError)
    def test_call_server_side_exception(self):
        client = RPCClient(HOST, PORT)
        client.open()

        try:
            ret = client.call('raise_error')
        except RPCError, e:
            eq_('error msg', e.message)
            raise

        eq_('message', ret)

    @raises(socket.timeout)
    def test_call_socket_timeout(self):
        client = RPCClient(HOST, PORT, timeout=0.1)
        client.open()

        client.reconnect = Mock()

        try:
            client.call('echo_delayed', 'message', 1)
        except socket.timeout:
            ok_(client.reconnect.called)
            raise

    def test_is_expired(self):
        client = RPCClient(HOST, PORT, lifetime=0.1)
        client.open()

        ok_(not client.is_expired())
        gevent.sleep(0.1)
        ok_(client.is_expired())
