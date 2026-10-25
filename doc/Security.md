# XML input policy and resource review

The port currently requires **trusted XML**. External access has explicit
controls and regression tests, but general limits on input size, expansion,
nesting and processing time remain unfinished.

## External resources

`XMLParser.followExternalRef` controls the external DTD subset, external general
entities and external parameter entities. The library retains the upstream
default of `TRUE`; set it explicitly before calling `ParseDocument`.

- With `FALSE`, ordinary external references are skipped. A guard at the shared
  external-buffer opening point also prevents reads during error recovery.
  Malformed input cannot bypass this guard through parameter-entity insertion.
- With `TRUE`, references may open any resource accepted by the supplied entity
  resolver and registered URI schemes. The resolver translates identifiers;
  the returned URI's `GetChannel` method opens the resource.
- The primary input is separate: `NewFile` and `NewURI` open the requested
  document before `followExternalRef` can be configured. `NewReader` and
  `NewChannel` use an application-supplied input and prefetch buffered data.
- Identifier resolution can still invoke the application's resolver when
  external reads are disabled. Custom resolvers, URI implementations and
  builder callbacks must enforce their own side-effect policies.

`XMLCheck` disables external reads by default. `--external` enables them, and
`--validate` enables them to read the complete DTD. Canonical and protocol output
flags alone leave external reads disabled. `XMLBasicParser.Parse` enables
external reads when a base URI is supplied or validation is requested.

## Reviewed paths and fixes

The external-opening paths converge on `XMLParser.GetBuffer`. These include
streamed DTD/general-entity parsing and `Internalize`, which reads an external
parameter entity into a Unicode string before inserting it into another value.

`TestEntityPolicy` uses an instrumented in-memory URI implementation, without
opening host files. It counts opens and checks:

- DTD subsets, general entities and parameter entities with access enabled and
  disabled;
- malformed parameter references inside internal entity declarations and
  indirect external references in attributes;
- unused unparsed entities, direct/indirect general-entity cycles and recursive
  external parameter entities;
- malformed UTF-8 in an internalized external parameter entity.

The review fixed three issues:

1. A parameter reference inside a malformed internal entity declaration could
   read an external resource despite `followExternalRef = FALSE`. The shared
   opening guard now rejects that path before calling `GetChannel`.
2. Parameter-entity references did not check whether the referent was already
   expanding. Direct and indirect cycles now produce a fatal diagnostic before
   another expansion or read.
3. `Internalize` checked the caller's decoder instead of the external entity's
   decoder. It now reports malformed encodings from the buffer actually read.

## Remaining resource work

Disabling external access does not bound internal-entity expansion or the
document itself. In particular:

- The parser recursively enters elements, general entities, DTD content models
  and conditional sections. The Basic parser's maximum depth limits object
  construction, not the core parser's native-stack use.
- Internal general entities are checked eagerly at the end of the DTD, even
  when unused by the document. Acyclic repeated references can amplify work.
- Attribute values retain entity-reference graphs. `XMLDTD` computes lengths
  and flattens those graphs recursively; parser-only expansion counters would
  miss some of that work and resulting allocation.
- Input buffers can grow to retain a complete token. External parameter entities
  may be internalized in full. Declarations, attribute lists, namespace tables
  and regular-expression states also allocate without configurable budgets.
- Fatal diagnostics suppress application callbacks, but the parser continues
  checking input. A builder-level error is therefore insufficient to enforce a
  parser work or recursion budget.

Before accepting untrusted XML, add parser-wide, safely aborting limits for
input bytes, nesting, entity expansions, expanded code units and allocated
structures. Apply input budgets before constructor prefetch and share them
across external resources. Charge attribute-graph traversal before computing
lengths or flattening. Add bounded adversarial tests with process timeouts and
memory limits, and re-run the full compiler/sanitizer matrix.
