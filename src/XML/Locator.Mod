(*      $Id: Locator.Mod,v 1.3 2000/07/22 16:18:08 mva Exp $   *)
MODULE XML:Locator [OOC_EXTENSIONS];
(*  Provides access to position information for XML parser callbacks.
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
  Buffer := XML:UnicodeBuffer, XML:Error, XML:DTD;

TYPE
  Locator* = POINTER TO Position;
  Position* = RECORD
    charIndex*: Buffer.CharPos;
    (**The character index of the starting position associated with a callback
       event, based on the UCS-2 character encoding.  This position is relative
       to the beginning of the current file (document entity, external DTD
       subset, or external entity), and begins with character index 0.  Please
       note that this number may differ from the number of Unicode characters
       before the given index, if the file contains characters with code values
       over 0xFFFF, which are encoded as two Unicode characters.  *)
    line*: Buffer.CharPos;
    (**Line number of the character.  Counting begins at zero.  *)
    column*: Buffer.CharPos;
    (**Column number of the character.  Counting begins at zero.  Currently,
       surrogate pairs are counted as two separate characters.  *)
    
    entity*: DTD.ExternalEntity;
    (**The current file entity (document entity, external DTD subset, or
       external entity).  Using this reference, the public identifier, the
       system identifier, and the base URI can be determined.  *)
    inInternalEntity*: DTD.InternalEntity;
    (**If the parsing is within the replacement text of an internal entity,
       this field refers to the innermost entity.  It is @code{NIL} as long
       as the parser is working on the top-most file level.  *)
  END;

TYPE
  ErrorListener* = POINTER TO ErrorListenerDesc;
  ErrorListenerDesc* = RECORD [ABSTRACT]
  END;

PROCEDURE (el: ErrorListener) [ABSTRACT] Error* (context: Error.Context;
                                                 code: Error.Code;
                                                 fatalError: BOOLEAN;
                                                 pos: Position): Error.Msg;
  END Error;
  
END XML:Locator.
