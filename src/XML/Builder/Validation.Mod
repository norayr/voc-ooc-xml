(*      $Id: Namespaces.Mod,v 1.6 2001/03/16 21:39:40 mva Exp $   *)
MODULE XML:Builder:Validation;
(*  Adds validation services to the XML:Parser.
    Copyright (C) 2001  Michael van Acken

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
  Ascii, Msg, LongStrings, URI, 
  XML:Error, XML:DTD, XML:Locator, XML:Parser,
  B := XML:Builder;


TYPE
  Builder* = POINTER TO BuilderDesc;
  BuilderDesc = RECORD
  (**This builder adds validation services to the parser.  *)
    (B.BuilderDesc)
    parserLocator: Locator.Locator;
    delegateBuilder: B.Builder;
    errorListener: Locator.ErrorListener;
    dtd: DTD.Builder;
    notationNamespace: DTD.Namespace;
  END;


CONST  (* error codes *)
  attributeNotDeclared = 1;
  notName = 2;
  notNames = 3;
  noSuchGeneralEntity = 4;
  notAnUnparsedEntity = 5;
  multipleIDAttr = 6;
  multipleNOTATIONAttr = 7;
  emptyElemWithNOTATION = 8;
  notationMismatch = 9;
  notationAlreadyDeclared = 10;
  noSuchNotation = 11;
  notNmtoken = 12;
  notNmtokens = 13;
  notInEnumeration = 14;
  fixedDefaultMismatch = 15;
  invalidDefaultID = 16;
  invalidDefaultValue = 17;
  
VAR
  validationContext: Error.Context;


PROCEDURE (b: Builder) SetLocator* (locator: Locator.Locator);
  BEGIN
    b. parserLocator := locator;
    b. delegateBuilder. SetLocator (locator)
  END SetLocator;

PROCEDURE (b: Builder) SetErrorListener* (el: Locator.ErrorListener);
  BEGIN
    b. errorListener := el;
    b. delegateBuilder. SetErrorListener (el)
  END SetErrorListener;

PROCEDURE Err (b: Builder; code: Error.Code);
  VAR
    err: Error.Msg;
  BEGIN
    err := b. errorListener. Error (validationContext, code,
                                    FALSE, b. parserLocator^)
  END Err;

PROCEDURE ErrString (b: Builder; code: Error.Code;
                     name: ARRAY OF CHAR; value: DTD.String);
  VAR
    err: Error.Msg;
  BEGIN
    err := b. errorListener. Error (validationContext, code,
                                    FALSE, b. parserLocator^);
    err. SetLStringAttrib (name, Msg.GetLStringPtr (value^));
  END ErrString;

PROCEDURE ErrString2 (b: Builder; code: Error.Code;
                      name1: ARRAY OF CHAR; value1: DTD.String;
                      name2: ARRAY OF CHAR; value2: DTD.String);
  VAR
    err: Error.Msg;
  BEGIN
    err := b. errorListener. Error (validationContext, code,
                                    FALSE, b. parserLocator^);
    err. SetLStringAttrib (name1, Msg.GetLStringPtr (value1^));
    err. SetLStringAttrib (name2, Msg.GetLStringPtr (value2^));
  END ErrString2;

PROCEDURE ErrString3 (b: Builder; code: Error.Code;
                      name1: ARRAY OF CHAR; value1: DTD.String;
                      name2: ARRAY OF CHAR; value2: DTD.String;
                      name3: ARRAY OF CHAR; value3: DTD.String);
  VAR
    err: Error.Msg;
  BEGIN
    err := b. errorListener. Error (validationContext, code,
                                    FALSE, b. parserLocator^);
    err. SetLStringAttrib (name1, Msg.GetLStringPtr (value1^));
    err. SetLStringAttrib (name2, Msg.GetLStringPtr (value2^));
    err. SetLStringAttrib (name3, Msg.GetLStringPtr (value3^));
  END ErrString3;


  PROCEDURE IsS (ch: DTD.Char): BOOLEAN;
    BEGIN
      RETURN (ch = Ascii.sp) OR (ch = Ascii.ht) OR
             (ch = Ascii.cr) OR (ch = Ascii.lf)
    END IsS;
  
  PROCEDURE IsName (VAR string: ARRAY OF DTD.Char): BOOLEAN;
    VAR
      i: LONGINT;
    BEGIN
      IF ~Parser.IsNameChar0 (string[0]) THEN
        RETURN FALSE
      ELSE
        i := 1;
        WHILE (string[i] # 0X) DO
          IF ~Parser.IsNameChar (string[i]) THEN
            RETURN FALSE
          END;
          INC (i)
        END;
        RETURN TRUE
      END
    END IsName;
  
  PROCEDURE IsNames (VAR string: ARRAY OF DTD.Char): BOOLEAN;
    VAR
      i: LONGINT;
    BEGIN
      i := 0;
      LOOP
        IF Parser.IsNameChar0 (string[i]) THEN
          REPEAT
            INC (i)
          UNTIL ~Parser.IsNameChar (string[i]);
          IF (string[i] = 0X) THEN       (* end of string *)
            RETURN TRUE
          ELSIF IsS (string[i]) THEN
            INC (i)
          ELSE                           (* name includes invalid char *)
            EXIT
          END
        ELSE
          EXIT                           (* not looking at Name *)
        END
      END;
      RETURN FALSE
    END IsNames;
  
  PROCEDURE IsNmtoken (VAR string: ARRAY OF DTD.Char): BOOLEAN;
    VAR
      i: LONGINT;
    BEGIN
      IF ~Parser.IsNameChar (string[0]) THEN
        RETURN FALSE
      ELSE
        i := 1;
        WHILE (string[i] # 0X) DO
          IF ~Parser.IsNameChar (string[i]) THEN
            RETURN FALSE
          END;
          INC (i)
        END;
        RETURN TRUE
      END
    END IsNmtoken;
  
  PROCEDURE IsNmtokens (VAR string: ARRAY OF DTD.Char): BOOLEAN;
    VAR
      i: LONGINT;
    BEGIN
      i := 0;
      LOOP
        IF Parser.IsNameChar (string[i]) THEN
          REPEAT
            INC (i)
          UNTIL ~Parser.IsNameChar (string[i]);
          IF (string[i] = 0X) THEN       (* end of string *)
            RETURN TRUE
          ELSIF IsS (string[i]) THEN
            INC (i)
          ELSE                           (* name includes invalid char *)
            EXIT
          END
        ELSE
          EXIT                           (* not looking at Name *)
        END
      END;
      RETURN FALSE
    END IsNmtokens;
    

PROCEDURE (b: Builder) StartDocument* (documentEntity: DTD.ExternalEntity);
  BEGIN
    b. delegateBuilder. StartDocument (documentEntity)
  END StartDocument;

PROCEDURE (b: Builder) EndDocument*;
  BEGIN
    b. delegateBuilder. EndDocument
  END EndDocument;

PROCEDURE (b: Builder) StartDTD* (dtdBuilder: DTD.Builder);
  BEGIN
    b. dtd := dtdBuilder;
    b. delegateBuilder. StartDTD (dtdBuilder)
  END StartDTD;

PROCEDURE (b: Builder) EndDTD* (externalDTD: DTD.ExternalEntity;
                                allDeclarationsProcessed: BOOLEAN);
  VAR
    decl: DTD.Declaration;
    elemDecl: DTD.ElementDecl;
    nameNode: DTD.NameNode;
    
  PROCEDURE CheckAttributes (list: DTD.Declaration);
    VAR
      decl: DTD.Declaration;
      attrDecl: DTD.AttrDecl;
      default: DTD.String;
      match: BOOLEAN;
    BEGIN
      decl := list;
      WHILE (decl # NIL) DO
        attrDecl := decl(DTD.AttrDecl);
        
        IF (attrDecl. default >= DTD.attrDefault) THEN
          IF (attrDecl. type = DTD.attrID) THEN
            (* an ID attribute must be #IMPLIED or #REQUIRED *)
            ErrString2 (b, invalidDefaultID, "element", attrDecl. elementName,
                        "attribute", attrDecl. name)
          ELSE
            (* the default value of an attribute must match the syntactical 
               contraints of the attribute type *)
            default := attrDecl. defaultValue. Flatten (attrDecl);
            CASE attrDecl. type OF
            | DTD.attrIDREF, DTD.attrENTITY:
              match := IsName (default^)
            | DTD.attrIDREFS, DTD.attrENTITIES:
              match := IsNames (default^)
            | DTD.attrNMTOKEN:
              match := IsNmtoken (default^)
            | DTD.attrNMTOKENS:
              match := IsNmtokens (default^)
            | DTD.attrENUMERATED:
              match := IsNmtoken (default^) &
                       attrDecl. enumeration. Matches (default^)
            | DTD.attrNOTATION:
              match := IsName (default^) &
                       attrDecl. enumeration. Matches (default^)
            | DTD.attrCDATA:
              match := TRUE
            END;
            IF ~match THEN
              ErrString2 (b, invalidDefaultValue,
                          "element", attrDecl. elementName,
                          "attribute", attrDecl. name)
            END
          END
        END;
        
        (* all names in a attribute notation declaration must be declared *)
        IF (attrDecl. type = DTD.attrNOTATION) THEN
          nameNode := attrDecl. enumeration. nameList;
          WHILE (nameNode # NIL) DO
            IF (b. notationNamespace. Get (nameNode. name) = NIL) THEN
              ErrString3 (b, noSuchNotation, 
                          "name", nameNode. name,
                          "element", attrDecl. elementName,
                          "attribute", attrDecl. name)
            END;
            nameNode := nameNode. next
          END
        END;
    
        decl := decl. next
      END
    END CheckAttributes;
  
  BEGIN
    CheckAttributes (b. dtd. attributeList);
    
    decl := b. dtd. elementNamespace. declList;
    WHILE (decl # NIL) DO
      elemDecl := decl(DTD.ElementDecl);
      IF (elemDecl. idAttr = DTD.undefAttr) THEN
        ErrString (b, multipleIDAttr, "element", elemDecl. name)
      END;
      
      IF (elemDecl. notationAttr = DTD.undefAttr) THEN
        ErrString (b, multipleNOTATIONAttr, "element", elemDecl. name)
      ELSIF (elemDecl. notationAttr # NIL) & elemDecl. IsEmpty() THEN
(*        ErrString2 (b, emptyElemWithNOTATION,
                    "element", elemDecl. name,
                    "attribute", elemDecl. notationAttr. name) ... *)
      END;
      
      CheckAttributes (elemDecl. attrNamespace. declList);
      decl := decl. next
    END;
    
    b. delegateBuilder. EndDTD (externalDTD, allDeclarationsProcessed)
  END EndDTD;



PROCEDURE (b: Builder) StartElement* (namespaceDecl: DTD.NamespaceDeclaration; 
                                      localName: DTD.String);
  BEGIN
    b. delegateBuilder. StartElement (namespaceDecl, localName);
    
(*    decl := d. dtd. elementNamespace. Get (localName);
    IF (decl = NIL) THEN
      (* ... *)
    END;*)
  END StartElement;

PROCEDURE (b: Builder) EndElement* (namespaceDecl: DTD.NamespaceDeclaration; 
                                    localName: DTD.String);
  BEGIN
    b. delegateBuilder. EndElement (namespaceDecl, localName)
  END EndElement;

PROCEDURE (b: Builder) Attribute* (namespaceDecl: DTD.NamespaceDeclaration; 
                                   localName: DTD.String;
                                   attrDecl: DTD.AttrDecl;
                                   value: DTD.AttValue;
                                   specified: BOOLEAN);
  VAR
    string, substr, default: DTD.String;
    decl: DTD.Declaration;
    i, start: LONGINT;
  
  BEGIN
    IF (attrDecl = NIL) THEN
      Err (b, attributeNotDeclared)
    ELSE
      CASE attrDecl. type OF
      | DTD.attrENTITY:
        (* check if an unparsed entity of the given name exists; we don't need
           to check the attribute syntax, because all declared entities have
           a valid name *)
        string := value. Flatten (attrDecl);
        IF ~IsName (string^) THEN
          ErrString (b, notName, "name", string)
        ELSE
          decl := b. dtd. geNamespace. Get (string);
          IF (decl = NIL) THEN
            ErrString (b, noSuchGeneralEntity, "name", string)
          ELSIF (decl(DTD.Entity). type # DTD.entityUnparsed) THEN
            ErrString (b, notAnUnparsedEntity, "name", string)
          END
        END
      
      | DTD.attrENTITIES:
        string := value. Flatten (attrDecl);
        IF ~IsNames (string^) THEN
          Err (b, notNames)
        ELSE
          i := 0;
          LOOP
            start := i;
            WHILE (string[i] > Ascii.sp) DO
              INC (i)
            END;
            
            NEW (substr, i-start+1);
            LongStrings.Extract (string^, SHORT (start), SHORT (i-start), substr^);
            decl := b. dtd. geNamespace. Get (substr);
            IF (decl = NIL) THEN
              ErrString (b, noSuchGeneralEntity, "name", substr)
            ELSIF (decl(DTD.Entity). type # DTD.entityUnparsed) THEN
              ErrString (b, notAnUnparsedEntity, "name", substr)
            END;
            
            IF (string[i] = 0X) THEN
              EXIT
            ELSE
              INC (i)
            END
          END
        END
      
      | DTD.attrNOTATION:
        string := value. Flatten (attrDecl);
        IF ~attrDecl. enumeration. Matches (string^) THEN
          ErrString (b, notationMismatch, "name", string)
        END
        
      | DTD.attrNMTOKEN:
        string := value. Flatten (attrDecl);
        IF ~IsNmtoken (string^) THEN
          ErrString (b, notNmtoken, "name", string)
        END
      
      | DTD.attrNMTOKENS:
        string := value. Flatten (attrDecl);
        IF ~IsNmtokens (string^) THEN
          Err (b, notNmtokens)
        END
      
      | DTD.attrENUMERATED:
        string := value. Flatten (attrDecl);
        IF ~IsNmtoken (string^) THEN
          Err (b, notNmtoken)
        ELSIF ~attrDecl. enumeration. Matches (string^) THEN
          ErrString (b, notInEnumeration, "name", string)
        END
      
      ELSE  (* no validity constraints apply to the other attribute types *)
      END;
      
      IF (attrDecl. default = DTD.attrFixed) THEN
        default := attrDecl. defaultValue. Flatten (attrDecl);
        string := value. Flatten (attrDecl);
        IF (string^ # default^) THEN
          Err (b, fixedDefaultMismatch)
        END
      END
    END;
    
    b. delegateBuilder. Attribute (namespaceDecl, localName, attrDecl,
                                   value, specified)
  END Attribute;
  
PROCEDURE (b: Builder) NamespaceDeclaration* (namespaceDecl: DTD.NamespaceDeclaration);
  BEGIN
    ASSERT (FALSE)
  END NamespaceDeclaration;

PROCEDURE (b: Builder) AttributesDone*;
  BEGIN
    b. delegateBuilder. AttributesDone
  END AttributesDone;


PROCEDURE (b: Builder) SkippedEntity* (name: DTD.String; referent: DTD.Entity);
  BEGIN
    b. delegateBuilder. SkippedEntity (name, referent)
  END SkippedEntity;


PROCEDURE (b: Builder) Characters* (VAR chars: DTD.StringVar;
                                    charsStart, charsEnd: DTD.CharPos;
                                    elementWhitespace: DTD.ElementWhitespaceType);
  BEGIN
    b. delegateBuilder. Characters (chars, charsStart, charsEnd,
                                    elementWhitespace)
  END Characters;


PROCEDURE (b: Builder) StartCDATA*;
  BEGIN
    b. delegateBuilder. StartCDATA
  END StartCDATA;

PROCEDURE (b: Builder) EndCDATA*;
  BEGIN
    b. delegateBuilder. EndCDATA
  END EndCDATA;

PROCEDURE (b: Builder) StartEntity* (entity: DTD.Entity);
  BEGIN
    b. delegateBuilder. StartEntity (entity)
  END StartEntity;

PROCEDURE (b: Builder) EndEntity* (entity: DTD.Entity);
  BEGIN
    b. delegateBuilder. EndEntity (entity)
  END EndEntity;



PROCEDURE (b: Builder) EntityDecl* (entity: DTD.Entity);
  BEGIN
    b. delegateBuilder. EntityDecl (entity)
  END EntityDecl;

PROCEDURE (b: Builder) Notation* (notation: DTD.Notation);
  BEGIN
    IF ~b. notationNamespace. Add (notation) THEN
      ErrString (b, notationAlreadyDeclared, "name", notation. name)
    END;
    b. delegateBuilder. Notation (notation)
  END Notation;

PROCEDURE (b: Builder) ProcessingInstruction* (
                     target: DTD.String; VAR content: DTD.StringVar;
                     contentStart, contentEnd: DTD.CharPos; baseURI: URI.URI);
  BEGIN
    b. delegateBuilder. ProcessingInstruction (target, content,
      contentStart, contentEnd, baseURI)
  END ProcessingInstruction;

PROCEDURE (b: Builder) Comment* (VAR chars: DTD.StringVar;
                                 start, end: DTD.CharPos);
  BEGIN
    b. delegateBuilder. Comment (chars, start, end)
  END Comment;



PROCEDURE Init* (b: Builder; delegateBuilder: B.Builder);
  BEGIN
    b. delegateBuilder := delegateBuilder;
    b. parserLocator := NIL;
    b. errorListener := NIL;
    b. dtd := NIL;
    b. notationNamespace := DTD.NewNamespace();
  END Init;

PROCEDURE New* (delegateBuilder: B.Builder): Builder;
(**Creates a new builder that performs namespaces transformations on the
   parser callbacks.  Except for splitting qualified names into namespace URI
   and local name, all callbacks are passed on to @oparam{delegateBuilder}
   unchanged.  *)
  VAR
    b: Builder;
  BEGIN
    NEW (b);
    Init (b, delegateBuilder);
    RETURN b
  END New;


PROCEDURE SetErrorMessages;
  VAR
    i: INTEGER;
    t: ARRAY 128 OF CHAR;
  BEGIN
    FOR i := 0 TO 999 DO
      CASE i OF
      | attributeNotDeclared:
        t := "Attribute has not been declared"
      | notName:
        t := "Attribute value `${name}' does not match the Name production"
      | notNames:
        t := "Attribute value does not match the Names production"
      | noSuchGeneralEntity:
        t := "`${name}' refers to an unknown general entity"
      | notAnUnparsedEntity:
        t := "`${name}' refers to a parsed entity"
      | multipleIDAttr:
        t := "Element `${element}' has more than one ID attribute"
      | multipleNOTATIONAttr:
        t := "Element `${element}' has more than one NOTATION attribute"
      | emptyElemWithNOTATION:
        t := "Empty element `${element}' has a NOTATION attribute `${attribute}'"
      | notationMismatch:
        t := "`${name}' does not match any of the names of the notation declaration"
      | notationAlreadyDeclared:
        t := "Notation `${name}' is already declared"
      | noSuchNotation:
        t := "Attribute declaration `${element}/@${attribute}' refers to undeclared notation `${name}'"
      | notNmtoken:
        t := "Attribute value `${name}' does not match the Nmtoken production"
      | notNmtokens:
        t := "Attribute value does not match the Nmtokens production"
      | notInEnumeration:
        t := "`${name}' does not match any of the names of the enumeration declaration"
      | fixedDefaultMismatch:
        t := "Attribute value does not match the fixed default value"
      | invalidDefaultID:
        t := "Attribute declaration `${element}/@${attribute}' of type ID must not have a default value"
      | invalidDefaultValue:
        t := "Invalid default value in attribute declaration `${element}/@${attribute}'"
      ELSE
        t := ""
      END;
      IF (t # "") THEN
        validationContext. SetString (i, t)
      END
    END
  END SetErrorMessages;

BEGIN
  validationContext := Error.NewContext ("XML:Builder:Validation");
  SetErrorMessages
END XML:Builder:Validation.
