(* 	$Id: Error.Mod,v 1.1.1.2 2000/07/10 20:31:56 mva Exp $	 *)
MODULE XML:Error;
(*  Creates lists of error messages and converts them to text.
    Copyright (C) 2000  Michael van Acken
*)


IMPORT
  Ascii, Strings,Channel, TextRider, LongStrings, M := Msg,
  URI, URI:Scheme:File;
  
  
TYPE
  Msg* = M.Msg;
  Code* = M.Code;
  Char* = M.Char;
  LChar* = M.LChar;
  String* = M.String;
  StringPtr* = M.StringPtr;
  LString* = M.LString;
  LStringPtr* = M.LStringPtr;
  
TYPE
  Mapping* = POINTER TO MappingDesc;
  MappingDesc = RECORD
    next: Mapping;
    code: Code;
    text: LStringPtr;
  END;

TYPE
  Context* = POINTER TO ContextDesc;
  ContextDesc* = RECORD
    (M.ContextDesc)
    mapping: Mapping;
  END;

TYPE
  List* = POINTER TO ListDesc;
  ListDesc = RECORD
    (M.MsgListDesc)
    cwdURI: URI.HierarchicalURI;
  END;


PROCEDURE InitContext* (c: Context; id: M.String);
  BEGIN
    M.InitContext (c, id);
    c. mapping := NIL
  END InitContext;

PROCEDURE NewContext* (id: M.String): Context;
  VAR
    c: Context;
  BEGIN
    NEW (c);
    InitContext (c, id);
    RETURN c
  END NewContext;

PROCEDURE (context: Context) GetTemplate* (msg: Msg; VAR templ: LString);
  VAR
    m: Mapping;
    entityName: M.Attribute;
  CONST
    eol = Ascii.lf;
  BEGIN
    entityName := msg. GetAttribute ("entity_name");
    IF (entityName = NIL) THEN
      COPY ("", templ)
    ELSE
      COPY ("While expanding entity `", templ);
      LongStrings.Append (entityName(M.LStringAttribute). string^, templ);
      LongStrings.Append ("': ", templ)
    END;
    
    m := context. mapping;
    WHILE (m # NIL) & (m. code # msg. code) DO
      m := m. next
    END;
    IF (m # NIL) THEN
      LongStrings.Append (m. text^, templ)
    ELSE
      LongStrings.Append ("--unknown error code--", templ);
      LongStrings.Append (eol+"msg_context=${MSG_CONTEXT}"+
                          eol+"msg_code=${MSG_CODE}", templ)
    END;
    LongStrings.Insert ("line=${line}, column=${column}"+eol+
                        "${char}: ", 0, templ);
  END GetTemplate;

PROCEDURE (context: Context) SetString* (code: Code; str: String);
  PROCEDURE Append (VAR mlist: Mapping);
    VAR
      str16: ARRAY 1024 OF M.LChar;
    BEGIN
      IF (mlist = NIL) THEN
        NEW (mlist);
        mlist. next := NIL;
        mlist. code := code;
        COPY (str, str16);
        mlist. text := M.GetLStringPtr (str16)
      ELSIF (mlist. code = code) THEN
        COPY (str, str16);
        mlist. text := M.GetLStringPtr (str16)
      ELSE
        Append (mlist. next)
      END
    END Append;
  
  BEGIN
    Append (context. mapping)
  END SetString;

PROCEDURE New* (context: Context; code: Code): Msg;
  BEGIN
    RETURN M.New (context, code)
  END New;

PROCEDURE NewList*(): List;
(**Creates new error list.  *)
  VAR
    list: List;
  BEGIN
    NEW (list);
    M.InitMsgList (list);
    list. cwdURI := File.GetCwd();
    RETURN list
  END NewList;


PROCEDURE (errList: List) Write* (ch: Channel.Channel);
(**Writes the list of error messages to the ouput channel @oparam{ch}.  The
   channel must be writable.  The generated list is prefixed by the name
   of the file to which the errors refer.  File names relative to the current
   working directory are rewritten to relative path names, using the list's
   `cwdURI' as base.  *)
  VAR
    writer: TextRider.Writer;
    msg, prev: Msg;
    text: ARRAY 8*1024 OF CHAR;
    uriAttr: M.Attribute;
    uri, prevURI: URI.URI;
    repl1, repl2: ARRAY 1024 OF CHAR;

  PROCEDURE Replace (VAR text: ARRAY OF CHAR; pattern, repl: ARRAY OF CHAR);
    VAR
      pos: INTEGER;
      found: BOOLEAN;
    BEGIN
      Strings.FindNext (pattern, text, 0, found, pos);
      WHILE found DO
        Strings.Delete (text, pos, Strings.Length (pattern));
        Strings.Insert (repl, pos, text);
        INC (pos, Strings.Length (repl));
        Strings.FindNext (pattern, text, pos, found, pos)
      END
    END Replace;
  
  PROCEDURE DistanceOk (m0, m1: M.Msg): BOOLEAN;
    VAR
      p0, p1: M.Attribute;
    BEGIN
      IF (m0 = NIL) THEN
        RETURN TRUE
      ELSE
        p0 := m0. GetAttribute ("char");
        p1 := m1. GetAttribute ("char");
        IF (p0 # NIL) & (p1 # NIL) &
           (p0 IS M.IntAttribute) &
           (p1 IS M.IntAttribute) &
           (ABS (p0(M.IntAttribute). int - p1(M.IntAttribute). int) < 16) THEN
          RETURN FALSE
        ELSE
          RETURN TRUE
        END
      END
    END DistanceOk;
  
  BEGIN
    writer := TextRider.ConnectWriter (ch);
    ASSERT (writer # NIL);
    
    errList. cwdURI. GetString (repl1);
    errList. cwdURI(File.URI). GetPath (repl2);
    Strings.Insert ("file_name=", 0, repl2);
    
    prev := NIL; prevURI := NIL;
    msg := errList. msgList;
    WHILE (msg # NIL) DO
      IF DistanceOk (prev, msg) THEN
        uriAttr := msg. GetAttribute ("baseURI");
        IF (uriAttr(URI.URIAttribute). uri # prevURI) THEN
          uri := uriAttr(URI.URIAttribute). uri. MakeRelative (errList. cwdURI);
          uri. GetString (text);
          writer. WriteString ("In file ");
          writer. WriteString (text);
          writer. WriteString (": ");
          writer. WriteLn
        END;
        prevURI := uriAttr(URI.URIAttribute). uri;
        
        msg. GetText (text);
        Replace (text, repl1, "file:");
        Replace (text, repl2, "file_name=");
        writer. WriteString (text);
        writer. WriteLn;
        prev := msg
      END;
      msg := msg. nextMsg
    END
  END Write;

END XML:Error.
