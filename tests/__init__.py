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

    def test_context_manager(self):
        with pxpy.Table(os.path.join(FIXTURE_DIR, 'KOMMENT.DB')) as table:
            self.assertEqual(table.getTableName(), 'KOMMENT.DB')

    def test_getitem(self):
        with pxpy.Table(
            os.path.join(FIXTURE_DIR, 'LAND.DB'),
            os.path.join(FIXTURE_DIR, 'LAND.PX')
        ) as table:
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

            try:
                table[-217]
            except IndexError:
                pass
            else:
                self.fail()

            first = table[0]
            self.assertEqual(first[0].getValue(), 'AFG')
            field = first[2]
            self.assertEqual(field.getName(), 'Land_navn')
            self.assertEqual(field.getValue(), 'Afghanistan')
            field = first['Land_navn']
            self.assertEqual(field.getName(), 'Land_navn')
            self.assertEqual(field.getValue(), 'Afghanistan')

            last = table[-1]
            field = last[0]
            self.assertEqual(field.getName(), 'Land_kode')
            self.assertEqual(field.getValue(), 'ZZZ')

            first_negative = table[-216]
            self.assertEqual(first[0].getValue(), first_negative[0].getValue())

    def test_iteration(self):
        table = pxpy.Table(
            os.path.join(FIXTURE_DIR, 'LAND.DB'),
            os.path.join(FIXTURE_DIR, 'LAND.PX'))
        table.open()
        for i, record in enumerate(table):
            for j, field in enumerate(record):
                same_field = table[i][j]
                self.assertEqual(field.getValue(), same_field.getValue())
                self.assertEqual(field.getName(), same_field.getName())
        table.close()

    def test_blob_file(self):
        table = pxpy.Table(
            os.path.join(FIXTURE_DIR, 'KOMMENT.DB'),
            blob_file=os.path.join(FIXTURE_DIR, 'KOMMENT.MB'))
        table.open()
        
        baptistene = table[0]
        field = baptistene[0]
        self.assertEqual(field.getName(), u"Aar")
        self.assertEqual(field.getValue(), u"2006")
        self.assertEqual(field.type, 1)
        
        self.assertEqual(baptistene[1].getValue(), u"BAPTI")
        self.assertRegex(baptistene[3].getValue(), r"^Statistikken inkluderer")

        for record in table:
            self.assertNotEqual(record[3], "[MISSING BLOB FILE]")
        
        table.close()

    def test_table_slice(self):
        with pxpy.Table(
                os.path.join(FIXTURE_DIR, 'LAND.DB'),
                os.path.join(FIXTURE_DIR, 'LAND.PX')
        ) as table:
            first_10 = table[:10]
            self.assertEqual(len(first_10), 10)
            iterations = 0
            for record in first_10:
                iterations += 1
            self.assertEqual(iterations, 10)
            second_iteration = 0
            for record in first_10:
                second_iteration += 1
            self.assertEqual(second_iteration, 10)

            last_10 = table[-10:]
            self.assertEqual(len(last_10), 10)
            iterations = 0
            for record in last_10:
                iterations += 1
            self.assertEqual(iterations, 10)

            same_positive = table[-10:-10]
            self.assertEqual(len(same_positive), 0)

            same_negative = table[-10:-10]
            self.assertEqual(len(same_negative), 0)

            over_limit = table[-10:1000]
            self.assertEqual(len(over_limit), 10)
            iterations = 0
            for record in over_limit:
                iterations += 1
            self.assertEqual(iterations, 10)

            over_offset = table[1000:]
            self.assertEqual(len(over_offset), 0)

            middle = table[10:-10]
            self.assertEqual(len(middle), len(table) - 20)
        

if __name__ == "__main__":
    unittest.main()

    
