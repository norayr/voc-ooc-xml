MODULE TestGet;

(**
This program takes a single argument, an "http" URI.  It tries to retrieve
the URI using a "GET" request.  On success, the retrieved entity's content
is written to stdout.  Otherwise, an error message is written to stderr.
*)

IMPORT
  Channel, Err, Msg, ProgramArgs, StdChannels, TextRider,
  URI, URI:Parser, URI:Scheme:HTTP;
  (* note: all supported schemes must be imported explicitly! *)


TYPE
  Buffer = ARRAY 8*1024 OF CHAR;

VAR
  res: Msg.Msg;
  ch: Channel.Channel;
  argReader: TextRider.Reader;
  reader: Channel.Reader;
  writer: Channel.Writer;
  buffer: Buffer;
  uri: URI.URI;

BEGIN
  IF (ProgramArgs.args. ArgNumber() # 1) THEN
    Err.String ("usage: ./TestGet <absolute-uri>"); Err.Ln; HALT (1)
  ELSE
    argReader := TextRider.ConnectReader (ProgramArgs.args);
    argReader. ReadLine (buffer);        (* skip command name *)
    argReader. ReadLine (buffer);        (* get argument *)
    
    uri := Parser.NewURI (buffer, NIL, res); (* parse URI *)
    IF (res = NIL) THEN
      ch := uri. GetChannel (URI.channelOld, res); (* get channel for URI *)
      IF (res = NIL) THEN                (* success: copy channel to stdout *)
        reader := ch. NewReader();
        writer := StdChannels.stdout. NewWriter();
        WHILE (reader. res = Channel.done) DO
          reader. ReadBytes (buffer, 0, SIZE (Buffer));
          writer. WriteBytes (buffer, 0, reader. bytesRead)
        END;
        IF (reader. res. code # Channel.readAfterEnd) THEN
          res := reader. res
        END
      END
    END;
    
    IF (res # NIL) THEN
      res. GetText (buffer);
      Err.String ("Error: ");
      Err.String (buffer);
      Err.Ln;
      HALT (1)
    END
  END
END TestGet.
