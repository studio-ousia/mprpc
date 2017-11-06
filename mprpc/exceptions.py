# -*- coding: utf-8 -*-


class RPCProtocolError(Exception):
    pass


class MethodNotFoundError(Exception):
    pass


class RPCError(Exception):
    remote_exception_module = None
    remote_exception_type = None

