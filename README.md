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

The Unicode codecs, string operations and message diagnostics build with VOC:

```sh
make test
```

This requires VOC with its oo2c `CharClass` and `IntStr` support modules
and their dependencies installed.

This builds and tests the Unicode support layer. The XML parser remains under
development. `XMLUnicodeCodecImportAll` registers the bundled ASCII, Latin-1,
UTF-8 and UTF-16 encodings at startup. The codec source paths are unchanged so
the changes remain easy to compare with CVS.

`XMLUnicode.LONGCHAR` is the shared type for UTF-16 code units. VOC and
standard Oberon-2 have no built-in `LONGCHAR`, so this alias uses `LONGINT`
storage for values in the original 0..65535 range. Supplementary characters
use surrogate pairs. `XMLUnicodeCodec.Char` uses this same type, and encoders
reject out-of-range values.

`LongStrings` supplies UTF-16 code-unit copying, editing, searching and
comparison. `Msg` preserves Unicode message attributes through `GetLText`.
Both are built from `src/oo2c/`; their unchanged source baselines and provenance
are recorded in [history/oo2c-support.md](history/oo2c-support.md).

The Oberon tests cover ASCII, Latin-1, Armenian, supplementary characters,
both UTF-16 byte orders, malformed/truncated input, buffer boundaries,
string-edit combinations, Unicode diagnostics and lengths above 32767.
They pass with GCC and Clang in C23 mode, and TCC. XML conformance testing
will follow the parser port.

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
