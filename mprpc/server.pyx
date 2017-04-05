# cython: profile=False
# -*- coding: utf-8 -*-

import gevent.socket
import msgpack

from constants import MSGPACKRPC_REQUEST, MSGPACKRPC_RESPONSE, SOCKET_RECV_SIZE
from exceptions import MethodNotFoundError, RPCProtocolError
from gevent.local import local


cdef class RPCServer:
    """RPC server.

    This class is assumed to be used with gevent StreamServer.

    :param str pack_encoding: (optional) Character encoding used to pack data
        using Messagepack.
    :param str unpack_encoding: (optional) Character encoding used to unpack
        data using Messagepack
    :param dict pack_params: (optional) Parameters to pass to Messagepack Packer
    :param dict unpack_params: (optional) Parameters to pass to Messagepack
        Unpacker

    Usage:
        >>> from gevent.server import StreamServer
        >>> import mprpc
        >>>
        >>> class SumServer(mprpc.RPCServer):
        ...     def sum(self, x, y):
        ...         return x + y
        ...
        >>>
        >>> server = StreamServer(('127.0.0.1', 6000), SumServer())
        >>> server.serve_forever()
    """

    cdef _packer
    cdef _unpack_encoding
    cdef _unpack_params
    cdef _tcp_no_delay
    cdef _methods
    cdef _address

    def __init__(self, *args, **kwargs):
        pack_encoding = kwargs.pop('pack_encoding', 'utf-8')
        pack_params = kwargs.pop('pack_params', dict())

        self._unpack_encoding = kwargs.pop('unpack_encoding', 'utf-8')
        self._unpack_params = kwargs.pop('unpack_params', dict(use_list=False))

        self._tcp_no_delay = kwargs.pop('tcp_no_delay', False)
        self._methods = {}

        self._packer = msgpack.Packer(encoding=pack_encoding, **pack_params)

        self._address = local()
        self._address.client_host = None
        self._address.client_port = None

        if args and isinstance(args[0], gevent.socket.socket):
            self._run(_RPCConnection(args[0]))

    def __call__(self, sock, address):
        if self._tcp_no_delay:
            sock.setsockopt(gevent.socket.IPPROTO_TCP, gevent.socket.TCP_NODELAY, 1)

        self._address.client_host = address[0]
        self._address.client_port = address[1]

        self._run(_RPCConnection(sock))

    property client_host:
        def __get__(self):
            return self._address.client_host

    property client_port:
        def __get__(self):
            return self._address.client_port

    def _run(self, _RPCConnection conn):
        cdef bytes data
        cdef int msg_id

        unpacker = msgpack.Unpacker(encoding=self._unpack_encoding,
                                    **self._unpack_params)
        while True:
            data = conn.recv(SOCKET_RECV_SIZE)
            if not data:
                break

            unpacker.feed(data)
            try:
                req = next(unpacker)
            except StopIteration:
                continue

            if type(req) not in (tuple, list):
                self._send_error("Invalid protocol", -1, conn)
                # reset unpacker as it might have garbage data
                unpacker = msgpack.Unpacker(encoding=self._unpack_encoding,
                                            **self._unpack_params)
                continue

            (msg_id, method, args) = self._parse_request(req)

            try:
                ret = method(*args)

            except Exception, e:
                self._send_error(str(e), msg_id, conn)

            else:
                self._send_result(ret, msg_id, conn)

    cdef tuple _parse_request(self, req):
        if (len(req) != 4 or req[0] != MSGPACKRPC_REQUEST):
            raise RPCProtocolError('Invalid protocol')

        cdef int msg_id

        (_, msg_id, method_name, args) = req

        method = self._methods.get(method_name, None)

        if method is None:
            if method_name.startswith('_'):
                raise MethodNotFoundError('Method not found: %s', method_name)

            if not hasattr(self, method_name):
                raise MethodNotFoundError('Method not found: %s', method_name)

            method = getattr(self, method_name)
            if not hasattr(method, '__call__'):
                raise MethodNotFoundError('Method is not callable: %s', method_name)

            self._methods[method_name] = method

        return (msg_id, method, args)

    cdef _send_result(self, object result, int msg_id, _RPCConnection conn):
        msg = (MSGPACKRPC_RESPONSE, msg_id, None, result)
        conn.send(self._packer.pack(msg))

    cdef _send_error(self, str error, int msg_id, _RPCConnection conn):
        msg = (MSGPACKRPC_RESPONSE, msg_id, error, None)
        conn.send(self._packer.pack(msg))


cdef class _RPCConnection:
    cdef _socket

    def __init__(self, socket):
        self._socket = socket

    cdef recv(self, int buf_size):
        return self._socket.recv(buf_size)

    cdef send(self, bytes msg):
        self._socket.sendall(msg)

    def __del__(self):
        try:
            self._socket.close()
        except:
            pass
