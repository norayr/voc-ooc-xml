(*      $Id: EntityResolver.Mod,v 1.4 1999/11/29 14:31:02 ooc-devel Exp $   *)
MODULE XML:EntityResolver;
(*  Locates and opens external entities for the XML parser.
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
  LongStrings, Msg, Strings, URI, URI:Parser,
  DTD := XML:BuilderDTD, Codec := XML:UnicodeCodec, XML:UnicodeCodec:UTF8;


TYPE
  Resolver* = POINTER TO ResolverDesc;
  ResolverDesc* = RECORD
  END;

PROCEDURE (r: Resolver) GetURI* (public, system: DTD.String; baseURI: URI.URI;
                                 VAR uri: URI.URI; VAR res: Msg.Msg);
(**Interprets the public or system identifier of an external entity and
   constructs an URI for it.  On success, the URI of the document is returned
   in @oparam{uri}, and @code{NIL} in @oparam{res}.  On failure, @oparam{res}
   holds an error message.
   
   The default implementation ignores the public identifier and uses the
   URI in @oparam{system}.  An relative system identifier is expanded relative
   to @oparam{baseURI}.  Both @oparam{uri} and @oparam{res} are set to 
   @code{NIL} if no system identifier is present, which is permitted for
   notation declarations.  *)
  VAR
    len16, len8, i: INTEGER;
    codec: Codec.Codec;
    str8: POINTER TO ARRAY OF CHAR;
    repl: ARRAY 4 OF CHAR;
    srcDone, destDone: LONGINT;

  PROCEDURE ToHex (i: INTEGER): CHAR;
    BEGIN
      IF (i < 10) THEN
        RETURN CHR (i+ORD ("0"))
      ELSE
        RETURN CHR (i+(ORD ("A")-10))
      END
    END ToHex;

  BEGIN
    IF (system = NIL) THEN               (* notation declaration *)
      uri := NIL; res := NIL;
      RETURN
    END;
    
    len16 := LongStrings.Length (system^);
    len8 := len16*9+1;
    NEW (str8, len8);
    (* conservative approximation: UCS-2 character code is mapped to at
       most 3 bytes, a UCS-2 surrogate pair to 2 characters each; then,
       a non-ASCII character is encoded as %HH *)
    codec := UTF8.factory. NewCodec();

    (* encode UCS-2 character sequence as UTF-8 character sequence *)
    IF (len16 # 0) THEN
      codec. Encode (system^, 0, len16, str8^, 0, len8, srcDone, destDone);
      IF (srcDone # len16) THEN
        codec. Encode (system^, srcDone, len16, str8^, destDone, len8,
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

    IF (baseURI # NIL) & (baseURI IS URI.HierarchicalURI) THEN
      uri := Parser.NewURI (str8^, baseURI(URI.HierarchicalURI), res)
    ELSE
      uri := Parser.NewURI (str8^, NIL, res)
    END
  END GetURI;
  
PROCEDURE New* (): Resolver;
  VAR
    er: Resolver;
  BEGIN
    NEW (er);
    RETURN er
  END New;

END XML:EntityResolver.
