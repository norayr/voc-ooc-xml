MODULE XML:Parser;

IMPORT
  Log, Out, Ascii, Channel, Msg, Strings, LongStrings, URI, URI:Scheme:File,
  URIParser := URI:Parser,
  Codec := XML:UnicodeCodec, XML:UnicodeCodec:UTF8,
  Buffer := XML:UnicodeBuffer, XML:Error, DTD := XML:BuilderDTD, XML:Builder;
(* should import UTF8 and UTF16 ... FIXME *)

TYPE
  Position = RECORD
    char: Buffer.CharPos;
    line: Buffer.CharPos;
    column: Buffer.CharPos;
  END;

TYPE
  PEInfo = RECORD
    oldChars: DTD.String;
    oldCPos,
    oldCurrLine,
    oldCurrLinePos,
    oldCurrLineTab: Buffer.CharPos;
    entity: DTD.Entity;
    in: Buffer.Input;
  END;

TYPE
  Parser* = POINTER TO ParserDesc;
  NameList = POINTER TO ARRAY OF DTD.String;
  PEInfoList = POINTER TO ARRAY OF PEInfo;
  ParserDesc = RECORD
    errList-: Error.List;
       
    in: Buffer.Input;
    initialBuilder, builder: Builder.Builder;
    (* When parsing starts, both @ofield{initialBuilder} and @ofield{builder}
       refer to the builder that was passed to @oproc{New}.  The first fatal
       error changes @ofield{builder} to an instance of the empty builder
       @otype{Builder.Builder}.  *)
    dtd: DTD.Builder;
    
    documentEntity: DTD.ExternalEntity;
    (* this is a reference to the document entity; the base URI that was passed
       to the constructor @oproc{New} is stored in this entity *)
    fileEntity: DTD.ExternalEntity;
    (* the field @ofield{fileEntity} is a reference to the entity (document,
       external DTD subset, or external entity) that is currently parsed; it
       is never @code{NIL} *)
       
    followExternalRef*: BOOLEAN;
    (* if TRUE, then the parser should try to follow external references;
       if this fails, it is an error *)
    processDeclarations: BOOLEAN;
    (* if FALSE, then entity declarations and attribute declarations must no
       be processed; this field starts out TRUE, and is set to FALSE after
       a reference to a parameter entity that is not read, but only if 
       "standalone" is not "yes".  *)
    
    inDocumentElement: BOOLEAN;
    (* if TRUE, then the parser is within the document element *)
    inDTD: BOOLEAN;
    (* if TRUE, then the parser is within the document type declaration *)
    inExternalSubset: BOOLEAN;
    (* if TRUE, then the parser is within the external subset of the
       document type declaration *)
    inExternalEntity: BOOLEAN;
    (* if TRUE, then the parser is within an external parameter entity; note
       that the external subset is not considered to be an external parameter
       entity *)

    currEntityValue: DTD.AttValue;
    (* when parsing an entity value, this list is used to collect the text
       fragments from the value itself and any included parameter entity
       references *)
    
    nameList: NameList;
    lenNameList: LONGINT;
    (* these two fields hold a list of all attribute names that are part of
       a start tag or empty tag; using this list, the set of unsatisfied 
       default attributes is determined for the tag *)
    
    peStack: PEInfoList;
    lenPEStack: LONGINT;
    (* stack of currently being expanded entity declarations; maintained by
       PushEntity/PopEntity *)
  END;

CONST
  tabWidth = 8;

CONST
  initNameList = 8;
  incrNameList = 8;
  initPEStack = 4;
  incrPEStack = 4;
  
CONST
  stringSystemLiteral = 1;
  stringPubidLiteral = 2;
  stringVersion = 3;
  stringEncoding = 4;
  stringStandalone = 5;

VAR
  suplPubidChar: ARRAY 32 OF Buffer.Char;
  noName: DTD.String;


CONST  (* error codes *)
  (* lexical errors *)
  invalidChar = 1;
  junkAfterDocument = 2;
  invalidCloseCDATA = 3;
  invalidCommentDashDash = 4;
  commentNotClosed = 5;
  stringNotClosed = 6;
  piNotClosed = 7;
  cdataNotClosed = 8;
  expectedWhitespace = 9;
  expectedName = 10;
  expectedNmtoken = 11;
  expectedChar = 12;
  lAngleInAttValue = 13;
  expectedDigit10 = 14;
  expectedDigit16 = 15;
  expectedString = 16;
  invalidCharRef = 17;
  expectedEOS = 18;
  ignoreNotClosed = 19;
  invalidPubidChar = 20;
  invalidEncNameChar = 21;
  invalidVersionNumChar = 22;
  expectedNonEmptyString = 23;
  expectedYesNo = 24;
  xmlDeclNotAtBeginning = 25;
  reservedPITarget = 26;
  invalidCharacterEncodings = 27;
  junkAfterExtSubset = 28;
  unknownCharacterEncoding = 29;
  
  (* DTD errors *)
  expectedMarkupDecl = 105;
  expectedContentSpec = 106;
  expectedAttType = 107;
  expectedAttValue = 108;
  expectedEntityValue = 109;
  expectedCP = 110;
  expectedVersion = 111;
  expectedExternalID = 112;
  expectedConditional = 113;
  expectedPIEnd = 114;
  nonMarkupDeclPERef = 115;
  expectedEncodingDecl = 116;
  invalidLangCode = 117;
  malformedURI = 118;
  
  (* document errors *)
  expectedElement = 208;
  expectedEndTag = 209;
  noSuchGeneralEntity = 210;
  noSuchParameterEntity = 211;
  multipleAttrName = 212;
  recursiveGeneralEntity = 213;
  
  (* reference errors *)
  unbalancedPERef = 300;
  unbalancedGERef = 301;  (* unused...? *)
  invalidGEReplacement = 302;
  accessError = 303;
  referenceToUnparsed = 304;
  externalRefInAtttribute = 305;
  
VAR
  parserContext: Error.Context;



PROCEDURE IsCharUCS4 (ch: LONGINT): BOOLEAN;
  BEGIN
    RETURN (020H <= ch) & (ch <= 0D7FFH) OR
           (ch = 9H) OR (ch = 0AH) OR (ch = 0DH) OR
           (0E000H <= ch) & (ch <= 0FFFDH) OR
           (10000H <= ch) & (ch <= 10FFFFH)
  END IsCharUCS4;

PROCEDURE IsDigit (ch: Buffer.Char): BOOLEAN;
  BEGIN
    IF (ch < 100X) THEN
      RETURN (30X <= ch) & (ch <= 39X)
    ELSE
      CASE ch OF
      | 0660X .. 0669X, 06F0X .. 06F9X, 0966X .. 096FX, 09E6X .. 09EFX,
        0A66X .. 0A6FX, 0AE6X .. 0AEFX, 0B66X .. 0B6FX, 0BE7X .. 0BEFX,
        0C66X .. 0C6FX, 0CE6X .. 0CEFX, 0D66X .. 0D6FX, 0E50X .. 0E59X, 
        0ED0X .. 0ED9X, 0F20X .. 0F29X:
        RETURN TRUE
      ELSE
        RETURN FALSE
      END
    END
  END IsDigit;

PROCEDURE IsBaseChar (ch: Buffer.Char): BOOLEAN;
  BEGIN
    IF (ch < 100X) THEN
      CASE ch OF
      | 0041X .. 005AX, 0061X .. 007AX, 00C0X .. 00D6X, 00D8X .. 00F6X, 
        00F8X .. 00FFX: 
        RETURN TRUE
      ELSE
        RETURN FALSE
      END
    ELSIF (ch < 400X) THEN
      CASE ch OF
      | 0100X .. 0131X, 0134X .. 013EX, 0141X .. 0148X, 014AX .. 017EX, 
        0180X .. 01C3X, 01CDX .. 01F0X, 01F4X .. 01F5X, 01FAX .. 0217X, 
        0250X .. 02A8X, 02BBX .. 02C1X, 0386X, 0388X .. 038AX, 038CX, 
        038EX .. 03A1X, 03A3X .. 03CEX, 03D0X .. 03D6X, 03DAX, 03DCX, 03DEX, 
        03E0X, 03E2X .. 03F3X:
        RETURN TRUE
      ELSE
        RETURN FALSE
      END
    ELSIF (ch < 800X) THEN
      CASE ch OF
      | 0401X .. 040CX, 040EX .. 044FX, 0451X .. 045CX, 045EX .. 0481X, 
        0490X .. 04C4X, 04C7X .. 04C8X, 04CBX .. 04CCX, 04D0X .. 04EBX, 
        04EEX .. 04F5X, 04F8X .. 04F9X, 0531X .. 0556X, 0559X, 0561X .. 0586X, 
        05D0X .. 05EAX, 05F0X .. 05F2X, 0621X .. 063AX, 0641X .. 064AX, 
        0671X .. 06B7X, 06BAX .. 06BEX, 06C0X .. 06CEX, 06D0X .. 06D3X, 
        06D5X, 06E5X .. 06E6X:
        RETURN TRUE
      ELSE
        RETURN FALSE
      END
    ELSIF (ch < 0C00X) THEN
      CASE ch OF
      | 0905X .. 0939X, 093DX, 0958X .. 0961X, 0985X .. 098CX, 098FX .. 0990X,
        0993X .. 09A8X, 09AAX .. 09B0X, 09B2X, 09B6X .. 09B9X, 09DCX .. 09DDX, 
        09DFX .. 09E1X, 09F0X .. 09F1X, 0A05X .. 0A0AX, 0A0FX .. 0A10X, 
        0A13X .. 0A28X, 0A2AX .. 0A30X, 0A32X .. 0A33X, 0A35X .. 0A36X, 
        0A38X .. 0A39X, 0A59X .. 0A5CX, 0A5EX, 0A72X .. 0A74X, 0A85X .. 0A8BX, 
        0A8DX, 0A8FX .. 0A91X, 0A93X .. 0AA8X, 0AAAX .. 0AB0X, 0AB2X .. 0AB3X, 
        0AB5X .. 0AB9X, 0ABDX, 0AE0X, 0B05X .. 0B0CX, 0B0FX .. 0B10X, 
        0B13X .. 0B28X, 0B2AX .. 0B30X, 0B32X .. 0B33X, 0B36X .. 0B39X, 0B3DX, 
        0B5CX .. 0B5DX, 0B5FX .. 0B61X, 0B85X .. 0B8AX, 0B8EX .. 0B90X, 
        0B92X .. 0B95X, 0B99X .. 0B9AX, 0B9CX, 0B9EX .. 0B9FX, 0BA3X .. 0BA4X, 
        0BA8X .. 0BAAX, 0BAEX .. 0BB5X, 0BB7X .. 0BB9X:
        RETURN TRUE
      ELSE
        RETURN FALSE
      END
    ELSIF (ch < 1000X) THEN
      CASE ch OF
      | 0C05X .. 0C0CX, 0C0EX .. 0C10X, 0C12X .. 0C28X, 0C2AX .. 0C33X, 
        0C35X .. 0C39X, 0C60X .. 0C61X, 0C85X .. 0C8CX, 0C8EX .. 0C90X, 
        0C92X .. 0CA8X, 0CAAX .. 0CB3X, 0CB5X .. 0CB9X, 0CDEX, 0CE0X .. 0CE1X, 
        0D05X .. 0D0CX, 0D0EX .. 0D10X, 0D12X .. 0D28X, 0D2AX .. 0D39X, 
        0D60X .. 0D61X, 0E01X .. 0E2EX, 0E30X, 0E32X .. 0E33X, 0E40X .. 0E45X, 
        0E81X .. 0E82X, 0E84X, 0E87X .. 0E88X, 0E8AX, 0E8DX, 0E94X .. 0E97X, 
        0E99X .. 0E9FX, 0EA1X .. 0EA3X, 0EA5X, 0EA7X, 0EAAX .. 0EABX, 
        0EADX .. 0EAEX, 0EB0X, 0EB2X .. 0EB3X, 0EBDX, 0EC0X .. 0EC4X, 
        0F40X .. 0F47X, 0F49X .. 0F69X:
        RETURN TRUE
      ELSE
        RETURN FALSE
      END
    ELSIF (ch < 1400X) THEN
      CASE ch OF
      | 10A0X .. 10C5X, 10D0X .. 10F6X, 1100X, 1102X .. 1103X, 1105X .. 1107X, 
        1109X, 110BX .. 110CX, 110EX .. 1112X, 113CX, 113EX, 1140X, 114CX, 
        114EX, 1150X, 1154X .. 1155X, 1159X, 115FX .. 1161X, 1163X, 1165X, 
        1167X, 1169X, 116DX .. 116EX, 1172X .. 1173X, 1175X, 119EX, 11A8X, 
        11ABX, 11AEX .. 11AFX, 11B7X .. 11B8X, 11BAX, 11BCX .. 11C2X, 11EBX, 
        11F0X, 11F9X:
        RETURN TRUE
      ELSE
        RETURN FALSE
      END
    ELSE
      CASE ch OF
      | 1E00X .. 1E9BX, 1EA0X .. 1EF9X, 1F00X .. 1F15X, 1F18X .. 1F1DX, 
        1F20X .. 1F45X, 1F48X .. 1F4DX, 1F50X .. 1F57X, 1F59X, 1F5BX, 1F5DX, 
        1F5FX .. 1F7DX, 1F80X .. 1FB4X, 1FB6X .. 1FBCX, 1FBEX, 1FC2X .. 1FC4X, 
        1FC6X .. 1FCCX, 1FD0X .. 1FD3X, 1FD6X .. 1FDBX, 1FE0X .. 1FECX, 
        1FF2X .. 1FF4X, 1FF6X .. 1FFCX, 2126X, 212AX .. 212BX, 212EX, 
        2180X .. 2182X, 3041X .. 3094X, 30A1X .. 30FAX, 3105X .. 312CX, 
        0AC00X .. 0D7A3X:
        RETURN TRUE
      ELSE
        RETURN FALSE
      END
    END
  END IsBaseChar;

