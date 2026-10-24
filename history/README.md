# CVS import

## Source

- Project: <https://sourceforge.net/p/ooc/code/>
- Complete CVS archive:
  <https://sourceforge.net/code-snapshots/cvs/o/oo/ooc.zip>
- Downloaded: 2026-10-24
- ZIP SHA256:
  `464a565c04ba739d82219033344ab546d3b14387cd54a2e9319f72d65906736f`
- Imported module: `ooc/libxml`, including its `Attic` files.

`libxml-cvs.tar.gz` contains all **1,940 original RCS master files** from
that module, without changes to their contents or executable bits. This
retains the exact per-file CVS history, including metadata that cannot be
represented directly by Git commits. The tar container has normalized owner
and timestamp metadata; revision dates inside the files are unchanged.

Archive SHA256:
`9bd1ced90fa063a24c53804babaa2071600cddfe40bba4cc26592f9635be3a8d`

## Conversion

The Git import uses **cvs-fast-export 2.6** and `git fast-import`. An initial
trial with 1.63 failed vendor-branch validation and was not used.

Converter release:
<http://www.catb.org/~esr/cvs-fast-export/cvs-fast-export-2.6.tar.gz>

Converter release SHA256:
`c769c754a7d018ebd8236b76e8c8dce26b841fa277334481d597ab4757c6c7f5`

From the directory containing the extracted `libxml` masters:

```sh
find libxml -type f -name '*,v' -print | LC_ALL=C sort > masters.txt
cvs-fast-export -N -R revisions.marks < masters.txt > libxml.fi
git init --bare upstream.git
git -C upstream.git fast-import --export-marks=../git.marks < libxml.fi
```

- CVS authors remain their original user IDs, without invented email addresses.
- Original log messages are retained, not rewritten as VOC commit messages.
- Original dates are retained. `-T` (synthetic dates) was **not** used.
- The converter's default 300-second changeset grouping window was used.
  CVS has per-file revisions rather than atomic, repository-wide commits.
- `-N` disables insertion of a synthetic default `.gitignore`. This module
  contains no versioned `.cvsignore` files.
- Keywords are retained as stored in CVS. Validation uses `co -ko`, not an
  expanded checkout or the release tarball's expanded `$Id` comments.
- Deleted paths are recovered from `Attic`.
- Mixed vendor/trunk release tags use converter-generated snapshot commits
  where necessary to reproduce their exact file sets.

Two independent exports produced identical streams and revision maps.
Fast-import stream SHA256:
`9c910438984aa2b3bc6221456eb96d7383de7a5f430d29f55576e9e6cb11a706`

The imported history has **187 reachable commits**, two branch tips and
eleven release tags. These are separate from subsequent provenance and VOC
porting commits.

| CVS symbol | Preserved Git ref |
| --- | --- |
| HEAD | `upstream-cvs` (`4119cabea5cc321e2f96c97ae509c11b9aabe6f7`) |
| MAIN (vendor branch) | `upstream-cvs-MAIN` (`bec7e7ad393db2aa94ee0a7c475719214cad7e70`) |
| release tags | Their original CVS names, including `libxml-3_2_0` |

The unrelated local 3.2.0 release-snapshot import is **not** an ancestor of
this repository. Neither local `libxmls-git` nor the empty `libxml-git` was
used as a substitute for the `libxml` history.

## Verification

- Compared all **3,291 live CVS revisions** against RCS `co -ko` output.
- Checked all **3,276 revision-to-commit mappings** emitted by the converter.
- Verified that 42 omitted initial vendor revisions (`1.1.1.1`) are
  byte-for-byte duplicates of the corresponding imported `1.1` revisions.
  Their original records remain in the RCS masters; they are not presented
  as new Git changes.
- Confirmed that all 23 dead revisions have file-deletion history.
- Compared the complete file sets, contents and executable modes of CVS
  HEAD, vendor MAIN and all eleven release tags against their Git trees.
- Ran `git fsck --full`.

`cvs-revisions.tsv` resolves the converter's revision marks to Git object
IDs. It can contain several rows for a revision represented on more than
one line of history. It is not a replacement for the original RCS masters.

The raw archive is retained here so that the conversion can be independently
checked or repeated without depending on SourceForge continuing to serve it.
