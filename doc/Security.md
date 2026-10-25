# XML input policy and resource review

The port currently requires **trusted XML**. External access controls and
parser resource budgets have regression coverage. Broader adversarial testing
and accounting in validation and application builders remain unfinished.

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

## Parser resource budgets

`XMLLimits.New()` creates a budget for one parse. Set its maxima before passing
it to `XMLParser.NewReaderLimited`, `NewChannelLimited`, `NewURILimited` or
`NewFileLimited`. These constructors have the corresponding original
constructor's arguments, with the budget after the builder and before any
result argument. For example:

```oberon
budget := XMLLimits.New();
budget.maxInputBytes := 1024*1024;
parser := XMLParser.NewReaderLimited(reader, baseURI, NIL, NIL, builder, budget);
parser.followExternalRef := FALSE;
parser.ParseDocument;
(* Inspect parser.errList before using the result. *)
```

The original constructors retain their unlimited behavior. `XMLCheck` uses a
fresh default budget for every invocation, including namespace, validation,
canonical and protocol modes. The Basic parser's convenience `Parse` interface
continues to use the original constructors.

| Budget maximum | Default | Accounted resources |
| --- | ---: | --- |
| `maxInputBytes` | 16 MiB | Accepted bytes across the document and all opened external entities. |
| `maxNesting` | 128 | Combined active element, entity, content-model, conditional-section and attribute-graph traversal levels. |
| `maxEntityExpansions` | 10,000 | Entity entries, including the external DTD and eager checking of internal declarations. |
| `maxExpandedUnits` | 16,777,216 | UTF-16 code units copied for entity insertion/internalization and visited while checking attribute/entity values. |
| `maxWork` | 100,000 | Name/string construction, character fragments, graph visits, parser diagnostics and declaration/attribute comparisons. |
| `maxAttributeUnits` | 1,048,576 | Code units in one flattened attribute or entity value. |
| `maxModelParticles` | 256 | Groups and named particles in one DTD content model. |

Zero is a real limit; a negative maximum disables that particular limit.
Counters are cumulative and a failed budget remains failed. Keep the budget
exclusive to its parse and leave the maxima unchanged during parsing.
Expansion accounting is conservative: checking a reused value can charge its
units again. `maxWork` bounds allocation-producing parser operations, rather
than measuring allocated bytes or elapsed time.

The byte budget wraps the reader before constructor prefetch and is shared
with every subsequent external reader. At an exact byte boundary a one-byte
probe distinguishes EOF from an overrun; at most one extra byte is consumed
and none of it is delivered to the parser. Expansion and nesting reservations
precede opening or internalizing an entity. Opening the primary URI and running
application resolver code still have their own side effects.

On exhaustion the parser records a resource diagnostic, sets `parser.aborted`,
suppresses further content callbacks and unwinds its grammar/entity stacks.
The original builder still receives `EndDocument` once. Its result may be
incomplete and must be discarded. `budget.error` identifies the diagnostic;
its code is `XMLLimits.codeBase` plus the relevant limit constant. `XMLCheck`
returns 1 for a resource diagnostic, just as for other XML errors.

Attribute graphs are checked for nesting, work and expanded length before
recursive length calculation or flattening. This also covers default values
and unused entity declarations. DTD namespace insertion is iterative and both
lookup and insertion charge comparisons. Retained-token byte and Unicode
buffers grow geometrically, keeping long-token copying linear in total size.

## Adversarial checks

`TestLimits` tests exact boundaries and independently exhausts every limit.
It varies byte, work, expansion, value-length, nesting and content-model
cutoffs throughout a document containing declarations, attributes, entities,
comments, instructions and CDATA. It checks diagnostics, stack unwinding,
content callback suppression and final notification.

`TestEntityPolicy` also cuts the shared byte allowance at every position across
external DTDs, repeated streamed entities and external-parameter internalization.
It checks that expansion exhaustion prevents a further external open.

```sh
make BUILD=../compiler/build/ports/ooc/2 test conformance limits
```

The `limits` target runs 45 hostile-input checks: deep elements, content models
and conditional sections, wide models, unused entity amplification, long entity
chains, parameter expansion, large attributes/input/names, many attributes and
siblings, malformed-control/reference floods and external internalization.
Each runs in plain, namespace and validation modes and must return a resource
diagnostic with exit code 1. The runner applies a 10-second CPU allowance,
a wall-clock timeout and a 512 MiB address-space ceiling on Linux. Under ASan
the address-space ceiling is disabled to accommodate shadow memory; CPU and
wall-clock limits remain active. Logs and results go under `BUILD/limits`.

## Remaining resource work

Continue using trusted documents while completing:

- work/allocation accounting inside validation, regular-expression processing
  and namespace/output/application builders, including aggregate costs across
  many content models;
- broader malformed-input and randomized testing, resolver/channel stalls and
  recovery from underlying allocation failures;
- budget support in the Basic parser convenience interface and direct DTD APIs.

Applications must bound their own resolver, channel and builder behavior.
Directly constructed DTD value graphs bypass the parser's graph checks. Retain
process-level time and memory limits when exercising hostile inputs.