PROCEDURE IsIdeographic (ch: Buffer.Char): BOOLEAN;
  BEGIN
    RETURN (4E00X <= ch) & (ch <= 9FA5X) OR
           (ch = 3007X) OR
           (3021X <= ch ) & (ch <= 3029X)
  END IsIdeographic;

PROCEDURE IsCombiningChar (ch: Buffer.Char): BOOLEAN;
  BEGIN
    IF (ch < 0300X) THEN
      RETURN FALSE
    ELSIF (ch < 0A00X) THEN
      CASE ch OF
      | 0300X .. 0345X, 0360X .. 0361X, 0483X .. 0486X, 0591X .. 05A1X, 
        05A3X .. 05B9X, 05BBX .. 05BDX, 05BFX, 05C1X .. 05C2X, 05C4X, 
        064BX .. 0652X, 0670X, 06D6X .. 06DCX, 06DDX .. 06DFX, 
        06E0X .. 06E4X, 06E7X .. 06E8X, 06EAX .. 06EDX, 0901X .. 0903X, 093CX, 
        093EX .. 094CX, 094DX, 0951X .. 0954X, 0962X .. 0963X, 0981X .. 0983X, 
        09BCX, 09BEX, 09BFX, 09C0X .. 09C4X, 09C7X .. 09C8X, 09CBX .. 09CDX, 
        09D7X, 09E2X .. 09E3X:
        RETURN TRUE
      ELSE
        RETURN FALSE
      END
    ELSIF (ch < 0D00X) THEN
      CASE ch OF
      | 0A02X, 0A3CX, 0A3EX, 0A3FX, 0A40X .. 0A42X, 0A47X .. 0A48X, 
        0A4BX .. 0A4DX, 0A70X .. 0A71X, 0A81X .. 0A83X, 0ABCX, 0ABEX .. 0AC5X, 
        0AC7X .. 0AC9X, 0ACBX .. 0ACDX, 0B01X .. 0B03X, 0B3CX, 0B3EX .. 0B43X, 
        0B47X .. 0B48X, 0B4BX .. 0B4DX, 0B56X .. 0B57X, 0B82X .. 0B83X, 
        0BBEX .. 0BC2X, 0BC6X .. 0BC8X, 0BCAX .. 0BCDX, 0BD7X, 0C01X .. 0C03X, 
        0C3EX .. 0C44X, 0C46X .. 0C48X, 0C4AX .. 0C4DX, 0C55X .. 0C56X, 
        0C82X .. 0C83X, 0CBEX .. 0CC4X, 0CC6X .. 0CC8X, 0CCAX .. 0CCDX, 
        0CD5X .. 0CD6X:
        RETURN TRUE
      ELSE
        RETURN FALSE
      END
    ELSIF (ch < 1000X) THEN
      CASE ch OF
      | 0D02X .. 0D03X, 0D3EX .. 0D43X, 0D46X .. 0D48X, 0D4AX .. 0D4DX, 0D57X, 
        0E31X, 0E34X .. 0E3AX, 0E47X .. 0E4EX, 0EB1X, 0EB4X .. 0EB9X, 
        0EBBX .. 0EBCX, 0EC8X .. 0ECDX, 0F18X .. 0F19X, 0F35X, 0F37X, 0F39X, 
        0F3EX, 0F3FX, 0F71X .. 0F84X, 0F86X .. 0F8BX, 0F90X .. 0F95X, 0F97X, 
        0F99X .. 0FADX, 0FB1X .. 0FB7X, 0FB9X:
        RETURN TRUE
      ELSE
        RETURN FALSE
      END
    ELSIF (ch < 2000X) THEN
      RETURN FALSE
    ELSE
      CASE ch OF
      | 20D0X .. 20DCX, 20E1X, 302AX .. 302FX, 3099X, 309AX:
        RETURN TRUE
      ELSE
        RETURN FALSE
      END
    END
  END IsCombiningChar;

PROCEDURE IsExtender (ch: Buffer.Char): BOOLEAN;
  BEGIN
    IF (ch = 00B7X) THEN
      RETURN TRUE
    ELSIF (ch >= 02D0X) THEN
      CASE ch OF
      | 02D0X, 02D1X, 0387X, 0640X, 0E46X, 0EC6X, 3005X, 3031X .. 3035X, 
        309DX .. 309EX, 30FCX .. 30FEX:
        RETURN TRUE
      ELSE
        RETURN FALSE
      END
    ELSE
      RETURN FALSE
    END
  END IsExtender;

PROCEDURE IsLetter (ch: Buffer.Char): BOOLEAN;
  BEGIN
    RETURN IsBaseChar (ch) OR IsIdeographic (ch)
  END IsLetter;

PROCEDURE IsNameChar (ch: Buffer.Char): BOOLEAN;
  BEGIN
    RETURN IsLetter (ch) OR IsDigit (ch) OR
           (ch = ".") OR (ch = "-") OR (ch = "_") OR (ch = ":") OR
           IsCombiningChar (ch) OR IsExtender (ch)
  END IsNameChar;

PROCEDURE IsNameChar0 (ch: Buffer.Char): BOOLEAN;
  BEGIN
    RETURN IsLetter (ch) OR (ch = "_") OR (ch = ":")
  END IsNameChar0;

