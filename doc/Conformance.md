# XML conformance coverage

Run the bundled fixtures with Python 3.12 or newer and a matching VOC ooc build:

```sh
make BUILD=../compiler/build/ports/ooc/2 conformance
```

The runners extract archives into `BUILD/conformance/`. Source fixtures stay
unchanged. Reports include exclusions, expectation corrections and failures.
Each process has a five-second timeout. A negative fixture must return XML
diagnostics (exit 1); opening errors, traps and sanitizer errors fail the test.

| Checks | Included cases |
| --- | ---: |
| James Clark XML well-formedness | 360 |
| Original namespace well-formedness | 24 |
| James Clark DTD validation | 359 |
| IBM DTD validation | 932 |
| Sun DTD validation | 171 |
| OASIS DTD validation | 346 |
| James Clark canonical output | 163 |
| IBM canonical output | 148 |
| Sun canonical output | 28 |

All included checks pass, also under Clang ASan/UBSan. The DTD total is 1,808;
339 cases additionally compare canonical output byte-for-byte. James Clark
uses the first canonical form; IBM and Sun use the second form, which includes
sorted notation declarations.

## Upstream exclusions

The original test scripts exclude these fixtures. The runners preserve and
report those exclusions:

- James Clark `valid/sa/065.xml`: malformed entity replacement text.
- James Clark `valid/not-sa/022.xml`: improper conditional-section/parameter-
  entity nesting; excluded from validation only.
- IBM `valid/P02/ibm02v01.xml`: encoding errors in the fixture.
- IBM `valid/P58/ibm58v01.xml`: duplicate NOTATION tokens.

Sun fixtures are selected by the archive's four catalog fragments rather than
directory globs, which would also run copies of the catalogs as XML documents.

## Historical expectation corrections

`tests/voc/check-validation.py` records these corrections explicitly:

- IBM `valid/P45/ibm45v01.xml`, `valid/P47/ibm47v01.xml` and Sun
  `valid/optional.xml` contain non-deterministic content models. The validator
  reports the compatibility error specified by XML section 3.2.1, including
  models for element types unused in the document.
- IBM `valid/P57/ibm57v01.xml` and OASIS `p57pass1.xml`, `p58pass1.xml` declare
  NOTATION attributes on EMPTY elements, forbidden by XML section 3.3.1.
- Sun `valid/sa02.xml` and `valid/not-sa02.xml` contain character-reference
  CR/LF in NMTOKENS. These remain after attribute normalization; token
  separators must be spaces, as clarified by Second Edition erratum E20.
  Their reference outputs incorrectly collapse these references. The output
  runner expects `&#13;&#10;` at that attribute position and records the exact
  correction. All other reference bytes must match unchanged.
- Sun `invalid/attr11.xml` and `invalid/attr12.xml` use valid explicit ENTITY
  attributes while leaving semantically invalid defaults unused. Erratum E9
  requires only syntactic correctness for unused defaults.
- Sun `invalid/pe01.xml` contains a literal percent sign in an attribute
  default. Parameter entity references are not expanded there.
- Sun `not-wf/lang01.xml` through `lang06.xml` declare `xml:lang` as CDATA.
  Their language metadata does not impose additional XML well-formedness or
  DTD-validity constraints.

Specification references: [XML 1.0 Second Edition](https://www.w3.org/TR/2000/REC-xml-20001006/)
and its [errata](https://www.w3.org/XML/xml-V10-2e-errata).
