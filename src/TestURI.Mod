MODULE TestURI;

IMPORT
  ProgramArgs, TextRider, Err, StdChannels, Strings,
  URI, URI:Error, URI:String, URI:Parser,
  URI:Scheme:CurrentDoc, URI:Fragment:Unparsed,
  URI:Scheme:File, URI:Scheme:HTTP, URI:Scheme:MailTo;


VAR
  argReader: TextRider.Reader;
  arg, uriArg, baseArg, msgText, str: ARRAY 1024 OF CHAR;
  res: Error.Msg;
  uri: URI.URI;
  baseURI: URI.HierarchicalURI;
  relative: URI.URI;
  ref: URI.Reference;
  w: TextRider.Writer;
  fragmentPrototype: URI.Fragment;
  abs2rel: BOOLEAN;


PROCEDURE RegisterSchemes;
  BEGIN
    URI.RegisterScheme (File.NewPrototype());
    URI.RegisterScheme (HTTP.NewPrototype());
    URI.RegisterScheme (MailTo.NewPrototype());
  END RegisterSchemes;

PROCEDURE WriteQuotedI (w: TextRider.Writer; str: ARRAY OF CHAR; s, e: LONGINT);
  VAR
    last: LONGINT;
  BEGIN
    WHILE (s # e) DO
      last := s;
      WHILE (s # e) &
            (str[s] # "&") & (str[s] # "<") & (str[s] # ">") & 
            (str[s] # 09X) & (str[s] # 0AX) & (str[s] # 0DX) DO
        INC (s)
      END;
      w. byteWriter. WriteBytes (str, last, s-last);
      IF (s # e) THEN
        CASE str[s] OF
        | "&": w. WriteString ("&amp;")
        | "<": w. WriteString ("&lt;")
        | ">": w. WriteString ("&gt;")
        | 09X: w. WriteString ("&#9;")
        | 0AX: w. WriteString ("&#10;")
        | 0DX: w. WriteString ("&#13;")
        END;
        INC (s)
      END
    END
  END WriteQuotedI;

PROCEDURE WriteQuoted (w: TextRider.Writer; str: ARRAY OF CHAR);
  BEGIN
    WriteQuotedI (w, str, 0, Strings.Length (str))
  END WriteQuoted;

BEGIN
  RegisterSchemes;
  fragmentPrototype := Unparsed.New (String.Copy (""));
  
  IF (ProgramArgs.args. ArgNumber() = 0) OR
     (ProgramArgs.args. ArgNumber() > 3) THEN
    Err.String ("Usage: TestURI <uri> [<base-uri> [abs2rel]]"); Err.Ln;
    HALT (1)
  ELSE
    argReader := TextRider.ConnectReader (ProgramArgs.args);
    argReader. ReadLine (arg);           (* skip command name *)
    argReader. ReadLine (uriArg);
    
    res := NIL; baseURI := NIL;
    IF (ProgramArgs.args. ArgNumber() > 1) THEN
      argReader. ReadLine (baseArg);
      uri := Parser.NewURI (baseArg, NIL, res);
      IF (res # NIL) THEN
        (* oops, failed to create URI object *)
      ELSIF (uri IS CurrentDoc.CurrentDoc) THEN
        baseURI := NIL
      ELSIF ~(uri IS URI.HierarchicalURI) THEN
        Err.String ("Error: Base URI is not hierarchical"); Err.Ln;
        HALT (1)
      ELSE
        baseURI := uri(URI.HierarchicalURI)
      END
    END;
    abs2rel := (ProgramArgs.args. ArgNumber() > 2);
    
    IF (res = NIL) THEN
      ref := Parser.NewReference (uriArg, baseURI, fragmentPrototype, res)
    END;
    
    w := TextRider.ConnectWriter (StdChannels.stdout);
    w. WriteString ("<?xml version='1.0' encoding='ISO-8859-1' standalone='yes'?>"); w. WriteLn;
    
    IF (res = NIL) & abs2rel THEN
      relative := ref. uri(URI.HierarchicalURI). MakeRelative (baseURI);
      
      w. WriteString ("<test-absolute-to-relative>");
      relative. WriteXML (w);
      w. WriteLn;
      w. WriteString ("<uri-string>");
      relative. GetString (str);
      WriteQuoted (w, str);
      w. WriteString ("</uri-string>");
      w. WriteLn;
      w. WriteString ("</test-absolute-to-relative>");
      w. WriteLn
    ELSIF (res = NIL) THEN
      w. WriteString ("<test-parse-uri>");
      ref. WriteXML (w);
      w. WriteLn;
      w. WriteString ("<uri-string>");
      ref. GetString (str);
      WriteQuoted (w, str);
      w. WriteString ("</uri-string>");
      w. WriteLn;
      w. WriteString ("</test-parse-uri>");
      w. WriteLn
    END;
    
    IF (res # NIL) THEN
      res. GetText (msgText);
      Err.String ("Error: ");
      Err.String (msgText);
      Err.Ln;
      HALT (1)
    END
  END
END TestURI.
