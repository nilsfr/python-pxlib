#  -*- Pyrex -*-
# :Project:  pxpy -- Python wrapper around pxlib
# :Source:   $Source: /cvsroot/pxlib/bindings/python/pxpy.pyx,v $
# :Created:  Sun, Apr 04 2004 00:20:28 CEST
# :Author:   Lele Gaifax <lele@nautilus.homeip.net>
# :Revision: $Revision: 1.6 $ by $Author: lele $
# :Date:     $Date: 2004/09/25 01:18:17 $
#

"""
Python wrapper around pxlib.

This module, written in Cython_, allow to read data from Paradox tables
using the pxlib_ library.

.. _cython: http://pxlib.sourceforge.net/
.. _pxlib: http://pxlib.sourceforge.net/
"""

import datetime
import sys
import atexit

cimport cpython
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from cpython.version cimport PY_MAJOR_VERSION

from paradox cimport *

cdef void errorhandler(pxdoc_t *p, int type, char *msg, void *data):
    print 'error', type, msg

cdef class Record
cdef class PXDoc

cdef class Table:
    """
    A `Table` represent a Paradox table, with primary index and blob file.

    An instance has notion about the current record number, and
    keeps a copy of the values associated to each field.
    """

    cdef PXDoc doc
    cdef readonly Record record
    cdef int current_recno
    cdef PrimaryIndex primary_index
    targetEncoding = "utf8"
    inputEncoding = "utf8"
    
    cdef fields

    def __cinit__(self, filename):
        self.doc = PXDoc(filename)

    def create(self, *fields):
        self.fields = fields
        self.doc.create(fields)

    def open(self):
        """
        Open the data file and associate a Record instance.
        """
        self.doc.open()
        self.setTargetEncoding(self.targetEncoding)
        self.setInputEncoding(self.inputEncoding)
        self.record = Record(self.doc)
        self.current_recno = -1
        self.primary_index = None

    def close(self):
        """
        Close the eventual primary index or blob file, then the data file.
        """
        if self.primary_index:
            self.primary_index.close()
        self.doc.close()

    def getTableName(self):
        return self.doc.getTableName()

    def getTargetEncoding(self):
        return self.doc.targetEncoding

    def setTargetEncoding(self, encoding):
        self.doc.targetEncoding = encoding

    def getInputEncoding(self):
        return self.doc.inputEncoding

    def setInputEncoding(self, encoding):
        self.doc.inputEncoding = encoding

    def setPrimaryIndex(self, filename):
        """
        Set the primary index of the table.
        """
        self.primary_index = PrimaryIndex(filename)
        self.primary_index.open()
        self.doc.setPrimaryIndex(self.primary_index)

    def setBlobFile(self, filename):
        """
        Set and open the external blob file.
        """
        self.doc.setBlobFile(filename)

    def getFieldsCount(self):
        """
        Get number of fields in the table.
        """
        return len(self.record)

    def readRecord(self, recno=None):
        """
        Read the data of the next/some specific `recno` record.

        Return False if at EOF or `recno` is beyond the last record,
        True otherwise. This makes this method suitable to be called
        in a while loop in this way::

           record = t.record
           while t.readRecord():
               for i in range(record.getFieldsCount()):
                   f = record.fields[i]
                   value = f.getValue()
                   print "%s: %s" % (f.fname, value)
        """

        if not recno:
            recno = self.current_recno + 1
        else:
            self.current_recno = recno

        if recno >= len(self.doc):
            return False

        self.current_recno = recno

        return self.record.read(recno)

    def __iter__(self):
        return self

    def __next__(self):
        ok = self.readRecord()
        if not ok:
            self.current_recno = -1
            raise StopIteration()
        return self.record

    def __getitem__(self, key):
        if key >= len(self.doc):
            raise IndexError()
        self.record.read(key)
        return self.record

    def __len__(self):
        return len(self.doc)

    def append(self, values):
        self.doc.append(self.fields, values)
        self.current_recno = self.current_recno + 1


