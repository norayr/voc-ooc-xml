MODULE XML:Basic:DataType;

IMPORT
  LongStrings, IntStr, XML:Basic:Element;


PROCEDURE GetIntAttr* (value: Element.AttValue; VAR number: LONGINT): BOOLEAN;
  VAR
    str: Element.String;
    str8: ARRAY 32 OF CHAR;
    res: IntStr.ConvResults;
    dummy: BOOLEAN;
  BEGIN
    str := value. FlattenValue (FALSE, dummy);
    LongStrings.Short (str^, "?", str8);
    IntStr.StrToInt (str8, number, res);
    RETURN (res = IntStr.strAllRight)
  END GetIntAttr;
  
PROCEDURE GetStringLatin1Attr* (value: Element.AttValue; VAR str: ARRAY OF CHAR): BOOLEAN;
  VAR
    v: Element.String;
    i: LONGINT;
    dummy: BOOLEAN;
  BEGIN
    v := value. FlattenValue (FALSE, dummy);
    IF (LongStrings.Length (v^) >= LEN (str)) THEN
      RETURN FALSE
    ELSE
      i := -1;
      REPEAT
        INC (i);
        IF (v[i] <= MAX (CHAR)) THEN
          str[i] := SHORT (v[i])
        ELSE
          RETURN FALSE
        END
      UNTIL (v[i] = 0X);
      RETURN TRUE
    END
  END GetStringLatin1Attr;
  
END XML:Basic:DataType.
