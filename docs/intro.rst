Introduction
============

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


RPC client with connection pooling using `gsocketpool <https://github.com/studio-ousia/gsocketpool>`_
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: python

    import gsocketpool.pool
    from mprpc import RPCPoolClient

    client_pool = gsocketpool.pool.Pool(RPCPoolClient, dict(host='127.0.0.1', port=6000))

    with client_pool.connection() as client:
        print client.call('sum', 1, 2)