cdef class PXDoc:
    """
    Basic wrapper to 'pxdoc_t' based objects.
    """

    cdef pxdoc_t *px_doc
    cdef bytes filename
    cdef char isopen

    def __cinit__(self, filename):
        """
        Create a PXDoc instance, associated to the given external filename.
        """
        if PY_MAJOR_VERSION >= 3 or isinstance(filename, unicode):
            filename = filename.encode('utf8')
        self.filename = filename
        self.px_doc = PX_new2(&errorhandler, NULL, NULL, NULL)
        self.isopen = 0

    def __len__(self):
        return self.px_doc.px_head.px_numrecords

    def create(self, *fields):
        n = len(fields)
        cdef pxfield_t *f = <pxfield_t *>(self.px_doc.malloc(self.px_doc,
                                                          n * sizeof(pxfield_t),
                                                          "Memory for fields"))
        for i from 0 <= i < n:
            f[i].px_fname = PX_strdup(self.px_doc, fields[i].fname)
            f[i].px_flen = fields[i].flen
            f[i].px_ftype = fields[i].ftype
            f[i].px_fdc = 0

        if PX_create_file(self.px_doc, f, n, self.filename, pxfFileTypIndexDB) < 0:
            raise Exception("Couldn't open '%s'" % self.filename)
        self.isopen = 1
        self.current_recno = -1

    def open(self):
        """
        Open the data file.
        """
        if PX_open_file(self.px_doc, self.filename) < 0:
            raise Exception("Couldn't open `%s`" % self.filename)
        self.isopen = 1

    def close(self):
        """
        Close the data file if needed.
        """

        if self.isopen:
            PX_close(self.px_doc)
            self.isopen = 0

    def getCodePage(self):
        """
        Return the code page of the underlying Paradox table.
        """
        return "cp%d" % self.px_doc.px_head.px_doscodepage

    def _getTargetEncoding(self):
        if self.px_doc.targetencoding:
            return self.px_doc.targetencoding
        return None
    def _setTargetEncoding(self, encoding):
        PX_set_targetencoding(self.px_doc, encoding)
    targetEncoding = property(_getTargetEncoding, _setTargetEncoding)

    def _getInputEncoding(self):
        if self.px_doc.inputencoding:
            return self.px_doc.inputencoding
        return None
    def _setInputEncoding(self, encoding):
        PX_set_inputencoding(self.px_doc, encoding)
    inputEncoding = property(_getInputEncoding, _setInputEncoding)

    def setValue(self, parameter, value):
        PX_set_value(self.px_doc, parameter, <float>value)

    def setParameter(self, parameter, value):
        PX_set_parameter(self.px_doc, parameter, value)

    def getTableName(self):
        return self.px_doc.px_head.px_tablename

    def setBlobFile(self, filename):
        """
        Set and open the external blob file.
        """
        PX_set_blob_file(self.px_doc, filename)

    def setPrimaryIndex(self, PrimaryIndex index):
        """
        Set the primary index of the table.
        """
        if PX_add_primary_index(self.px_doc, index.px_doc) < 0:
            raise Exception("Couldn't add primary index `%s`" % index.filename)

    def append(self, fields, values):
        cdef char *b
        l = len(fields)
        n = sum([ f.flen for f in fields ])
        bufsize = n * sizeof(char)
        cdef char *buffer = <char *>(
            self.px_doc.malloc(self.px_doc, bufsize, "Memory for appended record"))
        memset(buffer, 0, bufsize)
        o = 0
        fs = {}
        for i from 0 <= i < l:
            f = fields[i]
            v = values.get(f.fname, None)
            l = f.flen
            if v == None:
                l = 0
            if f.ftype == pxfAlpha:
                s = str(v or '').decode(self.inputEncoding)
                s = s.encode(self.getCodePage())
                b = <char *>(self.px_doc.malloc(self.px_doc, f.flen, "Memory for alpha field"))
                memcpy(b, <char *>s, max(f.flen, len(s)))
                PX_put_data_alpha(self.px_doc, &buffer[o], f.flen, b)
                self.px_doc.free(self.px_doc, b)
            elif f.ftype == pxfLong:
                PX_put_data_long(self.px_doc, &buffer[o], l, <long>int(v or 0))
            elif f.ftype == pxfNumber:
                PX_put_data_double(self.px_doc, &buffer[o], l, <double>float(v or 0.0))
            else:
                raise Exception("unknown type")
            o += f.flen

        if PX_put_record(self.px_doc, buffer) == -1:
            raise Exception("unable to put record")

        self.px_doc.free(self.px_doc, buffer)


    def __dealloc__(self):
        """
        Close the data file
        """
        self.close()
        PX_delete(self.px_doc)



