MODULE TestLimits;

IMPORT Out, S := LongStrings, M := Msg, Mem := IOMemory, Ch := Channel,
  B := XMLBuilder, D := XMLDTD, P := XMLParser, L := XMLLimits, XMLUnicodeCodecImportAll;

TYPE
  Capture = POINTER TO CaptureDesc;
  CaptureDesc = RECORD (B.BuilderDesc) ends: LONGINT; budget: L.Budget END;

PROCEDURE (capture: Capture) StartElement(namespace: D.NamespaceDeclaration; localName: D.String);
BEGIN ASSERT(capture.budget.error = NIL, 7) END StartElement;

PROCEDURE (capture: Capture) Characters(VAR text: D.StringVar; start, end: D.CharPos;
  whitespace: D.ElementWhitespaceType);
BEGIN ASSERT(capture.budget.error = NIL, 8) END Characters;

PROCEDURE (capture: Capture) EndDocument;
BEGIN INC(capture.ends) END EndDocument;

PROCEDURE Check(text: ARRAY OF CHAR; budget: L.Budget; kind: SHORTINT);
  VAR input: Mem.Channel; writer: Ch.Writer; parser: P.Parser; result, msg: M.Msg;
    capture: Capture; error: ARRAY 512 OF CHAR; found: BOOLEAN;
BEGIN
  input := Mem.Tmp("", {Mem.read, Mem.write}, result); ASSERT(result = NIL, 1);
  writer := input.NewWriter(); writer.WriteBytes(text, 0, S.Length8(text));
  NEW(capture); B.Init(capture); capture.ends := 0; capture.budget := budget;
  parser := P.NewReaderLimited(input.NewReader(), NIL, NIL, NIL, capture, budget);
  parser.followExternalRef := FALSE; parser.ParseDocument;
  IF (kind = 0) OR ((kind < 0) & (budget.error = NIL)) THEN
    IF parser.errList.msgCount # 0 THEN
      msg := parser.errList.msgList;
      WHILE msg # NIL DO msg.GetText(error); Out.String(error); Out.Ln; msg := msg.nextMsg END
    END;
    ASSERT((budget.error = NIL) & ~parser.aborted & (parser.errList.msgCount = 0), 2)
  ELSE
    found := FALSE; msg := parser.errList.msgList;
    WHILE msg # NIL DO
      IF msg = budget.error THEN found := TRUE END;
      msg := msg.nextMsg
    END;
    IF (budget.error = NIL) OR ((kind > 0) & (budget.error.code # L.codeBase+kind)) THEN
      Out.String(text); Out.Ln;
      msg := parser.errList.msgList;
      WHILE msg # NIL DO msg.GetText(error); Out.String(error); Out.Ln; msg := msg.nextMsg END
    END;
    ASSERT(parser.aborted & found, 3);
    IF kind > 0 THEN ASSERT(budget.error.code = L.codeBase+kind, 4) END
  END;
  ASSERT(budget.depth = 0, 5); ASSERT(capture.ends = 1, 6); input.Close
END Check;

PROCEDURE Checks;
  VAR budget: L.Budget; text: ARRAY 8192 OF CHAR; i: LONGINT;
BEGIN
  budget := L.New(); Check('<r a="&amp;">ok</r>', budget, 0);
  budget := L.New(); budget.maxInputBytes := 4; Check('<r/>', budget, 0);
  budget := L.New(); budget.maxInputBytes := 3; Check('<r/>', budget, L.inputBytes);
  budget := L.New(); budget.maxInputBytes := 0; Check('<r/>', budget, L.inputBytes);
  budget := L.New(); budget.maxNesting := 2; Check('<r><r><r/></r></r>', budget, L.nesting);
  budget := L.New(); budget.maxNesting := 2;
  Check('<!DOCTYPE r [<!ELEMENT r (((r)))>]><r/>', budget, L.nesting);
  budget := L.New(); budget.maxWork := 0; Check('<r/>', budget, L.work);
  budget := L.New(); budget.maxEntityExpansions := 0;
  Check('<!DOCTYPE r [<!ENTITY e "x">]><r/>', budget, L.entityExpansions);
  budget := L.New(); budget.maxExpandedUnits := 2;
  Check('<!DOCTYPE r [<!ENTITY e "long">]><r/>', budget, L.expandedUnits);
  budget := L.New(); budget.maxAttributeUnits := 3;
  Check('<r a="long"/>', budget, L.attributeUnits);
  budget := L.New(); budget.maxAttributeUnits := 10;
  Check('<!DOCTYPE r [<!ENTITY a "123456"><!ENTITY b "&a;&a;">]><r x="&b;"/>', budget, L.attributeUnits);
  budget := L.New(); budget.maxModelParticles := 2;
  Check('<!DOCTYPE r [<!ELEMENT r (r,r)>]><r/>', budget, L.modelParticles);
  budget := L.New(); budget.maxModelParticles := 2;
  Check('<!DOCTYPE r [<!ELEMENT r (#PCDATA|a|b)*>]><r/>', budget, L.modelParticles);
  text := '<r a="'; i := S.Length8(text);
  WHILE i < 7000 DO text[i] := 'x'; INC(i) END;
  text[i] := '"'; text[i+1] := '/'; text[i+2] := '>'; text[i+3] := 0X;
  budget := L.New(); budget.maxInputBytes := 5000; Check(text, budget, L.inputBytes)
END Checks;

PROCEDURE Cutoffs;
  VAR text: ARRAY 2048 OF CHAR; budget: L.Budget; i: LONGINT;
BEGIN
  text := '<?xml version="1.0"?><!DOCTYPE r [<!ELEMENT r ((r|s)*)><!ELEMENT s EMPTY><!ENTITY a "text"><!ENTITY b "&a;&a;"><!ATTLIST r a CDATA "&b;" c (x|y) "x">]><!--comment--><?pi text?><r a="&b;" c="x"><s/>&b;<![CDATA[text]]></r>';
  FOR i := 0 TO S.Length8(text) DO
    budget := L.New(); budget.maxInputBytes := i; Check(text, budget, -1)
  END;
  FOR i := 0 TO 200 DO
    budget := L.New(); budget.maxWork := i; Check(text, budget, -1);
    budget := L.New(); budget.maxExpandedUnits := i; Check(text, budget, -1);
    budget := L.New(); budget.maxAttributeUnits := i; Check(text, budget, -1)
  END;
  FOR i := 0 TO 20 DO
    budget := L.New(); budget.maxEntityExpansions := i; Check(text, budget, -1);
    budget := L.New(); budget.maxNesting := i; Check(text, budget, -1);
    budget := L.New(); budget.maxModelParticles := i; Check(text, budget, -1)
  END
END Cutoffs;

BEGIN Checks; Cutoffs; Out.String("XML resource limit checks passed"); Out.Ln
END TestLimits.
