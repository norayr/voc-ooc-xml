(*      $Id: Writer.Mod,v 1.2 2000/07/10 20:29:34 mva Exp $   *)
MODULE XML:Writer [OOC_EXTENSIONS];
(*  Auxiliary functions to write nice looking XML text.
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

TYPE
  Writer* = POINTER TO WriterDesc;
  WriterDesc = RECORD
    (UnicodeBuffer.OutputDesc)
    indent: LONGINT;
    newLine: ARRAY 3 OF CHAR;
    lenNewLine: LONGINT;
    baseURI-: URI.HierarchicalURI;
  END;


PROCEDURE New* (ch: Channel.Channel; codecFactory: Codec.Factory;
                createBOM: BOOLEAN): Writer;
  VAR
    w: Writer;
  BEGIN
    NEW (w);
    UnicodeBuffer.InitOutput (w, ch, codecFactory, createBOM);
    w. indent := 0;
    w. baseURI := NIL;
    w. newLine := Ascii.lf;
    w. lenNewLine := 1;
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
    w. WriteLatin1 ("<?xml");
    IF (version # "") THEN
      w. WriteLatin1 (" version='");
      w. WriteLatin1 (version);
      w. WriteLatin1 ("'")
    END;
    w. WriteLatin1 (" encoding='");
    w. codecFactory. GetEncodingName (encoding);
    w. WriteLatin1 (encoding);
    w. WriteLatin1 ("'");
    IF (standalone # "") THEN
      w. WriteLatin1 (" standalone='");
      w. WriteLatin1 (standalone);
      w. WriteLatin1 ("'")
    END;
    w. WriteLatin1 ("?>")
  END WriteTextDecl;

PROCEDURE (w: Writer) NewLine*;
  VAR
    i: LONGINT;
  BEGIN
    w. WriteLatin1I (w. newLine, 0, w. lenNewLine);
    FOR i := 1 TO w. indent DO
      w. WriteLatin1 ("  ")
    END
  END NewLine;

PROCEDURE (w: Writer) WriteQuotedI* (str[NO_COPY]: ARRAY OF Char;
                                     s, e: LONGINT);
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
      w. WriteI (str, last, s);
      IF (s # e) THEN
        CASE str[s] OF
        | "&": w. WriteLatin1 ("&amp;")
        | "<": w. WriteLatin1 ("&lt;")
        | ">": w. WriteLatin1 ("&gt;")
        | 09X: w. WriteLatin1 ("&#9;")
        | 0AX: w. WriteLatin1 ("&#10;")
        | 0DX: w. WriteLatin1 ("&#13;")
        END;
        INC (s)
      END
    END
  END WriteQuotedI;

PROCEDURE (w: Writer) WriteQuotedLatin1I* (str[NO_COPY]: ARRAY OF CHAR;
                                           s, e: LONGINT);
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
      w. WriteLatin1I (str, last, s);
      IF (s # e) THEN
        CASE str[s] OF
        | "&": w. WriteLatin1 ("&amp;")
        | "<": w. WriteLatin1 ("&lt;")
        | ">": w. WriteLatin1 ("&gt;")
        | 09X: w. WriteLatin1 ("&#9;")
        | 0AX: w. WriteLatin1 ("&#10;")
        | 0DX: w. WriteLatin1 ("&#13;")
        END;
        INC (s)
      END
    END
  END WriteQuotedLatin1I;

PROCEDURE (w: Writer) WriteQuoted* (str[NO_COPY]: ARRAY OF Char);
  BEGIN
    w. WriteQuotedI (str, 0, LongStrings.Length (str))
  END WriteQuoted;

PROCEDURE (w: Writer) WriteQuotedLatin1* (str[NO_COPY]: ARRAY OF CHAR);
  BEGIN
    w. WriteQuotedLatin1I (str, 0, Strings.Length (str))
  END WriteQuotedLatin1;

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


PROCEDURE (w: Writer) StartTag* (str[NO_COPY]: ARRAY OF Char);
  BEGIN
    w. NewLine;
    w. WriteLatin1 ("<");
    w. Write (str);
    w. WriteLatin1 (">");
    INC (w. indent)
  END StartTag;

PROCEDURE (w: Writer) StartTagInline* (str[NO_COPY]: ARRAY OF Char);
  BEGIN
    w. WriteLatin1 ("<");
    w. Write (str);
    w. WriteLatin1 (">")
  END StartTagInline;

PROCEDURE (w: Writer) StartAttr* (str[NO_COPY]: ARRAY OF Char);
  BEGIN
    w. NewLine;
    w. WriteLatin1 ("<");
    w. Write (str);
    INC (w. indent)
  END StartAttr;

PROCEDURE (w: Writer) StartAttrInline* (str[NO_COPY]: ARRAY OF Char);
  BEGIN
    w. WriteLatin1 ("<");
    w. Write (str)
  END StartAttrInline;

PROCEDURE (w: Writer) AttrString* (name[NO_COPY], value[NO_COPY]: ARRAY OF Char);
  BEGIN
    w. WriteLatin1 (" ");
    w. Write (name);
    w. WriteLatin1 ("='");
    w. WriteQuoted (value);
    w. WriteLatin1 ("'")
  END AttrString;

PROCEDURE (w: Writer) AttrInt* (name[NO_COPY]: ARRAY OF Char; value: LONGINT);
  VAR
    val: ARRAY 32 OF CHAR;
  BEGIN
    w. WriteLatin1 (" ");
    w. Write (name);
    w. WriteLatin1 ("='");
    IntStr.IntToStr (value, val);
    w. WriteLatin1 (val);
    w. WriteLatin1 ("'")
  END AttrInt;

PROCEDURE (w: Writer) AttrBool* (name[NO_COPY]: ARRAY OF Char; value: BOOLEAN);
  BEGIN
    w. WriteLatin1 (" ");
    w. Write (name);
    IF value THEN
      w. WriteLatin1 ("='yes'")
    ELSE
      w. WriteLatin1 ("='no'")
    END
  END AttrBool;

PROCEDURE (w: Writer) AttrURI* (name[NO_COPY]: ARRAY OF Char; uri: URI.URI;
                                absolute: BOOLEAN);
  BEGIN
    w. WriteLatin1 (" ");
    w. Write (name);
    w. WriteLatin1 ("='");
    w. WriteURI (uri, absolute);
    w. WriteLatin1 ("'")
  END AttrURI;

PROCEDURE (w: Writer) EndAttr* (isEmpty: BOOLEAN);
  BEGIN
    IF isEmpty THEN
      w. WriteLatin1 ("/>");
      DEC (w. indent)
    ELSE
      w. WriteLatin1 (">")
    END;
  END EndAttr;

PROCEDURE (w: Writer) EndTag* (str[NO_COPY]: ARRAY OF Char; newLine: BOOLEAN);
  BEGIN
    DEC (w. indent);
    IF newLine THEN
      w. NewLine
    END;
    w. WriteLatin1 ("</");
    w. Write (str);
    w. WriteLatin1 (">")
  END EndTag;

PROCEDURE (w: Writer) EndTagInline* (str[NO_COPY]: ARRAY OF Char);
  BEGIN
    w. WriteLatin1 ("</");
    w. Write (str);
    w. WriteLatin1 (">")
  END EndTagInline;

PROCEDURE (w: Writer) EmptyTag* (str[NO_COPY]: ARRAY OF Char);
  BEGIN
    w. NewLine;
    w. WriteLatin1 ("<");
    w. Write (str);
    w. WriteLatin1 ("/>")
  END EmptyTag;

PROCEDURE (w: Writer) EmptyTagInline* (str[NO_COPY]: ARRAY OF Char);
  BEGIN
    w. WriteLatin1 ("<");
    w. Write (str);
    w. WriteLatin1 ("/>")
  END EmptyTagInline;

PROCEDURE (w: Writer) EndOfText*;
  BEGIN
    w. NewLine;
    w. Flush
  END EndOfText;
  
END XML:Writer.
