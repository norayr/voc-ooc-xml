# oo2c support modules

The XML port also needs string, message and channel support from oo2c.
Their original sources were imported unchanged into `src/oo2c/` before
the VOC adaptations, so that each adaptation has a byte-for-byte baseline.
Original copyright and LGPL notices are retained in each module.

Source repository: <https://github.com/Spirit-of-Oberon/oo2c>

Source checkout commit: `ff5627208e1489b5dd0a0ff6c6e135d84b06a703`.
The imported baselines match that commit's `lib/src/` contents exactly.

| File | Last source commit | SHA256 of imported file |
| --- | --- | --- |
| `LongStrings.Mod` | `53be3c022dd7655c4a794464a8ad2aea999340fb` | `5f7ecc60ed6f6de1fdecefde5799f3c8e8f53b173e514884a7294639f781bbdc` |
| `Msg.Mod` | `468a936c890c1ca5fa02636336068d7886129356` | `3bdd4824b2758dd845482fb7fe1d172ece559dd36be113ee6e066ce9224b8083` |
| `Channel.Mod` | `777528893c31adaf4bc5b4b56c753fe802f54f05` | `af694e20348ab6a49b7902d727ddc9c5364b9fd848793ecf4c6c50c09cd96d65` |

The source runtime's `lib/src/__oo2c.h`, lines 136–138, defines `CAP` for
`LONGCHAR` using the same ASCII and Latin-1 uppercase mapping as for `CHAR`.
The string port preserves that mapping explicitly when replacing the built-in
operation on wide characters.

## Shared VOC package

The tested implementations now live in VOC's `src/ports/ooc/`, transferred in
[commit 9ec25546ab07cd37df96088d1dc5f7e64bf93d73](https://github.com/vishapoberon/compiler/commit/9ec25546ab07cd37df96088d1dc5f7e64bf93d73).
`Msg` and `Channel` replace the existing VOC implementations; `LongStrings`,
`IOMemory` and the shared `oocUnicode` code-unit type are supplied there too.
The string and message unit tests live in VOC's confidence suite. XML keeps
its codec/message integration test and memory/buffer integration tests.

The transferred versions were recorded in this repository at commit
`083e443`, before removing the staging copies. The original alias module
`src/XML/Unicode.Mod` is named `oocUnicode` in VOC so shared support can be
built independently of XML. The original `IOMemory` implementation is also
preserved as `src/IO/Memory.Mod` in the CVS branches and release tags.
