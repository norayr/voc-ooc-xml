(*      $Id: Canonical.Mod,v 1.2 2000/07/11 22:26:09 mva Exp $   *)
MODULE XML:Builder:Canonical [OOC_EXTENSIONS];
(*  Translates XML document to canonical XML.
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
  LongStrings, Channel, URI, Ascii,
  Codec := XML:UnicodeCodec, DTD := XML:BuilderDTD, B := XML:Builder,
  XML:UnicodeBuffer;

CONST
  firstCanonicalForm* = 1;
  secondCanonicalForm* = 2;
  thirdCanonicalForm* = 3;

TYPE
  Attribute = RECORD
    name: DTD.String;
    decl: DTD.AttrDecl;
    value: DTD.AttValue;
  END;
  AttributeList = POINTER TO ARRAY OF Attribute;
  
TYPE
  Node = POINTER TO NodeDesc;
  NodeDesc = RECORD
    next: Node;
    notation: DTD.Notation;
  END;

TYPE
  Builder* = POINTER TO BuilderDesc;
  BuilderDesc = RECORD
    (B.BuilderDesc)
    out-: UnicodeBuffer.Output;
    format: SHORTINT;
    
    notationList: Node;
    attrList: AttributeList;
    lenAttrList: LONGINT;
  END;

CONST
  initAttrList = 8;
  incrAttrList = 8;


(*PROCEDURE WritePos (writer: Codec.Writer; b: Builder);
  VAR
    pos: Locator.DocPos;
    
  PROCEDURE WriteInt (i: LONGINT);
    VAR
      str: ARRAY 16 OF CHAR;
      str16: ARRAY 16 OF Config.Char;
    BEGIN
      IntStr.IntToStr (i, str);
      COPY (str, str16);
      Write (writer, str16)
    END WriteInt;
  
  BEGIN
    b. locator. GetEndPos (pos);
    Write (writer, "[pos=");
    WriteInt (pos. char);
    Write (writer, ", line=");
    WriteInt (pos. line);
    Write (writer, ", col=");
    WriteInt (pos. column);
    Write (writer, "]")
  END WritePos;
*)


PROCEDURE WriteQuoted (out: UnicodeBuffer.Output; str[NO_COPY]: DTD.StringVar;
                       start, end: DTD.CharPos);
  VAR
    i: LONGINT;
  BEGIN
    i := start;
    WHILE (i # end) DO
      LOOP
        CASE str[i] OF
        | "&","<",">",'"',00X..1FX:
          (* only the control characters 09X,0AX,0DX can appear here *)
          EXIT
        ELSE
          INC (i);
          IF (i = end) THEN
            EXIT
          END
        END
      END;
      out. WriteI (str, start, i);
      
      IF (i # end) THEN
        CASE str[i] OF
        | "&": out. Write ("&amp;")
        | "<": out. Write ("&lt;")
        | ">": out. Write ("&gt;")
        | '"': out. Write ("&quot;")
        | 09X: out. Write ("&#9;")
        | 0AX: out. Write ("&#10;")
        | 0DX: out. Write ("&#13;")
        END;
        INC (i)
      END;
      start := i
    END
  END WriteQuoted;

PROCEDURE WriteDTD (b: Builder; root: DTD.String);
  VAR
    node: Node;
  
  PROCEDURE GetNext(): Node;
    VAR
      ptr, best: Node;
    BEGIN
      best := b. notationList;
      ptr := b. notationList. next;
      WHILE (ptr # NIL) DO
        IF (ptr. notation. name^ < best. notation. name^) THEN
          best := ptr
        END;
        ptr := ptr. next
      END;
      RETURN best
    END GetNext;
  
  PROCEDURE Remove (VAR list: Node; ptr: Node);
    BEGIN
      IF (ptr = list) THEN
        list := list. next
      ELSE
        Remove (list. next, ptr)
      END
    END Remove;
  
  BEGIN
    b. out. WriteLatin1 ("<!DOCTYPE ");
    b. out. Write (root^);
    b. out. WriteLatin1 (" ["+Ascii.lf);
    WHILE (b. notationList # NIL) DO
      node := GetNext();
      Remove (b. notationList, node);
      b. out. WriteLatin1 ("<!NOTATION ");
      b. out. Write (node. notation. name^);
      IF (node. notation. public # NIL) THEN
        b. out. WriteLatin1 (" PUBLIC '");
        b. out. Write (node. notation. public^);
        b. out. WriteLatin1 ("'");
        IF (node. notation. system # NIL) THEN
          b. out. WriteLatin1 (" '");
          b. out. Write (node. notation. system^);
          b. out. WriteLatin1 ("'")
        END
      ELSE
        b. out. WriteLatin1 (" SYSTEM '");
        b. out. Write (node. notation. system^);
        b. out. WriteLatin1 ("'")
      END;
      b. out. Write (">"+Ascii.lf)
    END;
    b. out. Write ("]>"+Ascii.lf)
  END WriteDTD;



PROCEDURE (b: Builder) StartDocument* (documentEntity: DTD.ExternalEntity);
  BEGIN
    (*IF b. writePosition THEN WritePos (b. writer, b) END*)
  END StartDocument;

PROCEDURE (b: Builder) EndDocument*;
  BEGIN
    (*IF b. writePosition THEN WritePos (b. writer, b) END;*)
    b. out. Flush
  END EndDocument;

PROCEDURE (b: Builder) StartElement* (namespaceURI: DTD.NamespaceURI;
                                      localName: DTD.String);
  BEGIN
    ASSERT (namespaceURI = NIL);
    IF (b. notationList # NIL) & (b. format # firstCanonicalForm) THEN
      WriteDTD (b, localName)
    END;
    b. lenAttrList := 0;
    
    b. out. WriteLatin1 ("<");
    b. out. Write (localName^);
(*    IF b. writePosition THEN WritePos (b. writer, b) END*)
  END StartElement;

PROCEDURE (b: Builder) Attribute* (namespaceURI: DTD.NamespaceURI; 
                                   localName: DTD.String;
                                   attrDecl: DTD.AttrDecl;
                                   value: DTD.AttValue;
                                   specified: BOOLEAN);
  VAR
    newList: AttributeList;
    i: LONGINT;
  BEGIN
    ASSERT (namespaceURI = NIL);
    IF (b. lenAttrList = LEN (b. attrList^)) THEN
      NEW (newList, LEN (b. attrList^)+incrAttrList);
      FOR i := 0 TO LEN (b. attrList^)-1 DO
        newList[i] := b. attrList[i]
      END;
      b. attrList := newList
    END;
    b. attrList[b. lenAttrList]. name := localName;
    b. attrList[b. lenAttrList]. decl := attrDecl;
    b. attrList[b. lenAttrList]. value := value;
    INC (b. lenAttrList)
  END Attribute;

PROCEDURE (b: Builder) AttributesDone*;
  VAR
    i, j: LONGINT;
    str: DTD.String;
  
  PROCEDURE GetMin (start: LONGINT): LONGINT;
    VAR
      min, i: LONGINT;
    BEGIN
      min := start;
      FOR i := start+1 TO b. lenAttrList-1 DO
        IF (b. attrList[i]. name^ < b. attrList[min]. name^) THEN
          min := i
        END
      END;
      RETURN min
    END GetMin;
  
  BEGIN
    FOR i := 0 TO b. lenAttrList-1 DO
      j := GetMin (i);
      b. out. WriteLatin1 (" ");
      b. out. Write (b. attrList[j]. name^);
      b. out. WriteLatin1 ('="');
      str := b. attrList[j]. value. Flatten (b. attrList[j]. decl);
      WriteQuoted (b. out, str^, 0, LongStrings.Length (str^));
      b. out. WriteLatin1 ('"');
      b. attrList[j] := b. attrList[i]
    END;
    b. out. WriteLatin1 (">")
  END AttributesDone;

PROCEDURE (b: Builder) EndElement* (namespaceURI: DTD.NamespaceURI;
                                    localName: DTD.String);
  BEGIN
    b. out. WriteLatin1 ("</");
    b. out. Write (localName^);
    b. out. WriteLatin1 (">");
(*    IF b. writePosition THEN WritePos (b. writer, b) END*)
  END EndElement;

PROCEDURE (b: Builder) Notation* (notation: DTD.Notation);
(**Called for notation declarations, see 2.10.  *)
  VAR
    node: Node;
  BEGIN
    NEW (node);
    node. next := b. notationList;
    node. notation := notation;
    b. notationList := node
  END Notation;

PROCEDURE (b: Builder) ProcessingInstruction* (
    target: DTD.String;
    VAR content: DTD.StringVar; contentStart, contentEnd: DTD.CharPos;
    baseURI: URI.URI);
  BEGIN
    b. out. WriteLatin1 ("<?");
    b. out. Write (target^);
    b. out. WriteLatin1 (" ");
    b. out. WriteI (content, contentStart, contentEnd);
    b. out. WriteLatin1 ("?>");
(*    IF b. writePosition THEN WritePos (b. writer, b) END*)
  END ProcessingInstruction;

PROCEDURE (b: Builder) Characters* (VAR chars: DTD.StringVar;
                                    charsStart, charsEnd: DTD.CharPos;
                                    elementWhitespace: DTD.ElementWhitespaceType;
                                    predefinedEntity: BOOLEAN);
  BEGIN
    WriteQuoted (b. out, chars, charsStart, charsEnd);
(*    IF b. writePosition THEN WritePos (b. writer, b) END*)
  END Characters;


PROCEDURE New* (outputChannel: Channel.Channel;
                codecFactory: Codec.Factory;
                format: SHORTINT): Builder;
  VAR
    b: Builder;
  BEGIN
    NEW (b);
    B.Init (b);
    b. out := UnicodeBuffer.NewOutput (outputChannel, codecFactory, TRUE);
    b. format := format;
    
    b. notationList := NIL;
    NEW (b. attrList, initAttrList);
    b. lenAttrList := 0;
    
    RETURN b
  END New;

END XML:Builder:Canonical.
