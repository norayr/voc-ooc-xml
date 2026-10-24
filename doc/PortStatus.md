# VOC port status

`make test` builds and tests the Unicode codecs, strings, diagnostics, memory
channels and XML byte/Unicode buffers under VOC's Oberon-2 model. URI support,
the parser, DTD handling, builders and XML writer are the next porting stages.

## Dependencies

Having a module with the same name is not enough: its character types,
integer widths, record extensions and method signatures must agree.

| Dependency | Status |
| --- | --- |
| XML parser, DTDs, builders, resolver and writer | Included in the CVS import; still need porting. |
| `XMLInputBuffer`, `XMLUnicodeBuffer` | Ported and tested with short reads, BOMs, growth, compaction, repeated flushes and partial-write retries. |
| `IOMemory` | Ported and tested: permissions, seeking, sparse writes, truncation, growth, overlapping copies, bounds and fingerprints. |
| Unicode codec registry, ASCII, Latin-1, UTF-8, UTF-16 | Adapted to `-O2`; new Oberon tests pass with GCC/C23, Clang/C23 and TCC. |
| `LongStrings` | Adapted in `src/oo2c/`, using `XMLUnicode.LONGCHAR` for code units and `LONGINT` for positions and lengths. |
| `Msg` | Adapted in `src/oo2c/`; wide attributes, template replacement and message-list transfers are tested. `GetLText` preserves UTF-16; `GetText` retains the original Latin-1 conversion. |
| `Channel` | Imported and rebuilt locally against the Unicode-safe `Msg`; memory channels implement its abstract methods. |
| `TextRider`, `Time` | `Time` is an installed dependency. `TextRider` still needs rebuilding against the local `Channel` and `Msg`. |
| `Ascii`, `CharClass`, `IntStr`, `RealStr` | VOC has ports; retain only the required interfaces and test their use. |
| `Strings` | XML expects oo2c semantics. VOC also has Oakwood `Strings` and `oocStrings`; choose explicitly, not just by module name. |
| `Files` | XML expects oo2c channels, whereas VOC's ordinary `Files` is an Oberon file/rider API. An explicit channel adapter is needed. |
| `StdChannels`, `Err`, `Log` | Original sources are available; not in the current VOC source tree under these names. Needed by upstream drivers/examples, not all by the parser itself. |
| `URI`, its parsers and scheme modules | Included here. Need legal VOC module names and compatible string/channel/error interfaces. |
| `OS:*`, `IO:PFD`, sockets and select | Included here, with original C bindings. Require a separate native-width/opaque-structure review; not part of the tested codec build. |
| `ADT:ArrayList`, `ADT:Dictionary`, `ADT:Object`, `ADT:String` | Used by optional `URI:Query:WWWForm`, not directly by the XML parser. Do not import newer generic replacements unnecessarily. |

Support-module provenance is recorded in
[history/oo2c-support.md](../history/oo2c-support.md). Additional imported
support modules need the same recorded provenance and unmodified baseline.

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

The four test programs pass with GCC/C23, Clang/C23 and TCC. An additional
Clang build instruments the ported modules and tests with AddressSanitizer
and UndefinedBehaviorSanitizer:

```sh
env CC=clang \
  CFLAGS='-std=c23 -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer' \
  ASAN_OPTIONS=detect_leaks=0:detect_stack_use_after_return=0 \
  UBSAN_OPTIONS=halt_on_error=1 \
  make BUILD=build/sanitize test
```

ASan's alternate stack frames must be disabled so VOC's conservative garbage
collector can find live pointers on the native stack. The installed VOC
runtime and support dependencies are used as provided by the compiler.

## Representation rules

- Build explicitly with `-O2`: 8-bit `SHORTINT`, 16-bit `INTEGER`, 32-bit
  `LONGINT`. Do not change the whole library to the C or V type model.
- Preserve Unicode values. The ported codec interface uses `LONGINT` storage
  through the shared `XMLUnicode.LONGCHAR` alias for UTF-16 code units.
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
5. Only then add a VOC port manifest and integrate the tested sources into
   VOC's ports tree. Optional HTTP/socket support can be handled independently.
