# -*- coding: utf-8 -*-

import sys
from setuptools import setup, find_packages
from Cython.Build import cythonize

if 'setuptools.extension' in sys.modules:
    m = sys.modules['setuptools.extension']
    m.Extension.__dict__ = m._Extension.__dict__

setup(
    name='mprpc',
    version='0.1.1',
    description='A fast MessagePack RPC library',
    long_description=open('README.rst').read(),
    author='Studio Ousia',
    author_email='admin@ousia.jp',
    url='http://github.com/studio-ousia/mprpc',
    packages=find_packages(),
    ext_modules=cythonize('mprpc/*.pyx'),
    license=open('LICENSE').read(),
    include_package_data=True,
    keywords=['rpc', 'msgpack', 'messagepack', 'msgpackrpc', 'messagepackrpc',
              'messagepack rpc', 'gevent'],
    classifiers=(
        'Development Status :: 4 - Beta',
        'Intended Audience :: Developers',
        'Natural Language :: English',
        'License :: OSI Approved :: Apache Software License',
        'Programming Language :: Python',
        'Programming Language :: Python :: 2.6',
        'Programming Language :: Python :: 2.7',
    ),
    install_requires=[
        'gsocketpool',
        'gevent',
        'msgpack-python',
    ],
    setup_requires=[
        'setuptools_cython',
    ],
    tests_require=[
        'nose',
        'mock',
    ],
    test_suite = 'nose.collector'
)
