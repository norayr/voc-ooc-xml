(*      $Id: Writer.Mod,v 1.3 2000/07/12 22:28:05 mva Exp $   *)
MODULE XML:Writer [OOC_EXTENSIONS];
(*  Support for generating XML documents.
    Copyright (C) 2000  Michael van Acken

    This module is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public License
    as published by the Free Software Foundation; either version 2 of
    the License, or (at your option) any later version.

    This module is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with OOC. If not, write to the Free Software Foundation,
    59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*)


IMPORT
  Ascii, Channel, Strings, LongStrings, IntStr, URI,
  Codec := XML:UnicodeCodec, XML:UnicodeBuffer;


TYPE
  Char* = LONGCHAR;
  String = POINTER TO ARRAY OF Char;
  Elements = POINTER TO ARRAY OF
               RECORD
                 name: String;
                 mixedContent: BOOLEAN;
               END;

TYPE
  Writer* = POINTER TO WriterDesc;
  WriterDesc = RECORD
    (UnicodeBuffer.OutputDesc)
    indentLevel: LONGINT;
    indent: LONGINT;
    newLine: ARRAY 3 OF CHAR;
    lenNewLine: LONGINT;
    baseURI-: URI.HierarchicalURI;
    
    elementStack: Elements;
    lenElementStack: LONGINT;
    doIndent: BOOLEAN;
    openStartTag: BOOLEAN;
  END;


PROCEDURE New* (ch: Channel.Channel; codecFactory: Codec.Factory;
                writeBOM: BOOLEAN; indentLevel: LONGINT): Writer;
  VAR
    w: Writer;
  BEGIN
    NEW (w);
    UnicodeBuffer.InitOutput (w, ch, codecFactory, writeBOM);
    w. indentLevel := indentLevel;
    w. indent := 0;
    w. baseURI := NIL;
    w. newLine := Ascii.lf;
    w. lenNewLine := 1;
    
    NEW (w. elementStack, 8);
    w. lenElementStack := 0;
    w. doIndent := (indentLevel >= 0);
    w. openStartTag := FALSE;
    
    RETURN w
  END New;

PROCEDURE (w: Writer) SetBaseURI* (baseURI: URI.HierarchicalURI);
  BEGIN
    w. baseURI := baseURI
  END SetBaseURI;

