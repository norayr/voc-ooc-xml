(*      $Id: ParserProtocol.Mod,v 1.6 2000/07/23 17:36:34 mva Exp $   *)
MODULE XML:Builder:ParserProtocol [OOC_EXTENSIONS];
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
  Channel, IntStr, URI, URI:Scheme:File,
  Codec := XML:UnicodeCodec, XML:DTD, B := XML:Builder,
  XML:Writer, XML:Locator;


TYPE
  Builder* = POINTER TO BuilderDesc;
  BuilderDesc = RECORD
    (B.BuilderDesc)
    w-: Writer.Writer;
    locator-: Locator.Locator;
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

PROCEDURE Int (w: Writer.Writer; name: ARRAY OF LONGCHAR; value: LONGINT);
  VAR
    val: ARRAY 32 OF CHAR;
  BEGIN
    w. StartTag (name);
    IntStr.IntToStr (value, val);
    w. WriteLatin1 (val);
    w. EndTag (name, FALSE)
  END Int;

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

PROCEDURE WritePos (b: Builder);
  BEGIN
    b. w. StartTag ("locator");
    IF (b. locator. entity. baseURI # NIL) THEN
      Int (b. w, "char-index", b. locator. charIndex);
      Int (b. w, "line", b. locator. line);
      Int (b. w, "column", b. locator. column);
      WriteURI (b. w, "base-uri", b. locator. entity. baseURI)
    END;
    b. w. EndTag ("locator", TRUE)
  END WritePos;


PROCEDURE Notation (b: Builder; notation: DTD.Notation; writePos: BOOLEAN);
  VAR
    w: Writer.Writer;
  BEGIN
    IF (notation # NIL) THEN
      w := b. w;
      w. StartTag ("notation");
      String (w, "name", notation. name);
      String (w, "system-identifier", notation. system);
      String (w, "public-identifier", notation. public);
      WriteURI (w, "base-uri", notation. baseURI);
      IF writePos THEN
        WritePos (b)
      END;
      w. EndTag ("notation", TRUE);
    END
  END Notation;

PROCEDURE Entity (b: Builder; entity: DTD.Entity; writePos: BOOLEAN);
  VAR
    w: Writer.Writer;
  BEGIN
    w := b. w;
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
      w. WriteQuotedI (entity. entityValue^, 0, entity. LengthValue());
      w. EndTag ("content", FALSE);
      Boolean (w, "predefined", entity. predefined)
    END;
    
    IF writePos THEN
      WritePos (b)
    END;
    w. EndTag ("entity", TRUE);
  END Entity;

PROCEDURE NamespaceDeclaration (w: Writer.Writer; namespaceDecl: DTD.NamespaceDeclaration);
  BEGIN
    w. StartTag ("namespace-declaration");
    String (w, "prefix", namespaceDecl. prefix);
    IF (namespaceDecl. uri # NIL) THEN
      w. StartTag ("namespace-uri");
      w. WriteLatin1 (namespaceDecl. uri^);
      w. EndTag ("namespace-uri", FALSE)
    END;
    w. EndTag ("namespace-declaration", TRUE)
  END NamespaceDeclaration;


PROCEDURE (b: Builder) SetLocator* (locator: Locator.Locator);
  BEGIN
    b. locator := locator
  END SetLocator;

PROCEDURE (b: Builder) StartDocument* (documentEntity: DTD.ExternalEntity);
  BEGIN
    b. w. StartAttr ("parser-protocol");
    (*b. w. AttrURI ("xml:base", b. w. baseURI, TRUE);
        this breaks the simple minded diff tests, so I leave it out for now *)
    b. w. EndAttr (FALSE);
    b. w. StartTag ("start-document");
    Entity (b, documentEntity, FALSE);
    WritePos (b);
    b. w. EndTag ("start-document", TRUE);
    (*IF b. writePosition THEN WritePos (b. writer, b) END*)
  END StartDocument;

PROCEDURE (b: Builder) EndDocument*;
  BEGIN
    (*IF b. writePosition THEN WritePos (b. writer, b) END;*)
    b. w. NewLine;
    b. w. StartTag ("end-document");
    WritePos (b);
    b. w. EndTag ("end-document", TRUE);
    b. w. EndTag ("parser-protocol", TRUE);
    b. w. EndOfText
  END EndDocument;


PROCEDURE (b: Builder) StartDTD*;
  BEGIN
    b. w. NewLine;
    b. w. StartTag ("start-dtd");
    WritePos (b);
    b. w. EndTag ("start-dtd", TRUE);
  END StartDTD;

PROCEDURE (b: Builder) EndDTD* (externalDTD: DTD.ExternalEntity);
  BEGIN
    b. w. NewLine;
    b. w. StartTag ("end-dtd");
    IF (externalDTD # NIL) THEN
      Entity (b, externalDTD, FALSE)
    END;
    WritePos (b);
    b. w. EndTag ("end-dtd", TRUE);
  END EndDTD;



PROCEDURE (b: Builder) StartElement* (namespaceDecl: DTD.NamespaceDeclaration; 
                                      localName: DTD.String);
  BEGIN
    b. w. NewLine;
    b. w. StartTag ("start-element");
    IF (namespaceDecl # NIL) THEN
      NamespaceDeclaration (b. w, namespaceDecl)
    END;
    String (b. w, "local-name", localName);
    WritePos (b);
    b. w. EndTag ("start-element", TRUE);
  END StartElement;

PROCEDURE (b: Builder) Attribute* (namespaceDecl: DTD.NamespaceDeclaration; 
                                   localName: DTD.String;
                                   attrDecl: DTD.AttrDecl;
                                   value: DTD.AttValue;
                                   specified: BOOLEAN);
  BEGIN
    b. w. NewLine;
    b. w. StartTag ("attribute");
    IF (namespaceDecl # NIL) THEN
      NamespaceDeclaration (b. w, namespaceDecl)
    END;
    String (b. w, "local-name", localName);
    IF (attrDecl # NIL) THEN
      b. w. StartTag ("attr-type");
      CASE attrDecl. type OF
      | DTD.attrID: b. w. WriteLatin1 ("ID")
      | DTD.attrIDREF: b. w. WriteLatin1 ("IDREF")
      | DTD.attrIDREFS: b. w. WriteLatin1 ("IDREFS")
      | DTD.attrENTITY: b. w. WriteLatin1 ("ENTITY")
      | DTD.attrENTITIES: b. w. WriteLatin1 ("ENTITIES")
      | DTD.attrNMTOKEN: b. w. WriteLatin1 ("NMTOKEN")
      | DTD.attrNMTOKENS: b. w. WriteLatin1 ("NMTOKENS")
      | DTD.attrNOTATION: b. w. WriteLatin1 ("NOTATION")
      | DTD.attrENUMERATED: b. w. WriteLatin1 ("ENUMERATED")
      | DTD.attrCDATA: b. w. WriteLatin1 ("CDATA")
      END;
      b. w. EndTag ("attr-type", FALSE);
      b. w. StartTag ("default-type");
      CASE attrDecl. default OF
      | DTD.attrRequired: b. w. WriteLatin1 ("#REQUIRED")
      | DTD.attrImplied: b. w. WriteLatin1 ("#IMPLIED")
      | DTD.attrDefault: b. w. WriteLatin1 ("#DEFAULT")
      | DTD.attrFixed: b. w. WriteLatin1 ("#FIXED")
      END;
      b. w. EndTag ("default-type", FALSE)
    END;
    String (b. w, "value", value. Flatten (attrDecl));
    Boolean (b. w, "specified", specified);
    IF specified THEN
      WritePos (b)
    END;
    b. w. EndTag ("attribute", TRUE);
  END Attribute;

PROCEDURE (b: Builder) NamespaceDeclaration* (namespaceDecl: DTD.NamespaceDeclaration);
  BEGIN
    b. w. NewLine;
    NamespaceDeclaration (b. w, namespaceDecl)
  END NamespaceDeclaration;

PROCEDURE (b: Builder) AttributesDone*;
  BEGIN
    b. w. NewLine;
    b. w. StartTag ("attributes-done");
    WritePos (b);
    b. w. EndTag ("attributes-done", TRUE)
  END AttributesDone;

PROCEDURE (b: Builder) SkippedEntity* (name: DTD.String; referent: DTD.Entity);
  BEGIN
    b. w. NewLine;
    b. w. StartTag ("skipped-entity");
    String (b. w, "name", name);
    IF (referent # NIL) THEN
      Entity (b, referent, FALSE)
    END;
    WritePos (b);
    b. w. EndTag ("skipped-entity", TRUE);
  END SkippedEntity;

PROCEDURE (b: Builder) EndElement* (namespaceDecl: DTD.NamespaceDeclaration; 
                                    localName: DTD.String);
  BEGIN
    b. w. NewLine;
    b. w. StartTag ("end-element");
    IF (namespaceDecl # NIL) THEN
      NamespaceDeclaration (b. w, namespaceDecl)
    END;
    String (b. w, "local-name", localName);
    WritePos (b);
    b. w. EndTag ("end-element", TRUE);
  END EndElement;

PROCEDURE (b: Builder) EntityDecl* (entity: DTD.Entity);
  BEGIN
    b. w. NewLine;
    Entity (b, entity, TRUE)
  END EntityDecl;

PROCEDURE (b: Builder) Notation* (notation: DTD.Notation);
  BEGIN
    b. w. NewLine;
    Notation (b, notation, TRUE)
  END Notation;

PROCEDURE (b: Builder) Characters* (VAR chars: DTD.StringVar;
                                    charsStart, charsEnd: DTD.CharPos;
                                    elementWhitespace: DTD.ElementWhitespaceType;
                                    predefinedEntity: BOOLEAN);
  BEGIN
    b. w. NewLine;
    b. w. StartTag ("characters");
    b. w. StartTag ("chars");
    b. w. WriteQuotedI (chars, charsStart, charsEnd);
    b. w. EndTag ("chars", FALSE);
    b. w. StartTag ("element-whitespace");
    CASE elementWhitespace OF
    | DTD.elementWhitespaceYes: b. w. WriteLatin1 ("yes")
    | DTD.elementWhitespaceNo: b. w. WriteLatin1 ("no")
    | DTD.elementWhitespaceUnknown: b. w. WriteLatin1 ("unknown")
    END;
    b. w. EndTag ("element-whitespace", FALSE);
    Boolean (b. w, "predefined-entity", predefinedEntity);
    WritePos (b);
    b. w. EndTag ("characters", TRUE);
  END Characters;

PROCEDURE (b: Builder) StartCDATA*;
  BEGIN
    b. w. NewLine;
    b. w. StartTag ("start-cdata");
    WritePos (b);
    b. w. EndTag ("start-cdata", TRUE);
  END StartCDATA;

PROCEDURE (b: Builder) EndCDATA*;
  BEGIN
    b. w. NewLine;
    b. w. StartTag ("end-cdata");
    WritePos (b);
    b. w. EndTag ("end-cdata", TRUE);
  END EndCDATA;

PROCEDURE (b: Builder) StartEntity* (entity: DTD.Entity);
  BEGIN
    b. w. NewLine;
    b. w. StartAttr ("start-entity");
    b. w. AttrString ("name", entity. name^);
    b. w. EndAttr (FALSE);
    WritePos (b);
    b. w. EndTag ("start-entity", TRUE);
  END StartEntity;

PROCEDURE (b: Builder) EndEntity* (entity: DTD.Entity);
  BEGIN
    b. w. NewLine;
    b. w. StartAttr ("end-entity");
    b. w. AttrString ("name", entity. name^);
    b. w. EndAttr (FALSE);
    WritePos (b);
    b. w. EndTag ("end-entity", TRUE);
  END EndEntity;


PROCEDURE (b: Builder) ProcessingInstruction* (
                      target: DTD.String; VAR content: DTD.StringVar;
                      contentStart, contentEnd: DTD.CharPos; baseURI: URI.URI);
  BEGIN
    b. w. NewLine;
    b. w. StartTag ("processing-instruction");
    String (b. w, "target", target);
    b. w. StartTag ("content");
    b. w. WriteQuotedI (content, contentStart, contentEnd);
    b. w. EndTag ("content", FALSE);
    WriteURI (b. w, "base-uri", baseURI);
    WritePos (b);
    b. w. EndTag ("processing-instruction", TRUE)
  END ProcessingInstruction;

PROCEDURE (b: Builder) Comment* (VAR chars: DTD.StringVar;
                                 start, end: DTD.CharPos);
  BEGIN
    b. w. NewLine;
    b. w. StartTag ("comment");
    b. w. StartTag ("content");
    b. w. WriteQuotedI (chars, start, end);
    b. w. EndTag ("content", FALSE);
    WritePos (b);
    b. w. EndTag ("comment", TRUE)
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
