(*      $Id: Validation.Mod,v 1.6 2001/03/19 00:22:54 mva Exp $   *)
MODULE XML:Regexp;
(*  Creates regular expression data structure from `children' content model.
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
  XML:DTD;


TYPE
  Node* = POINTER TO NodeDesc;
  NodeDesc = RECORD
    (DTD.RegexpNodeDesc)
    suc-, alt-: Node;
    elem-: DTD.String;
  END;

VAR
  endOfRegexp-: Node;


PROCEDURE NewNode (elem: DTD.String): Node;
  VAR
    n: Node;
  BEGIN
    NEW (n);
    n. suc := NIL;
    n. alt := NIL;
    n. elem := elem;
    RETURN n
  END NewNode;

PROCEDURE Create* (contentModel: DTD.CP): Node;
(**@precond
   The @oparam{contentModel} is neither @code{EMPTY}, @code{ANY}, nor
   @samp{Mixed}.
   @end precond  *)

  VAR
    start, q, r, s: Node;
    
  PROCEDURE link (p, q: Node);
    VAR
      t: Node;
    BEGIN  (* insert q in places indicated by linked chain p *)
      WHILE (p # NIL) DO
        t := p; p := p. suc; t. suc := q
      END
    END link;

  PROCEDURE Convert (cp: DTD.CP; VAR p, q, r, s: Node);
    VAR
      a, p1, q1, r1, s1: Node;
      ptr: DTD.CP;
    BEGIN
      p := NIL; q := NIL; r := NIL; s := NIL;
      
      WITH cp: DTD.NameCP DO
        a := NewNode (cp. name);
        p := a; q := a; r := a; s := a
        
      | cp: DTD.ChoiceCP DO
        Convert (cp. list, p, q, r, s);
        ptr := cp. list. next;
        WHILE (ptr # NIL) DO
          Convert (ptr, q. alt, q1, s. suc, s1); q := q1; s := s1;
          ptr := ptr. next
        END
        
      | cp: DTD.SeqCP DO
        Convert (cp. list, p, q, r, s);
        ptr := cp. list. next;
        WHILE (ptr # NIL) DO
          Convert (ptr, p1, q1, r1, s1); link (r, p1); r := r1; s := s1;
          ptr := ptr. next
        END
      END;
      
      CASE cp. cpMode OF
      | DTD.cpOnce:
        (* nothing to be done *)
      | DTD.cpOptional:
        a := NewNode (NIL);
        q. alt := a; s. suc := a; q := a; s := a
      | DTD.cpRepeat0:
        link (r, p);
        a := NewNode (NIL);
        q. alt := a; q := a; r := a; s := a
      | DTD.cpRepeat1:
        ASSERT (FALSE)
      END
    END Convert;
  
  BEGIN
    Convert (contentModel, start, q, r, s);
    link (r, endOfRegexp);
    RETURN start
  END Create;

BEGIN
  endOfRegexp := NewNode (NIL)
END XML:Regexp.
