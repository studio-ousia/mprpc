# -*- coding: utf-8 -*-

import os

from gevent import socket
from gevent.server import StreamServer

from mprpc import RPCServer


class SumServer(RPCServer):
    def sum(self, x, y):
        return x + y


def bind(sockname='/tmp/rpc.sock'):
    listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    if os.path.exists(sockname):
        os.remove(sockname)
    listener.bind(sockname)
    listener.listen(1)
    return listener


server = StreamServer(bind(), SumServer())
server.serve_forever()
