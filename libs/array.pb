Procedure SEARCHARRAYFOR(searchstring$, Array source$(1))
  ;Returns index of first occurence of matching search string
  ;returns -1 if nothing is found
  len = ArraySize(source$())
  
  For i = 0 To len
    If source$(i) = searchstring$ : ProcedureReturn i : EndIf
  Next i
  
  ProcedureReturn -1
EndProcedure

Procedure OCCURRENCEOF(searchstring$, Array source$(1))
  ;Returns number of occurences in array of search string
  ;E.G. DEBUG OCCURRENCEOF("HK", countrycodes$())
  len = ArraySize(source$())
  num = 0
  
  For i = 0 To len
    If source$(i) = searchstring$
      num = num + 1
    EndIf
  Next i
  
  ProcedureReturn num
EndProcedure

Procedure INSERT(adata$, Array dest$(1))
  ;INSERT data into array and resizes array dynamically
  
  len = ArraySize(dest$())
  
  If len = 0 And dest$(0) = ""
    dest$(0) = adata$
  Else
    ReDim dest$(len + 1)
    dest$(len + 1) = adata$
  EndIf
EndProcedure

Procedure DIFFERENCE(Array source1$(1), Array source2$(1), Array dest$(1))
  len = ArraySize(source1$())
  For i = 0 To LEN
    If SEARCHARRAYFOR(source1$(i), source2$()) = -1
      INSERT(source1$(i), dest$())
    EndIf
  Next i
  
  len = ArraySize(source2$())
  For i = 0 To LEN
    If SEARCHARRAYFOR(source2$(i), source1$()) = -1
      INSERT(source2$(i), dest$())
    EndIf
  Next i
EndProcedure

Procedure UNIQUE(Array source$(1), Array dest$(1))
  ;Returns an array with duplicate values removed.
  Dim temp$(0)
  index = 0
  
  len = ArraySize(source$())
  
  For i = 0 To len
    index = SEARCHARRAYFOR(source$(i), source$())
    
    If SEARCHARRAYFOR( Str(index), temp$() ) = -1
      INSERT( Str(index), temp$() )  
    EndIf    
  Next i
  
  ;Copy unique values to dest array
  len = ArraySize(temp$())
  ReDim dest$(len)
  
  For i = 0 To len
    dest$(i) = source$(Val(temp$(i)))
  Next i
  
EndProcedure

Procedure COPYDIMENSION(Array source$(2), Array dest$(1), copycol)
  ;copies column of 2D Array to 1D Array
  ;e.g. Copy column 2 from 2d array postsdata$() to 1d array test$()
  ;  DIM postsdata(7, 100)
  ;  DIM test$(0)
  ;  COPYDIMENSION(postsdata$(), test$(), 2)
  
  len = ArraySize(source$(), 2)
  
  ReDim dest$(len)
  
  For i = 0 To len
    dest$(i) = source$(copycol, i)
  Next i
EndProcedure

Procedure PRINTARRAY(Array source$(1))
  ;print's out content of 1D array
  ;e.g. Print out content of test$()
  ;
  ;DEBUGARRAY(test$())
  
  len = ArraySize(source$())
  
  For i = 0 To len
    PRINTM(source$(i))
  Next i
  
  PRINTM("Total: " + i)
EndProcedure

Procedure PRINT2DARRAY(Array postsdata$(2), colnum)
  ;prints out selected column of 2d array
  
  len = ArraySize(postsdata$(), 2)
  
  For i = 0 To len
    PRINTM( postsdata$(colnum, i) )
  Next i
  
  PRINTM("Total: " + i)
EndProcedure

Macro STR_PRINTSTRUCT(struct, field)
  len = ArraySize(struct())
  For i = 0 To len
    PRINTM( struct(i)\field )
  Next i
EndMacro

Macro INT_STRUCTTOARRAY(struct, field, dest)
  ;converts struct array with selected field type of INT to a string array
  ;e.g.
  ;DIM pdata.Posts(0)
  ;DIM postnums$(0)
  ;INT_STRUCTTOARRAY(pdata, field.i, postnums$)
  len = ArraySize(struct())
  ReDim dest(len)
  For i = 0 To len
    dest(i) = Str ( struct(i)\field )
  Next i
EndMacro

Macro STR_STRUCTTOARRAY(struct, field, dest)
  ;converts struct array with selected field type of STR to a string array
  ;e.g.
  ;DIM pdata.Posts(0)
  ;DIM postnums$(0)
  ;STR_STRUCTTOARRAY(pdata, field.s, postnums$)
  len = ArraySize(struct())
  ReDim dest(len)
  For i = 0 To len
    dest(i) = struct(i)\field
  Next i
EndMacro

Macro STR_STRUCTTO2COLARRAY(struct, field1, field2, dest)
  ;converts 2 values from struct array with selected field type of STR to a 2 columned string array
  ;e.g.
  ;DIM pdata.Posts(0)
  ;DIM postnums$(1,0)
  ;STR_STRUCTTOARRAY(pdata, field1.s, field2.s postnums$)
  len = ArraySize(struct())
  ReDim dest(1, len)
  For i = 0 To len
    dest(0,i) = struct(i)\field1
    dest(1,i) = struct(i)\field2
  Next i
EndMacro

Macro STR_INT_STRUCTTO2COLARRAY(struct, str_field1, int_field2, dest)
  ;converts 2 values from struct array with selected field type of STR to a 2 columned string array
  ;e.g.
  ;DIM pdata.Posts(0)
  ;DIM postnums$(1,0)
  ;STR_STRUCTTOARRAY(pdata, field1.s, field2.s postnums$)
  len = ArraySize(struct())
  ReDim dest(1, len)
  For i = 0 To len
    dest(0,i) = struct(i)\str_field1
    dest(1,i) = Str ( struct(i)\int_field2 )
  Next i
EndMacro

Procedure ARRAY_READFILELINES( filename$, Array dest$(1) )
  If ReadFile(0, filename$)
    While Eof(0) = 0
      INSERT( ReadString(0), dest$() )
    Wend
    CloseFile(0)
    
  Else
    ProcedureReturn 1
  EndIf
  
  ProcedureReturn 0
ENDPROCEDURE
