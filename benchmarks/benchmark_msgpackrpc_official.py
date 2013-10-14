# -*- coding: utf-8 -*-

import time
import msgpackrpc
import multiprocessing

NUM_CALLS = 10000


def run_sum_server():
    class SumServer(object):
        def sum(self, x, y):
            return x + y

    server = msgpackrpc.Server(SumServer())
    server.listen(msgpackrpc.Address("localhost", 6000))
    server.start()


def call():
    client = msgpackrpc.Client(msgpackrpc.Address("localhost", 6000))

    start = time.time()
    [client.call('sum', 1, 2) for _ in xrange(NUM_CALLS)]

    print 'call: %d qps' % (NUM_CALLS / (time.time() - start))


if __name__ == '__main__':
    p = multiprocessing.Process(target=run_sum_server)
    p.start()

    time.sleep(1)

    call()

    p.terminate()
