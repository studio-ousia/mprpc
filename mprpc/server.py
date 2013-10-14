# -*- coding: utf-8 -*-

import logging
import msgpack
from gevent.coros import Semaphore

from constants import MSGPACKRPC_REQUEST, MSGPACKRPC_RESPONSE, SOCKET_RECV_SIZE
from exceptions import MethodNotFoundError, RPCProtocolError


class RPCServer(object):
    """RPC server.

    This class is assumed to be used with gevent StreamServer.

    :param socket: Socket object.
    :param tuple address: Client address.
    :param str pack_encoding: (optional) Character encoding used to pack data
        using Messagepack.
    :param str unpack_encoding: (optional) Character encoding used to unpack
        data using Messagepack.

    Usage:
        >>> from gevent.server import StreamServer
        >>> import mprpc
        >>> 
        >>> class SumServer(mprpc.RPCServer):
        ...     def sum(self, x, y):
        ...         return x + y
        ...
        >>> 
        >>> server = StreamServer(('127.0.0.1', 6000), SumServer)
        >>> server.serve_forever()
    """

    def __init__(self, sock, address, pack_encoding='utf-8',
                 unpack_encoding='utf-8'):
        self._socket = sock

        self._packer = msgpack.Packer(encoding=pack_encoding)
        self._unpacker = msgpack.Unpacker(encoding=unpack_encoding,
                                          use_list=False)
        self._send_lock = Semaphore()

        self._run()

    def __del__(self):
        try:
            self._socket.close()
        except:
            logging.exception('Failed to clean up the socket')

    def _run(self):
        while True:
            data = self._socket.recv(SOCKET_RECV_SIZE)
            if not data:
                logging.debug('Client disconnected')
                break

            self._unpacker.feed(data)
            try:
                req = self._unpacker.next()
            except StopIteration:
                continue

            (msg_id, method, args) = self._parse_request(req)

            try:
                ret = method(*args)

            except Exception, e:
                logging.exception('An error has occurred')
                self._send_error(str(e), msg_id)

            else:
                self._send_result(ret, msg_id)

    def _parse_request(self, req):
        if (not isinstance(req, tuple) or
            len(req) != 4 or
            req[0] != MSGPACKRPC_REQUEST):
            raise RPCProtocolError('Invalid protocol')

        (_, msg_id, method_name, args) = req

        if (not isinstance(msg_id, int) or
            not isinstance(method_name, basestring) or
            not isinstance(args, tuple)):
            raise RPCProtocolError('Invalid protocol')

        if method_name.startswith('_'):
            raise MethodNotFoundError('Method not found: %s', method_name)

        if not hasattr(self, method_name):
            raise MethodNotFoundError('Method not found: %s', method_name)

        method = getattr(self, method_name)
        if not hasattr(method, '__call__'):
            raise MethodNotFoundError('Method is not callable: %s', method_name)

        return (msg_id, method, args)

    def _send_result(self, result, msg_id):
        msg = (MSGPACKRPC_RESPONSE, msg_id, None, result)
        self._send(msg)

    def _send_error(self, error, msg_id):
        msg = (MSGPACKRPC_RESPONSE, msg_id, error, None)
        self._send(msg)

    def _send(self, msg):
        self._send_lock.acquire()
        try:
            self._socket.sendall(self._packer.pack(msg))

        finally:
            self._send_lock.release()
