(*      $Id: TestParser.Mod,v 1.8 2001/03/19 00:22:32 mva Exp $   *)
MODULE TestParser;
(*  Converts XML document into its canonical representation.
    Copyright (C) 2000, 2001  Michael van Acken

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
  ProgramArgs, TextRider, StdChannels, Channel, Err, Msg,
  XML:Builder, XML:Parser, XML:UnicodeCodec:UTF8, XML:UnicodeCodec:ImportAll,
  XML:Builder:Canonical, XML:Builder:ParserProtocol, XML:Builder:Namespaces,
  XML:Builder:Validation;


CONST
  modeCanonical = 1;
  modeParserProtocol = 2;
  
VAR
  mode: SHORTINT;
  namespaceSupport, validating, dontFollowEntityRefs: BOOLEAN;
  format: SHORTINT;
  canon: Parser.Parser;
  builder, outputBuilder: Builder.Builder;
  str: ARRAY 1024 OF CHAR;

PROCEDURE CreateParser(): Parser.Parser;
  VAR
    arg: ARRAY 256 OF CHAR;
    argReader: TextRider.Reader;
    p: Parser.Parser;
    namespaceBuilder, validatingBuilder: Builder.Builder;
    res: Msg.Msg;
  BEGIN
    NEW (canon);
    
    (* write usage text and exit if no arguments are given *)
    IF (ProgramArgs.args. ArgNumber() = 0) THEN
      Err.String ("usage: TestParser [-1|-2|-3|-p] [-i|-v] [-n] <file>"); Err.Ln;
      HALT(1)
    END;
    
    (* parse command line arguments *)
    mode := modeCanonical;
    namespaceSupport := FALSE;
    validating := FALSE;
    dontFollowEntityRefs := FALSE;
    format := Canonical.firstCanonicalForm;
    argReader := TextRider.ConnectReader (ProgramArgs.args);
    argReader. ReadLine (arg);           (* skip command name *)
    argReader. ReadLine (arg);
    LOOP
      IF (arg = "-1") THEN
        mode := modeCanonical; format := Canonical.firstCanonicalForm
      ELSIF (arg = "-2") THEN
        mode := modeCanonical; format := Canonical.secondCanonicalForm
      ELSIF (arg = "-3") THEN
        mode := modeCanonical; format := Canonical.thirdCanonicalForm
      ELSIF (arg = "-p") THEN
        mode := modeParserProtocol
      ELSIF (arg = "-n") THEN
        namespaceSupport := TRUE
      ELSIF (arg = "-v") THEN
        validating := TRUE
      ELSIF (arg = "-i") THEN
        dontFollowEntityRefs := TRUE
      ELSE
        EXIT;
      END;
      argReader. ReadLine (arg)
    END;
    
    IF (mode = modeCanonical) THEN
      builder := Canonical.New (StdChannels.stdout, UTF8.factory, format)
    ELSIF (mode = modeParserProtocol) THEN
      builder := ParserProtocol.New (StdChannels.stdout, UTF8.factory)
    END;
    outputBuilder := builder;
    
    IF validating THEN
      dontFollowEntityRefs := FALSE;
      validatingBuilder := Validation.New (builder);
      builder := validatingBuilder
    END;
    IF namespaceSupport THEN
      namespaceBuilder := Namespaces.New (builder);
      builder := namespaceBuilder
    END;
    
    p := Parser.NewFile (arg, NIL, NIL, NIL, builder, res);
    p. followExternalRef := ~dontFollowEntityRefs;
    p. enforceQNames := namespaceSupport; (* enable QName and NCName checks *)
    p. validating := validating;          (* enable parser-level validation *)
    ASSERT (res = NIL);
    RETURN p
  END CreateParser;

BEGIN
  canon := CreateParser();
  canon. ParseDocument;
  
  WITH outputBuilder: Canonical.Builder DO
    IF (outputBuilder. out. writer. res # Channel.done) THEN
      Err.String ("Error: ");
      outputBuilder. out. writer. res. GetText (str);
      Err.String (str);
      Err.Ln;
      HALT (1)
    ELSIF (outputBuilder. out. codec. invalidChars # 0) THEN
      Err.String ("Error: ");
      Err.LongInt (outputBuilder. out. codec. invalidChars, 0);
      Err.String (" invalid characters were written");
      Err.Ln;
      HALT (1)
    END
  ELSE
    (* ignore errors for all other builders ... *)
  END;
  
  IF (canon. errList. msgCount # 0) THEN
    canon. errList. Write (StdChannels.stderr);
    HALT (1)
  END
END TestParser.
