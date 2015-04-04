#! /usr/bin/python
# -*- mode: python; coding: utf-8 -*-
# :Project:  python-pxpy
# :Source:   $Source: /cvsroot/pxlib/bindings/python/test.py,v $
# :Created:  Thu, May 13 2004 01:48:30 CEST
# :Author:   Lele Gaifax <lele@nautilus.homeip.net>
# :Revision: $Revision: 1.2 $ by $Author: lele $
# :Date:     $Date: 2004/07/19 14:38:04 $
# 
import unittest
import os.path
import pxpy

FIXTURE_DIR = os.path.join(os.path.dirname(__file__), 'fixtures')

class PxLibTest(unittest.TestCase):

    def __init__(self, *args, **kwargs):
        super(PxLibTest, self).__init__(*args, **kwargs)
        if not hasattr(self, 'assertRegex'):
            self.assertRegex = self.assertRegexpMatches

    def test_metadata(self):
        table = pxpy.Table(os.path.join(FIXTURE_DIR, 'KOMMENT.DB'))
        table.open()
        self.assertEqual(table.getTableName(), 'KOMMENT.DB')
        self.assertEqual(os.path.basename(table.getName()), 'KOMMENT.DB')
        self.assertEqual(table.getFieldCount(), 4)
        self.assertEqual(table.getFieldNames(), ['Aar', 'Org_kode', 'Merk', 'Kommentar'])
        self.assertEqual(table.getRecordCount(), 59)
        table.close()

    def test_iteration(self):
        table = pxpy.Table(
            os.path.join(FIXTURE_DIR, 'LAND.DB'),
            os.path.join(FIXTURE_DIR, 'LAND.PX'))
        table.open()

        self.assertEqual(table.getFieldCount(), 9)
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
        
        afg = table[0]
        field = afg[2]
        self.assertEqual(field.value, 'Afghanistan')
        self.assertEqual(field.name, 'Land_navn')
        field = afg['Land_navn']
        self.assertEqual(field.value, 'Afghanistan')
        self.assertEqual(field.name, 'Land_navn')

        for i, record in enumerate(table):
            for j, field in enumerate(record):
                same_field = table[i][j]
                self.assertEqual(field.value, same_field.value)
                self.assertEqual(field.name, same_field.name)
        table.close()

    def test_blob_file(self):
        table = pxpy.Table(
            os.path.join(FIXTURE_DIR, 'KOMMENT.DB'),
            blob_file=os.path.join(FIXTURE_DIR, 'KOMMENT.MB'))
        table.open()
        
        baptistene = table[0]
        field = baptistene[0]
        self.assertEqual(field.name, u"Aar")
        self.assertEqual(field.value, u"2006")
        self.assertEqual(field.type, 1)
        
        self.assertEqual(baptistene[1].value, u"BAPTI")
        self.assertRegex(baptistene[3].value, r"^Statistikken inkluderer")

        for record in table:
            self.assertNotEqual(record[3], "[MISSING BLOB FILE]")
        
        table.close()

    def test_context_manager(self):
        with pxpy.Table(os.path.join(FIXTURE_DIR, 'KOMMENT.DB')) as table:
            self.assertEqual(table.getTableName(), 'KOMMENT.DB')
        

if __name__ == "__main__":
    unittest.main()

    
