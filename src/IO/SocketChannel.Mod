MODULE IO:SocketChannel;

(*  Channel interface for sockets.
    Copyright (C) 2002  Stewart Greenhill

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

(**This module implements a Channel interface for sockets. 

Under the Windows operating system network sockets are not represented
using standard file descriptors. Instead, sockets have handles that are
specific to the networking subsystem (ie. Winsock). This means that
IO:PFD cannot be used to provide a Channel interface to network streams.

*)

IMPORT
  SYSTEM, C, Ch := Channel, IO:Socket, IO:Select, Time, Msg;

CONST
  done* = Ch.done;

  noPosition* = Ch.noPosition;
  noLength* = Ch.noLength;
  outOfRange* = Ch.outOfRange;
  channelClosed* = Ch.channelClosed;
  readAfterEnd* = Ch.readAfterEnd;
  
TYPE
  Channel* = POINTER TO ChannelDesc;
  ChannelDesc = RECORD
    (Ch.ChannelDesc)
    sock : Socket.Socket;
  END;

  Reader = POINTER TO ReaderDesc;
  ReaderDesc = RECORD (Ch.ReaderDesc)
    fdset : Select.FileDescrSet;
    ch : Channel;
  END;

  Writer = POINTER TO WriterDesc;
  WriterDesc = RECORD (Ch.WriterDesc)
    ch : Channel;
  END;
  
TYPE
  ErrorContext = POINTER TO ErrorContextDesc;
  ErrorContextDesc* = RECORD (Ch.ErrorContextDesc)
  END;

VAR
  errorContext: ErrorContext;

PROCEDURE GetError (code: Msg.Code): Msg.Msg;
  BEGIN
    RETURN Msg.New (errorContext, code)
  END GetError;

(* Reader methods 
   ------------------------------------------------------------------------ *)

PROCEDURE (r: Reader) Pos*(): LONGINT;
BEGIN
  RETURN noPosition;
END Pos;

PROCEDURE (r: Reader) Available*(): LONGINT;
VAR
  res : C.int;
BEGIN
  r.fdset.Zero();
  r.fdset.Set(r.ch.sock.fd);
  res := Select.Select(r.fdset, NIL, NIL, 0, 0);
  RETURN res;
END Available;

PROCEDURE (r: Reader) SetPos* (newPos: LONGINT);
BEGIN
  r.res := GetError(outOfRange);
END SetPos;

PROCEDURE (r: Reader) ReadBytes* (VAR x: ARRAY OF SYSTEM.BYTE; 
                                  start, n: LONGINT);
BEGIN
  r.bytesRead := r.ch.sock.Recv(x, start, n, {});
  r.res := r.ch.sock.res;
  IF (r.res # NIL) & (r.res.code = Socket.connectionTerminated) THEN
    (* Connection was closed. Clean up gracefully. *)
    r.ch.open := FALSE;
    r.res := GetError(readAfterEnd);
  END;
END ReadBytes;
  
PROCEDURE (r: Reader) ReadByte* (VAR x: SYSTEM.BYTE);
VAR
  a : ARRAY 1 OF SYSTEM.BYTE;
BEGIN
  r.ReadBytes(a,0,1);
  x := a[0];
END ReadByte;

(* Writer methods 
   ------------------------------------------------------------------------ *)

PROCEDURE (w: Writer) Pos*(): LONGINT;
BEGIN
  RETURN noPosition;
END Pos;

PROCEDURE (w: Writer) SetPos* (newPos: LONGINT);
BEGIN
  w.res := GetError(outOfRange);
END SetPos;

PROCEDURE (w: Writer) WriteBytes* (VAR x: ARRAY OF SYSTEM.BYTE; 
                                  start, n: LONGINT);
BEGIN
  w.bytesWritten := w.ch.sock.Send(x, start, n, {});
  w.res := w.ch.sock.res;
END WriteBytes;
  
PROCEDURE (w: Writer) WriteByte* (x: SYSTEM.BYTE);
VAR
  a : ARRAY 1 OF SYSTEM.BYTE;
BEGIN
  a[0] := x;
  w.WriteBytes(a,0,1);
END WriteByte;

(* Channel methods 
   ------------------------------------------------------------------------ *)
   
PROCEDURE (ch: Channel) Length*(): LONGINT;
BEGIN
  RETURN noLength;
END Length;

PROCEDURE (ch: Channel) GetModTime* (VAR mtime: Time.TimeStamp);
BEGIN
  ch. res := GetError (Ch.noModTime)
END GetModTime;

PROCEDURE (ch: Channel) NewReader*(): Reader;
VAR r : Reader;
BEGIN
  IF ch.open THEN
    NEW(r);
    r.fdset := Select.NewSet();
    r.ch := ch;
    r.positionable := FALSE;
    r.bytesRead := 0;
    r.res := done;
  ELSE
    r := NIL;
    ch. res := GetError (channelClosed)
  END;
  RETURN r
END NewReader;

PROCEDURE (ch : Channel) NewWriter*(): Writer;
VAR w : Writer;
BEGIN
  IF ch.open THEN
    NEW(w);
    w.ch := ch;
    w.positionable := FALSE;
    w.bytesWritten := 0;
    w.res := done;
  ELSE
    w := NIL;
    ch. res := GetError (channelClosed)
  END;
  RETURN w
END NewWriter;
  
PROCEDURE (ch: Channel) Flush*;
BEGIN
  IF ~ch. open THEN
    ch. res := GetError (channelClosed)
  END
END Flush;

PROCEDURE (ch: Channel) Close*;
BEGIN
  ch. open := FALSE;
  ch.sock.Close();
  ch.res := ch.sock.res;
END Close;

PROCEDURE New* (sock : Socket.Socket) : Channel;
VAR
  ch : Channel;
BEGIN
  NEW (ch);
  ch.res := done;
  ch.readable := TRUE;
  ch.writable := TRUE;
  ch.open := TRUE;
  ch.sock := sock;
  RETURN ch;
END New;

BEGIN
  NEW (errorContext);
  Msg.InitContext (errorContext, "IO:SocketChannel");
END IO:SocketChannel.
