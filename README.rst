mprpc
=====

.. image:: https://badge.fury.io/py/mprpc.png
    :target: http://badge.fury.io/py/mprpc

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

    server = StreamServer(('127.0.0.1', 6000), SumServer)
    server.serve_forever()

RPC client
^^^^^^^^^^

.. code-block:: python

    from mprpc import RPCClient

    client = RPCClient('127.0.0.1', 6000)
    client.open()

    print client.call('sum', 1, 2)


RPC client with connection pooling using gsocketpool
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: python

    import gsocketpool.pool
    from mprpc import RPCClient

    client_pool = gsocketpool.pool.Pool(RPCClient, dict(host='127.0.0.1', port=6000))

    with client_pool.connection() as client:
        print client.call('sum', 1, 2)


Performance
-----------

mprpc significantly outperforms the `official MessagePack RPC <https://github.com/msgpack-rpc/msgpack-rpc-python>`_ (**1.8x** faster), which is built using `Facebook's Tornado <http://www.tornadoweb.org/en/stable/>`_ and `MessagePack <http://msgpack.org/>`_, and `ZeroRPC <http://zerorpc.dotcloud.com/>`_ (**14x** faster), which is built using `ZeroMQ <http://zeromq.org/>`_ and `MessagePack <http://msgpack.org/>`_.

Results
^^^^^^^

.. image:: http://chart.googleapis.com/chart?chxl=0:|zerorpc|msgpack-rpc-python|mprpc+with+pool|mprpc&chxr=0,-5,156.667&chxs=0,676767,12,0,lt,676767&chxt=y&chbh=a,7,4&chs=550x150&cht=bhs&chco=4D89F9&chds=0,9790&chd=t:9061,9790,4976,655&chdl=Queries+per+second&chdlp=b&chma=8,0,10
    :width: 500px
    :height: 150px
    :alt: Performance Comparison

mprpc
~~~~~

.. code-block:: bash

    % python benchmarks/benchmark.py
    call: 9061 qps
    call_using_connection_pool: 9790 qps


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


Environment
^^^^^^^^^^^

- OS: Mac OS X 10.8.5
- CPU: Intel Core i7 2GHz
- Memory: 8GB
- Python: 2.7.3

Documentation
-------------

Documentation is available at http://mprpc.readthedocs.org/.
