# -*- coding: utf-8 -*-
from __future__ import print_function

import time
import multiprocessing

import sys

NUM_CALLS = 10000


def run_sum_server():
    from gevent.server import StreamServer
    from mprpc import RPCServer

    class SumServer(RPCServer):
        def sum(self, x, y):
            return x + y

    server = StreamServer(('127.0.0.1', 6000), SumServer())
    server.serve_forever()


def call():
    from mprpc import RPCClient

    client = RPCClient('127.0.0.1', 6000)

    start = time.time()
    [client.call('sum', 1, 2) for _ in range(NUM_CALLS)]

    print('call: %d qps' % (NUM_CALLS / (time.time() - start)))


def call_using_connection_pool():
    from mprpc import RPCPoolClient

    import gevent.pool
    import gsocketpool.pool

    def _call(n):
        with client_pool.connection() as client:
            return client.call('sum', 1, 2)

    options = dict(host='127.0.0.1', port=6000)
    client_pool = gsocketpool.pool.Pool(RPCPoolClient, options, initial_connections=20)
    glet_pool = gevent.pool.Pool(20)

    start = time.time()

    if sys.version_info < (3,):
        range = xrange
    else:
        import builtins
        range = builtins.range
    [None for _ in glet_pool.imap_unordered(_call, range(NUM_CALLS))]

    print('call_using_connection_pool: %d qps' % (NUM_CALLS / (time.time() - start)))


if __name__ == '__main__':
    p = multiprocessing.Process(target=run_sum_server)
    p.start()

    time.sleep(1)

    call()
    call_using_connection_pool()

    p.terminate()
