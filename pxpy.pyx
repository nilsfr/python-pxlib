#  -*- coding: utf-8 -*-

"""
Python wrapper around pxlib.

This module, written in Cython_, allow to read data from Paradox tables
using the pxlib_ library.

.. _cython: http://cython.org/
.. _pxlib: http://pxlib.sourceforge.net/
"""

import datetime
import sys
import atexit

from cpython.version cimport PY_MAJOR_VERSION

from paradox cimport *

cdef str DEFAULT_ENCODING="UTF-8"

cdef void errorhandler(pxdoc_t *p, int type, const_char_ptr msg, void *data):
    print("ParadoxError: {} - {}".format(type, msg))

cdef class Record
cdef class PXDoc

cdef class Table:
    """
    A `Table` represent a Paradox table, with primary index and blob file.
    """
    cdef PXDoc doc
    cdef RecordIterator defaultIterator
    cdef str target_encoding
    cdef str input_encoding
    cdef PrimaryIndex primary_index
    cdef bytes blob_file

    def __cinit__(self, filename, index_file=None, blob_file=None):
        self.target_encoding = DEFAULT_ENCODING
        self.input_encoding = DEFAULT_ENCODING
        self.doc = PXDoc(filename)
        self.primary_index = PrimaryIndex(index_file)\
            if index_file is not None else None
        self.blob_file = blob_file.encode(DEFAULT_ENCODING)\
            if blob_file is not None else None

    def open(self):
        """
        Open the data file and associate a Record instance.
        """
        self.doc.open()
        self.doc.targetEncoding = self.target_encoding
        self.doc.inputEncoding = self.input_encoding
        if self.primary_index is not None:
            self.primary_index.open()
            self.doc.setPrimaryIndex(self.primary_index)
        if self.blob_file is not None:
            self.doc.setBlobFile(self.blob_file)
        self.defaultIterator = RecordIterator(self.doc)

    def __enter__(self):
        self.open()
        return self

    def close(self):
        """
        Close the eventual primary index or blob file, then the data file.
        """
        if self.primary_index:
            self.primary_index.close()
        self.doc.close()

    def __exit__(self, type, value, traceback):
        self.close()

    def getTableName(self):
        return self.doc.getTableName()

    def getName(self):
        return self.doc.getName()

    def getTargetEncoding(self):
        return self.doc.targetEncoding

    def setTargetEncoding(self, encoding):
        self.target_encoding = encoding

    def getInputEncoding(self):
        return self.doc.inputEncoding

    def setInputEncoding(self, encoding):
        self.input_encoding = encoding

    def getCodePage(self):
        return self.doc.getCodePage()

    def hasBlobFile(self):
        return self.doc.hasBlobFile()

    def getBlobName(self):
        return self.doc.getBlobName()

    def getRecordCount(self):
        return len(self.doc)

    def getFieldCount(self):
        return self.defaultIterator.getFieldCount()

    def getFieldNames(self):
        return self.defaultIterator.getFieldNames()

    def __iter__(self):
        return self.defaultIterator

    def __getitem__(self, key):
        if isinstance(key, slice):
            start = key.start if key.start else 0
            stop = key.stop if key.stop else 0
            step = key.step if key.step else 1
            return RecordIterator(self.doc, start, stop, step)
        elif isinstance(key, int):
            return self.defaultIterator.readRecord(key)

    def __len__(self):
        return len(self.doc)


