MODULE TestServer;

(**
This program implements a simple server in the Internet namespace.  It
listens on port 5555 of the local host for incoming connections.  You
can use "telnet localhost 5555" to connect to the server process.  Any
data received on connections is written to stdout.  Debugging output
is send to stderr.
*)

IMPORT
  C, Channel, Err, Log, Msg, StdChannels, IO:Select, IO:Socket;
  
TYPE
  Buffer = ARRAY 8*1024 OF CHAR;

VAR
  sock, new: Socket.Socket;
  addr, remoteAddr: Socket.sockaddr_in;
  res: Msg.Msg;
  activeSet, readSet: Select.FileDescrSet;
  buffer: Buffer;
  i: LONGINT;
  remoteAddrLen: C.int;
  sockets: POINTER TO ARRAY OF Socket.Socket;
  out: Channel.Writer;


PROCEDURE CheckError (msg: Msg.Msg);
  VAR
    str: ARRAY 4*1024 OF CHAR;
  BEGIN
    IF (msg # NIL) THEN
      Err.String ("Error: ");
      msg. GetText (str);
      Err.String (str);
      Err.Ln;
      HALT (1)
    END
  END CheckError;

PROCEDURE ReadFromClient (sock: Socket.Socket): LONGINT;
  VAR
    nbytes: LONGINT;
  BEGIN
    nbytes := sock. Recv (buffer, SIZE (Buffer), {});
    IF (nbytes < 0) THEN
      Log.Msg ("read error");
      HALT (1)
    ELSIF (nbytes = 0) THEN
      RETURN -1
    ELSE
      out. WriteBytes (buffer, 0, nbytes);
      out. base. Flush;
      RETURN nbytes
    END
  END ReadFromClient;

BEGIN
  NEW (sockets, Select.FD_SETSIZE);
  out := StdChannels.stdout. NewWriter();
  
  Log.Msg ("Creating socket");
  sock := Socket.New (Socket.AF_INET, Socket.SOCK_STREAM, 0, res);
  CheckError (res); ASSERT (res = NIL); ASSERT (sock # NIL); 
  
  Log.Msg ("Getting address");
  Socket.InitSockAddrINET (addr, "", 5555);
  ASSERT (addr. sin_family = Socket.AF_INET);
  
  Log.Msg ("Binding to local address");
  sock. SetReuseAddress;
  sock. Bind (addr, SIZE (Socket.sockaddr_in));
  CheckError (sock. res);
  
  Log.Msg ("Calling listen()");
  sock. Listen (5);
  CheckError (res);
  
  activeSet := Select.NewSet();
  readSet := Select.NewSet();
  activeSet. Set (sock. fd);
  
  Log.Msg ("Entering server loop");
  LOOP
    activeSet. Copy (readSet);
    
    Log.Msg ("Calling select()");
    IF (Select.Select (readSet, NIL, NIL, -1, -1) < 0) THEN
      Log.Msg ("select: error");
      EXIT
    ELSE
      FOR i := 0 TO Select.FD_SETSIZE-1 DO
        IF readSet. IsSet (i) THEN
          IF (i = sock. fd) THEN  (* connection request on original socket *)
            Log.Msg ("Calling accept()");
            new := sock. Accept (remoteAddr, remoteAddrLen);
            CheckError (sock. res);
            activeSet. Set (new. fd);
            sockets[new. fd] := new
          ELSE
            IF (ReadFromClient (sockets[i]) < 0) THEN
              Log.Msg ("Connection closed");
              activeSet. Clear (i);
              sockets[i] := NIL
            END
          END
        END
      END
    END
  END
END TestServer.
