# -*- coding: utf-8 -*-

from __future__ import absolute_import

import logging
try:  # Python 2.7+
    from logging import NullHandler
except ImportError:
    class NullHandler(logging.Handler):
        def emit(self, record):
            pass

logger = logging.getLogger(__name__)
logger.addHandler(NullHandler())

from mprpc.client import RPCClient, RPCPoolClient
from mprpc.server import RPCServer
