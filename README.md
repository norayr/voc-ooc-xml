# ooc XML for VOC

This is a port in progress of Michael van Acken's **ooc-libxml**, the native
Oberon XML library for oo2c 1.x.

The original CVS history is the ancestry of this repository. The unmodified
CVS trunk and vendor branch are preserved as `upstream-cvs` and
`upstream-cvs-MAIN`; the original release tags are retained. VOC work belongs
on `main`, in commits following that import.

See [history/README.md](history/README.md) for the source archive, conversion
settings, revision map and verification results. The original oo2c build
instructions remain in [README](README).

## Porting scope

The target is VOC's **Oberon-2 (`-O2`)** type model. In particular, Unicode
characters must not be narrowed to its 8-bit `CHAR`, and native addresses
must not be stored in `LONGINT`.

### Working so far

The Unicode codec layer builds with VOC:

```sh
make test
```

This builds **only the codecs**, not the XML parser. The adapted modules are
`XMLUnicodeCodec`, `XMLUnicodeCodecASCII`, `XMLUnicodeCodecLatin1`,
`XMLUnicodeCodecUTF8`, `XMLUnicodeCodecUTF16` and `XMLUnicodeCodecImportAll`.
Their source paths are unchanged so the changes remain easy to compare with
CVS. `XMLUnicodeCodecImportAll` registers the bundled encodings at startup.

`XMLUnicodeCodec.Char` stores a UTF-16 code unit in an Oberon-2 `LONGINT`.
Values retain the original 0..65535 range, including surrogate pairs; the
storage is wider, not the character repertoire. Encoders reject out-of-range
values rather than truncating them to octets.

The new Oberon tests cover ASCII, Latin-1, Armenian, supplementary characters,
both UTF-16 byte orders, malformed/truncated input, exact-sized buffers and
invalid code-unit values. They pass with GCC and Clang in C23 mode, and TCC.
The upstream XML conformance suites have **not** run with VOC yet.

The work starts with Unicode strings and codecs, followed by in-memory XML
parsing, builders, namespaces, validation and writing. File/URI adapters and
the original regression suites follow. Optional network facilities need a
separate native-ABI review; they are not a prerequisite for an in-memory
parser.

[Port status and dependencies](doc/PortStatus.md) lists what is present and
what still needs adapting.

This library is **not yet ready for use with VOC**. The upstream `configure`
and `Makefile.in` still target oo2c. No VOC ports-tree integration has been
made; that will follow a working, tested standalone port.

Original copyright and per-file licence notices apply. Most parser modules
are LGPL-2.0-or-later. Test data and bundled third-party test archives retain
their own notices.
