MODULE XMLCheck;

IMPORT Args, Out, M := Msg, Mem := IOMemory, B := XMLBuilder,
  P := XMLParser, XMLUnicodeCodecImportAll;

VAR path, text: ARRAY 4096 OF CHAR; p: P.Parser; res: M.Msg;
  output: Mem.Channel; i: LONGINT; external: BOOLEAN;

BEGIN
  IF (Args.argc < 2) OR (Args.argc > 3) THEN
    Out.String("usage: XMLCheck [--external] file.xml"); Out.Ln; HALT(2)
  END;
  Args.Get(1, path); external := path = "--external";
  IF external THEN
    IF Args.argc # 3 THEN HALT(2) END;
    Args.Get(2, path)
  ELSIF Args.argc # 2 THEN HALT(2)
  END;
  p := P.NewFile(path, NIL, NIL, NIL, B.New(), res);
  IF p = NIL THEN res.GetText(text); Out.String(text); Out.Ln; HALT(2) END;
  p.followExternalRef := external; p.ParseDocument;
  IF p.errList.msgCount # 0 THEN
    output := Mem.Tmp("", {Mem.read, Mem.write}, res);
    p.errList.Write(output);
    FOR i := 0 TO output.Length()-1 DO Out.Char(output.file.data[i]) END;
    output.Close; HALT(1)
  END
END XMLCheck.
