(*      $Id: Regexp.Mod,v 1.1 2001/03/19 23:54:09 mva Exp $   *)
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
  LongStrings, XML:DTD;


TYPE
  Node* = POINTER TO NodeDesc;
  NodeDesc = RECORD
    (DTD.RegexpNodeDesc)
    suc-, alt-: Node;
    elem-: DTD.String;
    (* NIL for an empty node, and for @ovar{endOfRegexp} *)
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
        a := NewNode (NIL);
        link (r, a);
        a. alt := p; r := a; s := a;
        a := NewNode (NIL);
        a. suc := p; p := a; q := a
      END
    END Convert;
  
  BEGIN
    Convert (contentModel, start, q, r, s);
    link (r, endOfRegexp);
    RETURN start
  END Create;

(*PROCEDURE MatchingMatch* (node: Node; name: DTD.String): Node;
  VAR
    suc, match: Node;
      
  PROCEDURE Matching (node: Node): Node;
    VAR
      alt, suc, match: Node;
    BEGIN
      WHILE (node # NIL) DO
        IF (node. elem = NIL) THEN
          IF (node. alt = NIL) THEN
            node := node. suc
          ELSIF (node. suc = NIL) THEN
            node := node. alt
          ELSE
            alt := node. alt; suc := node. suc;
            node. alt := NIL; node. suc := NIL;
            match := Matching (alt);
            IF (match = NIL) THEN
              match := Matching (suc)
            END;
            node. alt := alt; node. suc := suc;
            RETURN match
          END
        ELSIF (node. elem^ = name^) THEN
          RETURN node
        ELSE
          node := node. alt
        END
      END;
      RETURN NIL
    END Matching;
  
  BEGIN
    suc := node. suc;
    node. suc := NIL;
    match := Matching (suc);
    node. suc := suc;
    RETURN match
  END MatchingMatch;*)

PROCEDURE GetMatch* (ptr: Node; name: DTD.String): Node;
  VAR
    alt, suc, result, ptr1, ptr2: Node;
  BEGIN
    LOOP
      IF (ptr = endOfRegexp) OR (ptr = NIL) THEN
        RETURN ptr
      ELSIF (ptr. elem = NIL) THEN
        IF (ptr. alt = NIL) THEN
          ptr := ptr. suc
        ELSIF (ptr. suc = NIL) THEN
          ptr := ptr. alt
        ELSE
          alt := ptr. alt; suc := ptr. suc;
          ptr. alt := NIL; ptr. suc := NIL;
          ptr1 := GetMatch (alt, name);
          IF (ptr1 = NIL) OR (ptr1 = endOfRegexp) THEN
            ptr2 := GetMatch (suc, name);
            IF (ptr1 = NIL) OR (ptr2 # NIL) THEN
              result := ptr2
            ELSE
              result := ptr1
            END
          ELSE
            result := ptr1
          END;
          ptr. alt := alt; ptr. suc := suc;
          RETURN result
        END
      ELSIF (ptr. elem^ = name^) THEN
        EXIT
      ELSE
        ptr := ptr. alt
      END
    END;
    RETURN ptr
  END GetMatch;

PROCEDURE ListElements* (ptr: Node): DTD.String;
  VAR
    str: DTD.String;
    len: LONGINT;
  
  PROCEDURE ListRec (ptr: Node);
    VAR
      str2: DTD.String;
      i: LONGINT;
      alt, suc: Node;
    BEGIN
      LOOP
        IF (ptr = NIL) OR (ptr = endOfRegexp) THEN
          EXIT
        ELSIF (ptr. elem = NIL) THEN
          IF (ptr. alt = NIL) THEN
            ptr := ptr. suc
          ELSIF (ptr. suc = NIL) THEN
            ptr := ptr. alt
          ELSE
            alt := ptr. alt; suc := ptr. suc;
            ptr. alt := NIL; ptr. suc := NIL;
            ListRec (alt); ListRec (suc);
            ptr. alt := alt; ptr. suc := suc;
          END
        ELSE
          i := LongStrings.Length (ptr. elem^);
          IF (len+i+1 >= LEN (str^)) THEN
            NEW (str2, LEN (str^)*2);
            COPY (str^, str2^)
          END;
          str[len] := " ";
          str[len+1] := 0X;
          LongStrings.Append (ptr. elem^, str^);
          INC (len, i+1);
          ptr := ptr. alt
        END
      END;
    END ListRec;
  
  BEGIN
    NEW (str, 64);
    str[0] := 0X;
    len := 0;
    ListRec (ptr);
    RETURN str
  END ListElements;

BEGIN
  endOfRegexp := NewNode (NIL)
END XML:Regexp.
