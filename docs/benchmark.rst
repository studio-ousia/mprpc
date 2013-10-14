Benchmark
=========

Environment
-----------

- OS: Mac OS X 10.8.5
- CPU: Intel Core i7 2GHz
- Memory: 8GB


Results
-------

.. code-block:: bash

    % python examples/benchmark.py
    call: 9061 qps
    call_using_pool: 9734 qps

.. note:: This significantly outperforms the `official MessagePack RPC <https://github.com/msgpack-rpc/msgpack-rpc-python>`_, which is based on `Facebook's Tornado <http://www.tornadoweb.org/en/stable/>`_. In our local environment, the QPS was around 4,000 using the benchmark code provided in the official implementation.

