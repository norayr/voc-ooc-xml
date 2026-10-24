MODULE XMLCheck;

IMPORT Args, Out, M := Msg, Mem := IOMemory, B := XMLBuilder,
  N := XMLBuilderNamespaces, P := XMLParser, XMLUnicodeCodecImportAll;

VAR path, text: ARRAY 4096 OF CHAR; p: P.Parser; res: M.Msg;
  output: Mem.Channel; i: LONGINT; arg: INTEGER;
  external, namespaces: BOOLEAN; builder: B.Builder;

BEGIN
  IF (Args.argc < 2) OR (Args.argc > 4) THEN
    Out.String("usage: XMLCheck [--external] [--namespaces] file.xml"); Out.Ln; HALT(2)
  END;
  arg := 1; external := FALSE; namespaces := FALSE;
  WHILE arg < Args.argc-1 DO
    Args.Get(arg, path);
    IF (path = "--external") & ~external THEN external := TRUE
    ELSIF (path = "--namespaces") & ~namespaces THEN namespaces := TRUE
    ELSE HALT(2)
    END;
    INC(arg)
  END;
  Args.Get(arg, path); builder := B.New();
  IF namespaces THEN builder := N.New(builder) END;
  p := P.NewFile(path, NIL, NIL, NIL, builder, res);
  IF p = NIL THEN res.GetText(text); Out.String(text); Out.Ln; HALT(2) END;
  p.followExternalRef := external; p.enforceQNames := namespaces; p.ParseDocument;
  IF p.errList.msgCount # 0 THEN
    output := Mem.Tmp("", {Mem.read, Mem.write}, res);
    p.errList.Write(output);
    FOR i := 0 TO output.Length()-1 DO Out.Char(output.file.data[i]) END;
    output.Close; HALT(1)
  END
END XMLCheck.