PROCEDURE (w: Writer) WriteTextDecl* (version, standalone: ARRAY OF CHAR);
  VAR
    encoding: ARRAY 256 OF CHAR;
  BEGIN
    w. Write8 ("<?xml");
    IF (version # "") THEN
      w. Write8 (" version='");
      w. Write8 (version);
      w. Write8 ("'")
    END;
    w. Write8 (" encoding='");
    w. codecFactory. GetEncodingName (encoding);
    w. Write8 (encoding);
    w. Write8 ("'");
    IF (standalone # "") THEN
      w. Write8 (" standalone='");
      w. Write8 (standalone);
      w. Write8 ("'")
    END;
    w. Write8 ("?>")
  END WriteTextDecl;

PROCEDURE (w: Writer) NewLine*;
  VAR
    i: LONGINT;
  BEGIN
    IF w. doIndent THEN
      w. Write8I (w. newLine, 0, w. lenNewLine);
      FOR i := 1 TO w. indent DO
        w. Write8 (" ")
      END
    END
  END NewLine;


PROCEDURE (w: Writer) CloseStartTag*;
  BEGIN
    ASSERT (w. openStartTag);
    w. Write8 (">");
    w. openStartTag := FALSE
  END CloseStartTag;

PROCEDURE (w: Writer) WriteI* (str[NO_COPY]: ARRAY OF Char; s, e: LONGINT);
  VAR
    last: LONGINT;
  BEGIN
    IF w. openStartTag THEN w. CloseStartTag END;
    WHILE (s # e) DO
      last := s;
      WHILE (s # e) &
            (str[s] # "&") & (str[s] # "<") & (str[s] # ">") DO
        INC (s)
      END;
      w. Write16I (str, last, s);
      IF (s # e) THEN
        CASE str[s] OF
        | "&": w. Write8 ("&amp;")
        | "<": w. Write8 ("&lt;")
        | ">": w. Write8 ("&gt;")
        END;
        INC (s)
      END
    END
  END WriteI;

PROCEDURE (w: Writer) WriteLatin1I* (str[NO_COPY]: ARRAY OF CHAR;
                                     s, e: LONGINT);
  VAR
    last: LONGINT;
  BEGIN
    IF w. openStartTag THEN w. CloseStartTag END;
    WHILE (s # e) DO
      last := s;
      WHILE (s # e) &
            (str[s] # "&") & (str[s] # "<") & (str[s] # ">") DO
        INC (s)
      END;
      w. Write8I (str, last, s);
      IF (s # e) THEN
        CASE str[s] OF
        | "&": w. Write8 ("&amp;")
        | "<": w. Write8 ("&lt;")
        | ">": w. Write8 ("&gt;")
        END;
        INC (s)
      END
    END
  END WriteLatin1I;

PROCEDURE (w: Writer) Write* (str[NO_COPY]: ARRAY OF Char);
  BEGIN
    w. WriteI (str, 0, LongStrings.Length (str))
  END Write;

PROCEDURE (w: Writer) WriteLatin1* (str[NO_COPY]: ARRAY OF CHAR);
  BEGIN
    w. WriteLatin1I (str, 0, Strings.Length (str))
  END WriteLatin1;

PROCEDURE (w: Writer) WriteURI* (uri: URI.URI; absolute: BOOLEAN);
  VAR
    str: ARRAY 1024 OF CHAR;
  BEGIN
    IF ~absolute THEN
      uri := uri. MakeRelative (w. baseURI)
    END;
    uri. GetString (str);
    w. WriteLatin1 (str)
  END WriteURI;


PROCEDURE GetString (VAR str: ARRAY OF Char): String;
  VAR
    s: String;
  BEGIN
    NEW (s, LongStrings.Length (str)+1);
    COPY (str, s^);
    RETURN s
  END GetString;

PROCEDURE (w: Writer) StartTag* (name[NO_COPY]: ARRAY OF Char;
                                 mixedContent: BOOLEAN);
  VAR
    new: Elements;
    i: LONGINT;
  BEGIN
    IF w. openStartTag THEN w. CloseStartTag END;
    w. NewLine;
    w. Write8 ("<");
    w. Write16 (name);
    
    IF (w. lenElementStack = LEN (w. elementStack^)) THEN
      NEW (new, w. lenElementStack*2);
      FOR i := 0 TO w. lenElementStack-1 DO
        new[i] := w. elementStack[i]
      END;
      w. elementStack := new
    END;
    w. elementStack[w. lenElementStack]. name := GetString (name);
    w. elementStack[w. lenElementStack]. mixedContent := mixedContent;
    INC (w. lenElementStack);
    w. openStartTag := TRUE;
    
    w. doIndent := (w. indentLevel >= 0) & ~mixedContent;
    IF w. doIndent THEN
      INC (w. indent, w. indentLevel)
    END
  END StartTag;

PROCEDURE (w: Writer) StartTagLatin1* (name[NO_COPY]: ARRAY OF CHAR;
                                       mixedContent: BOOLEAN);
  VAR
    name16: ARRAY 1024 OF Char;
  BEGIN
    COPY (name, name16);
    w. StartTag (name16, mixedContent)
  END StartTagLatin1;


PROCEDURE (w: Writer) AttrString* (name[NO_COPY], value[NO_COPY]: ARRAY OF Char);
  VAR
    s, e, last: LONGINT;
  BEGIN
    ASSERT (w. openStartTag);
    w. Write8 (" ");
    w. Write16 (name);
    w. Write8 ("='");
    
    s := 0; e := LongStrings.Length (value);
    WHILE (s # e) DO
      last := s;
      WHILE (s # e) & (value[s] # "'") &
            (value[s] # "&") & (value[s] # "<") & (value[s] # ">") DO
        INC (s)
      END;
      w. Write16I (value, last, s);
      IF (s # e) THEN
        CASE value[s] OF
        | "&": w. Write8 ("&amp;")
        | "<": w. Write8 ("&lt;")
        | ">": w. Write8 ("&gt;")
        | "'": w. Write8 ("&apos;")
        END;
        INC (s)
      END
    END;
    
    w. Write8 ("'")
  END AttrString;

PROCEDURE (w: Writer) AttrStringLatin1* (name[NO_COPY]: ARRAY OF Char;
                                         value[NO_COPY]: ARRAY OF CHAR);
  VAR
    s, e, last: LONGINT;
  BEGIN
    ASSERT (w. openStartTag);
    w. Write8 (" ");
    w. Write16 (name);
    w. Write8 ("='");
    
    s := 0; e := Strings.Length (value);
    WHILE (s # e) DO
      last := s;
      WHILE (s # e) & (value[s] # "'") &
            (value[s] # "&") & (value[s] # "<") & (value[s] # ">") DO
        INC (s)
      END;
      w. Write8I (value, last, s);
      IF (s # e) THEN
        CASE value[s] OF
        | "&": w. Write8 ("&amp;")
        | "<": w. Write8 ("&lt;")
        | ">": w. Write8 ("&gt;")
        | "'": w. Write8 ("&apos;")
        END;
        INC (s)
      END
    END;
    
    w. Write8 ("'")
  END AttrStringLatin1;

PROCEDURE (w: Writer) AttrInt* (name[NO_COPY]: ARRAY OF Char; value: LONGINT);
  VAR
    val: ARRAY 32 OF CHAR;
  BEGIN
    IntStr.IntToStr (value, val);
    w. AttrStringLatin1 (name, val)
  END AttrInt;

PROCEDURE (w: Writer) AttrBool* (name[NO_COPY]: ARRAY OF Char; value: BOOLEAN);
  BEGIN
    IF value THEN
      w. AttrStringLatin1 (name, "yes")
    ELSE
      w. AttrStringLatin1 (name, "no")
    END
  END AttrBool;

PROCEDURE (w: Writer) AttrURI* (name[NO_COPY]: ARRAY OF Char; uri: URI.URI;
                                absolute: BOOLEAN);
  BEGIN
    ASSERT (w. openStartTag);
    w. Write8 (" ");
    w. Write16 (name);
    w. Write8 ("='");
    w. WriteURI (uri, absolute);
    w. Write8 ("'")
  END AttrURI;


PROCEDURE (w: Writer) EndTag*;
  BEGIN
    IF (w. lenElementStack <= 0) THEN
      w. Flush; ASSERT (FALSE)
    END;
    
    IF w. doIndent THEN
      DEC (w. indent, w. indentLevel)
    END;
    DEC (w. lenElementStack);
    
    IF w. openStartTag THEN
      w. Write8 ("/>");
      w. openStartTag := FALSE
    ELSE
      w. NewLine;
      w. Write8 ("</");
      w. Write16 (w. elementStack[w. lenElementStack]. name^);
      w. Write8 (">")
    END;
    
    w. doIndent := (w. indentLevel >= 0);
    IF (w. lenElementStack > 0) THEN
      w. doIndent := w. doIndent&
                     ~(w. elementStack[w. lenElementStack-1]. mixedContent)
    END
  END EndTag;

PROCEDURE (w: Writer) EndOfText*;
  BEGIN
    w. NewLine;
    w. Flush;
    ASSERT (w. lenElementStack = 0);
  END EndOfText;
  
END XML:Writer.
