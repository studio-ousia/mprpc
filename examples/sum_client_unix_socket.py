# -*- coding: utf-8 -*-

from mprpc import RPCClient

client = RPCClient(unix_socket_path='/tmp/rpc.sock')
print client.call('sum', 1, 2)
