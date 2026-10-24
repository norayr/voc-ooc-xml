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

The Unicode codecs, XML buffers, DTD data model, entity resolver, XML
parser and namespace builder build with VOC:

```sh
make test
```

This requires VOC with the
[shared ooc and URI support](https://github.com/vishapoberon/compiler/commit/8e8edff2896e139e57b0f1e38ec57f2fa7d38765)
installed, including `LongStrings.Equal8`.
These provide `oocUnicode`, `LongStrings`, Unicode-safe `Msg`, `Channel`,
`IOMemory`, `URIParser` and the file/memory URI schemes.
Their sources and unit tests live in VOC's `src/ports/ooc/` and confidence
tests. Rebuild VOC and its dependent modules together when updating this
package.

`XMLParser` reports document, element, attribute, text and DTD events through
`XMLBuilder`. Applications extend that builder to consume the events.
Wrap an application builder with `XMLBuilderNamespaces.New(builder)` and set
`parser.enforceQNames := TRUE` to receive namespace URIs and local names.
`XMLUnicodeCodecImportAll` registers the bundled ASCII, Latin-1,
UTF-8 and UTF-16 encodings at startup. The codec source paths are unchanged so
the changes remain easy to compare with CVS.

`oocUnicode.LONGCHAR` is the shared type for UTF-16 code units. VOC and
standard Oberon-2 have no built-in `LONGCHAR`, so this alias uses `LONGINT`
storage for values in the original 0..65535 range. Supplementary characters
use surrogate pairs. `XMLUnicodeCodec.Char` uses this same type, and encoders
reject out-of-range values.

`LongStrings` supplies UTF-16 code-unit copying, editing, searching and
comparison. `Msg` preserves Unicode message attributes through `GetLText`.
Both are supplied by VOC's ooc package. Their original source baselines and
transfer provenance are recorded in
[history/oo2c-support.md](history/oo2c-support.md).

VOC's `Channel` uses this message interface. `IOMemory` provides
seekable, growable memory files. `XMLInputBuffer` reads bytes, and
`XMLUnicodeBuffer` decodes input and encodes buffered output. They support
short reads, partial writes, UTF-8/UTF-16 BOM handling and bounded operations.

The XML tests cover ASCII, Latin-1, Armenian, supplementary characters,
both UTF-16 byte orders, malformed/truncated input, buffer boundaries,
Unicode diagnostics, streaming boundaries, flush/retry behavior and lengths
above 32767. String-edit and message-framework unit tests run in VOC.
DTD tests cover declaration lookup, predefined entities, attribute values
and content-model classification. Resolver tests cover relative system
identifiers, UTF-8 percent escapes, surrogate pairs, malformed UTF-16 and
40,000-code-unit identifiers.
Parser tests cover callbacks, internal and parameter entities, default
attributes, Unicode names, character references, malformed documents and
70,000-unit text streamed through short reads. Namespace tests cover scope,
default declarations, implicit `xml` bindings, Unicode, DTD defaults,
duplicate expanded attribute names and reserved bindings. The six integration
programs pass with GCC and Clang in C23 mode, TCC and Clang ASan/UBSan.

The bundled James Clark XML test archive supplies the first well-formedness
corpus. The fixture runner requires Python 3.12 or newer. Run it with:

```sh
make BUILD=../compiler/build/ports/ooc/2 conformance
```

All 360 included XML cases and 24 original namespace fixtures pass, also under
ASan/UBSan. The runner records the upstream exclusion of `valid/sa/065.xml`,
whose entity replacement is malformed.
This checks acceptance and rejection; canonical output and DTD validation
remain later stages.

`make xmlcheck` builds `XMLCheck`, a file well-formedness checker. Use
`XMLCheck --namespaces file.xml` to enable namespace checks. Its default
disables external references; `XMLCheck --external file.xml` enables them for
trusted local fixtures. Exit codes are 0 for successful parsing, 1 for XML
diagnostics and 2 for usage or opening errors.

VOC's ooc package supplies URI parsing, relative resolution and file/memory
channels. XML's `XMLEntityResolver` converts Unicode system identifiers to
these URI objects. The validation builder, writer and remaining original
regression suites are the next adaptation stages.
External-entity controls and resource limits still need review
before the parser can accept untrusted documents.

### Testing with a VOC source build

The ooc package can be built and tested in a VOC checkout using an installed
VOC compiler and matching runtime libraries. XML can then use that package's
Oberon-2 build directory directly. For a sibling VOC checkout:

```sh
make -C ../compiler/src/ports/ooc test
make BUILD=../compiler/build/ports/ooc/2 test
```

The shared build directory contains the matching `.sym`, `.h` and `.o`
files. A normal `make test` uses the installed VOC library.

[Port status and dependencies](doc/PortStatus.md) lists what is present and
what still needs adapting.

The XML port is in progress. Its VOC ports-tree integration will follow
completion of the standalone port and its tests. The shared support modules have
been transferred into VOC's existing ooc package. The upstream `configure`
and `Makefile.in` describe the original oo2c build.

Original copyright and per-file licence notices apply. Most parser modules
are LGPL-2.0-or-later. Test data and bundled third-party test archives retain
their own notices.
