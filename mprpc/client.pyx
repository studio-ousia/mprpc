# cython: profile=False
# -*- coding: utf-8 -*-

import logging
import msgpack
import time
from gevent import socket
from gsocketpool.connection import Connection

from exceptions import RPCProtocolError, RPCError
from constants import MSGPACKRPC_REQUEST, MSGPACKRPC_RESPONSE, SOCKET_RECV_SIZE


cdef class RPCClient:
    """RPC client.

    Usage:
        >>> from mprpc import RPCClient
        >>> client = RPCClient('127.0.0.1', 6000)
        >>> print client.call('sum', 1, 2)
        3

    :param str host: Hostname.
    :param int port: Port number.
    :param int timeout: (optional) Socket timeout.
    :param bool lazy: (optional) If set to True, the socket connection is not
        established until you specifically call open()
    :param str pack_encoding: (optional) Character encoding used to pack data
        using Messagepack.
    :param str unpack_encoding: (optional) Character encoding used to unpack
        data using Messagepack.
    :param dict pack_params: (optional) Parameters to pass to Messagepack Packer
    :param dict unpack_params: (optional) Parameters to pass to Messagepack
        Unpacker
    """

    cdef str _host
    cdef _port
    cdef str _unix_socket_path
    cdef int _msg_id
    cdef _timeout
    cdef _socket
    cdef _packer
    cdef _unpack_encoding
    cdef _unpack_params
    cdef _tcp_no_delay

    def __init__(self, host=None, port=None, unix_socket_path=None, timeout=None, lazy=False,
                 pack_encoding='utf-8', unpack_encoding='utf-8',
                 pack_params=dict(), unpack_params=dict(use_list=False),
                 tcp_no_delay=False):
        self._host = host
        self._port = port
        self._unix_socket_path = unix_socket_path
        self._timeout = timeout

        assert all((host, port)) or unix_socket_path, 'You must provide either host and port or unix_socket_path'

        self._msg_id = 0
        self._socket = None
        self._tcp_no_delay = tcp_no_delay
        self._unpack_encoding = unpack_encoding
        self._unpack_params = unpack_params

        self._packer = msgpack.Packer(encoding=pack_encoding, **pack_params)

        if not lazy:
            self.open()

    def _create_unix_socket_connection(self):
        """Creates connection to a unix domain socket."""
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        if self._timeout:
            sock.settimeout(self._timeout)
        sock.connect(self._unix_socket_path)
        return sock

    def _create_tcp_connection(self):
        """Creates a tcp connection, set TCP NODELAY."""
        if self._timeout:
            sock = socket.create_connection((self._host, self._port),
                                                    self._timeout)
        else:
            # use the default timeout value
            sock = socket.create_connection((self._host, self._port))
        # set TCP NODELAY
        if self._tcp_no_delay:
            self._socket.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        return sock

    def open(self):
        """Opens a connection."""

        assert self._socket is None, 'The connection has already been established'

        logging.debug('openning a msgpackrpc connection')

        if self._unix_socket_path:
            self._socket = self._create_unix_socket_connection()
        else:
            self._socket = self._create_tcp_connection()

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

    def call(self, str method, *args):
        """Calls a RPC method.

        :param str method: Method name.
        :param args: Method arguments.
        """

        cdef bytes req = self._create_request(method, args)

        cdef bytes data
        self._socket.sendall(req)

        unpacker = msgpack.Unpacker(encoding=self._unpack_encoding,
                                    **self._unpack_params)
        while True:
            data = self._socket.recv(SOCKET_RECV_SIZE)
            if not data:
                raise IOError('Connection closed')
            unpacker.feed(data)
            try:
                response = next(unpacker)
                break
            except StopIteration:
                continue

        return self._parse_response(response)

    cdef bytes _create_request(self, method, tuple args):
        self._msg_id += 1

        cdef tuple req
        req = (MSGPACKRPC_REQUEST, self._msg_id, method, args)

        return self._packer.pack(req)

    cdef _parse_response(self, tuple response):
        if (len(response) != 4 or response[0] != MSGPACKRPC_RESPONSE):
            raise RPCProtocolError('Invalid protocol')

        cdef int msg_id
        (_, msg_id, error, result) = response

        if msg_id != self._msg_id:
            raise RPCError('Invalid Message ID')

        if error:
            raise RPCError(str(error))

        return result


class RPCPoolClient(RPCClient, Connection):
    """Wrapper class of :class:`RPCClient <mprpc.client.RPCClient>` for `gsocketpool <https://github.com/studio-ousia/gsocketpool>`_.

    Usage:
        >>> import gsocketpool.pool
        >>> from mprpc import RPCPoolClient
        >>> client_pool = gsocketpool.pool.Pool(RPCPoolClient, dict(host='127.0.0.1', port=6000))
        >>> with client_pool.connection() as client:
        ...     print client.call('sum', 1, 2)
        ...
        3

    :param str host: Hostname.
    :param int port: Port number.
    :param int timeout: (optional) Socket timeout.
    :param int lifetime: (optional) Connection lifetime in seconds. Only valid
        when used with `gsocketpool.pool.Pool <http://gsocketpool.readthedocs.org/en/latest/api.html#gsocketpool.pool.Pool>`_.
    :param str pack_encoding: (optional) Character encoding used to pack data
        using Messagepack.
    :param str unpack_encoding: (optional) Character encoding used to unpack
        data using Messagepack.
    :param dict pack_params: (optional) Parameters to pass to Messagepack Packer
    :param dict unpack_params: (optional) Parameters to pass to Messagepack
        Unpacker
    """

    def __init__(self, host, port, timeout=None, lifetime=None,
                 pack_encoding='utf-8', unpack_encoding='utf-8',
                 pack_params=dict(), unpack_params=dict(use_list=False),
                 tcp_no_delay=False):

        if lifetime:
            assert lifetime > 0, 'Lifetime must be a positive value'
            self._lifetime = time.time() + lifetime
        else:
            self._lifetime = None

        RPCClient.__init__(
            self, host, port, timeout=timeout, lazy=True,
            pack_encoding=pack_encoding, unpack_encoding=unpack_encoding,
            pack_params=pack_params, unpack_params=unpack_params,
            tcp_no_delay=False)

    def is_expired(self):
        """Returns whether the connection has been expired.

        :rtype: bool
        """

        if not self._lifetime or time.time() > self._lifetime:
            return True

        else:
            return False

    def call(self, str method, *args):
        """Calls a RPC method.

        :param str method: Method name.
        :param args: Method arguments.
        """

        try:
            return RPCClient.call(self, method, *args)

        except socket.timeout:
            self.reconnect()
            raise

        except IOError:
            self.reconnect()
            raise