cdef class PrimaryIndex:
    """
    The primary index file.
    """

    cdef pxdoc_t *px_doc
    cdef bytes filename
    cdef char isopen

    def __cinit__(self, filename):
        """
        Create a PXDoc instance, associated to the given external filename.
        """
        if PY_MAJOR_VERSION >= 3 or isinstance(filename, unicode):
            filename = filename.encode('utf8')
        self.filename = filename
        self.px_doc = PX_new2(&errorhandler, NULL, NULL, NULL)
        self.isopen = 0

    def open(self):
        """
        Open the data file.
        """
        if PX_open_file(self.px_doc, self.filename) < 0:
            raise Exception("Couldn't open `%s`" % self.filename)
        if PX_read_primary_index(self.px_doc) < 0:
            raise Exception("Couldn't read primary index `%s`" % self.filename)
        self.isopen = 1

    def close(self):
        """
        Close the data file if needed.
        """
        if self.isopen:
            PX_close(self.px_doc)
            self.isopen = 0

    def __dealloc__(self):
        """
        Close the data file
        """
        self.close()
        PX_delete(self.px_doc)


cdef class ParadoxField:
    cdef readonly fname
    cdef readonly ftype
    cdef readonly flen

    def __cinit__(self, *args):
        pass

    def _init_fields(self, fname, int ftype, int flen):
        self.fname = fname
        self.ftype = ftype
        self.flen = flen

    def __init__(self, fname, int ftype, int flen):
        self._init_fields(fname, ftype, flen)


def default_field_length(int ftype, len = 10):
    if ftype == pxfLong:
        return 4
    elif ftype == pxfAlpha:
        return len
    elif ftype == pxfNumber:
        return 8
    else:
        return 0


def type_to_field_type(type ftype):
    if ftype == int:
        return pxfLong
    elif ftype == str:
        return pxfAlpha
    elif ftype == float:
        return pxfNumber
    else:
        raise Exception("unsupported field type %s" % ftype)


cdef class Field(ParadoxField):
    def __init__(self, fname, type t, int flen = 0):
        ft = type_to_field_type(t)
        fl = default_field_length(ft, flen)
        ParadoxField.__init__(self, fname, ft, fl)


