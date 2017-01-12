# cython: predicateofile=False
# -*- coding: utf-8 -*-

import gevent.socket
import msgpack
import inspect

from constants import MSGPACKRPC_REQUEST, MSGPACKRPC_RESPONSE, SOCKET_RECV_SIZE
from exceptions import MethodNotFoundError, RPCProtocolError


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

    def __init__(self, *args, **kwargs):
        pack_encoding = kwargs.pop('pack_encoding', 'utf-8')
        pack_params = kwargs.pop('pack_params', dict())

        self._unpack_encoding = kwargs.pop('unpack_encoding', 'utf-8')
        self._unpack_params = kwargs.pop('unpack_params', dict(use_list=False))

        self._tcp_no_delay = kwargs.pop('tcp_no_delay', True)
        self._methods = dict((k, v) for k, v in inspect.getmembers(self, predicate=inspect.ismethod) if k[0] != '_')

        self._packer = msgpack.Packer(encoding=pack_encoding, **pack_params)

        if args and isinstance(args[0], gevent.socket.socket):
            self._run(_RPCConnection(args[0]))

    def __call__(self, sock, peername):
        if self._tcp_no_delay:
            sock.setsockopt(gevent.socket.IPPROTO_TCP, gevent.socket.TCP_NODELAY, 1)
        self._run(_RPCConnection(sock))

    def _run(self, _RPCConnection conn):
        cdef bytes data
        cdef tuple req, args
        cdef int msg_id

        self._connection = conn
        self._peer = conn.getpeername()
        if hasattr(self, '_connect'): self._connect()

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

            except Exception as e:
                if hasattr(self, '_error'):
                    self._error('invalid_protocol', data=data)
                break

            if type(req) != tuple:
                if hasattr(self, '_error'):
                    self._error('invalid_protocol', data=data)
                break

            if (len(req) != 4 or req[0] != MSGPACKRPC_REQUEST):
                if hasattr(self, '_error'):
                    self._error('invalid_protocol2', req=req)
                break

            _, msg_id, method_name, args = req
            method_fn = self._methods.get(method_name)
            if method_fn is None:
                if hasattr(self, '_error'):
                    self._error('method_nod_found', method_name=method_name, args=args)
                self._send_error('method_nod_found', msg_id, conn)
                continue

            if hasattr(self, '_call'): self._call(method_name, method_fn, args)
            try:
                ret = method_fn(*args)

            except Exception, e:
                if hasattr(self, '_error'):
                    self._error('method_fn', method_name=method_name, args=args, e=e)
                self._send_error('error', msg_id, conn)
                continue

            else:
                self._send_result(ret, msg_id, conn)

        if hasattr(self, '_disconnect'): self._disconnect()

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

    def getpeername(self):
        return self._socket.getpeername()

    cdef recv(self, int buf_size):
        return self._socket.recv(buf_size)

    cdef send(self, bytes msg):
        self._socket.sendall(msg)

    def __del__(self):
        try:
            self._socket.close()
        except:
            pass
