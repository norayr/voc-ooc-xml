MODULE XML:Builder [OOC_EXTENSIONS];

IMPORT
  URI, DTD := XML:BuilderDTD;


(*

This interface is based on the W3C Working Draft "XML Information
Set", dated December 20 1999.  It can be obtained at
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


*)

TYPE
  Builder* = POINTER TO BuilderDesc;
  BuilderDesc* = RECORD
  END;


(* The parser calls these type-bound procedures of the builder while traversing
   the document.  The @otypr{String} arguments should not be modified by the
   concrete builder.  *)


PROCEDURE (b: Builder) StartDocument* (documentEntity: DTD.ExternalEntity);
(**Marks the start of the document.  This method is called just before 
   parsing begins.  The base URI of the document can be obtained from 
   @oparam{documentEntity}, if it has been passed to @oproc{XML:Parser.New}. *)
  END StartDocument;

PROCEDURE (b: Builder) EndDocument*;
(**Called by the parser after it has processed the whole document.  Afterwards,
   none of the other builder methods will be called.  Note that unlike all the
   other event reporting methods, this method is even called if the document
   had a fatal error.  *)
  END EndDocument;

PROCEDURE (b: Builder) StartDTD*;
(**Called by the parser just before it begins parsing the document type
   declaration.  All comments and processing instruction events that are
   reported between @oproc{Builder.StartDTD} and @oproc{Builder.EndDTD}
   are part of the DTD.  Events from the internal DTD are reported before
   events of the external DTD.  *)
  END StartDTD;

PROCEDURE (b: Builder) EndDTD* (externalDTD: DTD.ExternalEntity);
(**This method is called by the paser when is done parsing the document type
   declaration.  If the DTD had an external subset, the reference to the
   entity is passed in @oparam{externalDTD}.  The public and system identifier
   of the external subset are available through the entity item.  *)
  END EndDTD;



PROCEDURE (b: Builder) StartElement* (name: DTD.String);
  END StartElement;

PROCEDURE (b: Builder) EndElement* (name: DTD.String);
  END EndElement;

PROCEDURE (b: Builder) ElementAttribute* (name: DTD.String;
                                          type: DTD.AttributeType;
                                          value: DTD.AttValue);
  END ElementAttribute;

PROCEDURE (b: Builder) AttributesDone*;
  END AttributesDone;


PROCEDURE (b: Builder) Characters* (
  VAR chars: DTD.StringVar;
  charsStart, charsEnd: DTD.CharPos;
  elementWhitespace: DTD.ElementWhitespaceType;
  predefinedEntity: BOOLEAN);
(**Called for non-markup characters that appear within the document element.
   See 2.7.  *)
  END Characters;



PROCEDURE (b: Builder) Entity* (entityType: DTD.EntityType; name: DTD.String;
                                systemIdentifier, publicIdentifier: DTD.String;
                                baseURI: URI.URI; notation: DTD.Notation;
                                content, charSet: DTD.String;
                                standalone: DTD.StandaloneType);
(**Called for entity information items, see 2.9.  *)
  BEGIN
    
  END Entity;

PROCEDURE (b: Builder) Notation* (name: DTD.String;
                                  publicIdentifier: DTD.String;
                                  systemIdentifier: DTD.String;
                                  baseURI: URI.URI);
(**Called for notation declarations, see 2.10.  *)
  BEGIN
    
  END Notation;

PROCEDURE (b: Builder) ProcessingInstruction* (
    target: DTD.String;
    VAR content: DTD.StringVar; contentStart, contentEnd: DTD.CharPos;
    baseURI: URI.URI);
(**Called for processing instructions, see 2.4.  *)
  END ProcessingInstruction;

PROCEDURE (b: Builder) Comment* (VAR chars: DTD.StringVar;
                                 start, end: DTD.CharPos);
(**Called for comments, see 2.7.  *)
  END Comment;



PROCEDURE Init* (b: Builder);
  BEGIN
  END Init;

PROCEDURE New*(): Builder;
  VAR
    b: Builder;
  BEGIN
    NEW (b);
    Init (b);
    RETURN b
  END New;


END XML:Builder.
