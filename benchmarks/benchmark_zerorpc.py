# -*- coding: utf-8 -*-

import time
import multiprocessing

NUM_CALLS = 10000


def run_sum_server():
    import zerorpc

    class SumServer(object):
        def sum(self, x, y):
            return x + y

    server = zerorpc.Server(SumServer())
    server.bind("tcp://127.0.0.1:6000")
    server.run()


def call():
    import zerorpc

    client = zerorpc.Client()
    client.connect("tcp://127.0.0.1:6000")

    start = time.time()
    [client.sum(1, 2) for _ in xrange(NUM_CALLS)]

    print 'call: %d qps' % (NUM_CALLS / (time.time() - start))


if __name__ == '__main__':
    p = multiprocessing.Process(target=run_sum_server)
    p.start()

    time.sleep(1)

    call()

    p.terminate()
