# -*- coding: utf-8 -*-

import gsocketpool.pool
import gevent.pool

from mprpc import RPCClient, RPCPoolClient


def call():
    client = RPCClient('127.0.0.1', 6000)

    print( client.call('sum', 1, 2))


def call_using_pool():
    options = dict(host='127.0.0.1', port=6000)
    client_pool = gsocketpool.pool.Pool(RPCPoolClient, options)

    def _call(n):
        with client_pool.connection() as client:
            return client.call('sum', 1, 2)

    glet_pool = gevent.pool.Pool(10)
    print([result for result in glet_pool.imap_unordered(_call, xrange(10))])


call()
call_using_pool()