cdef class RecordField(ParadoxField):
    """
    Represent a single field of a Record associated to some Table.
    """

    cdef void *data
    cdef Record record

    def __init__(self, Record record, int index, int offset):
        """
        Create a new instance, associated with the given `record`,
        pointing to the index-th field, which data is displaced by
        `offset` from the start of the record memory buffer.
        """

        self.record = record
        self.data = record.data+offset
        ParadoxField.__init__(self,
                              record.doc.px_doc.px_head.px_fields[index].px_fname,
                              record.doc.px_doc.px_head.px_fields[index].px_ftype,
                              record.doc.px_doc.px_head.px_fields[index].px_flen)

    def __str__(self):
        return self.__unicode__().encode(self.record.doc.targetEncoding)

    def __unicode__(self):
        return self.getValue()

    def getName(self):
        return self.fname
    name = property(getName)

    def getType(self):
        return self.ftype
    type = property(getType)

    def getValue(self):
        """
        Get the field's value.

        Return some Python value representing the current value of the field.
        """

        cdef double value_double
        cdef long value_long
        cdef char value_char
        cdef short value_short
        cdef int year, month, day
        cdef char *blobdata
        cdef int size
        cdef int mod_nr

        if self.ftype == pxfAlpha:
            codepage = self.record.doc.getCodePage()
            size = strnlen(<char*> self.data, self.flen)

            if size==0:
                return None
            else:
                py_string = PyString_FromStringAndSize(<char*> self.data, size);
                if not py_string:
                    raise Exception("Cannot get value from string %s" % self.fname)
                return PyString_AsDecodedObject(py_string, codepage, "replace")

        elif self.ftype == pxfDate:
            if PX_get_data_long(self.record.doc.px_doc,
                                self.data, self.flen, &value_long)<0:
                raise Exception("Cannot extract long field '%s'" % self.fname)
            if value_long:
                PX_SdnToGregorian(value_long+1721425,
                                  &year, &month, &day)
                return datetime.date(year, month, day)
            else:
                return None

        elif self.ftype == pxfShort:
            ret = PX_get_data_short(self.record.doc.px_doc,
                                    self.data, self.flen, &value_short)
            if ret < 0:
                raise Exception("Cannot extract short field '%s'" % self.fname)

            if ret == 0:
                return None

            return value_short

        elif self.ftype == pxfLong or self.ftype == pxfAutoInc:
            ret = PX_get_data_long(self.record.doc.px_doc,
                                   self.data, self.flen, &value_long)
            if ret < 0:
                raise Exception("Cannot extract long field '%s'" % self.fname)
            if ret == 0:
                return None

            return value_long

        elif self.ftype == pxfCurrency or self.ftype == pxfNumber:
            ret = PX_get_data_double(self.record.doc.px_doc,
                                     self.data, self.flen, &value_double)
            if ret < 0:
                raise Exception("Cannot extract double field '%s'" % self.fname)
            if ret == 0:
                return None
            return value_double

        elif self.ftype == pxfLogical:
            ret = PX_get_data_byte(self.record.doc.px_doc,
                                   self.data, self.flen, &value_char)
            if ret < 0:
                raise Exception("Cannot extract boolean field '%s'" % self.fname)
            if ret == 0:
                return None

            if value_char:
                return True
            else:
                return False

        elif self.ftype in [pxfMemoBLOb, pxfFmtMemoBLOb, pxfBLOb]:
            if not PX_has_blob_file(self.record.doc.px_doc):
                return "[MISSING BLOB FILE]"

            ret = PX_get_data_blob(self.record.doc.px_doc, self.data, self.flen,
                                   &mod_nr, &size, &blobdata)
            if ret < 0:
                raise Exception("Cannot extract blob field '%s'" % self.fname)
            if ret == 0:
                return None

            if blobdata and size > 0:
                codepage = self.record.doc.getCodePage()
                py_string = PyString_FromStringAndSize(<char*> blobdata, size)
                self.record.doc.px_doc.free(self.record.doc.px_doc, blobdata)
                if not py_string:
                    raise Exception("Cannot get value from string %s" % self.fname)
                return PyString_AsDecodedObject(py_string, codepage, "replace")

        elif self.ftype == pxfGraphic:
            if not PX_has_blob_file(self.record.doc.px_doc):
                return "[MISSING BLOB FILE]"

            ret = PX_get_data_graphic(self.record.doc.px_doc, self.data, self.flen,
                                      &mod_nr, &size, &blobdata)
            if ret < 0:
                raise Exception("Cannot extract graphic field '%s'" % self.fname)
            if ret == 0:
                return None

            if blobdata and size > 0:
                py_string = PyString_FromStringAndSize(blobdata, size)
                self.record.doc.px_doc.free(self.record.doc.px_doc, blobdata)
                return py_string


        elif self.ftype == pxfOLE:
            pass

        elif self.ftype == pxfTime:
            if PX_get_data_long(self.record.doc.px_doc,
                                self.data, self.flen, &value_long)<0:
                raise Exception("Cannot extract long field '%s'" % self.fname)
            if value_long:
                return datetime.time(value_long/3600000,
                                     value_long/60000%60,
                                     value_long%60000/1000.0)
            else:
                return None

        elif self.ftype == pxfTimestamp:
            pass
        elif self.ftype == pxfBCD:
            pass
        elif self.ftype == pxfBytes:
            pass
        elif self.ftype == pxfNumTypes:
            pass
    value = property(getValue)

cdef class Record:
    """
    An instance of this class wraps the memory buffer associated to a
    single record of a given PXDoc.
    """

    cdef void *data
    cdef int current_fieldno
    cdef PXDoc doc
    cdef public fields

    def __init__(self, PXDoc doc):
        """
        Create a Record instance, allocating the memory buffer and
        building the list of the Field instances.
        """

        cdef int offset

        self.data = doc.px_doc.malloc(doc.px_doc,
                                     doc.px_doc.px_head.px_recordsize,
                                     "Memory for record")
        self.current_fieldno = -1

        self.doc = doc
        self.fields = []
        offset = 0
        for i in range(len(self)):
            field = RecordField(self, i, offset)
            self.fields.append(field)
            offset = offset + doc.px_doc.px_head.px_fields[i].px_flen        

    def __len__(self):
        """
        Get number of fields in the record.
        """
        return self.doc.px_doc.px_head.px_numfields

    def read(self, recno):
        """
        Read the data associated to the record numbered `recno`.
        """

        if PX_get_record(self.doc.px_doc, recno, self.data) == NULL:
            raise Exception("Couldn't get record %d from '%s'" % (recno,
                                                                  self.doc.filename))
        return True

    def __iter__(self):
        return self

    def __next__(self):
        fieldno = self.current_fieldno + 1
        try:
            field = self.fields[fieldno]
            self.current_fieldno = fieldno
            return field
        except IndexError:
            self.current_fieldno = -1
            raise StopIteration()

    def __getitem__(self, key):
        return self.fields[key]

# Sets up locale for pxlib
PX_boot()

# Shut down pxlib
def __dealloc__():
    PX_shutdown()
atexit.register(__dealloc__)