PROCEDURE IsPubidChar (ch: Buffer.Char): BOOLEAN;
  VAR
    i: LONGINT;
  BEGIN
    IF ("A" <= CAP (ch)) & (CAP (ch) <= "Z") OR
       ("0" <= ch) & (ch <= "9") OR
       (ch = " ") OR (ch = Ascii.cr) OR (ch = Ascii.lf) THEN
      RETURN TRUE
    ELSE
      i := 0;
      WHILE (suplPubidChar[i] # 0X) & (suplPubidChar[i] # ch) DO
        INC (i)
      END;
      RETURN (suplPubidChar[i] # 0X)
    END
  END IsPubidChar;

PROCEDURE IsVersionNumChar (ch: Buffer.Char): BOOLEAN;
  BEGIN
    RETURN ("A" <= CAP (ch)) & (CAP (ch) <= "Z") OR
           ("0" <= ch) & (ch <= "9") OR
           (ch = "_") OR (ch = ".") OR (ch = ":") OR (ch = "-")
  END IsVersionNumChar;

PROCEDURE IsEncNameChar (ch: Buffer.Char; first: BOOLEAN): BOOLEAN;
  BEGIN
    IF ("A" <= CAP (ch)) & (CAP (ch) <= "Z") THEN
      RETURN TRUE
    ELSIF ~first THEN
      RETURN ("0" <= ch) & (ch <= "9") OR
             (ch = ".") OR (ch = "_") OR (ch = "-")
    ELSE
      RETURN FALSE
    END
  END IsEncNameChar;


(* ------------------------------------------------------------------------ *)

PROCEDURE document (p: Parser);
  VAR
    dtd: DTD.Builder;
    cpos, currLine, currLinePos, currLineTab: Buffer.CharPos;
    cstart, cdelta: Buffer.CharPos;
    chars: Buffer.CharArray;
    lastError: Error.Msg;
  
  CONST
    followedByAny = 0;
    followedByNonName = 2;
  
  (*
  Character Information            Value
  ------------------------------   -----------------------------
  current file position            in. offsetFromPos0+cpos
  current line                     currLine
  current column                   cpos-currLinePos+currLineTab
  file position of current line    currLinePos
  column delta because of tabs     currLineTab
  marked file position             cstart
  
  All numbering (file position, line, column) starts at zero.
  
  
  Handling of control characters is slightly tricky.  There are three end of
  line variants (LF, CR, CR+LF) to handle, and the end of a line requires
  adjustment of @ovar{currLine}, @ovar{currLinePos}, and @ovar{currLineTab}.
  A tab character means adjustment of @ovar{currLineTab}.  All other control
  characters are invalid and must be reported as such.  The special character
  @oconst{Buffer.markedEOB} means that the end of the current buffer has been
  reached and new characters must be retrieved from file.  The other special,
  @oconst{Buffer.markedEOD}, means that the end of the document has been 
  reached.
  
  
  The prodedures that produce content (character data, attribute value, or
  entity value) produce normalized values of the character data in the
  input buffer itself.  With @ovar{cpos} denoting the current reading
  position, the character interval
  @samp{[@ovar{cstart}, @ovar{cpos}-@ovar{cdelta}[} holds the normalized
  value.  The value of @ovar{cdelta} is increased each time the normalized
  value of a character sequence is shorter than the sequence itself.  Examples
  for this are CR+LF end of line marker, or character references.
  *)
  
  PROCEDURE DecLength (VAR pos: Position; len: DTD.CharPos);
    BEGIN
      DEC (pos. char, len);
      DEC (pos. column, len)
    END DecLength;
  
  PROCEDURE StorePosition (VAR pos: Position);
    VAR
      i: LONGINT;
    BEGIN
      IF (p. in # NIL) & (chars = p. in. chars) THEN
        pos. char := cpos+p. in. offsetFromPos0;
        pos. line := currLine;
        pos. column := cpos-currLinePos+currLineTab
      ELSE
        (* go down the stack of pushed entities, until the external entity
           is found that represents the most recently opened file *)
        IF (p. in = NIL) THEN
          i := 0
        ELSE
          i := p. lenPEStack-1;
          WHILE (p. peStack[i]. oldChars # p. in. chars) DO
            DEC (i)
          END
        END;
        pos. char := p. peStack[i]. oldCPos+p. peStack[i]. in. offsetFromPos0;
        pos. line := currLine;
        pos. column := p. peStack[i]. oldCPos-currLinePos+currLineTab;
        IF (p. peStack[i]. entity. name # NIL) THEN
          DecLength (pos, LongStrings.Length (p. peStack[i]. entity. name^)+2)
        END
      END
    END StorePosition;
  
  PROCEDURE ErrPos (code: Error.Code; pos: Position);
    VAR
      i: LONGINT;
    BEGIN
      lastError := Error.New (parserContext, code);
      lastError. SetIntAttrib ("char", pos. char);
      lastError. SetIntAttrib ("line", pos. line);
      lastError. SetIntAttrib ("column", pos. column);
      lastError. SetAttribute (URI.NewURIAttribute ("baseURI", p. fileEntity. baseURI));
      IF (chars # p. in. chars) THEN
        i := p. lenPEStack-1;
        (*WHILE (p. peStack[i]. oldChars # p. in. chars) DO
          DEC (i)
        END;*)
        lastError. SetLStringAttrib ("entity_name", 
                              Msg.GetLStringPtr (p. peStack[i]. entity. name^))
      END;
      (*IF (pos. systemId # NIL) THEN
        lastError. SetLStringAttrib ("systemId", pos. systemId)
      END;
      IF (pos. publicId # NIL) THEN
        lastError. SetLStringAttrib ("publicId", pos. publicId)
      END*)
      p. errList. Append (lastError);
      IF (p. builder = p. initialBuilder) THEN
        p. builder := Builder.New()
      END;
      
(*      Log.LongInt ("ERROR CODE", code);
      Log.Msg ("Position: ");
      FOR i := cpos TO p. in. endOfBuffer-1 DO
        E.Char (SHORT (chars[i]))
      END;
      E.Ln;
      ASSERT (FALSE)*)
    END ErrPos;
  
  PROCEDURE WriteBuffer (msg: ARRAY OF CHAR);
    VAR
      i, end: LONGINT;
    BEGIN
      end := cpos+80;
      i := cpos;
      Out.Ln; Out.String ("### buffer contents "); 
      Out.String (msg); Out.String (" ###"); Out.Ln;
      WHILE (chars[i] < Buffer.markerEOB) & (i <= end) DO
        IF (chars[i] > 0FFX) THEN
          Out.Char("?")
        ELSE
          Out.Char(SHORT (chars[i]))
        END;
        INC (i)
      END;
      Out.Ln;
    END WriteBuffer;
  
  PROCEDURE Err (code: Error.Code);
    VAR
      pos: Position;
    BEGIN
(*      WriteBuffer ("ERROR");*)
      StorePosition (pos);
      ErrPos (code, pos)
    END Err;
  
  (* ---------------------------------------------------------------------- *)
  
  PROCEDURE Clone (string: DTD.String): DTD.String;
    VAR
      clone: DTD.String;
      i: LONGINT;
    BEGIN
      NEW (clone, LEN (string^));
      FOR i := 0 TO LEN (string^)-1 DO
        clone[i] := string[i]
      END;
      RETURN clone
    END Clone;
  
  PROCEDURE GetString (start, end: DTD.CharPos): DTD.String;
    VAR
      string: DTD.String;
      i: DTD.CharPos;
    BEGIN
      NEW (string, end-start+1);
      i := 0;
      WHILE (start # end) DO
        string[i] := chars[start];
        INC (start); INC (i)
      END;
      string[i] := 0X;
      RETURN string
    END GetString;
  
  PROCEDURE GetBuffer (entity: DTD.ExternalEntity): Buffer.Input;
    VAR
      res: Msg.Msg;
      ch: Channel.Channel;
      in: Buffer.Input;
      str: ARRAY 2*1024 OF CHAR;
    BEGIN
      IF (entity. baseURI = NIL) THEN
        RETURN NIL
      ELSE
        ch := entity. baseURI. GetChannel (FALSE, res);
        IF (ch = NIL) THEN
          Err (accessError);
          entity. baseURI. GetString (str);
          lastError. SetStringAttrib ("uri", Msg.GetStringPtr (str));
          lastError. SetMsgAttrib ("channel_error", res);
          RETURN NIL
        ELSE
          in := Buffer.NewInput (ch, NIL, p. errList);
          ASSERT (in # NIL);
          RETURN in
        END
      END
    END GetBuffer;
  
  PROCEDURE PushEntity (entity: DTD.Entity; syncEntity: BOOLEAN);
  (* `syncEntity=TRUE' means that the resolved entity is matched against
     a grammar production (extPE, extParsedPE, externalSubset) and is not
     inserted at an arbitrary place in the external subset or an entity
     value *)
    VAR
      newList: PEInfoList;
      i: LONGINT;
    BEGIN
      IF (entity # NIL) THEN
        entity. expanding := TRUE
      END;
      
      IF (p. lenPEStack = LEN (p. peStack^)) THEN
        NEW (newList, LEN (p. peStack^)+incrPEStack);
        FOR i := 0 TO LEN (p. peStack^)-1 DO
          newList[i] := p. peStack[i]
        END;
        p. peStack := newList
      END;
      p. peStack[p. lenPEStack]. entity := entity;
      p. peStack[p. lenPEStack]. oldChars := chars;
      p. peStack[p. lenPEStack]. oldCPos := cpos;
      p. peStack[p. lenPEStack]. oldCurrLine := currLine;
      p. peStack[p. lenPEStack]. oldCurrLinePos := currLinePos;
      p. peStack[p. lenPEStack]. oldCurrLineTab := currLineTab;
      p. peStack[p. lenPEStack]. in := p. in;
      INC (p. lenPEStack);
      
      IF syncEntity & (entity IS DTD.ExternalEntity) THEN
        (* external entity read from file *)
        p. in := GetBuffer (entity(DTD.ExternalEntity));
        p. fileEntity := entity(DTD.ExternalEntity);
        currLine := 0; currLinePos := 0; currLineTab := 0;
        IF (p. in = NIL) THEN            (* read error: simulate empty file *)
          NEW (chars, 2);
          chars[0] := Buffer.markerEOD
        ELSE
          chars := p. in. chars
        END
      ELSE
        (* internal entity or internalized external entity that is inserted
           somewhere "in between"; continue parsing in a _copy_ of the entity
           value, because the value may be modified during parsing *)
        chars := Clone (entity. entityValue);
        
        CASE entity. type OF
        | DTD.entityInternalGeneral, DTD.entityExternalGeneral:
          ASSERT (chars[LEN (chars^)-2] = Buffer.markerEOD)
        | DTD.entityInternalParameter, DTD.entityExternalParameter:
          ASSERT (chars[LEN (chars^)-2] = Buffer.markerEOB);
          
          (* add a space to the end of the interal entity (or internalized
             external entity), unless we are within
             an entity value declaration; this ensures the replacement ends in
             a whitespace character, and at the same tim `LookingAt' will not
             fall out of an expanded entity reference *)
          IF (p. currEntityValue = NIL) THEN
            chars[LEN (chars^)-2] := " ";
            chars[LEN (chars^)-1] := Buffer.markerEOB
          END
        END
      END;
      cpos := 0; cdelta := 0; cstart := 0
    END PushEntity;
  
  PROCEDURE CheckInvalidChars;
    VAR
      str: ARRAY 2*1024 OF CHAR;
    BEGIN
      IF (p. in. codec. invalidChars # 0) THEN
        Err (invalidCharacterEncodings);
        p. fileEntity. baseURI. GetString (str);
        lastError. SetStringAttrib ("uri", Msg.GetStringPtr (str));
        lastError. SetIntAttrib ("encodings", p. in. codec. invalidChars)
      END
    END CheckInvalidChars;
  
  PROCEDURE PopEntity;
    VAR
      i: LONGINT;
    BEGIN
      IF (p. currEntityValue # NIL) THEN
        (* we are parsing the entity value of an entity declaration: append
           text fragment to the value's fragment list *)
        p. currEntityValue. Append (dtd. NewCharacters (chars, cstart, cpos-cdelta, TRUE))
      END;
      
      DEC (p. lenPEStack);
      IF (p. in # NIL) & (p. in # p. peStack[p. lenPEStack]. in) THEN
        CheckInvalidChars;
        p. in. Close                     (* close external entity buffer *)
      END;
      chars := p. peStack[p. lenPEStack]. oldChars;
      cpos := p. peStack[p. lenPEStack]. oldCPos;
      currLine := p. peStack[p. lenPEStack]. oldCurrLine;
      currLinePos := p. peStack[p. lenPEStack]. oldCurrLinePos;
      currLineTab := p. peStack[p. lenPEStack]. oldCurrLineTab;
      i := p. lenPEStack-1;
      WHILE (i >= 0) & ~(p. peStack[i]. entity IS DTD.ExternalEntity) DO
        DEC (i)
      END;
      IF (i >= 0) THEN
        p. fileEntity := p. peStack[i]. entity(DTD.ExternalEntity)
      ELSE
        p. fileEntity := p. documentEntity
      END;
      p. in := p. peStack[p. lenPEStack]. in;
      cstart := cpos; cdelta := 0;
      
      IF (p. peStack[p. lenPEStack]. entity # NIL) THEN
        p. peStack[p. lenPEStack]. entity. expanding := FALSE
      END
    END PopEntity;
  
  PROCEDURE NextBlock;
    VAR
      oldOffset: Buffer.CharPos;
      res: BOOLEAN;
    BEGIN
      ASSERT (chars[cpos] = Buffer.markerEOB);
      IF (p. lenPEStack # 0) & (p. in. chars # chars) THEN
        (* fix up end of entity by removing the space that was added there
           by PushEntity *)
        IF (p. currEntityValue = NIL) THEN
          ASSERT (chars[LEN (chars^)-2] = " ");
          ASSERT (chars[LEN (chars^)-1] = Buffer.markerEOB);
          chars[LEN (chars^)-2] := Buffer.markerEOB;
        END;
        
        (* we reached the end of an internal parameter entity expansion;
           remove the top-level stack element, restore the old context, and
           continue parsing *)
        PopEntity
      ELSE
        oldOffset := p. in. offsetFromPos0;
        res := p. in. NextBlock();
        chars := p. in. chars;
        DEC (cpos, p. in. offsetFromPos0-oldOffset);
        DEC (cstart, p. in. offsetFromPos0-oldOffset);
        DEC (currLinePos, p. in. offsetFromPos0-oldOffset);
      END
    END NextBlock;
  
  PROCEDURE DiscardPreviousInput;
    BEGIN
      IF (p. in. chars = chars) THEN
        p. in. discardable := cpos;
        cstart := cpos
      END
    END DiscardPreviousInput;
  
  PROCEDURE Internalize (entity: DTD.ExternalEntity): DTD.String;
    VAR
      in: Buffer.Input;
      len, i, delta: Buffer.CharPos;
      str: DTD.String;
    BEGIN
      in := GetBuffer (entity);
      IF (in # NIL) THEN
        WHILE in. NextBlock() DO END;

        (* do eol replacement magic *)
        len := in. endOfBuffer;
        i := 0; delta := 0;
        WHILE (i # len) DO
          CASE in. chars[i] OF
          | Ascii.cr:
            in. chars[i-delta] := Ascii.lf;
            IF (in. chars[i+1] = Ascii.lf) THEN
              INC (i); INC (delta)
            END
          ELSE
            in. chars[i-delta] := in. chars[i]
          END;
          INC (i)
        END;
        DEC (len, delta);

        NEW (str, len+2);
        FOR i := 0 TO len-1 DO
          str[i] := in. chars[i]
        END;
        CheckInvalidChars;
        in. Close
      ELSE
        NEW (str, 2);
        len := 0
      END;
      CASE entity. type OF
      | DTD.entityExternalGeneral:
        str[len] := Buffer.markerEOD
      | DTD.entityExternalParameter:
        str[len] := Buffer.markerEOB
      END;
      RETURN str
    END Internalize;
  
  PROCEDURE EndOfLine;
  (* Must be called @emph{after} skipping over an end of line marker (LF, CR,
     or CR+LF).  *)
    BEGIN
      IF (chars = p. in. chars) THEN
        INC (currLine);
        currLinePos := cpos;
        currLineTab := 0
      END
    END EndOfLine;
  
  PROCEDURE Tab;
  (* Must be called @emph{before} skipping over a tab charatcer (Ascii.ht).  *)
    VAR
      currColumn: Buffer.CharPos;
    BEGIN
      IF (chars = p. in. chars) THEN
        currColumn := cpos-currLinePos+currLineTab;
        INC (currLineTab, tabWidth-currColumn MOD tabWidth-1)
      END
    END Tab;
  
  PROCEDURE LookingAtS(): BOOLEAN;
  (* pre: chars[cpos] is valid *)
    BEGIN
      IF (chars[cpos] <= " ") THEN
        RETURN TRUE
      ELSIF (p. inExternalSubset OR p. inExternalEntity) &
            (chars[cpos] = "%") THEN
       IF (chars[cpos+1] = Buffer.markerEOB) THEN
         IF (chars = p. in. chars) THEN
           (* we aren't within an internal entity value *)
           INC (cpos);
           NextBlock;
           DEC (cpos);
           RETURN IsNameChar (chars[cpos+1])
         ELSE
           RETURN FALSE
         END
       ELSE
         RETURN IsNameChar (chars[cpos+1])
       END
      ELSE
        RETURN FALSE
      END
    END LookingAtS;
  
  PROCEDURE LookingAtSnoPE(): BOOLEAN;
  (* pre: chars[cpos] is valid *)
    BEGIN
      RETURN (chars[cpos] <= " ")
    END LookingAtSnoPE;
  
  (* ---------------------------------------------------------------------- *)
  
  (* NOTE: All procedures that consume characters from the input stream
     must ensure that @samp{chars[cpos] # Buffer.markerEOB} after completion.
     That is, the current lookahead character @samp{chars[cpos]} must be
     valid if such a procedure is done.  Conversely, all procedure can 
     depend on @samp{chars[cpos]} when activated.  *)
  
  PROCEDURE LookingAt (str: ARRAY OF CHAR; followedBy: SHORTINT): BOOLEAN;
  (* pre: `str' does not contain any whitespace characters
     post: ~result & (chars[cpos] # Buffer.markerEOB) OR
           result & (chars[cpos..cpos+Length(str)] # Buffer.markerEOB)
           the pointer `chars' has not changed *)
    VAR
      i: Buffer.CharPos;
    BEGIN
      i := 0;
      LOOP
        IF (chars[cpos] = Buffer.markerEOB) THEN
          IF (chars = p. in. chars) THEN
            NextBlock
          ELSE
            (* we are in an internal entity reference; EOB marks the end of
               the reference *)
            DEC (cpos, i);
            RETURN (str[i] = 0X)
          END
        ELSIF (str[i] = 0X) THEN
          DEC (cpos, i);
          CASE followedBy OF
          | followedByNonName:
            RETURN ~IsNameChar (chars[cpos+i])
          | followedByAny:
            RETURN TRUE
          END
        ELSIF (str[i] = chars[cpos]) THEN
          INC (i); INC (cpos)
        ELSE
          DEC (cpos, i);
          RETURN FALSE
        END
      END
    END LookingAt;
  
  PROCEDURE NextChar;
    BEGIN
      IF (chars[cpos] # Buffer.markerEOD) THEN
        INC (cpos);
        IF (chars[cpos] = Buffer.markerEOB) THEN
          NextBlock
        END
      END
    END NextChar;
  
  PROCEDURE Nmtoken(): DTD.String;
  (* pre: chars[cpos] # Buffer.markerEOB *)
    VAR
      string: DTD.String;
    BEGIN
      IF IsNameChar (chars[cpos]) THEN
        cstart := cpos;
        INC (cpos);
        LOOP
          IF (chars[cpos] = Buffer.markerEOB) THEN
            IF (chars # p. in. chars) THEN (* in internal entity value *)
              string := GetString (cstart, cpos);
              NextBlock;
              EXIT
            ELSE
              NextBlock
            END
          ELSIF IsNameChar (chars[cpos]) THEN
            INC (cpos)
          ELSE
            string := GetString (cstart, cpos);
            EXIT
          END
        END;
        RETURN string
      ELSE
        Err (expectedNmtoken);
        NextChar;
        RETURN noName
      END
    END Nmtoken;
  
  PROCEDURE Name(): DTD.String;
  (* pre: chars[cpos] # Buffer.markerEOB *)  
    BEGIN
      IF IsNameChar0 (chars[cpos]) THEN
        RETURN Nmtoken()
      ELSE
        Err (expectedName);
        NextChar;
        RETURN noName
      END
    END Name;
  
  PROCEDURE CheckChar (ch: CHAR);
  (* Compare the current character with @oparam{ch}, and report an error if
     they don't match.  *)
    VAR
      str: ARRAY 2 OF CHAR;
    BEGIN
      IF (chars[cpos] # ch) THEN
        Err (expectedChar);
        str := "X";
        str[0] := ch;
        lastError. SetStringAttrib ("symbol", Msg.GetStringPtr (str))
      END;
      IF (chars[cpos] # Buffer.markerEOD) THEN
        INC (cpos);
        IF (chars[cpos] = Buffer.markerEOB) THEN
          NextBlock
        END
      END
    END CheckChar;
  
  PROCEDURE ^ XMLDecl (entity: DTD.ExternalEntity);
  PROCEDURE ^ extSubsetDecl;
  
  PROCEDURE PEReference (markupDecl: BOOLEAN);
    VAR
      name: DTD.String;
      decl: DTD.Declaration;
      entity: DTD.Entity;
      oldCStart: DTD.CharPos;
      pos: Position;
      oldFlag: BOOLEAN;
    BEGIN  (* pre: (chars[cpos] = "%") *)
      StorePosition (pos);
      IF ~markupDecl & 
         (~p. inExternalSubset & ~p. inExternalEntity) THEN
        Err (nonMarkupDeclPERef)
      END;
      CheckChar ("%");
      oldCStart := cstart+p. in. offsetFromPos0;
      name := Name();
      cstart := oldCStart-p. in. offsetFromPos0;
      CheckChar (";");
      decl := dtd. peNamespace. Get (name);
      IF (decl = NIL) THEN
        Err (noSuchParameterEntity);
        lastError. SetLStringAttrib ("name", Msg.GetLStringPtr (name^))
      ELSE
        entity := decl(DTD.Entity);
        IF (entity. type = DTD.entityExternalParameter) THEN
          (* external references must match extPE; they must not be followed
             for well-formedness tests *)
          IF p. followExternalRef THEN
            IF ~markupDecl THEN
              IF (entity IS DTD.ExternalEntity) THEN
                entity. SetEntityValue (Internalize (entity(DTD.ExternalEntity)))
              END;
              PushEntity (entity, FALSE)
            ELSE
              PushEntity (entity, markupDecl);
              oldFlag := p. inExternalEntity;
              p. inExternalEntity := TRUE;
              IF LookingAt ("<?xml", followedByNonName) THEN
                XMLDecl (entity(DTD.ExternalEntity))
              END;
              extSubsetDecl;
              IF (chars[cpos] # Buffer.markerEOD) THEN
                Err (junkAfterExtSubset)
              END;
              p. inExternalEntity := oldFlag;
              PopEntity
            END
          ELSIF (p. documentEntity. standalone # DTD.standaloneYes) THEN
            p. processDeclarations := FALSE
          END
        ELSE
          PushEntity (entity, markupDecl)
        END
      END
    END PEReference;
  
  PROCEDURE OptS (noPE: BOOLEAN);
  (* Matches the syntax rule "S?".  This procedure is used only @emph{outside}
     the document element, and never as part of an entity or attribute value.
     This means that the characters skipped by this rule are never reported
     to the application.  *)
    BEGIN
      LOOP
        CASE chars[cpos] OF
        | Buffer.markerEOB:
          NextBlock
        | " ":
          INC (cpos)
        | Ascii.lf:
          INC (cpos); EndOfLine
        | Ascii.cr:
          INC (cpos);
          IF (chars[cpos] = Buffer.markerEOB) THEN
            NextBlock
          END;
          IF (chars[cpos] = Ascii.lf) THEN
            INC (cpos)
          END;
          EndOfLine
        | Ascii.ht:
          Tab; INC (cpos)
        | "%":
          IF ~noPE THEN
            PEReference (FALSE);
            OptS (noPE)
          ELSE
            EXIT
          END
        ELSE
          IF (chars[cpos] < " ") THEN
            Err (invalidChar);
            INC (cpos)
          ELSE
            EXIT
          END
        END
      END
    END OptS;
  
  PROCEDURE S;
    BEGIN
      IF LookingAtS() THEN
        OptS (FALSE)
      ELSE
        Err (expectedWhitespace)
      END
    END S;

  PROCEDURE SnoPE;
    BEGIN
      IF LookingAtSnoPE() THEN
        OptS (TRUE)
      ELSE
        Err (expectedWhitespace)
      END
    END SnoPE;

  PROCEDURE ControlChar (eolReplacement: DTD.Char);
  (* @precond
     @itemize
     @item
     @samp{(chars[cpos] < " ") OR (chars[cpos] = Buffer.markerEOB)}
     
     @item
     The variables @ovar{cstart} and @ovar{coffset} have been initialized.
     
     @item
     @oparam{eolReplacement} is either space (ASCII 20X), denoting attribute
     value normalization, or newline (ASCII 0AX), denoting normal end of
     line processing.
     @end precond  *)
    VAR
      cend: DTD.CharPos;
    BEGIN
      ASSERT ((chars[cpos] < " ") OR (chars[cpos] = Buffer.markerEOB));
      cend := cpos-cdelta;
      CASE chars[cpos] OF
      | Buffer.markerEOB:
        NextBlock
      | " ":
        chars[cend] := " "; INC (cpos)
      | Ascii.lf:
        chars[cend] := eolReplacement; INC (cpos); EndOfLine
      | Ascii.cr:
        chars[cend] := eolReplacement;
        INC (cpos);
        IF (chars[cpos] = Buffer.markerEOB) THEN
          NextBlock
        END;
        IF (chars[cpos] = Ascii.lf) THEN
          INC (cpos); INC (cdelta)
        END;
        EndOfLine
      | Ascii.ht:
        IF (eolReplacement = " ") THEN
          chars[cend] := " "
        ELSE
          chars[cend] := Ascii.ht
        END;
        Tab; INC (cpos)
      ELSE
        chars[cend] := Buffer.markerError;
        Err (invalidChar);
        INC (cpos)
      END
    END ControlChar;
  
  
  PROCEDURE String (type: SHORTINT): DTD.String;
    VAR
      pos: Position;
      endChar: DTD.Char;
      string: DTD.String;
    
    PROCEDURE NormalizeWhitespace;
    (* For a PubidLiteral, normalize whitespace by collapsing sequences of
       whitespace into a single space character, and by remobing leading and
       trailing whitespace.  *)
      VAR
        i, delta: LONGINT;
      BEGIN
        (* strip leading whitespace *)
        WHILE (cstart # cpos-cdelta) & (chars[cstart] <= " ") DO
          INC (cstart)
        END;
        i := cstart; delta := 0;
        WHILE (i # cpos-cdelta) DO
          IF (chars[i] <= " ") THEN
            (* fold sequence of whitespace into single space *)
            chars[i-delta] := " ";
            WHILE (i+1 # cpos-cdelta) & (chars[i+1] <= " ") DO
              INC (i); INC (delta)
            END
          ELSE
            chars[i-delta] := chars[i]
          END;
          INC (i)
        END;
        (* strip space character from end of string (can only be one) *)
        INC (cdelta, delta);
        IF (cpos-cdelta # cstart) & (chars[cpos-cdelta-1] = " ") THEN
          INC (cdelta)
        END
      END NormalizeWhitespace;
    
    BEGIN
      IF (chars[cpos] = "'") OR (chars[cpos] = '"') THEN
        StorePosition (pos);
        endChar := chars[cpos];
        INC (cpos);
        cstart := cpos; cdelta := 0;
        LOOP
          CASE chars[cpos] OF
          | 00X..1FX, Buffer.markerEOB:
            IF (type = stringPubidLiteral) & (chars[cpos] = Ascii.ht) THEN
              Err (invalidPubidChar)
            END;
            ControlChar (Ascii.lf)
          | Buffer.markerEOD:
            ErrPos (stringNotClosed, pos);
            RETURN GetString (cstart, cpos-cdelta)
          ELSE
            IF (chars[cpos] = endChar) THEN
              IF (type = stringPubidLiteral) THEN
                NormalizeWhitespace
              END;
              string := GetString (cstart, cpos-cdelta);
              CheckChar (SHORT (endChar));
              
              CASE type OF
              | stringStandalone:
                IF (string^ # "yes") & (string^ # "no") THEN
                  ErrPos (expectedYesNo, pos)
                END
              | stringEncoding, stringVersion:
                IF (string^ = "") THEN
                  ErrPos (expectedNonEmptyString, pos)
                END
              ELSE (* ignore *)
              END;
              RETURN string
              
            ELSE
              CASE type OF
              | stringPubidLiteral:
                IF ~IsPubidChar (chars[cpos]) THEN
                  Err (invalidPubidChar)
                END
              | stringEncoding:
                IF ~IsEncNameChar (chars[cpos], cpos=cstart) THEN
                  Err (invalidEncNameChar)
                END
              | stringVersion:
                IF ~IsVersionNumChar (chars[cpos]) THEN
                  Err (invalidVersionNumChar)
                END
              ELSE (* ignore *)
              END;
              chars[cpos-cdelta] := chars[cpos]; INC (cpos)
            END
          END
        END
      ELSE
        Err (expectedString);
        RETURN GetString (cpos, cpos)
      END
    END String;

  PROCEDURE Eq;
  (* post: chars[cpos] # Buffer.markerEOB *)
    BEGIN
      OptS (TRUE); CheckChar ("="); OptS (TRUE)
    END Eq;
  
  PROCEDURE XMLDecl (entity: DTD.ExternalEntity);
  (* pre: cpos=0 and looking at "<?xml"+NonName *)
    VAR
      string: DTD.String;
      encoding: POINTER TO ARRAY OF CHAR;
      codecFactory: Codec.Factory;
      i: LONGINT;
    BEGIN
      ASSERT (cpos = 0);
      ASSERT (entity # NIL);
      INC (cpos, 5);                   (* skip over "<?xml" *)
      IF (chars[cpos] # "?") THEN S END;
      IF LookingAt ("version", followedByNonName) THEN
        INC (cpos, 7);                 (* skip over "version" *)
        Eq;
        entity. SetVersion (String (stringVersion));
        IF (chars[cpos] # "?") THEN S END
      ELSIF (entity. type = DTD.entityDocument) THEN
        Err (expectedVersion)
      END;
      IF LookingAt ("encoding", followedByNonName) THEN
        INC (cpos, 8);                 (* skip over "encoding" *)
        Eq;
        string := String (stringEncoding);
        
        IF p. in. autoDetectedCodec & (entity. encoding = NIL) THEN
          (* if the character encoding was determined, through auto
             detection, then install a new codec and parse XMLDecl again *)
          NEW (encoding, LongStrings.Length (string^)+1);
          FOR i := 0 TO LEN (encoding^)-1 DO
            IF (string[i] > MAX (CHAR)) THEN
              encoding[i] := "?"
            ELSE
              encoding[i] := SHORT (string[i])
            END
          END;
          codecFactory := Codec.GetFactory (encoding^);
          IF (codecFactory = NIL) THEN
            Err (unknownCharacterEncoding)
          ELSE
            p. in. SetCodec (codecFactory, FALSE);
            cpos := 0; currLine := 0; currLinePos := 0; currLineTab := 0;
            XMLDecl (entity);
            RETURN
          END
        END;
        
        entity. SetEncoding (string);
        IF (chars[cpos] # "?") THEN S END
      ELSIF (entity. type # DTD.entityDocument) THEN
        Err (expectedEncodingDecl)
      END;
      IF (entity. type = DTD.entityDocument) &
         LookingAt ("standalone", followedByNonName) THEN
        INC (cpos, 10);              (* skip over "standalone" *)
        Eq;
        string := String (stringStandalone);
        entity. SetStandalone (DTD.standaloneYes)
      END;
      OptS (TRUE);
      IF LookingAt ("?>", followedByAny) THEN
        INC (cpos, 2)
      ELSE
        Err (expectedPIEnd)
      END
    END XMLDecl;


  PROCEDURE PI;
  (* pre: looking at "<?" *)
    VAR
      pos: Position;
      target: DTD.String;
    
    PROCEDURE IsReserved (name: ARRAY OF DTD.Char): BOOLEAN;
      BEGIN
        RETURN (CAP (name[0]) = "X") &
               (CAP (name[1]) = "M") &
               (CAP (name[2]) = "L")
      END IsReserved;
    
    BEGIN
      StorePosition (pos);
      INC (cpos, 2);                     (* skip over "<?" *)
      target := Name();
      IF (target^ = "xml") THEN
        ErrPos (xmlDeclNotAtBeginning, pos)
      ELSIF IsReserved (target^) THEN
        ErrPos (reservedPITarget, pos)
      END;
      
      IF LookingAt ("?>", followedByAny) THEN
        p. builder. ProcessingInstruction (target, chars^, 0, 0, 
                                           p. fileEntity. baseURI);
        INC (cpos, 2)
      ELSE
        S;
        cstart := cpos; cdelta := 0;
        LOOP
          CASE chars[cpos] OF
          | 00X..1FX, Buffer.markerEOB:
            ControlChar (Ascii.lf)
          | Buffer.markerEOD:
            ErrPos (piNotClosed, pos);
            EXIT
          | "?":
            IF LookingAt ("?>", followedByAny) THEN
              p. builder. ProcessingInstruction (target, chars^, cstart,
                                                 cpos-cdelta,
                                                 p. fileEntity. baseURI);
              INC (cpos, 2);
              EXIT
            ELSE
              chars[cpos-cdelta] := chars[cpos]; INC (cpos)
            END
          ELSE
            chars[cpos-cdelta] := chars[cpos]; INC (cpos)
          END
        END
      END
    END PI;

  PROCEDURE Comment;
  (* pre: looking at "<!--" *)
    VAR
      pos: Position;
    BEGIN
      StorePosition (pos);
      INC (cpos, 4);                     (* skip over "<!--" *)
      cstart := cpos; cdelta := 0;
      LOOP
        CASE chars[cpos] OF
        | 00X..1FX, Buffer.markerEOB:
          ControlChar (Ascii.lf)
        | Buffer.markerEOD:
          ErrPos (commentNotClosed, pos);
          EXIT
        | "-":
          IF LookingAt ("-->", followedByAny) THEN
            p. builder. Comment (chars^, cstart, cpos-cdelta);
            INC (cpos, 3);
            EXIT
          ELSIF LookingAt ("--", followedByAny) THEN
            Err (invalidCommentDashDash)
          END;
          chars[cpos-cdelta] := chars[cpos]; INC (cpos);
        ELSE
          chars[cpos-cdelta] := chars[cpos]; INC (cpos)
        END
      END;
      DiscardPreviousInput
    END Comment;

  PROCEDURE CDSect;
  (* pre: looking at "<![CDATA[" *)
    VAR
      pos: Position;
    BEGIN
      StorePosition (pos);
      p. builder. StartCDATA;
      INC (cpos, 9);                     (* skip over "<![CDATA[" *)
      cstart := cpos; cdelta := 0;
      LOOP
        CASE chars[cpos] OF
        | 00X..1FX, Buffer.markerEOB:
          ControlChar (Ascii.lf)
        | Buffer.markerEOD:
          ErrPos (cdataNotClosed, pos);
          EXIT
        | "]":
          IF LookingAt ("]]>", followedByAny) THEN
            p. builder. Characters (chars^, cstart, cpos-cdelta,
                                    DTD.elementWhitespaceUnknown, FALSE);
            INC (cpos, 3);
            p. builder. EndCDATA;
            EXIT
          ELSE
            chars[cpos-cdelta] := chars[cpos]; INC (cpos)
          END
        ELSE
          chars[cpos-cdelta] := chars[cpos]; INC (cpos)
        END
      END
    END CDSect;
  
  PROCEDURE CharRef;
  (* Parses the character references and writes the result to 
     `chars[cpos-cdelta]'.  If `cstart=cpos-cdelta' when this procedure
     is invoked, then `chars[cstart,cpos-cdelta[' is the replacement
     text for the character reference.  
     pre: looking at "&#"
     post: `cstart' is preserved *)
    CONST
      overflow = 20000H;
      errorReplacement = 20H;
    VAR
      cval: LONGINT;
      pos: Position;
    
    PROCEDURE ToUnicode (cval: LONGINT): DTD.CharPos;
      BEGIN
        IF (cval <= 0FFFFH) THEN
          chars[cpos-cdelta] := LONGCHR (cval);
          RETURN 1
        ELSE
          DEC (cval, 10000H);
          chars[cpos-cdelta] := LONGCHR (0D800H + cval DIV 1024);
          chars[cpos-cdelta+1] := LONGCHR (0DC00H + cval MOD 1024);
          RETURN 2
        END
      END ToUnicode;
    
    BEGIN
      StorePosition (pos);
      cval := 0;
      IF LookingAt ("&#x", followedByAny) THEN
        INC (cpos, 3); INC (cdelta, 3);
        LOOP
          CASE chars[cpos] OF
          | Buffer.markerEOB:
            NextBlock
          | ";", Buffer.markerEOD:
            EXIT
          | "0".."9":
            IF (cval <= overflow) THEN
              cval := cval*16 + ORD (chars[cpos]) - ORD ("0")
            END;
            INC (cpos); INC (cdelta)
          | "a".."f", "A".."F":
            IF (cval <= overflow) THEN
              cval := cval*16 + (ORD (CAP (chars[cpos])) + 10) - ORD ("A")
            END;
            INC (cpos); INC (cdelta)
          ELSE
            Err (expectedDigit16); cval := errorReplacement; EXIT
          END
        END
      ELSE
        INC (cpos, 2); INC (cdelta, 2);
        LOOP
          CASE chars[cpos] OF
          | Buffer.markerEOB:
            NextBlock
          | ";", Buffer.markerEOD:
            EXIT
          | "0".."9":
            IF (cval <= overflow) THEN
              cval := cval*10 + ORD (chars[cpos]) - ORD ("0")
            END;
            INC (cpos); INC (cdelta)
          ELSE
            Err (expectedDigit10); cval := errorReplacement; EXIT
          END
        END
      END;
      IF (chars[cpos] = ";") THEN INC (cdelta) END;
      CheckChar (";");
      IF ~IsCharUCS4 (cval) THEN
        ErrPos (invalidCharRef, pos); cval := errorReplacement
      END;
      
      DEC (cdelta, ToUnicode (cval))
    END CharRef;

  PROCEDURE EntityRef (enforceDecl, permitExternal: BOOLEAN): DTD.EntityRef;
  (* pre: (chars[cpos] = "&") & (chars[cpos] # "#")
     post: `cstart' is preserved *)
    VAR
      name: DTD.String;
      decl: DTD.Declaration;
      entity: DTD.Entity;
      localCStart: DTD.CharPos;
      pos: Position;
    BEGIN
      StorePosition (pos);
      CheckChar ("&");
      localCStart := p. in. offsetFromPos0+cstart;
      name := Name();
      cstart := localCStart-p. in. offsetFromPos0;
      CheckChar (";");
      
      decl := dtd. geNamespace. Get (name);
      IF (decl = NIL) THEN
        entity := NIL;
        IF enforceDecl & p. processDeclarations & (name # noName) THEN
          ErrPos (noSuchGeneralEntity, pos);
          lastError. SetLStringAttrib ("name", Msg.GetLStringPtr (name^))
        END
      ELSE
        entity := decl(DTD.Entity);
        IF (entity. type = DTD.entityUnparsed) THEN
          ErrPos (referenceToUnparsed, pos);
          lastError. SetLStringAttrib ("name", Msg.GetLStringPtr (name^));
          name := noName
        ELSIF ~permitExternal & (entity. type = DTD.entityExternalGeneral) THEN
          ErrPos (externalRefInAtttribute, pos);
          lastError. SetLStringAttrib ("name", Msg.GetLStringPtr (name^));
          name := noName
        END
      END;
      IF (name = noName) THEN
        (* the name wasn't taken from the input data *)
        RETURN dtd. NewEntityRef (name, entity, noName, 0, 
                                  LongStrings.Length (noName^))
      ELSE
        RETURN dtd. NewEntityRef (name, entity, chars, 
                                  cpos-2-LongStrings.Length (name^), cpos)
      END
    END EntityRef;

  PROCEDURE AttValue (isAttDecl: BOOLEAN): DTD.AttValue;
  (* Parses an attribute value string and returns a data structure containing
     character sequences and general entity references.  The attribute is
     partially normalized by replacing newlines with spaces.  No non-CDATA
     normalization is done, and no general entity references are resolved.  *)
    VAR
      attValue: DTD.AttValue;
      endChar: DTD.Char;
      pos: Position;
    
    PROCEDURE Flush;
      BEGIN
        IF (cpos-cdelta # cstart) THEN
          attValue. Append (dtd. NewCharacters (chars, cstart, cpos-cdelta, isAttDecl));
        END
      END Flush;
    
    BEGIN
      attValue := dtd. NewAttValue();
      IF (chars[cpos] = "'") OR (chars[cpos] = '"') THEN
        StorePosition (pos);
        endChar := chars[cpos];
        INC (cpos);
        cstart := cpos; cdelta:= 0;
        LOOP
          CASE chars[cpos] OF
          | 00X..1FX, Buffer.markerEOB:
            ControlChar (" ")
          | Buffer.markerEOD:
            ErrPos (stringNotClosed, pos);
            Flush;
            EXIT
          | "<":
            Err (lAngleInAttValue);
            chars[cpos-cdelta] := " "; INC (cpos)
          | "&":
            IF LookingAt ("&#", followedByAny) THEN
              (* looking at character reference: replace on the spot *)
              CharRef();
              IF (chars[cpos-cdelta-1] <= " ") &
                 (chars[cpos-cdelta-1] # Ascii.ht) THEN
                (* character reference expanded to a whitespace character;
                   replace it with a space; I'm not 100% sure that this is
                   correct; see xmltest/valid/sa/10[67].xml and the comments
                   in xmltest.xml from the OASIS tests *)
                chars[cpos-cdelta-1] := " "
              END
            ELSE
              Flush;
              attValue. Append (EntityRef (TRUE, FALSE));
              cstart := cpos
            END;
          ELSE
            IF (chars[cpos] = endChar) THEN
              (* if the attribute type is not CDATA, then strip the trailing
                 space; the normalization for such attributes ensures that
                 there is at most one space at the end of the value *)
              Flush;
              CheckChar (SHORT (endChar));
              EXIT
            ELSE
              chars[cpos-cdelta] := chars[cpos]; INC (cpos)
            END
          END
        END
      ELSE
        Err (expectedAttValue); NextChar
      END;
      RETURN attValue
    END AttValue;

  PROCEDURE element;
    VAR
      emptyElementTag: BOOLEAN;
      startName, endName: DTD.String;
      attrName: DTD.String;
      attrValue: DTD.AttValue;
      decl, decl0: DTD.Declaration;
      attrDecl: DTD.AttrDecl;
      pos: Position;
      
    PROCEDURE content;
    (* post: chars[cpos] # Buffer.markerEOB *)

      PROCEDURE CharData;
      (* This procedure matches character data and character references.  The
         latter are included for efficiency reasons.  A text sequence with
         with embedded character references will cause only a single up 
         call.  *)
        BEGIN
          cstart := cpos; cdelta := 0;
          
          LOOP  (* loop invariant: cdelta = 0 *)
            (* this is a very specialized version of the loop down below; it
               covers the case where `cdelta' stays zero, which means that
               no characters must be copied *)
            CASE chars[cpos] OF
            | 00X..1FX, Buffer.markerEOB:
              IF (chars # p. in. chars) THEN
                INC (cpos)
              ELSE
                ControlChar (Ascii.lf);
                IF (cdelta # 0) THEN
                  EXIT
                END
              END
            | "<", "&", Buffer.markerEOD:
              EXIT
            | "]":
              IF LookingAt ("]]>", followedByAny) THEN
                EXIT
              ELSE
                INC (cpos)
              END
            ELSE
              INC (cpos)
            END
          END;
          
          LOOP
            CASE chars[cpos] OF
            | 00X..1FX, Buffer.markerEOB:
              IF (chars # p. in. chars) THEN
                (* when expanding an entity reference, no translation of
                   end of line characters is done; the reason for this is that
                   they have already been normalized when parsing the entity
                   value, and any remaining CR/LF characters have been
                   explicitly introduced through character references *)
                chars[cpos-cdelta] := chars[cpos]; INC (cpos)
              ELSE
                ControlChar (Ascii.lf)
              END
            | "<", Buffer.markerEOD:
              EXIT
            | "&":
              IF LookingAt ("&#", followedByAny) THEN (* character reference *)
                CharRef()
              ELSE
                EXIT
              END
            | "]":
              IF LookingAt ("]]>", followedByAny) THEN
                Err (invalidCloseCDATA)
              END;
              chars[cpos-cdelta] := chars[cpos]; INC (cpos)
            ELSE
              chars[cpos-cdelta] := chars[cpos]; INC (cpos)
            END
          END;
          
          IF (cpos-cdelta # cstart) THEN
            p. builder. Characters (chars^, cstart, cpos-cdelta,
                                    DTD.elementWhitespaceUnknown, FALSE)
          END
        END CharData;

      PROCEDURE FollowEntityRef (entityRef: DTD.EntityRef);
        VAR
          decl: DTD.Declaration;
          entity: DTD.Entity;
          pos: Position;
        BEGIN
          decl := dtd. geNamespace. Get (entityRef. name);
          entity := NIL;
          IF (decl # NIL) THEN
            entity := decl(DTD.Entity)
          END;
          
          IF (entity = NIL) THEN
            StorePosition (pos);
            IF (chars = p. in. chars) THEN
              DecLength (pos, LongStrings.Length (entityRef. name^)+2)
            END;
            ErrPos (noSuchGeneralEntity, pos);
            lastError. SetLStringAttrib ("name",
                                         Msg.GetLStringPtr (entityRef. name^))
          ELSIF entity. expanding THEN
            Err (recursiveGeneralEntity);
            lastError. SetLStringAttrib ("name",
                                         Msg.GetLStringPtr (entityRef. name^))
          ELSIF (entity. type = DTD.entityExternalGeneral) &
                ~p. followExternalRef THEN
            p. builder. SkippedEntity (entityRef. name, entity)
          ELSE
            p. builder. StartEntity (entity);
            PushEntity (entity, TRUE);
            StorePosition (pos);
            (* recursivly enter replacement; FIXME: endless loop? *)
            IF (entity. type = DTD.entityExternalGeneral) &
               LookingAt ("<?xml", followedByNonName) THEN
              XMLDecl (decl(DTD.ExternalEntity))
            END;
            content;
            IF (chars[cpos] # Buffer.markerEOD) THEN
              ErrPos (invalidGEReplacement, pos);
              lastError. SetLStringAttrib ("name",
                                          Msg.GetLStringPtr (entityRef. name^))
            END;
            PopEntity;
            p. builder. EndEntity (entity);
          END
        END FollowEntityRef;
      
      BEGIN
        LOOP
          CASE chars[cpos] OF
          | Buffer.markerEOD:
            EXIT
          | "<":
            IF LookingAt ("<!--", followedByAny) THEN
              Comment
            ELSIF LookingAt ("<![CDATA[", followedByAny) THEN
              CDSect
            ELSIF LookingAt ("<?", followedByAny) THEN
              PI
            ELSIF (chars[cpos+1] # "/") THEN
              element
            ELSE
              EXIT
            END;
          | "&":
            IF LookingAt ("&#", followedByAny) THEN (* character reference *)
              CharData
            ELSE
              FollowEntityRef (EntityRef (FALSE, TRUE))
            END
          ELSE
            CharData
          END
        END
      END content;
    
    PROCEDURE Expand (attValue: DTD.AttValue);
      VAR
        fragment: DTD.Fragment;
        decl: DTD.Declaration;
        entity: DTD.Entity;
        
      PROCEDURE IsRecursive (entity: DTD.Entity): BOOLEAN;
        VAR
          fragment: DTD.Fragment;
        BEGIN
          IF entity. expanding THEN
            RETURN TRUE
          ELSE
            entity. expanding := TRUE;
            fragment := entity. attValue. fragmentList;
            WHILE (fragment # NIL) DO
              WITH fragment: DTD.EntityRef DO
                IF (fragment. entity # NIL) &
                   IsRecursive (fragment. entity) THEN
                  entity. expanding := FALSE;
                  RETURN TRUE
                END
              ELSE                           (* ignore *)
              END;
              fragment := fragment. next
            END;
            entity. expanding := FALSE;
            RETURN FALSE
          END
        END IsRecursive;

      PROCEDURE ExpandAttValue (entity: DTD.Entity): DTD.AttValue;
        VAR
          attValue: DTD.AttValue;
        
        PROCEDURE Flush;
          BEGIN
            IF (cpos # cstart) THEN
              attValue. Append (dtd. NewCharacters (chars, cstart, cpos, FALSE))
            END
          END Flush;

        BEGIN
          IF (entity IS DTD.ExternalEntity) THEN
            entity. SetEntityValue (Internalize (entity(DTD.ExternalEntity)))
          END;
                    
          PushEntity (entity, FALSE);
          attValue := dtd. NewAttValue();
          cstart := cpos;
          LOOP
            CASE chars[cpos] OF
            | Buffer.markerEOD:
              Flush;
              EXIT
            | 00X .. 1FX:
              (* the entity value has been cleaned of end of line artifacts or
                  invalid characters; any remaining whitespace must be replaced
                  with " " *)
              IF (chars[cpos] # Ascii.ht) THEN
                chars[cpos] := " "
              END
            | "<":
              Err (lAngleInAttValue);
              INC (cpos)
            | "&":
              Flush;
              IF LookingAt ("&#", followedByAny) THEN
                (* looking at character reference: replace on the spot *)
                cstart := cpos; cdelta := 0;
                CharRef();
                attValue. Append (dtd. NewCharacters (chars, cstart, cpos-cdelta, FALSE))
              ELSE
                attValue. Append (EntityRef (TRUE, FALSE))
              END;
              cstart := cpos
            ELSE
              INC (cpos)
            END
          END;
          PopEntity;
          RETURN attValue
        END ExpandAttValue;

      BEGIN
        fragment := attValue. fragmentList;
        WHILE (fragment # NIL) DO
          WITH fragment: DTD.EntityRef DO
            decl := dtd. geNamespace. Get (fragment. name);
            IF (decl = NIL) THEN
              Err (noSuchGeneralEntity);
              lastError. SetLStringAttrib ("name", Msg.GetLStringPtr (fragment. name^))
            ELSE
              entity := decl(DTD.Entity);
              fragment. entity := entity;
              IF (entity. attValue = NIL) THEN
                entity. attValue := ExpandAttValue (entity);
                Expand (entity. attValue)
              END;
              
              IF IsRecursive (entity) THEN
                Err (recursiveGeneralEntity);
                lastError. SetLStringAttrib ("name", Msg.GetLStringPtr (entity. name^));
                fragment. entity. attValue. Clear
              END
            END
          ELSE                           (* leave characters as is *)
          END;
          fragment := fragment. next
        END
      END Expand;
    
    PROCEDURE NoteName (name: DTD.String);
      VAR
        newList: NameList;
        i: LONGINT;
      BEGIN
        IF (p. lenNameList = LEN (p. nameList^)) THEN
          NEW (newList, LEN (p. nameList^)+incrNameList);
          FOR i := 0 TO LEN (p. nameList^)-1 DO
            newList[i] := p. nameList[i]
          END;
          p. nameList := newList
        END;
        p. nameList[p. lenNameList] := name;
        INC (p. lenNameList)
      END NoteName;
    
    PROCEDURE AttributeNameUsed (name: DTD.String): BOOLEAN;
      VAR
        i: LONGINT;
      BEGIN
        FOR i := 0 TO p. lenNameList-1 DO
          IF (name^ = p. nameList[i]^) THEN
            RETURN TRUE
          END
        END;
        RETURN FALSE
      END AttributeNameUsed;
    
    PROCEDURE CheckXmlLang (attrValue: DTD.AttValue);
      VAR
        string: DTD.String;
        err: BOOLEAN;
        langCode: SHORTINT;
        pos: LONGINT;
      CONST
        langCodeIana = 0;
        langCodeUser = 1;
        langCodeISO639 = 2;
      
      PROCEDURE IsLetter (ch: DTD.Char): BOOLEAN;
        BEGIN
          RETURN ("A" <= CAP (ch)) & (CAP (ch) <= "Z")
        END IsLetter;
      
      BEGIN
        string := attrValue. Flatten (NIL);
        err := FALSE;
        pos := 0;
        (* parse language code *)
        IF (CAP (string[pos]) = "I") & (string[pos+1] = "-") THEN
          langCode := langCodeIana;
          INC (pos, 2);
          WHILE IsLetter (string[pos]) DO
            INC (pos)
          END;
          err := (pos = 2)               (* not letter after "-" *)
        ELSIF (CAP (string[pos]) = "X") & (string[pos+1] = "-") THEN
          langCode := langCodeUser;
          INC (pos, 2);
          WHILE IsLetter (string[pos]) DO
            INC (pos)
          END;
          err := (pos = 2)               (* not letter after "-" *)
        ELSIF IsLetter (string[pos]) & IsLetter (string[pos+1]) THEN
          langCode := langCodeISO639;
          INC (pos, 2)
        ELSE
          err := TRUE
        END;
        
        (* parse list of subcodes *)
        WHILE ~err & (string[pos] = "-") DO
          INC (pos);
          IF IsLetter (string[pos]) THEN
            REPEAT
              INC (pos)
            UNTIL ~IsLetter (string[pos])
          ELSE
            err := TRUE
          END
        END;
        
        err := err OR (string[pos] # 0X);
        IF err THEN
          Err (invalidLangCode)
        END
      END CheckXmlLang;
    
    PROCEDURE AddDefaultAttributes (elemDecl: DTD.ElementDecl);
      VAR
        decl: DTD.Declaration;
        attrDecl: DTD.AttrDecl;
      
      PROCEDURE AttributeDefined (name: DTD.String): BOOLEAN;
        VAR
          i: LONGINT;
        BEGIN
          i := 0;
          WHILE (i # p. lenNameList) DO
            IF (p. nameList[i]^ = name^) THEN
              RETURN TRUE
            END;
            INC (i)
          END;
          RETURN FALSE
        END AttributeDefined;
      
      BEGIN
        decl := elemDecl. attrNamespace. declList;
        WHILE (decl # NIL) DO
          attrDecl := decl(DTD.AttrDecl);
          IF (attrDecl. default >= DTD.attrDefault) & 
             ~AttributeDefined (attrDecl. name) THEN
            Expand (attrDecl. defaultValue);
            IF (attrDecl. name^ = "xml:lang") THEN
              CheckXmlLang (attrDecl. defaultValue)
            END;
            p. builder. ElementAttribute (NIL, decl. name, attrDecl,
                                          attrDecl. defaultValue, FALSE)
          END;
          decl := decl. next
        END
      END AddDefaultAttributes;
    
    PROCEDURE ErrEndTag;
      BEGIN
        IF (startName # noName) THEN
          ErrPos (expectedEndTag, pos);
          lastError. SetLStringAttrib ("name", Msg.GetLStringPtr (startName^))
        END
      END ErrEndTag;
    
    BEGIN
      IF (chars[cpos] = "<") THEN
        CheckChar ("<");
        p. lenNameList := 0;
        emptyElementTag := FALSE;
        startName := Name();
        decl := dtd. elementNamespace. Get (startName);
        p. builder. StartElement (NIL, startName);
        LOOP
          IF (chars[cpos] = Buffer.markerEOD) THEN
            EXIT
          ELSIF (chars[cpos] # ">") & (chars[cpos] # "/") THEN
            S
          END;
          IF (chars[cpos] = "/") THEN
            CheckChar ("/");
            emptyElementTag := TRUE;
            EXIT
          ELSIF (chars[cpos] = ">") THEN
            EXIT
          END;
          
          StorePosition (pos);
          attrName := Name();
          IF AttributeNameUsed (attrName) THEN
            ErrPos (multipleAttrName, pos);
            lastError. SetLStringAttrib ("name", Msg.GetLStringPtr (attrName^))
          END;
          NoteName (attrName);
          Eq;
          attrDecl := NIL;
          IF (decl # NIL) THEN
            decl0 := decl(DTD.ElementDecl). attrNamespace. Get (attrName);
            IF (decl0 # NIL) THEN
              attrDecl := decl0(DTD.AttrDecl)
            END
          END;
          attrValue := AttValue (TRUE);
          Expand (attrValue);
          IF (attrName^ = "xml:lang") THEN
            CheckXmlLang (attrValue)
          END;
          p. builder. ElementAttribute (NIL, attrName, attrDecl, attrValue, TRUE)
        END;
        
        IF (decl # NIL) THEN
          AddDefaultAttributes (decl(DTD.ElementDecl))
        END;
        p. builder. AttributesDone();
        
        CheckChar (">");
        DiscardPreviousInput;
        IF emptyElementTag THEN
          p. builder. EndElement (NIL, startName)
        ELSE
          content;
          StorePosition (pos);
          IF (chars[cpos] # "<") THEN ErrEndTag END;
          CheckChar ("<");
          IF (chars[cpos] # "/") THEN ErrEndTag END;
          CheckChar ("/");
          endName := Name();
          IF (endName^ # startName^) THEN ErrEndTag END;
          p. builder. EndElement (NIL, startName);
          OptS (TRUE);
          CheckChar (">")
        END
      ELSE
        Err (expectedElement)
      END
    END element;
  
  PROCEDURE MiscRep;
  (* post: chars[cpos] # Buffer.markerEOB *)
    BEGIN
      LOOP
        CASE chars[cpos] OF
        | Buffer.markerEOB:
          NextBlock
        | "<":
          IF LookingAt ("<!--", followedByAny) THEN
            Comment
          ELSIF LookingAt ("<?", followedByAny) THEN
            PI
          ELSE
            EXIT
          END
        | 00X.." ":
          S
        ELSE
          EXIT
        END
      END
    END MiscRep;
  
  PROCEDURE ExternalID (optionJustPubid: BOOLEAN;
                        VAR public, system: DTD.String; VAR baseURI: URI.URI);
  (* pre: ExternalID is optionally followed by S *)
    
    PROCEDURE CheckURI (str16: DTD.String): URI.URI;
      VAR
        len16, len8, i: INTEGER;
        codec: Codec.Codec;
        str8: POINTER TO ARRAY OF CHAR;
        repl: ARRAY 4 OF CHAR;
        srcDone, destDone: LONGINT;
        uri: URI.URI;
        res: Msg.Msg;
        
      PROCEDURE ToHex (i: INTEGER): CHAR;
        BEGIN
          IF (i < 10) THEN
            RETURN CHR (i+ORD ("0"))
          ELSE
            RETURN CHR (i+(ORD ("A")-10))
          END
        END ToHex;

      BEGIN
        len16 := LongStrings.Length (str16^);
        len8 := len16*9+1;
        NEW (str8, len8);
        (* conservative approximation: UCS-2 character code is mapped to at
           most 3 bytes, a UCS-2 surrogate pair to 2 characters each; then,
           a non-ASCII character is encoded as %HH *)
        codec := UTF8.factory. NewCodec();
        
        (* encode UCS-2 character sequence as UTF-8 character sequence *)
        IF (len16 # 0) THEN
          codec. Encode (str16^, 0, len16, str8^, 0, len8, srcDone, destDone);
          IF (srcDone # len16) THEN
            codec. Encode (str16^, srcDone, len16, str8^, destDone, len8,
                           srcDone, destDone);
            ASSERT (srcDone = len16)
          END;
          str8[destDone] := 0X
        ELSE
          COPY ("", str8^)
        END;
        
        (* encode every non-ASCII character in the UTF-8 string to %HH *)
        i := 0;
        WHILE (str8[i] # 0X) DO
          IF (str8[i] >= 80X) THEN
            repl := "%HH";
            repl[1] := ToHex (ORD (str8[i]) DIV 16);
            repl[2] := ToHex (ORD (str8[i]) MOD 16);
            Strings.Delete (str8^, i, 1);
            Strings.Insert (str8^, i, repl);
            INC (i, 3)
          ELSE
            INC (i)
          END
        END;
        
        IF (p. fileEntity. baseURI # NIL) &
           (p. fileEntity. baseURI IS URI.HierarchicalURI) THEN
          uri := URIParser.NewURI (str8^, p. fileEntity. baseURI(URI.HierarchicalURI), res)
        ELSE
          uri := URIParser.NewURI (str8^, NIL, res)
        END;
        IF (res # NIL) THEN
          Err (malformedURI);
          lastError. SetMsgAttrib ("uri_error", res)
        END;
        RETURN uri
      END CheckURI;
    
    BEGIN                                (* ... needs entity resolver *)
      public := NIL;
      system := NIL;
      baseURI := NIL;
      IF LookingAt ("SYSTEM", followedByNonName) THEN
        INC (cpos, 6);               (* skip over "SYSTEM" *)
        S;
        system := String (stringSystemLiteral);
        baseURI := CheckURI (system)
      ELSIF LookingAt ("PUBLIC", followedByNonName) THEN
        INC (cpos, 6);               (* skip over "PUBLIC" *)
        S;
        public := String (stringPubidLiteral);
        IF ~optionJustPubid OR LookingAtS() THEN
          S;
          IF ~optionJustPubid OR
             (chars[cpos] = "'") OR (chars[cpos] = '"') THEN
            system := String (stringPubidLiteral);
            baseURI := CheckURI (system)
          END
        END
      ELSE
        Err (expectedExternalID)
      END
    END ExternalID;

  PROCEDURE markupdecl;
    PROCEDURE elementdecl;
    (* pre: looking at "<!ELEMENT"+NonName *)
      VAR
        elementName: DTD.String;
        cp: DTD.CP;
        elementDecl: DTD.ElementDecl;
        dummy: BOOLEAN;
        
      PROCEDURE contentspec(): DTD.CP;
        PROCEDURE Mixed(): DTD.CP;
        (* pre: looking at "#PCDATA"+nonNameChar *)
          VAR
            hasAlternative: BOOLEAN;
            first, last: DTD.CP;
          BEGIN
            first := dtd. NewNameCP (DTD.cpOnce, GetString (cpos, cpos+7));
            INC (cpos, 7);             (* skip over "#PCDATA" *)
            last := first;
            OptS (FALSE);
            hasAlternative := FALSE;
            WHILE (chars[cpos] = "|") DO
              hasAlternative := TRUE;
              CheckChar ("|");
              OptS (FALSE);
              last. SetNext (dtd. NewNameCP (DTD.cpOnce, Name()));
              OptS (FALSE)
            END;
            CheckChar (")");
            IF hasAlternative OR (chars[cpos] = "*") THEN
              CheckChar ("*");
              RETURN dtd. NewChoiceCP (DTD.cpRepeat0, first)
            ELSE
              RETURN dtd. NewChoiceCP (DTD.cpOnce, first)
            END
          END Mixed;

        PROCEDURE children(): DTD.CP;
        (* pre: character before chars[cpos] was "("+S? *)
          VAR
            cp: DTD.CP;

          PROCEDURE Quantifier(): DTD.CPModeType;
          (* pre: chars[cpos] # markerEOB *)
            BEGIN
              CASE chars[cpos] OF
              | "*": CheckChar ("*"); RETURN DTD.cpRepeat0
              | "+": CheckChar ("+"); RETURN DTD.cpRepeat1
              | "?": CheckChar ("?"); RETURN DTD.cpOptional
              ELSE
                RETURN DTD.cpOnce
              END
            END Quantifier;

          PROCEDURE choiceseq(): DTD.CP;
          (* pre: character before chars[cpos] was "("+S? *)
            VAR
              class: DTD.Char;
              first, last: DTD.CP;

            PROCEDURE cp(): DTD.CP;
            (* pre: chars[cpos] # markerEOB *)
              VAR
                cp: DTD.CP;
              BEGIN
                IF (chars[cpos] = "(") THEN
                  CheckChar ("(");
                  OptS (FALSE);
                  cp := choiceseq()
                ELSIF IsNameChar0 (chars[cpos]) THEN
                  cp := dtd. NewNameCP (DTD.cpOnce, Name())
                ELSE
                  Err (expectedCP);
                  cp := dtd. NewNameCP (DTD.cpOnce, noName)
                END;
                cp. SetMode (Quantifier());
                RETURN cp
              END cp;

            BEGIN
              class := 0X;
              first := cp();
              OptS (FALSE);
              last := first;
              LOOP
                CASE chars[cpos] OF
                | Buffer.markerEOB:
                  NextBlock
                | ",", "|":
                  IF (class = 0X) THEN
                    class := chars[cpos]
                  END;
                  CheckChar (SHORT (class));
                  OptS (FALSE);
                  last. SetNext (cp());
                  OptS (FALSE)
                ELSE                   (* end of document, or other char *)
                  EXIT
                END
              END;
              CheckChar (")");

              IF (class = ",") THEN
                RETURN dtd. NewSeqCP (DTD.cpOnce, first)
              ELSE
                RETURN dtd. NewChoiceCP (DTD.cpOnce, first)
              END
            END choiceseq;

          BEGIN
            cp := choiceseq();
            cp. SetMode (Quantifier());
            RETURN cp
          END children;

        BEGIN
          IF LookingAt ("EMPTY", followedByNonName) THEN
            RETURN dtd. NewNameCP (DTD.cpOnce, Name())
          ELSIF LookingAt ("ANY", followedByNonName) THEN
            RETURN dtd. NewNameCP (DTD.cpOnce, Name())
          ELSIF (chars[cpos] = "(") THEN
            CheckChar ("(");
            OptS (FALSE);
            IF LookingAt ("#PCDATA", followedByNonName) THEN
              RETURN Mixed()
            ELSE
              RETURN children()
            END
          ELSE
            Err (expectedContentSpec);
            RETURN dtd. NewNameCP (DTD.cpOnce, noName)
          END
        END contentspec;

      BEGIN
        INC (cpos, 9);                 (* skip over "<!ELEMENT" *)
        S;
        elementName := Name();
        S;
        cp := contentspec();
        OptS (FALSE);

        elementDecl := dtd. NewElementDecl (elementName, cp);
        dummy := dtd. elementNamespace. Add (elementDecl);

        CheckChar (">")
      END elementdecl;

    PROCEDURE AttListDecl;
    (* pre: looking at "<!ATTLIST"+NonName *)
      VAR
        elementName, attrName: DTD.String;
        attrType: DTD.AttributeType;
        attrEnumeration: DTD.Enumeration;
        default: DTD.DefaultType;
        defaultValue: DTD.AttValue;
        attrDecl: DTD.AttrDecl;

      PROCEDURE AttType (VAR attrType: DTD.AttributeType;
                         VAR enum: DTD.Enumeration);
      (* post: chars[cpos] # Buffer.markerEOB *)

        PROCEDURE Enumeration (attrType: DTD.AttributeType): DTD.Enumeration;
          BEGIN
            enum := dtd. NewEnumeration();
            CheckChar ("(");
            LOOP
              OptS (FALSE);
              CASE attrType OF
              | DTD.attrNOTATION:
                enum. Append (Name())
              | DTD.attrENUMERATED:
                enum. Append (Nmtoken())
              END;
              OptS (FALSE);
              IF (chars[cpos] = "|") THEN
                CheckChar ("|")
              ELSE
                EXIT
              END
            END;
            CheckChar (")");
            RETURN enum
          END Enumeration;

        BEGIN
          enum := NIL;
          IF LookingAt ("CDATA", followedByNonName) THEN
            INC (cpos, 5);
            attrType := DTD.attrCDATA
          ELSIF LookingAt ("ID", followedByNonName) THEN
            INC (cpos, 2);
            attrType := DTD.attrID
          ELSIF LookingAt ("IDREF", followedByNonName) THEN
            INC (cpos, 5);
            attrType := DTD.attrIDREF
          ELSIF LookingAt ("IDREFS", followedByNonName) THEN
            INC (cpos, 6);
            attrType := DTD.attrIDREFS
          ELSIF LookingAt ("ENTITY", followedByNonName) THEN
            INC (cpos, 6);
            attrType := DTD.attrENTITY
          ELSIF LookingAt ("ENTITIES", followedByNonName) THEN
            INC (cpos, 8);
            attrType := DTD.attrENTITIES
          ELSIF LookingAt ("NMTOKEN", followedByNonName) THEN
            INC (cpos, 7);
            attrType := DTD.attrNMTOKEN
          ELSIF LookingAt ("NMTOKENS", followedByNonName) THEN
            INC (cpos, 8);
            attrType := DTD.attrNMTOKENS
          ELSIF LookingAt ("NOTATION", followedByNonName) OR
                (chars[cpos] = "(") THEN
            IF (chars[cpos] = "(") THEN
              attrType := DTD.attrENUMERATED
            ELSE
              attrType := DTD.attrNOTATION;
              INC (cpos, 8);           (* skip over "NOTATION" *)
              S
            END;
            enum := Enumeration (attrType)
          ELSE
            Err (expectedAttType);
            NextChar;
            attrType := DTD.attrCDATA
          END
        END AttType;

      PROCEDURE DefaultDecl (attrType: DTD.AttributeType;
                             VAR default: DTD.DefaultType;
                             VAR defaultValue: DTD.AttValue);
        BEGIN
          defaultValue := NIL;
          IF LookingAt ("#REQUIRED", followedByNonName) THEN
            INC (cpos, 9);
            default := DTD.attrRequired
          ELSIF LookingAt ("#IMPLIED", followedByNonName) THEN
            INC (cpos, 8);
            default := DTD.attrImplied
          ELSE
            IF LookingAt ("#FIXED", followedByNonName) THEN
              INC (cpos, 6);           (* skip over "#FIXED" *)
              S;
              default := DTD.attrFixed
            ELSE
              default := DTD.attrDefault
            END;
            defaultValue := AttValue (TRUE)
          END
        END DefaultDecl;

      BEGIN
        INC (cpos, 9);                 (* skip over "<!ATTLIST" *)
        S;
        elementName := Name();
        LOOP
          IF (chars[cpos] # ">") THEN
            S
          END;
          IF (chars[cpos] = ">") OR (chars[cpos] = Buffer.markerEOD) THEN
            EXIT
          END;

          attrName := Name();
          S;
          AttType (attrType, attrEnumeration);
          S;
          DefaultDecl (attrType, default, defaultValue);
          IF p. processDeclarations THEN
            attrDecl := dtd. NewAttrDecl (elementName, attrName,
              attrType, attrEnumeration, default, defaultValue);
            dtd. AddAttribute (attrDecl)
          END
        END;
        CheckChar (">")
      END AttListDecl;

    PROCEDURE EntityDecl;
    (* pre: looking at "<!ENTITY"+NonName *)
      VAR
        name: DTD.String;
        isPEntity: BOOLEAN;
        entityValue, public, system, ndata: DTD.String;
        baseURI: URI.URI;
        entity: DTD.Entity;
        entityType: DTD.EntityType;
        dummy: BOOLEAN;

      PROCEDURE EntityValue (isPEntity: BOOLEAN): DTD.String;
      (* pre: chars[cpos] # Buffer.markerEOB *)
        VAR
          endChar: DTD.Char;
          pos: Position;
          storedPos: DTD.CharPos;
          string: DTD.String;
          fragment: DTD.Fragment;
          startLevel: LONGINT;

        PROCEDURE Copy (start, end: DTD.CharPos);
          BEGIN
            WHILE (start # end) DO
              chars[start-cdelta] := chars[start];
              INC (start)
            END
          END Copy;

        BEGIN
          string := noName;
          IF (chars[cpos] = "'") OR (chars[cpos] = '"') THEN
            (* if the entity value contains parameter entity references, all
               the pieces are collected first into `p. currEntityValue', and are only
               at the very end rewritten into one large string *)
            p. currEntityValue := dtd. NewAttValue();
            
            StorePosition (pos);
            startLevel := p. lenPEStack;
            endChar := chars[cpos];
            INC (cpos);
            cstart := cpos; cdelta := 0;
            LOOP
              CASE chars[cpos] OF
              | 00X..1FX, Buffer.markerEOB:
                ControlChar (Ascii.lf)
              | Buffer.markerEOD:
                ErrPos (stringNotClosed, pos);
                p. currEntityValue. Append (dtd. NewCharacters (chars, cstart, cpos-cdelta, TRUE));
                EXIT
              | "%":
                IF (cstart # cpos-cdelta) THEN
                  (* append character sequence before the PE reference to
                     the fragment list *)
                  p. currEntityValue. Append (dtd. NewCharacters (chars, cstart, cpos-cdelta, TRUE))
                END;
                PEReference (FALSE);
                (* note: PopEntity will attach the characters from within the
                   reference to `currEntityValue'; it will also reset
                   `cstart' and `cdelta' *)
              | "&":
                IF LookingAt ("&#", followedByAny) THEN
                  (* looking at character reference: replace on the spot *)
                  CharRef()
                ELSE
                  storedPos := cpos+p. in. offsetFromPos0;
                  fragment := EntityRef (FALSE, TRUE);
                  Copy (storedPos-p. in. offsetFromPos0, cpos)
                END
              ELSE
                IF (chars[cpos] = endChar) & (p. lenPEStack = startLevel) THEN
                  (* only recognize the string end delimiter if we are not
                     expanding any entity references *)
                  p. currEntityValue. Append (dtd. NewCharacters (chars, cstart, cpos-cdelta, TRUE));
                  CheckChar (SHORT (endChar));
                  EXIT
                ELSE
                  chars[cpos-cdelta] := chars[cpos]; INC (cpos)
                END
              END
            END;
            string := p. currEntityValue. Flatten (NIL);
            IF isPEntity THEN
              string[LEN (string^)-2] := Buffer.markerEOB
            ELSE
              string[LEN (string^)-2] := Buffer.markerEOD
            END;
            p. currEntityValue := NIL
          ELSE
            Err (expectedEntityValue); NextChar
          END;
          RETURN string
        END EntityValue;

      BEGIN
        INC (cpos, 8);                 (* skip over entity *)
        SnoPE;
        isPEntity := (chars[cpos] = "%");
        IF isPEntity THEN
          CheckChar ("%");
          S
        END;
        name := Name();
        S;
        IF (chars[cpos] = "'") OR (chars[cpos] = '"') THEN
          public := NIL; system := NIL; ndata := NIL;
          entityValue := EntityValue (isPEntity);

          IF isPEntity THEN
            entityType := DTD.entityInternalParameter
          ELSE
            entityType := DTD.entityInternalGeneral
          END;
          entity := dtd. NewInternalEntity (name, entityType, entityValue, FALSE)
        ELSE
          entityValue := NIL;
          IF isPEntity THEN
            entityType := DTD.entityExternalParameter
          ELSE
            entityType := DTD.entityExternalGeneral
          END;
          ExternalID (FALSE, public, system, baseURI);

          ndata := NIL;
          IF ~isPEntity & LookingAtS() THEN
            S;
            IF LookingAt ("NDATA", followedByNonName) THEN
              entityType := DTD.entityUnparsed;
              INC (cpos, 5);           (* skipt over "NDATA" *)
              S;
              ndata := Name()
            END
          END;
          entity := dtd. NewExternalEntity (name, entityType, public, system, ndata, baseURI)
        END;
        OptS (FALSE);
        CheckChar (">");

        IF p. processDeclarations THEN
          IF isPEntity THEN
            dummy := dtd. peNamespace. Add (entity)
          ELSIF dtd. geNamespace. Add (entity) THEN
            p. builder. EntityDecl (entity)
          END
        END
      END EntityDecl;

    PROCEDURE NotationDecl;
    (* pre: looking at "<!NOTATION"+NonName *)
      VAR
        name, public, system: DTD.String;
        baseURI: URI.URI;
      BEGIN
        INC (cpos, 10);                (* skipt over "<!NOTATION" *)
        S;
        name := Name();
        S;
        ExternalID (TRUE, public, system, baseURI);
        OptS (FALSE);
        p. builder. Notation (dtd. NewNotation (name, public, system, baseURI));
        CheckChar (">")
      END NotationDecl;

    BEGIN
      IF LookingAt ("<!ELEMENT", followedByNonName) THEN
        elementdecl
      ELSIF LookingAt ("<!ATTLIST", followedByNonName) THEN
        AttListDecl
      ELSIF LookingAt ("<!ENTITY", followedByNonName) THEN
        EntityDecl
      ELSIF LookingAt ("<!NOTATION", followedByNonName) THEN
        NotationDecl
      ELSIF LookingAt ("<?", followedByAny) THEN
        PI
      ELSIF LookingAt ("<!--", followedByAny) THEN
        Comment
      ELSE
        Err (expectedMarkupDecl); NextChar
      END;
      DiscardPreviousInput
    END markupdecl;

  PROCEDURE extSubsetDecl;
    VAR
      pos: Position;
      
    PROCEDURE ignoreSectContents;
      VAR
        level: LONGINT;
      BEGIN
        level := 1;
        cstart := cpos; cdelta := 0;
        LOOP
          CASE chars[cpos] OF
          | 00X..1FX, Buffer.markerEOB:
            ControlChar (Ascii.lf)
          | Buffer.markerEOD:
            ErrPos (ignoreNotClosed, pos);
            EXIT
          | "]":
            IF LookingAt ("]]>", followedByAny) THEN
              INC (cpos, 3);             (* skip over "]]>" *)
              DEC (level);
              IF (level = 0) THEN
                EXIT
              END
            ELSE
              chars[cpos-cdelta] := chars[cpos]; INC (cpos)
            END
          | "<":
            IF LookingAt ("<![", followedByAny) THEN
              INC (cpos, 3);             (* skip over "]]>" *)
              INC (level)
            ELSE
              chars[cpos-cdelta] := chars[cpos]; INC (cpos)
            END
          ELSE
            chars[cpos-cdelta] := chars[cpos]; INC (cpos)
          END
        END
      END ignoreSectContents;
    
    BEGIN
      LOOP
        IF (chars[cpos] = "<") THEN
          StorePosition (pos);
          IF LookingAt ("<![", followedByAny) THEN
            INC (cpos, 3);           (* skip over "<![" *)
            OptS (FALSE);
            IF LookingAt ("INCLUDE", followedByNonName) THEN
              INC (cpos, 7);         (* skip over "INCLUDE" *)
              OptS (FALSE);
              CheckChar ("[");
              extSubsetDecl;
              IF LookingAt ("]]>", followedByAny) THEN
                INC (cpos, 3)        (* skip over "]]>" *)
              ELSE
                Err (expectedEOS)
              END
            ELSIF LookingAt ("IGNORE", followedByNonName) THEN
              INC (cpos, 6);         (* skip over "IGNORE" *)
              OptS (FALSE);
              CheckChar ("[");
              ignoreSectContents
            ELSE
              Err (expectedConditional)
            END
          ELSE
            markupdecl
          END
        ELSIF (chars[cpos] = "%") THEN
          PEReference (TRUE)
        ELSIF LookingAtSnoPE() THEN
          SnoPE
        ELSE
          EXIT
        END
      END;
    END extSubsetDecl;

  PROCEDURE prolog;
    PROCEDURE doctypedecl;
      VAR
        rootName, public, system: DTD.String;
        baseURI: URI.URI;
        externalSubset: DTD.ExternalEntity;
      BEGIN  (* pre: looking at "<!DOCTYPE"+NonName *)
        p. inDTD := TRUE;
        p. builder. StartDTD;
        INC (cpos, 9);                   (* skip over "<!DOCTYPE" *)
        S;
        rootName := Name();
        OptS (FALSE);
        IF LookingAt ("SYSTEM", followedByAny) OR
           LookingAt ("PUBLIC", followedByAny) THEN
          (* this implies that there was some whitespace between the name
             and the current character *)
          ExternalID (FALSE, public, system, baseURI); 
          OptS (FALSE)
        ELSE
          system := NIL; public := NIL; baseURI := NIL
        END;
        IF (chars[cpos] = "[") THEN
          CheckChar ("[");
          LOOP
            IF (chars[cpos] = "<") THEN
              markupdecl
            ELSIF (chars[cpos] = "%") THEN
              PEReference (TRUE)
            ELSIF LookingAtSnoPE() THEN
              SnoPE
            ELSE
              EXIT
            END
          END;
          IF (p. lenPEStack # 0) THEN
            Err (unbalancedPERef)
          END;
          CheckChar ("]");
          OptS (FALSE)
        END;
        CheckChar (">");
        
        IF (public # NIL) OR (system # NIL) THEN
          externalSubset := dtd. NewExternalDTD (public, system, baseURI);
          PushEntity (externalSubset, TRUE);
          p. inExternalSubset := TRUE;
          IF LookingAt ("<?xml", followedByNonName) THEN
            XMLDecl (externalSubset)
          END;
          extSubsetDecl;
          p. inExternalSubset := FALSE;
          IF (chars[cpos] # Buffer.markerEOD) THEN
            Err (junkAfterExtSubset)
          END;
          PopEntity
        ELSE
          externalSubset := NIL;
        END;
        p. builder. EndDTD (externalSubset);
        p. inDTD := FALSE
      END doctypedecl;
    
    BEGIN
      IF LookingAt ("<?xml", followedByNonName) THEN
        XMLDecl (p. documentEntity)
      END;
      MiscRep;
      IF LookingAt ("<!DOCTYPE", followedByNonName) THEN
        doctypedecl;
        MiscRep
      END
    END prolog;
  
  BEGIN
    cpos := 0; cstart := 0;
    currLine := 0;
    currLinePos := cpos;
    currLineTab := 0;
    chars := p. in. chars;
    dtd := p. dtd;
    
    p. builder. StartDocument (p. documentEntity);
    prolog;
    dtd. AttachAttributes;
    p. inDocumentElement := TRUE;
    element;
    IF (p. lenPEStack # 0) THEN
      Err (unbalancedGERef)
    END;
    p. inDocumentElement := FALSE;
    MiscRep;
    IF (chars[cpos] # Buffer.markerEOD) THEN
      Err (junkAfterDocument)
    END;
    CheckInvalidChars;
    p. initialBuilder. EndDocument
  END document;


PROCEDURE (p: Parser) ParseDocument*;
  BEGIN
    document (p)
  END ParseDocument;

PROCEDURE New* (ch: Channel.Channel; codecFactory: Codec.Factory;
                baseURI: URI.URI; builder: Builder.Builder
                ): Parser;
(**@oparam{baseURI} is the absolute URI of the document entity, as computed
   by the method of RFC 2396, if that is known.  If this value is @code{NIL},
   or refers to an opaque URI, then relative URIs in the document cannot be
   resolved.  *)
  VAR
    p: Parser;
    cwdURI: File.URI;
  BEGIN
    NEW (p);
    cwdURI := File.GetCwd();
    IF (cwdURI # NIL) THEN
      p. errList := Error.NewList (baseURI. MakeRelative (cwdURI))
    ELSE
      p. errList := Error.NewList (baseURI)
    END;
    p. in := Buffer.NewInput (ch, codecFactory, p. errList);
    p. builder := builder;
    p. initialBuilder := builder;
    p. dtd := DTD.New();
    
    p. documentEntity := p. dtd. NewDocumentEntity (baseURI);
    p. fileEntity := p. documentEntity;
    
    p. followExternalRef := TRUE;
    p. processDeclarations := TRUE;
    
    p. inDocumentElement := FALSE;
    p. inDTD := FALSE;
    p. inExternalSubset := FALSE;
    p. inExternalEntity := FALSE;
    
    p. currEntityValue := NIL;
    NEW (p. nameList, initNameList);
    p. lenNameList := 0;
    NEW (p. peStack, initPEStack);
    p. lenPEStack := 0;
    
    RETURN p
  END New;


PROCEDURE SetErrorMessages;
  VAR
    i: INTEGER;
    t: ARRAY 128 OF CHAR;
  BEGIN
    FOR i := 0 TO 999 DO
      CASE i OF
      | invalidChar:
        t := "Invalid character in document"
      | junkAfterDocument:
        t := "Junk after document element"
      | invalidCloseCDATA:
        t := "String `]]>' not allowed in character data"
      | invalidCommentDashDash:
        t := "String `--' not allowed in comment"
      | commentNotClosed:
        t := "Comment not closed"
      | stringNotClosed:
        t := "String not closed"
      | piNotClosed:
        t := "Processing instruction not closed"
      | cdataNotClosed:
        t := "CDATA section not closed"
      | expectedWhitespace:
        t := "Expected whitespace"
      | expectedName:
        t := "Expected name token"
      | expectedNmtoken:
        t := "Expected Nmtoken"
      | expectedChar:
        t := "Expected character `${symbol}'"
      | lAngleInAttValue:
        t := "Character `<' not allowed in attribute value"
      | expectedDigit10:
        t := "Expected digit [0-9]"
      | expectedDigit16:
        t := "Expected digit [0-9a-fA-F]"
      | expectedString:
        t := "Expected string"
      | invalidCharRef:
        t := "Character reference designates illegal character"
      | expectedEOS:
        t := "Exepcted `]]>'"
      | ignoreNotClosed:
        t := "Ignored section not closed"
      | invalidPubidChar:
        t := "Invalid character in public ID string"
      | invalidEncNameChar:
        t := "Invalid character in encoding name"
      | invalidVersionNumChar:
        t := "Invalid character in version number"
      | expectedNonEmptyString:
        t := "Expected non-empty string"
      | expectedYesNo:
        t := "Expected 'yes' or 'no'"
      | xmlDeclNotAtBeginning:
        t := "XML declaration must be at beginning of file"
      | reservedPITarget:
        t := "This target name is reserved"
      | invalidCharacterEncodings:
        t := "Document `${uri}' had ${encodings} character encoding errors"
      | junkAfterExtSubset:
        t := "Junk after external DTD subset"
      | unknownCharacterEncoding:
        t := "Unknown character encoding"
        
      | expectedMarkupDecl:
        t := "Expected markup declaration"
      | expectedContentSpec:
        t := "Expected content specification: `EMPTY', `ANY', or `('"
      | expectedAttType:
        t := "Expected attribute type (type name, `NOTATION', or enumeration)"
      | expectedAttValue:
        t := "Expected attribute value"
      | expectedEntityValue:
        t := "Expected entity value"
      | expectedCP:
        t := "Expected content particle (name or `(')"
      | expectedVersion:
        t := "Expected token `version'"
      | expectedExternalID:
        t := "Expected `PUBLIC' or `SYSTEM'"
      | expectedConditional:
        t := "Expected `INCLUDE' or `IGNORE'"
      | expectedPIEnd:
        t := "Expected `?>'"
      | nonMarkupDeclPERef:
        t := "Parameter entity references are restricted to markup declarations in the internal subset of the DTD"
      | expectedEncodingDecl:
        t := "Expected token `encoding'"
      | invalidLangCode:
        t := "Malformed language code in `xml:lang' attribute"
      | malformedURI:
        t := "Malformed URI: ${uri_error}"
        
      | expectedElement:
        t := "Expected element"
      | expectedEndTag:
        t := "Expected end tag </${name}>"
      | noSuchGeneralEntity:
        t := "General entity `${name}' not defined"
      | noSuchParameterEntity:
        t := "Parameter entity `${name}' not defined"
      | multipleAttrName:
        t := "Attribute `${name}' is already defined"
      | recursiveGeneralEntity:
        t := "General entity `${name}' is defined recursively"
      
      | unbalancedPERef:
        t := "End tag `${name}' comes from a different entity than its start tag"
      | unbalancedGERef:
        t := "Unbalanced general entity reference"
      | invalidGEReplacement:
        t := "Replacement text of general entity `${name}' is not valid content"
      | accessError:
        t := "Could not access URL `${uri}': ${channel_error}"
      | referenceToUnparsed:
        t := "Reference to unparsed entity `${name}' not allowed"
      | externalRefInAtttribute:
        t := "Attribute value contains reference to external entity `${name}'"
      ELSE
        t := ""
      END;
      IF (t # "") THEN
        parserContext. SetString (i, t)
      END
    END
  END SetErrorMessages;

BEGIN
  suplPubidChar := "-'()+,./:=?;!*#@$_%";
  NEW (noName, 8);
  COPY ("#no_name", noName^);

  parserContext := Error.NewContext ("XML:Parser");
  SetErrorMessages
END XML:Parser.
