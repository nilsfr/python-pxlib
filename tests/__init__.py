#! /usr/bin/python
# -*- mode: python; coding: utf-8 -*-
# :Project:  pxpy -- silly tester
# :Source:   $Source: /cvsroot/pxlib/bindings/python/test.py,v $
# :Created:  Thu, May 13 2004 01:48:30 CEST
# :Author:   Lele Gaifax <lele@nautilus.homeip.net>
# :Revision: $Revision: 1.2 $ by $Author: lele $
# :Date:     $Date: 2004/07/19 14:38:04 $
# 
import unittest2 as unittest
import os.path
import pxpy

FIXTURE_DIR = os.path.join(os.path.dirname(__file__), 'fixtures')

class PxLibTest(unittest.TestCase):

    def test_headers(self):
        table = pxpy.Table(os.path.join(FIXTURE_DIR, 'KOMMENT.DB'))
        table.open()
        self.assertEqual(table.getTableName(), 'KOMMENT.DB')
        table.close()

    def test_iteration(self):
        table = pxpy.Table(os.path.join(FIXTURE_DIR, 'LAND.DB'))
        table.open()

        self.assertEqual(table.getFieldsCount(), 9)
        self.assertEqual(len(table), 216)
        try:
            table[216]
        except IndexError:
            pass
        else:
            self.fail()
        try:
            table[0][10]
        except IndexError:
            pass
        else:
            self.fail()
        
        afg = table[0][2]
        self.assertEquals(afg.getValue(), 'Afghanistan')
        self.assertEquals(afg.fname, 'Land_navn')

        for i, record in enumerate(table):
            for j, field in enumerate(record):
                same_field = table[i][j]
                self.assertEquals(field.getValue(), same_field.getValue())
                self.assertEquals(field.fname, same_field.fname)
        table.close()

    def test_blob_file(self):
        table = pxpy.Table(os.path.join(FIXTURE_DIR, 'KOMMENT.DB'))
        table.open()
        table.setBlobFile(os.path.join(FIXTURE_DIR, 'KOMMENT.MB'))
        
        baptistene = table[0]
        field = baptistene[0]
        self.assertEqual(field.name, u"Aar")
        self.assertEqual(field.value, u"2006")
        self.assertEqual(field.type, 1)
        
        self.assertEqual(baptistene[1].value, u"BAPTI")
        self.assertRegexpMatches(baptistene[3].value, r"^Statistikken inkluderer")

        
        for record in table:
            self.assertNotEqual(record[3], "[MISSING BLOB FILE]")

        
        table.close()

if __name__ == "__main__":
    unittest.main()

    
