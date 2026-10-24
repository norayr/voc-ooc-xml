# VOC port status

The full XML library does not yet build with VOC. `make test` currently tests
the six adapted Unicode codec modules only. The parser, DTD handling,
builders and writer remain upstream source, not tested VOC implementations.

## Dependencies

Having a module with the same name is not enough: its character types,
integer widths, record extensions and method signatures must agree.

| Dependency | Status |
| --- | --- |
| XML parser, DTDs, builders, resolver, buffers and writer | Included in the CVS import; still need porting. |
| Unicode codec registry, ASCII, Latin-1, UTF-8, UTF-16 | Adapted to `-O2`; new Oberon tests pass with GCC/C23, Clang/C23 and TCC. |
| `LongStrings` | Not in VOC's current oo2c port set. Original source is available; needs an interface using preserved Unicode code units, not `CHAR`. |
| `Msg` | VOC has it, but its `LChar` is `CHAR`. The Unicode XML message/attribute interfaces cannot use that representation unchanged. |
| `Channel`, `TextRider`, `Time` | VOC has oo2c ports. Their interfaces need checking against the XML channel implementations. |
| `Ascii`, `CharClass`, `IntStr`, `RealStr` | VOC has ports; retain only the required interfaces and test their use. |
| `Strings` | XML expects oo2c semantics. VOC also has Oakwood `Strings` and `oocStrings`; choose explicitly, not just by module name. |
| `Files` | XML expects oo2c channels, whereas VOC's ordinary `Files` is an Oberon file/rider API. An explicit channel adapter is needed. |
| `StdChannels`, `Err`, `Log` | Original sources are available; not in the current VOC source tree under these names. Needed by upstream drivers/examples, not all by the parser itself. |
| `URI`, its parsers and scheme modules | Included here. Need legal VOC module names and compatible string/channel/error interfaces. |
| `OS:*`, `IO:PFD`, sockets and select | Included here, with original C bindings. Require a separate native-width/opaque-structure review; not part of the tested codec build. |
| `ADT:ArrayList`, `ADT:Dictionary`, `ADT:Object`, `ADT:String` | Used by optional `URI:Query:WWWForm`, not directly by the XML parser. Do not import newer generic replacements unnecessarily. |

The original support sources are available locally, so there is no known
source-availability blocker. Any imported support module needs its own
recorded provenance and an unmodified baseline before adaptation.

## Representation rules

- Build explicitly with `-O2`: 8-bit `SHORTINT`, 16-bit `INTEGER`, 32-bit
  `LONGINT`. Do not change the whole library to the C or V type model.
- Preserve Unicode values. The ported codec interface uses `LONGINT` storage
  for UTF-16 code units, rather than narrowing `LONGCHAR` to 8-bit `CHAR`.
- Replace implicit wide-string operations with explicit string helpers.
  Record memory moves must use the actual element size after porting.
- Audit indices and lengths separately from character values. VOC's ordinary
  `Strings.Length` has an `INTEGER` result and is not a general XML document
  length operation.
- Keep native addresses in `SYSTEM.ADDRESS`, preserve native field widths,
  and check narrowing conversions at OS boundaries.
- Retain the Oberon parser and writer. No C libxml dependency is being added.

## Next stages

1. Unicode string operations and Unicode-safe diagnostic attributes.
2. Port memory channels, URI types and XML buffers with bounded operations.
3. Build and test the in-memory parser and basic builders, then namespaces,
   DTD validation and the writer.
4. Adapt file resolution and upstream test drivers. Review entity expansion,
   recursion and external-entity controls before accepting untrusted input.
5. Run the original XML/namespace/encoding suites. Separate external fixture
   availability from genuine parser failures.
6. Only then add a VOC port manifest and integrate the tested sources into
   VOC's ports tree. Optional HTTP/socket support can be handled independently.

The W3c port is a separate follow-up; its sources have not been mixed into
this repository.
