# -*- coding: utf-8 -*-

import logging
import msgpack
import random
import time
from gevent import socket
from gsocketpool.connection import Connection

from exceptions import RPCProtocolError, RPCError
from constants import MSGPACKRPC_REQUEST, MSGPACKRPC_RESPONSE, SOCKET_RECV_SIZE


class RPCClient(Connection):
    """RPC client.

    :param str host: Hostname.
    :param int port: Port number.
    :param int timeout: (optional) Socket timeout.
    :param int lifetime: (optional) Connection lifetime in seconds. Only valid
        when used with `gsocketpool.pool.Pool <http://gsocketpool.readthedocs.org/en/latest/api.html#gsocketpool.pool.Pool>`_.
    :param str pack_encoding: (optional) Character encoding used to pack data
        using Messagepack.
    :param str unpack_encoding: (optional) Character encoding used to unpack
        data using Messagepack.

    Usage:
        >>> from mprpc import RPCClient
        >>> 
        >>> client = RPCClient('127.0.0.1', 6000)
        >>> client.open()
        >>> 
        >>> print client.call('sum', 1, 2)
        3
    """

    def __init__(self, host, port, timeout=None, lifetime=None,
                 pack_encoding='utf-8', unpack_encoding='utf-8'):
        self._host = host
        self._port = port
        self._timeout = timeout

        self._msg_id = 0
        self._socket = None

        if lifetime:
            assert lifetime > 0, 'Lifetime must be a positive value'
            self._lifetime = time.time() + lifetime
            # avoid many connections expire simultaneously
            self._lifetime -= random.randint(0, 10)
        else:
            self._lifetime = None

        self._packer = msgpack.Packer(encoding=pack_encoding)
        self._unpacker = msgpack.Unpacker(encoding=unpack_encoding, use_list=False)

    def open(self):
        """Opens a connection."""

        assert self._socket is None, 'The connection has already been established'

        logging.debug('openning a msgpackrpc connection')
        self._socket = socket.create_connection((self._host, self._port))

        if self._timeout:
            self._socket.settimeout(self._timeout)

    def close(self):
        """Closes the connection."""

        assert self._socket is not None, 'Attempt to close an unopened socket'

        logging.debug('Closing a msgpackrpc connection')
        try:
            self._socket.close()
        except:
            logging.exception('An error has occurred while closing the socket')

        self._socket = None

    def is_connected(self):
        """Returns whether the connection has already been established.

        :rtype: bool
        """

        if self._socket:
            return True
        else:
            return False

    def call(self, method, *args):
        """Calls a RPC method.

        :param str method: Method name.
        :param args: Method arguments.
        """

        req = self._create_request(method, *args)

        try:
            self._socket.sendall(req)

            while True:
                data = self._socket.recv(SOCKET_RECV_SIZE)
                if not data:
                    raise IOError('Connection closed')
                self._unpacker.feed(data)
                try:
                    response = self._unpacker.next()
                    break
                except StopIteration:
                    continue

        except socket.timeout:
            self.reconnect()
            raise

        except IOError:
            self.reconnect()
            raise

        return self._parse_response(response)

    def is_expired(self):
        if not self._lifetime or time.time() > self._lifetime:
            return True
        else:
            return False

    def _create_request(self, method, *args):
        self._msg_id += 1
        req = (MSGPACKRPC_REQUEST, self._msg_id, method, args)
        return self._packer.pack(req)

    def _parse_response(self, response):
        if (not isinstance(response, tuple) or
            len(response) != 4 or
            response[0] != MSGPACKRPC_RESPONSE):
            raise RPCProtocolError('Invalid protocol')

        (_, msg_id, error, result) = response

        if not isinstance(msg_id, int):
            raise RPCProtocolError('Invalid protocol')

        if msg_id != self._msg_id:
            raise RPCError('Invalid Message ID')

        if error:
            raise RPCError(str(error))

        return result
