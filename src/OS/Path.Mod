(* 	$Id: Path.Mod,v 1.1.1.1 2000/07/10 15:24:44 mva Exp $	 *)
MODULE OS:Path;
(*  Manipulation of file and directory names.
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
  Strings;


PROCEDURE dirname* (path: ARRAY OF CHAR; VAR dirname: ARRAY OF CHAR);
(**Calculates the directory name of pathname @oparam{path} and returns the
   result in @oparam{dirname}.  If @oparam{dirname} is not long enough to hold
   the result, the string is truncated. *)
  VAR
    i, j: INTEGER;
    len: LONGINT;
  BEGIN
    len := LEN (dirname);
    
    (* copy anything in path up to and including the final "/" to dirname *)
    i := Strings.Length (path);
    WHILE (i > 0) & (path[i-1] # "/") DO
      DEC (i)
    END;
    FOR j := 0 TO i-1 DO
      IF (j < len) THEN
        dirname[j] := path[j]
      END
    END;
    IF (i >= len) THEN
      i := SHORT (len-1)
    END;
    dirname[i] := 0X;
    
    (* if dirname is not composed exclusively of slashes, remove any
       trailing "/" characters *)
    i := -1;
    j := 0;
    WHILE (dirname[j] # 0X) DO
      IF (dirname[j] # "/") THEN
        i := j
      END;
      INC (j)
    END;
    IF (i >= 0) THEN
      dirname[i+1] := 0X
    END
  END dirname;

PROCEDURE Test;
  VAR
    str: ARRAY 1024 OF CHAR;
  BEGIN
    dirname("", str);
    ASSERT (str = "");

    dirname("/", str);
    ASSERT (str = "/");

    dirname("//", str);
    ASSERT (str = "//");

    dirname("abc", str);
    ASSERT (str = "");

    dirname("/abc", str);
    ASSERT (str = "/");

    dirname("~", str);
    ASSERT (str = "");

    dirname("~/", str);
    ASSERT (str = "~");

    dirname("~foo/", str);
    ASSERT (str = "~foo");

    dirname("abc/", str);
    ASSERT (str = "abc");

    dirname("abc///", str);
    ASSERT (str = "abc");
  END Test;

BEGIN
  Test
END OS:Path.
