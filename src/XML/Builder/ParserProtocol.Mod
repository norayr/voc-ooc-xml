(*      $Id: ParserProtocol.Mod,v 1.1.1.1 2000/07/10 15:24:39 mva Exp $   *)
MODULE XML:Builder:ParserProtocol [OOC_EXTENSIONS];
(*  Translates XML document to canonical XML.
    Copyright (C) 2000  Michael van Acken

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation; either version 2 of the
    License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this library. If not, write to the Free Software
    Foundation, 59 Temple Place - Suite 330, Boston, MA 02111-1307,
    USA.
*)


IMPORT
  Channel, URI, URI:Scheme:File,
  Codec := XML:UnicodeCodec, DTD := XML:BuilderDTD, B := XML:Builder,
  XML:Writer;


TYPE
  Builder* = POINTER TO BuilderDesc;
  BuilderDesc = RECORD
    (B.BuilderDesc)
    w-: Writer.Writer;
  END;

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

PROCEDURE String (w: Writer.Writer; name: ARRAY OF LONGCHAR; string: DTD.String);
  BEGIN
    IF (string # NIL) THEN
      w. StartTag (name);
      w. Write (string^);
      w. EndTag (name, FALSE)
    END
  END String;

PROCEDURE Boolean (w: Writer.Writer; name: ARRAY OF LONGCHAR; value: BOOLEAN);
  BEGIN
    w. StartTag (name);
    IF value THEN
      w. WriteLatin1 ("yes")
    ELSE
      w. WriteLatin1 ("no")
    END;
    w. EndTag (name, FALSE)
  END Boolean;

PROCEDURE WriteURI (w: Writer.Writer; name: ARRAY OF LONGCHAR; uri: URI.URI);
  BEGIN
    IF (uri # NIL) THEN
      w. StartTag (name);
      w. WriteURI (uri, FALSE);
      w. EndTag (name, FALSE)
    END
  END WriteURI;


(*PROCEDURE Notation (w: Writer.Writer; notation: DTD.Notation);
  BEGIN
    IF (notation # NIL) THEN
      w. StartTag ("notation");
      (* ... notation *)
      w. EndTag ("notation", TRUE);
    END
  END Notation;*)

PROCEDURE Entity (w: Writer.Writer; entity: DTD.Entity);
  BEGIN
    w. StartTag ("entity");
    
    w. StartTag ("type");
    CASE entity. type OF
    | DTD.entityInternalGeneral: w. WriteLatin1 ("internal general")
    | DTD.entityInternalParameter: w. WriteLatin1 ("internal parameter")
    | DTD.entityExternalGeneral: w. WriteLatin1 ("external general")
    | DTD.entityExternalParameter: w. WriteLatin1 ("external parameter")
    | DTD.entityUnparsed: w. WriteLatin1 ("external general unparsed")
    | DTD.entityDocument: w. WriteLatin1 ("document")
    | DTD.entityExternalDTDSubset: w. WriteLatin1 ("external DTD subset")
    END;
    w. EndTag ("type", FALSE);
    
    String (w, "name", entity. name);
    WITH entity: DTD.ExternalEntity DO
      String (w, "system-identifier", entity. system);
      String (w, "public-identifier", entity. public);
      WriteURI (w, "base-uri", entity. baseURI);
      String (w, "notation", entity. ndata);
    | entity: DTD.InternalEntity DO
      w. StartTag ("content");
      w. WriteQuoted (entity. entityValue^);
      w. EndTag ("content", FALSE);
      Boolean (w, "predefined", entity. predefined)
    END;
    
    w. EndTag ("entity", TRUE);
  END Entity;


PROCEDURE (b: Builder) StartDocument* (documentEntity: DTD.ExternalEntity);
  BEGIN
    b. w. StartAttr ("parser-protocol");
    b. w. AttrURI ("xml:base", b. w. baseURI, TRUE);
    b. w. EndAttr (FALSE);
    b. w. StartTag ("start-document");
    Entity (b. w, documentEntity);
    b. w. EndTag ("start-document", TRUE);
    (*IF b. writePosition THEN WritePos (b. writer, b) END*)
  END StartDocument;

PROCEDURE (b: Builder) EndDocument*;
  BEGIN
    (*IF b. writePosition THEN WritePos (b. writer, b) END;*)
    b. w. NewLine;
    b. w. StartTag ("end-document");
    b. w. EndTag ("end-document", TRUE);
    b. w. EndTag ("parser-protocol", TRUE);
    b. w. EndOfText
  END EndDocument;

PROCEDURE (b: Builder) StartElement* (name: DTD.String);
  BEGIN
(*    IF b. writePosition THEN WritePos (b. writer, b) END*)
  END StartElement;

PROCEDURE (b: Builder) ElementAttribute* (name: DTD.String;
                                          type: DTD.AttributeType;
                                          value: DTD.AttValue);
  BEGIN
  END ElementAttribute;

PROCEDURE (b: Builder) AttributesDone*;
  END AttributesDone;

PROCEDURE (b: Builder) EndElement* (name: DTD.String);
  END EndElement;

PROCEDURE (b: Builder) Notation* (name: DTD.String;
                                  publicIdentifier: DTD.String;
                                  systemIdentifier: DTD.String;
                                  baseURI: URI.URI);
  END Notation;

PROCEDURE (b: Builder) Characters* (VAR chars: DTD.StringVar;
                                    charsStart, charsEnd: DTD.CharPos;
                                    elementWhitespace: DTD.ElementWhitespaceType;
                                    predefinedEntity: BOOLEAN);
  END Characters;


PROCEDURE (b: Builder) ProcessingInstruction* (
    target: DTD.String;
    VAR content: DTD.StringVar; contentStart, contentEnd: DTD.CharPos;
    baseURI: URI.URI);
  BEGIN
    b. w. NewLine;
    b. w. StartTag ("processing-instruction");
    String (b. w, "target", target);
    b. w. StartTag ("content");
    b. w. WriteQuotedI (content, contentStart, contentEnd);
    b. w. EndTag ("content", FALSE);
    WriteURI (b. w, "base-uri", baseURI);
    b. w. EndTag ("processing-instruction", TRUE)
  END ProcessingInstruction;

PROCEDURE (b: Builder) Comment* (VAR chars: DTD.StringVar;
                                 start, end: DTD.CharPos);
  BEGIN
    b. w. NewLine;
    b. w. StartTag ("comment");
    b. w. WriteQuotedI (chars, start, end);
    b. w. EndTag ("comment", FALSE)
  END Comment;


PROCEDURE New* (outputChannel: Channel.Channel;
                codecFactory: Codec.Factory): Builder;
  VAR
    b: Builder;
  BEGIN
    NEW (b);
    B.Init (b);
    b. w := Writer.New (outputChannel, codecFactory, TRUE);
    b. w. WriteTextDecl ("1.0", "");
    b. w. SetBaseURI (File.GetCwd());
    RETURN b
  END New;

END XML:Builder:ParserProtocol.
