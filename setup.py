#!/usr/bin/env python
# -*- coding: utf-8 -*-
# :Project:  pxpy -- Module setup
# :Source:   $Source: /cvsroot/pxlib/bindings/python/Setup.py,v $
# :Created:  Sun, Apr 04 2004 00:14:12 CEST
# :Author:   Lele Gaifax <lele@nautilus.homeip.net>
# :Revision: $Revision: 1.3 $ by $Author: lele $
# :Date:     $Date: 2004/07/19 23:04:35 $
#
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), '.pyrex'))

from setuptools import setup, Extension
from distutils.command.clean import clean as _clean
from distutils import log
from Cython.Distutils import build_ext


class clean(_clean):
    """
    Subclass clean so it removes all the Cython generated C files.
    """
    
    def run(self):
        _clean.run(self)
        for ext in self.distribution.ext_modules:
            cy_sources = [s for s in ext.sources if s.endswith('.pyx')]
            for cy_source in cy_sources:
                for extension in ('c', 'so'):
                    xfile = cy_source[:-3] + extension
                    if os.path.exists(xfile):
                        log.info('removing %s', xfile)
                        os.remove(xfile)

setup(
    name='python-pxlib',
    description="Python wrapper around pxlib",
    version='0.0.1',
    author="Lele Gaifax",
    author_email="lele@nautilus.homeip.net",
    url="http://pxlib.sourceforge.net/",
    test_suite='tests',
    cmdclass={
        'build_ext': build_ext,
        'clean': clean
    },
    data_files=[
        ('', ['pxpy.pyx'])
    ],
    zip_safe=False,
    setup_requires=["Cython>=0.13"],
    tests_require=["unittest2==0.5.1"],
    ext_modules=[
        Extension('pxpy', ['pxpy.pyx'],
                  libraries=['px']),
        ],
    )
