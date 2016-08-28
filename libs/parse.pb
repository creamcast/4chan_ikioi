DeclareModule String
  Declare.s Parse(type, string$, pass$, stopbefore$, List series.s())
  #once = 0
  #all = 1  
EndDeclareModule

Module String
  EnableExplicit
  Procedure.s GetNextChar(*string)
    Define str$ = PeekS(*string)
    Define chr$ = Left(str$, 1)
    PokeS(*string, Mid(str$, 2))
    ProcedureReturn chr$
  EndProcedure
  
  Procedure.s Parse(type, string$, pass$, stopbefore$, List series.s())
    Define extract$ = ""
    Define passlen = Len(pass$)
    Define sblen = Len(stopbefore$)
    Define record.b = #False
    Define s
    Define chr$
    
    While (1)
      If Left(string$, passlen) = pass$ And record.b = #False ;start recording after
        For s = 1 To passlen : GetNextChar(@string$) : Next s ;skip through it
        record.b = #True
      EndIf
      
      If Left(string$, sblen) = stopbefore$ And record.b = #True ;stop recording before
        If type = #once : ProcedureReturn extract$ : EndIf
        
        AddElement(series())
        series() = extract$
        record.b = #False
        extract$ = ""
      EndIf
      
      chr$ = GetNextChar(@string$)
      ;added 2014 6 13
      ;-----------------
      If chr$ = "" And extract$ <> "" And type = #all
        AddElement(series())
        series() = extract$
        Break
      EndIf
      ;-----------------
      If chr$ = "" : Break : EndIf
      If record.b = #True : extract$ = extract$ + chr$ : EndIf
    Wend
    ProcedureReturn extract$
  EndProcedure
EndModule

;Example:
;NewList mylist.s()
;String::Parse(String::#all, "<a>Hello World</a><a>Hello World</a><a>Hello World</a><a>Hello World</a>", "<a>", "</a>", mylist())
;ForEach mylist()
;  Debug mylist()
;Next
; IDE Options = PureBasic 5.21 LTS (MacOS X - x64)
; CursorPosition = 59
; FirstLine = 27
; Folding = -
; EnableUnicode
; EnableXP