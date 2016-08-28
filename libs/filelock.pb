DeclareModule FileLock
  #readonlyext = ".readonly"
  Declare.s Lock(filename$, try = 100)
  ;if lock succeeds a string with the temporary filename to write to will be returned, if failed empty string is returned
  ;A filename$ + ".readonly" file will be created where file contents can be read while a file is locked. do not write to this file.
  
  Declare.s Unlock(tmpname$, filename$)
  ;unlocks file. Requires tmp filename and original filename
  
  ;use tmp file name when writing to file
  Declare.s ReadStrFromFile(filename$, line = 0)  
  Declare WriteStrToFile(filename$, str$, newline.b = #True, flag.b = 0)
EndDeclareModule

Module FileLock
  EnableExplicit
  Procedure.s Lock(filename$, try = 100)
    Define tmpname$ = Str(getpid_())
    Define count = 0
    Repeat
      If CopyFile(filename$, filename$ + #readonlyext) And RenameFile(filename$, tmpname$)
        ProcedureReturn tmpname$  
      EndIf
      count = count + 1
      If count >= try : ProcedureReturn "" : EndIf
    ForEver
  EndProcedure
  
  Procedure.s ReadStrFromFile(filename$, line = 0)
    If ReadFile(0, filename$)
      Define i = 0
      Define str$ = ""
      For i = 0 To line
        str$ = ReadString(0)
      Next
      CloseFile(0)
      ProcedureReturn str$  
    Else
      ProcedureReturn ""
    EndIf
  EndProcedure
  
  Procedure WriteStrToFile(filename$, str$, newline.b = #True, flag.b = 0)
    If OpenFile(0, filename$, flag.b)
      If newline = #True : WriteStringN(0, str$) : Else : WriteString(0, str$) : EndIf
      CloseFile(0)
    Else
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure.s Unlock(tmpname$, filename$)
    If RenameFile(tmpname$, filename$) = 0 : ProcedureReturn "" : EndIf
    ProcedureReturn filename$
  EndProcedure
EndModule

;EXAMPLE
;XIncludeFile "../libs/filelock.pb"
;EnableExplicit
;OpenConsole()
;Define file$ = "somefile.txt"
;Define tmpname$ = FileLock::Lock(file$)
;If tmpname$ <> ""
;  Define numstr$ = FileLock::ReadStrFromFile(tmpname$)
;  Define num = Val(numstr$) + 1
;  FileLock::WriteStrToFile(tmpname$, Str(num), #False)
;  If FileLock::Unlock(tmpname$, file$) <> ""
;    PrintN("OK")
;  Else
;    PrintN("error")
;  EndIf
;Else
;  PrintN("timeout")
;EndIf
; IDE Options = PureBasic 5.21 LTS (MacOS X - x64)
; CursorPosition = 11
; Folding = --
; EnableUnicode
; EnableXP
; Executable = ../filelock/lockwrite.app