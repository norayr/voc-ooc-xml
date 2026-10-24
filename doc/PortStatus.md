# VOC port status

`make test` builds and tests the Unicode codecs and XML byte/Unicode buffers
against VOC's shared ooc support under the Oberon-2 model. URI support,
the parser, DTD handling, builders and XML writer are the next porting stages.

## Dependencies

Having a module with the same name is not enough: its character types,
integer widths, record extensions and method signatures must agree.

| Dependency | Status |
| --- | --- |
| XML parser, DTDs, builders, resolver and writer | Included in the CVS import; still need porting. |
| `XMLInputBuffer`, `XMLUnicodeBuffer` | Ported and tested with short reads, BOMs, growth, compaction, repeated flushes and partial-write retries. |
| `IOMemory` | Transferred to VOC's ooc package. Tests cover permissions, seeking, sparse writes, truncation, growth, overlapping copies, bounds and fingerprints. |
| Unicode codec registry, ASCII, Latin-1, UTF-8, UTF-16 | Adapted to `-O2`; new Oberon tests pass with GCC/C23, Clang/C23 and TCC. |
| `oocUnicode`, `LongStrings` | Supplied by VOC's ooc package, using the shared `LONGCHAR` alias for code units and `LONGINT` for positions and lengths. |
| `Msg` | VOC's ooc module now uses the tested Unicode-safe implementation. `GetLText` preserves UTF-16; `GetText` retains the original Latin-1 conversion. |
| `Channel` | VOC's existing ooc module now uses the tested implementation, rebuilt against the Unicode-safe `Msg`. |
| `TextRider`, `BinaryRider`, `Time` | Supplied by VOC. The riders are rebuilt against the updated interfaces; text diagnostics widen their templates explicitly. |
| `Ascii`, `CharClass`, `IntStr`, `RealStr` | VOC has ports; retain only the required interfaces and test their use. |
| `Strings` | XML expects oo2c semantics. VOC also has Oakwood `Strings` and `oocStrings`; choose explicitly, not just by module name. |
| `Files` | XML expects oo2c channels. VOC already provides that interface as `oocFiles`, backed by `FilesHost` and `Platform`; adapt the URI file scheme to use it. |
| `StdChannels`, `Err`, `Log` | Original sources are available; not in the current VOC source tree under these names. Needed by upstream drivers/examples, not all by the parser itself. |
| `URI`, its parsers and scheme modules | Included here. Need legal VOC module names and compatible string/channel/error interfaces. |
| `OS:*`, `IO:PFD`, sockets and select | The imported sources include upstream C bindings. Use VOC's system interfaces for the port; file I/O and current-directory access already have Oberon interfaces. Network support remains a separate stage. |
| `ADT:ArrayList`, `ADT:Dictionary`, `ADT:Object`, `ADT:String` | Used by optional `URI:Query:WWWForm`, not directly by the XML parser. Do not import newer generic replacements unnecessarily. |

Support-module provenance is recorded in
[history/oo2c-support.md](../history/oo2c-support.md). Additional imported
support modules need the same recorded provenance and unmodified baseline.

## VOC integration boundary

VOC's XML port will contain the XML-specific modules. Reusable dependencies,
including strings, diagnostics, channels, memory files and URI support, belong
in VOC's `src/ports/ooc/` package.

VOC's `Msg` and `Channel` have been replaced by the tested implementations.
`LongStrings`, `IOMemory` and the shared `oocUnicode.LONGCHAR` alias also live
in VOC's ooc directory. The XML build imports these modules from VOC.
The shared package and its dependents, including `oocFiles`, `TextRider`,
`BinaryRider` and `ProgramArgs`, are rebuilt and tested together.

Use the existing Oberon `oocFiles`, `FilesHost` and `Platform` interfaces for
system access. Add portable `Platform` functions only for verified missing
operations. The upstream C adapters remain in the preserved history; they
will not be part of the VOC port's implementation.

## String and diagnostic checks

- Copies, edits and searches preserve UTF-16 code units, including Armenian
  characters and surrogate pairs. Positions count code units; bounded edits
  may split a pair, as in the original interface.
- `Long` and `Append8` widen Latin-1 octets. UTF-8 decoding uses the codecs.
- `Capitalize` preserves oo2c's ASCII and Latin-1 mapping; other code units
  remain unchanged.