cdef class RecordIterator:
    """
    An instance has notion about the current record number, offset and limit
    """
    cdef readonly Record record
    cdef int limit
    cdef int offset
    cdef int step
    cdef int current_recno

    def __cinit__(self, PXDoc doc, int offset=0, int limit=0, int step=1):
        self.record = Record(doc)
        cdef int doc_length = len(doc)

        if limit == 0:
            limit = doc_length
        elif limit > doc_length:
            limit = doc_length
        elif limit < 0:
            limit = doc_length + limit
        self.limit = limit

        if offset < 0:
            offset = doc_length + offset
        elif offset > doc_length:
            offset = doc_length

        self.offset = offset

        self.step = step
        self.current_recno = self.offset

    def next(self):
        return self.__next__()

    def __next__(self):
        recno = self.current_recno
        ok = True
        if recno >= self.limit:
            ok = False
        else:
            ok = self.record.read(recno)
            self.current_recno = recno + self.step
        if not ok:
            self.current_recno = self.offset
            raise StopIteration()
        return self.record

    def __iter__(self):
        return self

    def __len__(self):
        return self.limit - self.offset

    def getFieldCount(self):
        return len(self.record)

    def getFieldNames(self):
        return self.record.getFieldNames()

    def readRecord(self, recno):
        if recno < 0:
            recno = self.limit + recno
        if recno >= self.limit or recno < 0:
            raise IndexError()
        self.record.read(recno)
        return self.record


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
        self.filename = filename.encode(DEFAULT_ENCODING)
        self.px_doc = PX_new2(&errorhandler, NULL, NULL, NULL)
        self.isopen = 0

    def __len__(self):
        return self.px_doc.px_head.px_numrecords

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
        return str("cp" + str(self.px_doc.px_head.px_doscodepage)).encode()

    property targetEncoding:
        def __get__(self):
            if self.px_doc.targetencoding:
                return self.px_doc.targetencoding.decode()
            return None
        def __set__(self, encoding):
            if (PY_MAJOR_VERSION >= 3 and isinstance(encoding, str))\
                    or isinstance(encoding, unicode):
                encoding = encoding.encode()
            PX_set_targetencoding(self.px_doc, encoding)

    property inputEncoding:
        def __get__(self):
            if self.px_doc.inputencoding:
                return self.px_doc.inputencoding.decode()
            return None
        def __set__(self, encoding):
            if (PY_MAJOR_VERSION >= 3 and isinstance(encoding, str))\
                    or isinstance(encoding, unicode):
                encoding = encoding.encode()
            PX_set_inputencoding(self.px_doc, encoding)
            

    def setValue(self, parameter, value):
        PX_set_value(self.px_doc, parameter, <float>value)

    def setParameter(self, parameter, value):
        PX_set_parameter(self.px_doc, parameter, value)

    def getTableName(self):
        return self.px_doc.px_head.px_tablename.decode(self.targetEncoding)
    
    def getName(self):
        return self.px_doc.px_name.decode(self.targetEncoding)

    def getBlobName(self):
        return self.px_doc.px_blob.mb_name if self.hasBlobFile() else None

    cdef setBlobFile(self, bytes filename):
        """
        Set and open the external blob file.
        """
        PX_set_blob_file(self.px_doc, filename)

    cdef setPrimaryIndex(self, PrimaryIndex index):
        """
        Set the primary index of the table.
        """
        if PX_add_primary_index(self.px_doc, index.px_doc) < 0:
            raise Exception("Couldn't add primary index `%s`" % index.filename)

    cdef bint hasBlobFile(self):
       return PX_has_blob_file(self.px_doc)

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
        self.filename = filename.encode(DEFAULT_ENCODING)
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
    Represent a single field of a Record associated with some Table.
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
        ParadoxField.__init__(
            self,
            record.doc.px_doc.px_head.px_fields[index].px_fname,
            record.doc.px_doc.px_head.px_fields[index].px_ftype,
            record.doc.px_doc.px_head.px_fields[index].px_flen
            )

    def __str__(self):
        return "{}: {}".format(self.name, self.value)

    def getName(self):
        return self.fname.decode(self.record.doc.targetEncoding)
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

            if size == 0:
                return None
            else:
                py_string = PyUnicode_Decode(<char*> self.data, size, codepage, b"replace");
                if not py_string:
                    raise Exception("Cannot get value from string %s" % self.fname)
                return py_string

        elif self.ftype == pxfDate:
            if PX_get_data_long(self.record.doc.px_doc,
                                self.data, self.flen, &value_long) < 0:
                raise Exception("Cannot extract long field '%s'" % self.fname)
            if value_long:
                PX_SdnToGregorian(value_long + 1721425,
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
            if not self.record.doc.hasBlobFile():
                return "[MISSING BLOB FILE]"

            ret = PX_get_data_blob(self.record.doc.px_doc, self.data, self.flen,
                                   &mod_nr, &size, &blobdata)
            if ret < 0:
                raise Exception("Cannot extract blob field '%s'" % self.fname)
            if ret == 0:
                return None

            if blobdata and size > 0:
                codepage = self.record.doc.getCodePage()
                py_string = PyUnicode_Decode(<char*> blobdata, size, codepage, b"replace")
                self.record.doc.px_doc.free(self.record.doc.px_doc, blobdata)
                if not py_string:
                    raise Exception("Cannot get value from string %s" % self.fname)
                return py_string

        elif self.ftype == pxfGraphic:
            if not self.record.doc.hasBlobFile():
                return "[MISSING BLOB FILE]"

            ret = PX_get_data_graphic(self.record.doc.px_doc, self.data, self.flen,
                                      &mod_nr, &size, &blobdata)
            if ret < 0:
                raise Exception("Cannot extract graphic field '%s'" % self.fname)
            if ret == 0:
                return None

            if blobdata and size > 0:
                py_bytes = PyBytes_FromStringAndSize(blobdata, size)
                self.record.doc.px_doc.free(self.record.doc.px_doc, blobdata)
                return py_bytes


        elif self.ftype == pxfOLE:
            pass

        elif self.ftype == pxfTime:
            if PX_get_data_long(self.record.doc.px_doc,
                                self.data, self.flen, &value_long)<0:
                raise Exception("Cannot extract long field '%s'" % self.fname)
            if value_long:
                return datetime.time(
                    value_long/3600000,
                    value_long/60000%60,
                    value_long%60000/1000.0
                )
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
    An instance of this class wraps the memory buffer associated with a
    single record of a given PXDoc.
    """

    cdef void *data
    cdef int current_fieldno
    cdef PXDoc doc
    cdef public fields

    def __cinit__(self, PXDoc doc):
        """
        Create a Record instance, allocating the memory buffer and
        building the list of the Field instances.
        """

        cdef int offset

        self.data = doc.px_doc.malloc(
            doc.px_doc,
            doc.px_doc.px_head.px_recordsize,
            "Memory for record"
        )
        self.current_fieldno = -1

        self.doc = doc
        self.fields = []
        offset = 0
        for i in range(len(self)):
            field = RecordField(self, i, offset)
            self.fields.append(field)
            offset = offset + doc.px_doc.px_head.px_fields[i].px_flen

    def __dealloc__(self):
        if self.doc:
            self.doc.px_doc.free(self.doc.px_doc, self.data)

    def getFieldNames(self):
        return [f.name for f in self.fields]

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
            raise Exception("Couldn't get record {} from '{}'".format(
                    recno, self.doc.filename))
        return True

    def __str__(self):
        return "{0}".format([(f.name, f.value) for f in self.fields])

    def __iter__(self):
        return self

    def next(self):
        return self.__next__()

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
        if isinstance(key, str):
            for field in self.fields:
                if field.name == key:
                    return field
            raise KeyError("'" + key + "'")
        else:
            return self.fields[key]

# Sets up locale for pxlib
PX_boot()

# Shut down pxlib
def __dealloc__():
    PX_shutdown()
atexit.register(__dealloc__)
