(* 	$Id: DTD.Mod,v 1.5 2000/08/20 13:00:30 mva Exp $	 *)
MODULE XML:DTD [OOC_EXTENSIONS];
(*  Implements the internal representation of a document DTD.
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


(**This module implements the mechanisms to store, maintain, and query the data
   gathered from an XML document's DTD.  An instance of @otype{Builder} is
   created by the parser @otype{*XML:Parser.Parser} to hold a document's DTD
   information.  *)

IMPORT
  LongStrings, URI, XML:UnicodeBuffer;


TYPE
  Char* = UnicodeBuffer.Char;
  (**Character type used to store names and character data from an XML
     document.  *)
  String* = UnicodeBuffer.CharArray;
  (**A pointer to an array of @otype{Char}.  *)
  StringVar* = ARRAY OF Char;
  (**An open array with @otype{Char} as element type.  *)
  CharPos* = UnicodeBuffer.CharPos;
  (**This integer type is used to store the position of a character in the
     input buffer or in a string.  *)
  
TYPE
  StandaloneType* = SHORTINT;
  (**Used to store information about the @samp{standalone} of an XML
     declaration.  One of @oconst{standaloneYes}, @oconst{standaloneNo},
     @oconst{standaloneNotPresent}, or @oconst{standaloneNotApplicable}.  *)

CONST
  standaloneYes* = 0;
  standaloneNo* = 1;
  standaloneNotPresent* = 2;
  standaloneNotApplicable* = 3;
  
TYPE
  Namespace* = POINTER TO NamespaceDesc;
  Declaration* = POINTER TO DeclarationDesc;
  Builder* = POINTER TO BuilderDesc;
  BuilderDesc* = RECORD
    geNamespace-: Namespace;
    (**Namespace with general entity declarations.  *)
    peNamespace-: Namespace;
    (**Namespace with parameter entity declarations.  *)
    elementNamespace-: Namespace;
    (**Namespace with element declarations.  *)
    
    attributeList, attributeTail: Declaration;
  END;


(* Declarations and Namespace
   ------------------------------------------------------------------------ *)

TYPE
  DeclarationDesc = RECORD [ABSTRACT]
    next-: Declaration;
    (**Next declaration in namespace.  *)
    name-: String;
    (**Name of the declared object.  *)
  END;

TYPE
  NamespaceDesc = RECORD
    declList-: Declaration;
    (**Refers to the first element of the list of declarations.  The other
       declarations can be reached through @ofield{Declaration.next}.  *)
    
  END;


(* Attribute and Entity Value
   ------------------------------------------------------------------------ *)

TYPE
  Fragment* = POINTER TO FragmentDesc;
  FragmentDesc = RECORD
  (**Abstract base type for @otype{Characters} and @otype{EntityRef}.  *)
    next-: Fragment;
    (**Refers to the next fragment in the list @ofield{AttValue.fragmentList}.  *)
  END;

TYPE
  Characters* = POINTER TO CharactersDesc;
  CharactersDesc = RECORD
  (**A sequence of characters appearing in an attribute value.  *)
    (FragmentDesc)
    source-: String;
    (**The array slice @samp{@ofield{source}[@ofield{sourceStart},
       @ofield{sourceEnd}[} holds the fragment's character data.  *)
    sourceStart-, sourceEnd-: CharPos;
  END;

TYPE
  EntityRef* = POINTER TO EntityRefDesc;
  Entity* = POINTER TO EntityDesc;
  EntityRefDesc = RECORD
  (**A general entity reference appearing in an attribute value.  *)
  (FragmentDesc)
    name-: String;
    (**The name of the reference.  *)
    entity*: Entity;
    (**After the name has been resolved successfully, this field refers to the
       internal entity declaration that is being referenced.  *)
  END;

TYPE
  AttValue* = POINTER TO AttValueDesc;
  AttValueDesc = RECORD
  (**An attribute value is stored as a list of character data and general
     entity references.  That is, the internal structure of the value string is
     not resolved at first.  Character data is stored as
     @otype{Characters}, and entity references as @otype{EntityRef}.  *)
    fragmentList-, fragmentTail: Fragment;
    (**The head of the list of attribute value fragments.  For an empty
       attribute, this is @code{NIL}.  *)
  END;


(* Attribute Declaration
   ------------------------------------------------------------------------ *)

TYPE
  NameNode* = POINTER TO NameNodeDesc;
  NameNodeDesc = RECORD
  (**A name in an @otype{Enumeration}.  *)
    next-: NameNode;
    name-: String;
  END;

TYPE
  Enumeration* = POINTER TO EnumerationDesc;
  EnumerationDesc = RECORD
  (**Used to store an attribute value enumeration.  *)
    nameList-, nameTail: NameNode;
    (**A list of names.  Used for both @oconst{attrENUMERATED} and
       @oconst{attrNOTATION}.  @ofield{NameNode.next} refers to the next
       element in the list.  *)
  END;


TYPE
  AttributeType* = SHORTINT;
  (**Indicates the type of an attribute.  See @oconst{attrCDATA} et al.  *)

CONST
  attrID* = 0;
  attrIDREF* = 1;
  attrIDREFS* = 2;
  attrENTITY* = 3;
  attrENTITIES* = 4;
  attrNMTOKEN* = 5;
  attrNMTOKENS* = 6;
  attrNOTATION* = 7;
  attrENUMERATED* = 8;
  attrCDATA* = 9;

TYPE
  DefaultType* = SHORTINT;
  (**Indicates the defaulting mode of an attribute declaration.  One of
     @oconst{attrRequired}, @oconst{attrImplied}, @oconst{attrDefault}, or
     @oconst{attrFixed}.  *)
  
CONST
  attrRequired* = 0;
  attrImplied* = 1;
  attrDefault* = 2;
  attrFixed* = 3;

TYPE
  AttrDecl* = POINTER TO AttrDeclDesc;
  AttrDeclDesc = RECORD
  (**An attribute declaration from a DTD.  *)
  (DeclarationDesc)
    elementName-: String;
    type-: AttributeType;
    enumeration-: Enumeration;
    default-: DefaultType;
    defaultValue-: AttValue;
  END;


(* Entities
   ------------------------------------------------------------------------ *)

TYPE
  EntityType* = SHORTINT;
  (**Values of this type indicate the type of an entity.  See
     @oconst{entityInternalGeneral} et al.  *)
  
CONST
  entityInternalGeneral* = 0;
  (**Internal general entity.  *)
  entityInternalParameter* = 1;
  (**Internal parameter entity.  Such entities do not appear in the XML
     infoset.  *)
  entityExternalGeneral* = 2;
  (**External general entity.  *)
  entityExternalParameter* = 3;
  (**External parameter entity.  Such entities do not appear in the XML
     infoset.  *)
  entityUnparsed* = 4;
  (**Unparsed external general entity.  *)
  entityDocument* = 5;
  (**Document entity.  It represents the top-level entity of a document,
     the one that holds the internal DTD subset and the root element.  *)
  entityExternalDTDSubset* = 6;
  (**Entity representing the external DTD subset.  *)

TYPE
  EntityDesc = RECORD [ABSTRACT]
  (**Abstract base type for both internal and external entities.  *)
    (DeclarationDesc)
    type-: EntityType;
    (**This field indicates the kind of entity.  It distinguishes between
       general/parameter, internal/external, and parsed/unparsed.  *)
    entityValue-: String;
    (**This is either the value of an internal entity, or the internalized
       version of an external entity.  For an internal entity, this field
       is never @code{NIL}.  This string is not terminated with an @code{0X},
       use @oproc{Entity.LengthValue} to determine its length.  *)

    expanding*: BOOLEAN;
    (**This field is used internally by the parser.  While expanding the 
       entity, it is set to @code{TRUE}.  *)
    attValue*: AttValue;
    (**This field is used internally by the parser.  If an entity is ever
       expanded within an attribute value, this field holds the expanded
       text before non-CDATA normalization.  *)
  END;

TYPE
  InternalEntity* = POINTER TO InternalEntityDesc;
  InternalEntityDesc = RECORD
    (EntityDesc)
  END;

TYPE
  ExternalEntity* = POINTER TO ExternalEntityDesc;
  ExternalEntityDesc = RECORD
    (EntityDesc)
    public-: String;
    (**Public identifier of the external entity.  May be @code{NIL}.  *)
    system-: String;
    (**System identifier of the external entity.  This field is never
       @code{NIL}.  *)
    ndata-: String;
    (**For a parsed entity declaration, this field is @code{NIL}.  For an
       unparsed entity, it holds the name of the @code{NDATA}.  *)
    baseURI-: URI.URI;
    (**The base URI of the external entity.  For a document entity, this 
       is the URI passed to @oproc{*XML:Parser.NewChannel}, and therefore may
       be @code{NIL}.  For other entities, it is either derived from the
       public or system identifier, and always present.  *)
    
    version-: String;
    (**The version string from the XML or text declaration.  @code{NIL}, if
       the version is omitted.  *)
    encoding-: String;
    (**The encoding string from the XML or text declaration.  @code{NIL}, if
       no encoding is given.  *)
    standalone-: StandaloneType;
    (**The standalone declaration.  Only applicable to the document entity.  *)
  END;


(* Notations
   ------------------------------------------------------------------------ *)

TYPE
  Notation* = POINTER TO NotationDesc;
  NotationDesc = RECORD
  (**This class represent notation declarations  *)
    (DeclarationDesc)
    public-:String;
    (**Public identifier.  May be @code{NIL}.  *)
    system-: String;
    (**System identifier.  May be @code{NIL}.  *)
    baseURI-: URI.URI;
    (**The base URI of the external entity.  For a document entity, this 
       is the URI passed to @oproc{*XML:Parser.NewChannel}, and therefore may
       be @code{NIL}.  For other entities, it is either derived from the
       public or system identifier, and always present.  *)
  END;


(* Element Declaration and Element Content
   ------------------------------------------------------------------------ *)

TYPE
  CPModeType* = SHORTINT;
  
CONST
  cpOnce* = 0;
  cpOptional* = 1;
  cpRepeat0* = 2;
  cpRepeat1* = 3;
  
TYPE
  CP* = POINTER TO CPDesc;
  CPDesc = RECORD
    cpMode-: SHORTINT;                   (* once, "?", "*", or "+" *)
    next-: CP;                           (* next in sequence or alternative *)
  END;
  
  ChoiceCP* = POINTER TO ChoiceCPDesc;
  ChoiceCPDesc = RECORD
    (CPDesc)
    list-: CP;
  END;
  SeqCP* = POINTER TO SeqCPDesc;
  SeqCPDesc = RECORD
    (CPDesc)
    list-: CP;
  END;
  NameCP* = POINTER TO NameCPDesc;
  NameCPDesc = RECORD
    (CPDesc)
    name-: String;
  END;
  

TYPE
  ElementDecl* = POINTER TO ElementDeclDesc;
  ElementDeclDesc = RECORD
  (**Instances of this class represent element declarations.  *)
    (DeclarationDesc)
    contentModel-: CP;
    (**The content model of the element.  *)
    attrNamespace-: Namespace;
    (**The attribute namespace of the element.  *)
  END;

(* ------------------------------------------------------------------------ *)

TYPE
  ElementWhitespaceType* = SHORTINT;

CONST
  elementWhitespaceYes* = 0;
  elementWhitespaceNo* = 1;
  elementWhitespaceUnknown* = 2;


TYPE
  NamespaceDeclaration* = POINTER TO NamespaceDeclarationDesc;
  StringURI* = POINTER TO ARRAY OF CHAR;
  NamespaceDeclarationDesc = RECORD
    (**This class describes notation declaration items of the XML Information
       Set.  *)
    prefix-: String;
    (**The prefix being declared.  Syntactically, this is the part of the
       attribute name following the @code{xmlns:} prefix.  If the attribute
       name is simply @code{xmlns}, this field is @code{NIL}.  *)
    uri-: StringURI;
    (**The absolute URI (plus optional fragment identifier) of the namespace
        being declared.  It may be @code{NIL} if the attribute name
        is @code{xmlns}.  *)
  END;


(* Declarations and Namespace
   ------------------------------------------------------------------------ *)

PROCEDURE InitDeclaration (decl: Declaration; name: String);
  BEGIN
    decl. next := NIL;
    decl. name := name;
  END InitDeclaration;

PROCEDURE InitNamespace (ns: Namespace);
  BEGIN
    ns. declList := NIL
  END InitNamespace;

PROCEDURE NewNamespace*(): Namespace;
  VAR
    ns: Namespace;
  BEGIN
    NEW (ns);
    InitNamespace (ns);
    RETURN ns
  END NewNamespace;

PROCEDURE (ns: Namespace) Add* (decl: Declaration): BOOLEAN;
(**Adds the declaration @oparam{decl} to the namespace @oparam{ns}.  Nothing is
   done if the namespace already contains a declaration of the same name.  In
   this case, the value @code{FALSE} is returned.  If the declaration was
   added to the namespace, then the result is @code{TRUE}.  *)
   
  PROCEDURE RecAdd (VAR list: Declaration): BOOLEAN;
    BEGIN
      IF (list = NIL) THEN
        list := decl;
        RETURN TRUE
      ELSIF (list. name^ # decl. name^) THEN
        RETURN RecAdd (list. next)
      ELSE
        RETURN FALSE
      END
    END RecAdd;
  
  BEGIN
    decl. next := NIL;
    RETURN RecAdd (ns. declList)
  END Add;

PROCEDURE (ns: Namespace) Get* (name: String): Declaration;
  VAR
    ptr: Declaration;
  BEGIN
    ptr := ns. declList;
    WHILE (ptr # NIL) & (ptr. name^ # name^) DO
      ptr := ptr. next
    END;
    RETURN ptr
  END Get;


(* Attribute Value
   ------------------------------------------------------------------------ *)

PROCEDURE InitFragment* (f: Fragment);
  BEGIN
    f. next := NIL;
  END InitFragment;


PROCEDURE InitCharacters* (chars: Characters;
                           source: String; start, end: CharPos);
  BEGIN
    InitFragment (chars);
    chars. source := source;
    chars. sourceStart := start;
    chars. sourceEnd := end
  END InitCharacters;

PROCEDURE (b: Builder) NewCharacters* (source: String; start, end: CharPos;
                                       createCopy: BOOLEAN): Characters;
  VAR
    chars: Characters;
    len, i: CharPos;
    copy: String;
  BEGIN
    NEW (chars);
    IF createCopy THEN
      len := end-start;
      NEW (copy, len);
      FOR i := 0 TO len-1 DO
        copy[i] := source[start+i]
      END;
      InitCharacters (chars, copy, 0, len)
    ELSE
      InitCharacters (chars, source, start, end)
    END;
    RETURN chars
  END NewCharacters;


PROCEDURE InitEntityRef* (entRef: EntityRef; name: String; entity: Entity);
  BEGIN
    InitFragment (entRef);
    entRef. name := name;
    entRef. entity := entity
  END InitEntityRef;

PROCEDURE (b: Builder) NewEntityRef* (name: String;
                                      entity: Entity): EntityRef;
  VAR
    entRef: EntityRef;
  BEGIN
    NEW (entRef);
    InitEntityRef (entRef, name, entity);
    RETURN entRef
  END NewEntityRef;


PROCEDURE InitAttValue* (attValue: AttValue);
  BEGIN
    attValue. fragmentList := NIL;
    attValue. fragmentTail := NIL;
  END InitAttValue;

PROCEDURE (b: Builder) NewAttValue* (): AttValue;
  VAR
    attValue: AttValue;
  BEGIN
    NEW (attValue);
    InitAttValue (attValue);
    RETURN attValue
  END NewAttValue;

PROCEDURE (attValue: AttValue) Clear*;
  BEGIN
    attValue. fragmentList := NIL;
    attValue. fragmentTail := NIL
  END Clear;

PROCEDURE (attValue: AttValue) Append* (fragment: Fragment);
  BEGIN
    fragment. next := NIL;
    IF (attValue. fragmentList = NIL) THEN
      attValue. fragmentList := fragment
    ELSE
      attValue. fragmentTail. next := fragment
    END;
    attValue. fragmentTail := fragment
  END Append;

PROCEDURE (attValue: AttValue) Length* (): LONGINT;
(**Calculates the length of the attribute value, as if it were of type
   CDATA.  *)
  VAR
    fragment: Fragment;
    len: LONGINT;
  BEGIN
    len := 0;
    fragment := attValue. fragmentList;
    WHILE (fragment # NIL) DO
      WITH fragment: EntityRef DO
        IF (fragment. entity # NIL) THEN
          INC (len, fragment. entity. attValue. Length())
        ELSE
          INC (len, LongStrings.Length (fragment. name^)+2)
        END
      | fragment: Characters DO
        INC (len, fragment. sourceEnd-fragment. sourceStart)
      END;
      fragment := fragment. next
    END;
    RETURN len
  END Length;

PROCEDURE (attValue: AttValue) Flatten* (attrDecl: AttrDecl): String;
  VAR
    str: String;
    len, pos: LONGINT;
    skipSpace: BOOLEAN;
    normalizeWhitespace: BOOLEAN;
  
  PROCEDURE Append (attValue: AttValue);
    VAR
      f: Fragment;
    
    PROCEDURE Copy (source[NO_COPY]: StringVar; start, end: CharPos);
      VAR
        i: LONGINT;
      BEGIN
        i := start;
        WHILE (i # end) DO
          IF (source[i] = " ") THEN
            IF ~skipSpace THEN
              str[pos] := " ";
              INC (pos);
              skipSpace := normalizeWhitespace
            END;
          ELSE
            skipSpace := FALSE;
            str[pos] := source[i];
            INC (pos)
          END;
          INC (i)
        END
      END Copy;
    
    BEGIN
      f := attValue. fragmentList;
      WHILE (f # NIL) DO
        WITH f: EntityRef DO
          IF (f. entity # NIL) THEN
            Append (f. entity. attValue)
          ELSE
            Copy ("&", 0, 1);
            Copy (f. name^, 0, LongStrings.Length (f. name^));
            Copy (";", 0, 1)
          END
        | f: Characters DO
          Copy (f. source^, f. sourceStart, f. sourceEnd)
        END;
        f := f. next
      END
    END Append;
  
  BEGIN
    normalizeWhitespace := (attrDecl # NIL) & (attrDecl. type # attrCDATA);
    len := attValue. Length();
    NEW (str, len+2);
    (* the second additional character is used for entity value padding
       by the XML parser *)
    pos := 0;
    skipSpace := normalizeWhitespace;
    Append (attValue);
    IF normalizeWhitespace & (pos # 0) & (str[pos-1] = " ") THEN
      DEC (pos)
    END;
    str[pos] := 0X;
    RETURN str
  END Flatten;


(* Attribute Declaration
   ------------------------------------------------------------------------ *)

PROCEDURE (b: Builder) NewEnumeration*(): Enumeration;
  VAR
    enum: Enumeration;
  BEGIN
    NEW (enum);
    enum. nameList := NIL;
    enum. nameTail := NIL;
    RETURN enum
  END NewEnumeration;

PROCEDURE (enum: Enumeration) Append* (name: String);
  VAR
    node: NameNode;
  BEGIN
    NEW (node);
    node. next := NIL;
    node. name := name;
    
    IF (enum. nameList = NIL) THEN
      enum. nameList := node
    ELSE
      enum. nameTail := node
    END;
    enum. nameTail := node
  END Append;


PROCEDURE InitAttrDecl* (attrDecl: AttrDecl; elementName, name: String;
                         type: AttributeType; enum: Enumeration;
                         default: DefaultType; defaultValue: AttValue);
  BEGIN
    InitDeclaration (attrDecl, name);
    attrDecl. elementName := elementName;
    attrDecl. type := type;
    attrDecl. enumeration := enum;
    attrDecl. default := default;
    attrDecl. defaultValue := defaultValue
  END InitAttrDecl;

PROCEDURE (b: Builder) NewAttrDecl* (elementName, name: String;
                        type: AttributeType; enum: Enumeration;
                        default: DefaultType; defaultValue: AttValue): AttrDecl;
  VAR
    attrDecl: AttrDecl;
  BEGIN
    NEW (attrDecl);
    InitAttrDecl (attrDecl, elementName, name, type, enum,
                  default, defaultValue);
    RETURN attrDecl
  END NewAttrDecl;

PROCEDURE (b: Builder) AddAttribute* (attrDecl: AttrDecl);
  BEGIN
    IF (b. attributeList = NIL) THEN
      b. attributeList := attrDecl
    ELSE
      b. attributeTail. next := attrDecl
    END;
    b. attributeTail := attrDecl
  END AddAttribute;

PROCEDURE (b: Builder) AttachAttributes*;
  VAR
    attrDecl: AttrDecl;
    elemDecl: Declaration;
    dummy: BOOLEAN;
  BEGIN
    WHILE (b. attributeList # NIL) DO
      attrDecl := b. attributeList(AttrDecl);
      b. attributeList := attrDecl. next;
      
      elemDecl := b. elementNamespace. Get (attrDecl. elementName);
      IF (elemDecl # NIL) THEN
        dummy := elemDecl(ElementDecl). attrNamespace. Add (attrDecl)
      END
    END;
    b. attributeTail := NIL
  END AttachAttributes;


(* Entities
   ------------------------------------------------------------------------ *)

PROCEDURE InitEntity (ent: Entity; name: String; type: EntityType;
                      entityValue: String);
  BEGIN
    InitDeclaration (ent, name);
    ent. type := type;
    ent. entityValue := entityValue;
    ent. expanding := FALSE;
    ent. attValue := NIL
  END InitEntity;

PROCEDURE (entity: Entity) SetEntityValue* (entityValue: String);
  BEGIN
    entity. entityValue := entityValue
  END SetEntityValue;

PROCEDURE (entity: Entity) LengthValue*(): LONGINT;
(**Returns the length of the entity's value.  *)
  BEGIN
    RETURN LEN (entity. entityValue^)-2
  END LengthValue;


PROCEDURE InitInternalEntity (ent: InternalEntity;
                              name: String; type: EntityType;
                              entityValue: String);
  BEGIN
    InitEntity (ent, name, type, entityValue);
  END InitInternalEntity;

PROCEDURE (b: Builder) NewInternalEntity* (name: String; type: EntityType;
                                          entityValue: String): InternalEntity;
  VAR
    ent: InternalEntity;
  BEGIN
    NEW (ent);
    InitInternalEntity (ent, name, type, entityValue);
    RETURN ent
  END NewInternalEntity;

PROCEDURE (b: Builder) IsValidEntityDecl* (name, entityValue: String): BOOLEAN;
(**Tests if the internal entity declaration is legal.  If the name
   @oparam{name} refers to a predefined entity, but @oparam{entityValue} is no
   legal replacement text for the entity, then this function returns
   @code{FALSE}.  Otherwise, it returns @code{TRUE}.  *)
  BEGIN
    IF (name^ = "lt") THEN
      RETURN (entityValue^ = "&#60;")
    ELSIF (name^ = "amp") THEN
      RETURN (entityValue^ = "&#38;")
    ELSIF (name^ = "gt") THEN
      RETURN (entityValue^ = ">") OR (entityValue^ = "&#62;")
    ELSIF (name^ = "apos") THEN
      RETURN (entityValue^ = "'") OR (entityValue^ = "&#39;")
    ELSIF (name^ = "quot") THEN
      RETURN (entityValue^ = '"') OR (entityValue^ = "&#34;")
    ELSE
      RETURN TRUE
    END
  END IsValidEntityDecl;

PROCEDURE InitExternalEntity (ent: ExternalEntity;
                              name: String; type: EntityType;
                              public, system, ndata: String;
                              baseURI: URI.URI);
  BEGIN
    InitEntity (ent, name, type, NIL);
    ent. public := public;
    ent. system := system;
    ent. baseURI := baseURI;
    ent. ndata := ndata;
    ent. version := NIL;
    ent. encoding := NIL;
    ent. standalone := standaloneNotApplicable
  END InitExternalEntity;

PROCEDURE (b: Builder) NewExternalEntity* (name: String; type: EntityType;
                                           public, system, ndata: String;
                                           baseURI: URI.URI): ExternalEntity;
  VAR
    ent: ExternalEntity;
  BEGIN
    NEW (ent);
    InitExternalEntity (ent, name, type, public, system, ndata, baseURI);
    RETURN ent
  END NewExternalEntity;

PROCEDURE (entity: ExternalEntity) SetVersion* (version: String);
  BEGIN
    entity. version := version
  END SetVersion;

PROCEDURE (entity: ExternalEntity) SetEncoding* (encoding: String);
  BEGIN
    entity. encoding := encoding
  END SetEncoding;

PROCEDURE (entity: ExternalEntity) SetStandalone* (standalone: StandaloneType);
  BEGIN
    entity. standalone := standalone
  END SetStandalone;

PROCEDURE (b: Builder) NewExternalDTD* (public, system: String;
                                        baseURI: URI.URI): ExternalEntity;
  VAR
    entity: ExternalEntity;
  BEGIN
    NEW (entity);
    InitExternalEntity (entity, NIL, entityExternalDTDSubset,
                        public, system, NIL, baseURI);
    RETURN entity
  END NewExternalDTD;

PROCEDURE (b: Builder) NewDocumentEntity* (baseURI: URI.URI): ExternalEntity;
  VAR
    entity: ExternalEntity;
  BEGIN
    NEW (entity);
    InitExternalEntity (entity, NIL, entityDocument,
                        NIL, NIL, NIL, baseURI);
    entity. standalone := standaloneNotPresent;
    RETURN entity
  END NewDocumentEntity;


(* Notations
   ------------------------------------------------------------------------ *)

PROCEDURE InitNotation (notation: Notation; name, public, system: String; baseURI: URI.URI);
  BEGIN
    InitDeclaration (notation, name);
    notation. public := public;
    notation. system := system;
    notation. baseURI := baseURI
  END InitNotation;

PROCEDURE (b: Builder) NewNotation* (name, public, system: String; baseURI: URI.URI): Notation;
  VAR
    notation: Notation;
  BEGIN
    NEW (notation);
    InitNotation (notation, name, public, system, baseURI);
    RETURN notation
  END NewNotation;


(* Element Declaration and Element Content
   ------------------------------------------------------------------------ *)

PROCEDURE InitCP (cp: CP; cpMode: CPModeType);
  BEGIN
    cp. cpMode := cpMode;
    cp. next := NIL
  END InitCP;

PROCEDURE (cp: CP) SetNext* (next: CP);
  BEGIN
    cp. next := next
  END SetNext;

PROCEDURE (cp: CP) SetMode* (cpMode: SHORTINT);
  BEGIN
    cp. cpMode := cpMode
  END SetMode;


PROCEDURE InitChoiceCP* (choiceCP: ChoiceCP; cpMode: CPModeType; list: CP);
  BEGIN
    InitCP (choiceCP, cpMode);
    choiceCP. list := list
  END InitChoiceCP;

PROCEDURE (b: Builder) NewChoiceCP* (cpMode: CPModeType; list: CP): ChoiceCP;
  VAR
    choiceCP: ChoiceCP;
  BEGIN
    NEW (choiceCP);
    InitChoiceCP (choiceCP, cpMode, list);
    RETURN choiceCP
  END NewChoiceCP;

PROCEDURE InitSeqCP* (seqCP: SeqCP; cpMode: CPModeType; list: CP);
  BEGIN
    InitCP (seqCP, cpMode);
    seqCP. list := list
  END InitSeqCP;

PROCEDURE (b: Builder) NewSeqCP* (cpMode: CPModeType; list: CP): SeqCP;
  VAR
    seqCP: SeqCP;
  BEGIN
    NEW (seqCP);
    InitSeqCP (seqCP, cpMode, list);
    RETURN seqCP
  END NewSeqCP;

PROCEDURE InitNameCP* (nameCP: NameCP; cpMode: CPModeType; name: String);
  BEGIN
    InitCP (nameCP, cpMode);
    nameCP. name := name
  END InitNameCP;

PROCEDURE (b: Builder) NewNameCP* (cpMode: CPModeType; name: String): NameCP;
  VAR
    nameCP: NameCP;
  BEGIN
    NEW (nameCP);
    InitNameCP (nameCP, cpMode, name);
    RETURN nameCP
  END NewNameCP;


PROCEDURE InitElementDecl (elemDecl: ElementDecl; name: String; contentModel: CP; attrNamespace: Namespace);
  BEGIN
    InitDeclaration (elemDecl, name);
    elemDecl. contentModel := contentModel;
    elemDecl. attrNamespace := attrNamespace
  END InitElementDecl;

PROCEDURE (b: Builder) NewElementDecl* (name: String; contentModel: CP): ElementDecl;
  VAR
    elemDecl: ElementDecl;
  BEGIN
    NEW (elemDecl);
    InitElementDecl (elemDecl, name, contentModel, NewNamespace());
    RETURN elemDecl
  END NewElementDecl;


(* Namespace Declaration
   ------------------------------------------------------------------------ *)

PROCEDURE InitNamespaceDeclaration (namespaceDecl: NamespaceDeclaration;
                                    prefix: String; uri: StringURI);
  BEGIN
    namespaceDecl. prefix := prefix;
    namespaceDecl. uri := uri
  END InitNamespaceDeclaration;

PROCEDURE NewNamespaceDeclaration* (prefix: String; uri: StringURI): NamespaceDeclaration;
  VAR
    namespaceDecl: NamespaceDeclaration;
  BEGIN
    NEW (namespaceDecl);
    InitNamespaceDeclaration (namespaceDecl, prefix, uri);
    RETURN namespaceDecl
  END NewNamespaceDeclaration;


(* ------------------------------------------------------------------------ *)

PROCEDURE GetString* (VAR string: ARRAY OF Char; start, end: LONGINT): String;
  VAR
    s: String;
    i: LONGINT;
  BEGIN
    NEW (s, end-start+1);
    FOR i := 0 TO end-start-1 DO
      s[i] := string[start+i]
    END;
    s[end-start] := 0X;
    RETURN s
  END GetString;

PROCEDURE GetStringURI* (VAR string: ARRAY OF CHAR; start, end: LONGINT): StringURI;
  VAR
    s: StringURI;
    i: LONGINT;
  BEGIN
    NEW (s, end-start+1);
    FOR i := 0 TO end-start-1 DO
      s[i] := string[start+i]
    END;
    s[end-start] := 0X;
    RETURN s
  END GetStringURI;

PROCEDURE Init* (b: Builder);
(**Initializes the DTD builder.  Also registers the predefined general entities
   @samp{lt}, @samp{gt}, @samp{amp}, @samp{apos}, and @samp{quot}.  *)
  PROCEDURE PredefEntity (name, replacement: ARRAY OF LONGCHAR);
    VAR
      nameString, replString: String;
      entity: Entity;
      dummy: BOOLEAN;
    BEGIN
      NEW (nameString, LongStrings.Length (name)+1);
      COPY (name, nameString^);
      NEW (replString, LongStrings.Length (replacement)+2);
      COPY (replacement, replString^);
      replString[LEN (replString^)-2] := UnicodeBuffer.markerEOD;
      
      entity := b. NewInternalEntity (nameString, entityInternalGeneral, 
                                      replString);
      dummy := b. geNamespace. Add (entity)
    END PredefEntity;
  
  BEGIN
    b. geNamespace := NewNamespace();
    b. peNamespace := NewNamespace();
    b. elementNamespace := NewNamespace();
    
    b. attributeList := NIL;
    b. attributeTail := NIL;
    
    PredefEntity ("lt", "&#60;");
    PredefEntity ("gt", ">");
    PredefEntity ("amp", "&#38;");
    PredefEntity ("apos", "'");
    PredefEntity ("quot", '"')
  END Init;

PROCEDURE New*(): Builder;
  VAR
    b: Builder;
  BEGIN
    NEW (b);
    Init (b);
    RETURN b
  END New;

END XML:DTD.
