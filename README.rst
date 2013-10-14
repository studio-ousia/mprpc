mprpc
=====

mprpc is a fast MessagePack RPC implementation using `gevent <http://www.gevent.org/>`_.


Installation
------------

To install mprpc, simply:

.. code-block:: bash

    $ pip install mprpc

Alternatively,

.. code-block:: bash

    $ easy_install mprpc

Examples
--------

RPC server
^^^^^^^^^^

.. code-block:: python

    from gevent.server import StreamServer
    from mprpc import RPCServer

    class SumServer(RPCServer):
        def sum(self, x, y):
            return x + y

    server = StreamServer(('127.0.0.1', 6000), SumServer)
    server.serve_forever()


RPC client
^^^^^^^^^^

.. code-block:: python

    from mprpc import RPCClient

    def call():
        client = RPCClient('127.0.0.1', 6000)
        client.open()

        print client.call('sum', 1, 2)

    def call_using_pool():
        import gsocketpool.pool
        import gevent.pool

        options = dict(host='127.0.0.1', port=6000)
        client_pool = gsocketpool.pool.Pool(RPCClient, options)

        def _call(n):
            with client_pool.connection() as client:
                return client.call('sum', 1, 2)

        glet_pool = gevent.pool.Pool(10)
        print [result for result in glet_pool.imap_unordered(_call, xrange(10))]

    call()
    call_using_pool()

Benchmark
---------

.. code-block:: bash

    % python examples/benchmark.py
    call: 9061 qps
    call_using_pool: 9734 qps

NOTE: This significantly outperforms the `official MessagePack RPC <https://github.com/msgpack-rpc/msgpack-rpc-python>`_, which is based on `Facebook's Tornado <http://www.tornadoweb.org/en/stable/>`_. In our local environment, the QPS was around 4,000 using the benchmark code provided in the official implementation.

Environment
^^^^^^^^^^^

- OS: Mac OS X 10.8.5
- CPU: Intel Core i7 2GHz
- Memory: 8GB

Documentation
-------------

Documentation is available at http://mprpc.readthedocs.org/.