- Small-buffer edit combinations are checked against independently constructed
  expected results. Capacity tests use subtraction to avoid length overflow.
- Regression tests cover insertion beyond the end, message-list transfers into
  empty and extended lists, repeated built-in placeholders, bounded narrow
  output and wide/narrow strings longer than 32767 units or octets.
- A UTF-8 round trip through the string and diagnostic interfaces checks that
  Armenian and supplementary characters survive the complete support path.

## Memory channel and buffer checks

- Memory growth copies array contents using native-width addresses. Reads and
  writes validate ranges before address calculations, and overlapping copies
  are handled explicitly.
- Byte-buffer tests retain 50000 bytes, grow buffers, compact overlapping
  ranges and distinguish embedded zero octets from the end marker. Read
  errors are recorded once, including errors delivered with partial data.
- Unicode input waits for sufficient bytes before decoding a split character.
  Tests include one-byte reads, a split character at the normal block boundary,
  empty and BOM-only input, UTF-8/UTF-16 detection, truncated sequences and
  unsupported detected encodings.
- Unicode output preserves split surrogate pairs, retries short writes and
  retains unwritten bytes after errors. Repeated flushes preserve output
  exactly. A writer returning zero progress is reported as a write error.
- Round trips exercise 40001 UTF-16 code units, supplementary characters and
  an embedded U+FEFF through UTF-8 and both UTF-16 byte orders, with retained
  and discarded input blocks.
- Channel `WriteBytes` and buffer interval-write methods pass source arrays
  by `VAR` to avoid implicit full-array copies; these sources are read-only.

## Verification

The three XML test programs and six ooc regression programs pass with
GCC/C23, Clang/C23 and TCC under `-O2`. The shared ooc package is rebuilt
before each XML test run. An additional Clang build instruments the shared
package, ported XML modules and tests with AddressSanitizer and
UndefinedBehaviorSanitizer:

```sh
env CC=clang \
  CFLAGS='-std=c23 -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer' \
  ASAN_OPTIONS=detect_leaks=0:detect_stack_use_after_return=0 \
  UBSAN_OPTIONS=halt_on_error=1 \
  make -C ../compiler/src/ports/ooc BUILD="$PWD/build/sanitize" test
env CC=clang \
  CFLAGS='-std=c23 -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer' \
  ASAN_OPTIONS=detect_leaks=0:detect_stack_use_after_return=0 \
  UBSAN_OPTIONS=halt_on_error=1 \
  make BUILD=build/sanitize test
```

ASan's alternate stack frames must be disabled so VOC's conservative garbage
collector can find live pointers on the native stack. The installed VOC
runtime is used as provided by the compiler. Set `BUILD` to a rebuilt ooc
directory when testing from source without installing VOC first; see the
source-build example in the README.

## Representation rules

- Build explicitly with `-O2`: 8-bit `SHORTINT`, 16-bit `INTEGER`, 32-bit
  `LONGINT`. Do not change the whole library to the C or V type model.
- Preserve Unicode values. The ported codec interface uses `LONGINT` storage
  through the shared `oocUnicode.LONGCHAR` alias for UTF-16 code units.
  Its definition documents the representation and valid 0..65535 range.
- Replace implicit wide-string operations with explicit string helpers.
  Record memory moves must use the actual element size after porting.
- Audit indices and lengths separately from character values. VOC's ordinary
  `Strings.Length` has an `INTEGER` result and is not a general XML document
  length operation.
- Keep native addresses in `SYSTEM.ADDRESS`, preserve native field widths,
  and check narrowing conversions at OS boundaries.

## Next stages

1. Port URI types and the resolver/diagnostic dependencies required by the parser.
2. Build and test the in-memory parser and basic builders, then namespaces,
   DTD validation and the writer.
3. Adapt file resolution and upstream test drivers. Review entity expansion,
   recursion and external-entity controls before accepting untrusted input.
4. Run the original XML/namespace/encoding suites. Separate external fixture
   availability from genuine parser failures.
5. Only then add an XML port manifest for the XML-specific modules in a
   separate VOC port directory, with reusable dependencies in the existing
   ooc package. Test both packages together. Optional HTTP/socket support can
   be handled independently.
