#  -*- coding: utf-8 -*-
cdef extern from *:
    ctypedef char* const_char_ptr "const char*"


cdef extern from "stdlib.h" nogil:
    void *memset(void *str, int c, size_t n)
    void *memcpy(void *str1, void *str2, size_t n)


cdef extern from "Python.h":
    object PyBytes_FromStringAndSize(char *s, int len)
    object PyUnicode_Decode(char *s, int len, char *encoding, char *errors)


cdef extern from "string.h":
    int strnlen(char *s, int maxlen)
    char *strcpy(char *, char *)


cdef extern from "paradox.h":
    ctypedef enum fieldtype_t:
        pxfAlpha = 0x01
        pxfDate = 0x02
        pxfShort = 0x03
        pxfLong = 0x04
        pxfCurrency = 0x05
        pxfNumber = 0x06
        pxfLogical = 0x09
        pxfMemoBLOb = 0x0C
        pxfBLOb = 0x0D
        pxfFmtMemoBLOb = 0x0E
        pxfOLE = 0x0F
        pxfGraphic = 0x10
        pxfTime = 0x14
        pxfTimestamp = 0x15
        pxfAutoInc = 0x16
        pxfBCD = 0x17
        pxfBytes = 0x18
        pxfNumTypes = 0x18

    ctypedef enum filetype_t:
        pxfFileTypIndexDB = 0
        pxfFileTypPrimIndex = 1
        pxfFileTypNonIndexDB = 2
        pxfFileTypNonIncSecIndex = 3
        pxfFileTypSecIndex = 4
        pxfFileTypIncSecIndex = 5
        pxfFileTypNonIncSecIndexG = 6
        pxfFileTypSecIndexG = 7
        pxfFileTypIncSecIndexG = 8

    ctypedef struct pxfield_t:
        char *px_fname
        char px_ftype
        int px_flen
        int px_fdc

    ctypedef struct pxhead_t:
        char *px_tablename
        int px_recordsize
        char px_filetype
        int px_fileversion
        int px_numrecords
        int px_theonumrecords
        int px_numfields
        int px_maxtablesize
        int px_headersize
        int px_fileblocks
        int px_firstblock
        int px_lastblock
        int px_indexfieldnumber
        int px_indexroot
        int px_numindexlevels
        int px_writeprotected
        int px_doscodepage
        int px_primarykeyfields
        char px_modifiedflags1
        char px_modifiedflags2
        char px_sortorder
        int px_autoinc
        int px_fileupdatetime
        char px_refintegrity
        pxfield_t *px_fields
        unsigned long px_encryption

    ctypedef struct pxdoc_t:
        char *px_name
        pxhead_t *px_head
        void *(*malloc)(pxdoc_t *p, unsigned int size, char *caller)
        void  (*free)(pxdoc_t *p, void *mem)
        char *targetencoding
        char *inputencoding
        pxblob_t *px_blob

    ctypedef struct pxdatablockinfo_t

    ctypedef struct pxblob_t:
        char *mb_name
        pxdoc_t *pxdoc

    ctypedef struct pxpindex_t

    ctypedef struct pxstream_t
    
    ctypedef struct Pxval_str:
        char *val
        int len

    ctypedef union Pxval_value:
        long lval
        double dval
        Pxval_str str

    ctypedef struct pxval_t:
        char isnull
        int type
        Pxval_value value
    
    void PX_boot()
    void PX_shutdown()

    pxdoc_t* PX_new()
    pxdoc_t* PX_new2(
        void  (*errorhandler)(pxdoc_t *p, int type, const_char_ptr msg, void *data),
        void* (*allocproc)(pxdoc_t *p, size_t size, const_char_ptr caller),
        void* (*reallocproc)(pxdoc_t *p, void *mem, size_t size, const_char_ptr caller),
        void  (*freeproc)(pxdoc_t *p, void *mem)
        )
    char* PX_strdup(pxdoc_t *pxdoc, char *str)
    int PX_open_file(pxdoc_t *pxdoc, const_char_ptr filename)
    int PX_create_file(
        pxdoc_t *pxdoc,
        pxfield_t *px_fields,
        unsigned int numfields,
        char *filename,
        int type
        )
    int PX_read_primary_index(pxdoc_t *pindex)
    int PX_add_primary_index(pxdoc_t *pxdoc, pxdoc_t *pindex)
    int PX_set_targetencoding(pxdoc_t *pxdoc, char *encoding)
    int PX_set_inputencoding(pxdoc_t *pxdoc, char *encoding)
    int PX_set_parameter(pxdoc_t *pxdoc, char *name, char *value)
    int PX_set_value(pxdoc_t *pxdoc, char *name, float value)
    int PX_set_blob_file(pxdoc_t *pxdoc, const_char_ptr filename)
    bint PX_has_blob_file(pxdoc_t *pxdoc)
    void PX_close(pxdoc_t *pxdoc)
    void PX_delete(pxdoc_t *pxdoc)


    void* PX_get_record(pxdoc_t *pxdoc, int recno, void *data)
    void* PX_get_record2(
        pxdoc_t *pxdoc,
        int recno,
        void *data,
        int *deleted,
        pxdatablockinfo_t *pxdbinfo
        )
    int PX_get_data_alpha(pxdoc_t *pxdoc, void *data, int len, char **value)
    int PX_get_data_bytes(pxdoc_t *pxdoc, void *data, int len, char **value)
    int PX_get_data_double(pxdoc_t *pxdoc, void *data, int len, double *value)
    int PX_get_data_long(pxdoc_t *pxdoc, void *data, int len, long *value)
    int PX_get_data_short(pxdoc_t *pxdoc, void *data, int len, short int *value)
    int PX_get_data_byte(pxdoc_t *pxdoc, void *data, int len, char *value)
    int PX_get_data_blob(
        pxdoc_t *pxdoc,
        void *data,
        int len,
        int *mod,
        int *blobsize,
        char **value
        )
    int PX_get_data_graphic(
        pxdoc_t *pxdoc,
        void *data,
        int len,
        int *mod,
        int *blobsize,
        char **value
        )
    int PX_get_parameter(pxdoc_t *pxdoc, const_char_ptr name, char **value)
    pxval_t** PX_retrieve_record(pxdoc_t *pxdoc, int recno)

    int PX_put_record(pxdoc_t *pxdoc, char *data)
    void PX_put_data_alpha(pxdoc_t *pxdoc, char *data, int len, char *value)
    void PX_put_data_double(pxdoc_t *pxdoc, char *data, int len, double value)
    void PX_put_data_long(pxdoc_t *pxdoc, char *data, int len, int value)
    void PX_put_data_short(pxdoc_t *pxdoc, char *data, int len, short int value)

    void PX_SdnToGregorian(long int sdn, int *pYear, int *pMonth, int *pDay)
    long int PX_GregorianToSdn(int year, int month, int day)


