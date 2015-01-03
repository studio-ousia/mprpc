mprpc
=====

.. image:: https://badge.fury.io/py/mprpc.png
    :target: http://badge.fury.io/py/mprpc

.. image:: https://travis-ci.org/studio-ousia/mprpc.png?branch=master
    :target: https://travis-ci.org/studio-ousia/mprpc

mprpc is a lightweight `MessagePack RPC <https://github.com/msgpack-rpc/msgpack-rpc>`_ library. It enables you to easily build a distributed server-side system by writing a small amount of code. It is built on top of `gevent <http://www.gevent.org/>`_ and `MessagePack <http://msgpack.org/>`_.


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

    server = StreamServer(('127.0.0.1', 6000), SumServer())
    server.serve_forever()

RPC client
^^^^^^^^^^

.. code-block:: python

    from mprpc import RPCClient

    client = RPCClient('127.0.0.1', 6000)
    print client.call('sum', 1, 2)


RPC client with connection pooling
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: python

    import gsocketpool.pool
    from mprpc import RPCPoolClient

    client_pool = gsocketpool.pool.Pool(RPCPoolClient, dict(host='127.0.0.1', port=6000))

    with client_pool.connection() as client:
        print client.call('sum', 1, 2)


Performance
-----------

mprpc significantly outperforms the `official MessagePack RPC <https://github.com/msgpack-rpc/msgpack-rpc-python>`_ (**1.8x** faster), which is built using `Facebook's Tornado <http://www.tornadoweb.org/en/stable/>`_ and `MessagePack <http://msgpack.org/>`_, and `ZeroRPC <http://zerorpc.dotcloud.com/>`_ (**14x** faster), which is built using `ZeroMQ <http://zeromq.org/>`_ and `MessagePack <http://msgpack.org/>`_.

Results
^^^^^^^

.. image:: https://raw.github.com/studio-ousia/mprpc/master/docs/img/perf.png
    :width: 550px
    :height: 150px
    :alt: Performance Comparison

mprpc
~~~~~

.. code-block:: bash

    % python benchmarks/benchmark.py
    call: 9508 qps
    call_using_connection_pool: 10172 qps


Official MesssagePack RPC
~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

    % pip install msgpack-rpc-python
    % python benchmarks/benchmark_msgpackrpc_official.py
    call: 4976 qps

ZeroRPC
~~~~~~~

.. code-block:: bash

    % pip install zerorpc
    % python benchmarks/benchmark_zerorpc.py
    call: 655 qps


Documentation
-------------

Documentation is available at http://mprpc.readthedocs.org/.
