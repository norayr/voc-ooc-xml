(*      $Id: Builder.Mod,v 1.5 2000/07/17 07:41:00 mva Exp $   *)
MODULE XML:Builder [OOC_EXTENSIONS];
(*  Low-level builder interface to the XML parser.
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
  URI, XML:DTD, XML:Locator;


TYPE
  Builder* = POINTER TO BuilderDesc;
  BuilderDesc* = RECORD
  (**This interface is based on the W3C Working Draft @samp{XML
  Information Set}, dated December 20 1999.  It can be obtained at
  @url{http://www.w3.org/TR/1999/WD-xml-infoset-19991220}.
  Documentation below refers to sections of this document where
  appropriate.

  The low-level interface to the parser is governed by two requirements:
  It must make all core properties (and, as far as possible, all
  peripheral properties) of the XML Infoset available to the application,
  and the parser must be able to serve it without any overhead.  For
  this reason, the interface is not an instance of any of the
  established parser interfaces, like SAX, SAX2, or DOM.
  Specializations of @otype{Builder} provide these interfaces.

  The parser itself is @emph{not} namespace aware, even if this
  interface has the necessary hooks to provide namespace information.
  Namespaces are implemented by a special builder,
  @omodule{XML:Builder:Namespaces}, that translates between the parser
  and a namespace-aware application.
  
  The parser calls the type-bound procedures of the builder while
  traversing the document.  The string arguments passed to the procedures
  should not be modified by any concrete builder.
  
  @strong{Important}: The locator positions always refer to the top level of
  the processed file.  They do not follow internal entity references.  For
  example, if a start tag of an element is defined within an internal entity,
  then the locator position of @oproc{Builder.StartElement} is the position
  of the entity reference, instead of the position of the markup text.  *)
  END;


TYPE
  Attribute* = POINTER TO AttributeDesc;
  AttributeDesc = RECORD
    namespaceURI-: DTD.NamespaceURI; 
    localName-: DTD.String;
    attrDecl-: DTD.AttrDecl;
    value-: DTD.AttValue;
    specified-: BOOLEAN;
    pos-: Locator.Position;
  END;
  
TYPE
  AttributeList* = POINTER TO AttributeListDesc;
  AttributeArray = POINTER TO ARRAY OF Attribute;
  AttributeListDesc = RECORD
    len-: LONGINT;
    attr-: AttributeArray;
  END;


PROCEDURE (b: Builder) SetLocator* (locator: Locator.Locator);
  END SetLocator;

PROCEDURE (b: Builder) StartDocument* (documentEntity: DTD.ExternalEntity);
(**Marks the start of the document.  This method is called just before 
   parsing begins.  The base URI of the document can be obtained from 
   @oparam{documentEntity}, if it has been passed to @oproc{XML:Parser.New}.
   The locator is positioned at the very beginning of the file.  *)
  END StartDocument;

PROCEDURE (b: Builder) EndDocument*;
(**Called by the parser after it has processed the whole document.  Afterwards,
   none of the other builder methods will be called.  Note that unlike all the
   other event reporting methods, this method is even called if the document
   had a fatal error.  The locator is positioned at the very end of the
   file.  *)
  END EndDocument;

PROCEDURE (b: Builder) StartDTD*;
(**Called by the parser just before it begins parsing the document type
   declaration.  All comments and processing instruction events that are
   reported between @oproc{Builder.StartDTD} and @oproc{Builder.EndDTD}
   are part of the DTD.  Events from the internal DTD are reported before
   events of the external DTD.  The locator is positioned at the beginning of
   @samp{<!DOCTYPE}.  *)
  END StartDTD;

PROCEDURE (b: Builder) EndDTD* (externalDTD: DTD.ExternalEntity);
(**This method is called by the paser when is done parsing the document type
   declaration.  If the DTD had an external subset, the reference to the
   entity is passed in @oparam{externalDTD}.  The public and system identifier
   of the external subset are available through the entity item.  The locator
   is positioned after the closing @samp{>} of the DTD, and the external DTD 
   subset has been processed.  *)
  END EndDTD;



PROCEDURE (b: Builder) StartElement* (namespaceURI: DTD.NamespaceURI; 
                                      localName: DTD.String);
(**Called whenever a start tag is being parsed.  For a namespace aware parser,
   @oparam{namespaceURI} refers to the namespace URI of the element name.  If
   the name has no namespace part, the argument is @code{NIL}.
   @oparam{localName} is the element minus the namespace prefix and the colon.
   The locator is positioned at the beginning of the start tag's name.  *)
  END StartElement;

PROCEDURE (b: Builder) EndElement* (namespaceURI: DTD.NamespaceURI; 
                                    localName: DTD.String);
(**Called when an end tag is parsed.  See @oproc{Builder.StartElement} for
   a description of the arguments.  The locator is positioned at the beginning
   of the start tag's name, if an explicit end tag exists.  Otherwise, it is
   placed after the closing @samp{/>} of the empty element tag.  *)
  END EndElement;

PROCEDURE (b: Builder) Attribute* (namespaceURI: DTD.NamespaceURI; 
                                   localName: DTD.String;
                                   attrDecl: DTD.AttrDecl;
                                   value: DTD.AttValue;
                                   specified: BOOLEAN);
(**Called for every attribute (specified or defaulted) of the current element.
   For a namespace aware parser, @oparam{namespaceURI} refers to the namespace
   URI of the element name.  If the name has no namespace part, the argument is
   @code{NIL}.  @oparam{localName} is the element minus the namespace prefix
   and the colon.  If an attribute declaration for this attribute is known to
   the parser, it is passed in @oparam{attrDecl}.  Without a declaration, the
   application should treat the attribute as if it were of type 
   @oconst{DTD.attrCDATA}.  If the attribute is specified in the element's
   attribute list, instead of being defaulted from the attribute's declaration,
   @oparam{specified} is @code{TRUE}.
   
   The attribute's value is passed into the parameter @oparam{value}.  Call
   @oproc{DTD.AttValue.Flatten} to retrieve the normalized value of the 
   attribute.  You can also access the data structure @oparam{value}.
   The string values in the data structure are normalized 
   for @code{CDATA} values.  When reading @oparam{value} for
   non-@code{CDATA} attributes, you must collapse sequences of whitespace into
   a single space, and remove any whitespace from the beginning and the end
   of the attribute value.
   
   The locator is at the beginning of the attribute's name, if
   @oparam{specified} is @code{TRUE}.  For defaulted attributes, the locator
   is undefined.  *)
  END Attribute;
  
PROCEDURE (b: Builder) AttributesDone*;
(**Called when the all attributes of a start tag, specified or defaulted,
   have been reported to the application.  The locator is positioned at
   the closing @samp{>} of the start or empty element tag.  *)
  END AttributesDone;


PROCEDURE (b: Builder) SkippedEntity* (name: DTD.String; referent: DTD.Entity);
(**This method is called for every entity skipped by a non-validating parser,
   if it does not include external parsed entities.  @oparam{name} is the
   name of the skipped entity and @oparam{referent} its entity declaration,
   if this information is available.  The locator refers to the beginning of
   the named of the entity reference.  *)
  END SkippedEntity;


PROCEDURE (b: Builder) Characters* (
    VAR chars: DTD.StringVar; charsStart, charsEnd: DTD.CharPos;
    elementWhitespace: DTD.ElementWhitespaceType; predefinedEntity: BOOLEAN);
(**Called for non-markup characters that appear within the document element.
   See 2.7.  The locator refers to the first character.  *)
  END Characters;


PROCEDURE (b: Builder) StartCDATA*;
(**Called at the beginning of a CDATA section.  The locator is positioned
   at @samp{<![CDATA[}.  *)
  END StartCDATA;

PROCEDURE (b: Builder) EndCDATA*;
(**Called at the end of a CDATA section.  The locator refers to the position
   after the @samp{]]>}.  *)
  END EndCDATA;

PROCEDURE (b: Builder) StartEntity* (entity: DTD.Entity);
(**This method is called before the replacement text of a general entity
   is inspected in an element's content.  @oparam{entity} refers to the
   entity that is being expanded.  The locator points to the @samp{&} in front
   of the name of the entity reference.  *)
  END StartEntity;

PROCEDURE (b: Builder) EndEntity* (entity: DTD.Entity);
(**Called when parsing of the replacement text of @oparam{entity} is done.
  The locator points to the first character after the entity reference.  *)
  END EndEntity;



PROCEDURE (b: Builder) EntityDecl* (entity: DTD.Entity);
(**Called for declarations of general entities.  The document entity is passed
   to @oproc{Builder.StartDocument}, and the entity for the external DTD subset
   to @oproc{Builder.EndDTD}, of it exists.  The locator points to the 
   first character of the declared name.  *)
  END EntityDecl;

PROCEDURE (b: Builder) Notation* (notation: DTD.Notation);
(**Called for notation declarations, see 2.10.  The locator points to the 
   first character of the declared name.  *)
  END Notation;

PROCEDURE (b: Builder) ProcessingInstruction* (
                     target: DTD.String; VAR content: DTD.StringVar;
                     contentStart, contentEnd: DTD.CharPos; baseURI: URI.URI);
(**Called for processing instructions, see 2.4.  The locator is positioned
   at the @samp{<?}.  *)
  END ProcessingInstruction;

PROCEDURE (b: Builder) Comment* (VAR chars: DTD.StringVar;
                                 start, end: DTD.CharPos);
(**Called for comments, see 2.7.  The locator is positioned
   at the @samp{<!--}.  *)
  END Comment;



PROCEDURE Init* (b: Builder);
  BEGIN
  END Init;

PROCEDURE New*(): Builder;
(**Creates a new builder that does not do anything with the callbacks initiated
   by the parser.  *)
  VAR
    b: Builder;
  BEGIN
    NEW (b);
    Init (b);
    RETURN b
  END New;

(* Attribute Lists
   ------------------------------------------------------------------------ *)

PROCEDURE InitAttribute* (attr: Attribute;
                          namespaceURI: DTD.NamespaceURI; 
                          localName: DTD.String;
                          attrDecl: DTD.AttrDecl;
                          value: DTD.AttValue;
                          specified: BOOLEAN;
                          locator: Locator.Locator);
  BEGIN
    attr. namespaceURI := namespaceURI;
    attr. localName := localName;
    attr. attrDecl := attrDecl;
    attr. value := value;
    attr. specified := specified;
    locator. StorePosition (attr. pos)
  END InitAttribute;

PROCEDURE NewAttribute* (namespaceURI: DTD.NamespaceURI; 
                         localName: DTD.String;
                         attrDecl: DTD.AttrDecl;
                         value: DTD.AttValue;
                         specified: BOOLEAN;
                         locator: Locator.Locator): Attribute;
  VAR
    attr: Attribute;
  BEGIN
    NEW (attr);
    IF ~specified THEN
      locator := NIL
    END;
    InitAttribute (attr, namespaceURI, localName, attrDecl, value,
                   specified, locator);
    RETURN attr
  END NewAttribute;


PROCEDURE InitAttributeList* (attrList: AttributeList);
  BEGIN
    NEW (attrList. attr, 4);
    attrList. len := 0
  END InitAttributeList;

PROCEDURE NewAttributeList* (): AttributeList;
  VAR
    attrList: AttributeList;
  BEGIN
    NEW (attrList);
    InitAttributeList (attrList);
    RETURN attrList
  END NewAttributeList;

PROCEDURE (attrList: AttributeList) Clear*;
  VAR
    i: LONGINT;
  BEGIN
    FOR i := 0 TO attrList. len-1 DO
      attrList. attr[i] := NIL
    END;
    attrList. len := 0
  END Clear;

PROCEDURE (attrList: AttributeList) Append* (attr: Attribute);
  VAR
    new: AttributeArray;
    i: LONGINT;
  BEGIN
    IF (attrList. len = LEN (attrList. attr^)) THEN
      NEW (new, attrList. len*2);
      FOR i := 0 TO attrList. len-1 DO
        new[i] := attrList. attr[i]
      END;
      attrList. attr := new
    END;
    attrList. attr[attrList. len] := attr;
    INC (attrList. len)
  END Append;

END XML:Builder.
