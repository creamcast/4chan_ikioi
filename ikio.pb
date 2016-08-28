;http://a.4cdn.org/mlp/threads.json
EnableExplicit

DeclareModule Ikio
  Declare Run()
  Declare SetBoard(name$)
  Declare ClearThreadList()
EndDeclareModule

Module Ikio
  Structure threadinfo
    no.i
    replies.i
    started.i
    lastmodified.i
    speed.f
    tim.i
    ext.s
    com.s
    sub.s
    board.s
  EndStructure
  
  XIncludeFile "libs/JSON.pb"
  Global apiurl$ = "http://a.4cdn.org/"
  Global boardname$ = "mlp"
  Global NewList threads.threadinfo()
  
  Procedure SetBoard(name$)
    boardname$ = name$
  EndProcedure
  
  Procedure Error(str.s)
    PrintN(str)
  EndProcedure
  
  Procedure.f GetMinSince(start, nowtime) ;Get minutes passed since the thread became alive
    Define tpass = nowtime - start
    If tpass <= 0 : ProcedureReturn 1 : EndIf
    ProcedureReturn tpass / 60
  EndProcedure
  
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Procedure.q GetUTCDate()
      Protected UTCSystemTime.SYSTEMTIME
      Protected UTCFileTime.FILETIME
      Protected qDate.q
      
      GetSystemTime_(UTCSystemTime)
      SystemTimeToFileTime_(UTCSystemTime, UTCFileTime)
      
      qDate = (PeekQ(@UTCFileTime) - 116444736000000000) / 10000000
      ProcedureReturn qDate
    EndProcedure
  CompilerElseIf #PB_Compiler_OS = #PB_OS_MacOS
    Procedure.q GetUTCDate()
      ProcedureReturn time_(0)
      EndProcedure
  CompilerEndIf
  
    CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    Procedure.q GetUTCDate()
      ProcedureReturn time_(0)
      EndProcedure
  CompilerEndIf
  
  CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
    Procedure.s DLHTML2STRING(url.s)
      Define *Buffer = ReceiveHTTPMemory(url)
      If *Buffer
        Define Size = MemorySize(*Buffer)
        Define str.s = PeekS(*Buffer, Size, #PB_UTF8)
        FreeMemory(*Buffer)
        ProcedureReturn str
      Else
        Error("could not retreive json data")
      EndIf
    EndProcedure
  CompilerEndIf
  
    CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    Procedure.s DLHTML2STRING(url.s)
      Define *Buffer = ReceiveHTTPMemory(url.s)
      If *Buffer
        Define Size = MemorySize(*Buffer)
        Define str.s = PeekS(*Buffer, Size, #PB_UTF8)
        FreeMemory(*Buffer)
        ProcedureReturn str
      Else
        Error("could not retreive json data")
      EndIf
    EndProcedure
  CompilerEndIf
  
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  Procedure.s DLHTML2STRING(url.s)
    ;create a tmp file to work with
    Define tmpfile.s = ""
    RetryMakeTmpFile:
    tmpfile = "tmp_" + Str(Random(9999, 0))
    If FileSize(tmpfile) >= 0
      Goto RetryMakeTmpFile 
      Debug "retry make tmp file"
    EndIf
    
    ;dl
    If URLDownloadToFile_(0, url.s, tmpfile, 0, 0) <> #S_OK
      Error("could not retreive json data")
      ProcedureReturn ""
    EndIf
    
    ;prevent caching
    DeleteUrlCacheEntry_(url)
    
    ;read json from tmp file
    
    Define file = ReadFile(#PB_Any, tmpfile)
    Define str.s
    If file
      While Eof(file) = #False
        str = str + ReadString(file)
      Wend
      CloseFile(file)
    Else
      Debug "nofile"
      str = ""
    EndIf
    
    
    DeleteFile(tmpfile)
    ProcedureReturn str
  EndProcedure
    CompilerEndIf
  
  Procedure DLThreadInfo()
    ;Get thread start time (unix time) and number of replies
    Define url$ = apiurl$ + boardname$ + "/" + "catalog.json"
    Define json_threads$ = DLHTML2STRING(url$)
    Debug json_threads$
    If json_threads$
      Define *tmp.jsonObj
      *tmp = JSON_decode(json_threads$)
      Define nowtime = getUTCDate();time_(#Null)
      Define maxpages = *tmp\length - 1
      Define maxthreads = 0
      Define maxlastrep = 0
      Define i, j, tmpthreadnum, tmpstarttime, tmpreplies, tmplastmod, tmpspeed, tmptim
      Define tmpext$, tmpcom$, tmpsub$, tmpboard$
      For i = 0 To maxpages
        maxthreads = *tmp\a(i)\o("threads")\length - 1
        For j = 0 To maxthreads
          ;maxlastrep 	 = *tmp\a(i)\o("threads")\a(j)\o("last_replies")\length - 1 ;for getting last modified
          tmpthreadnum = *tmp\a(i)\o("threads")\a(j)\o("no")\i 
          tmpstarttime = *tmp\a(i)\o("threads")\a(j)\o("time")\i
          tmpreplies	 = *tmp\a(i)\o("threads")\a(j)\o("replies")\i
          tmptim 		 = *tmp\a(i)\o("threads")\a(j)\o("tim")\i
          tmpext$		 = *tmp\a(i)\o("threads")\a(j)\o("ext")\s
          tmpcom$		 = *tmp\a(i)\o("threads")\a(j)\o("com")\s
          tmpsub$		 = *tmp\a(i)\o("threads")\a(j)\o("sub")\s
          tmpboard$	 = boardname$
          ;get last modified
          ;if tmpreplies <> 0 
          ;	tmplastmod = *tmp\a(i)\o("threads")\a(j)\o("last_replies")\a(maxlastrep)\o("time")\i
          ;Else
          ;	tmplastmod = tmpstarttime
          ;endif
          AddElement( threads() )
          threads()\no = tmpthreadnum
          threads()\replies = tmpreplies
          threads()\started = tmpstarttime
          threads()\lastmodified = tmplastmod
          threads()\tim = tmptim
          threads()\ext = tmpext$
          threads()\com = tmpcom$
          threads()\sub = tmpsub$
          threads()\board = tmpboard$
          threads()\speed = tmpreplies / GetMinSince(tmpstarttime, nowtime) * 60 * 24
        Next
      Next      
      JSON_free(*tmp)
      ProcedureReturn #True
    Else
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure ClearThreadList()
    ClearList( threads() )
  EndProcedure
  
  Procedure.s FCellData(Data$)
    ProcedureReturn "<td>" + Data$ + "</td>"
  EndProcedure
  
  Procedure.s FCellDataComment(sub$, com$)
    ProcedureReturn "<td><b><u>" + sub$ + "</u></b><p>" + com$ + "</td>"
  EndProcedure
  
  Procedure.s FCellDataI(ndata)
    ProcedureReturn "<td>" + Str(ndata) + "</td>"
  EndProcedure
  
  Procedure.s FCellDataRank(ndata)
    ProcedureReturn "<td class='rankcol'>" + Str(ndata) + "</td>"
  EndProcedure
  
  Procedure.s FCellDataF(ndata.f)
    ProcedureReturn "<td>" + StrF(ndata, 3) + "</td>"
  EndProcedure
  
  Procedure.s FCellDataLink(ndata, bname$)
    Define url$ = "http://boards.4chan.org/" + bname$ + "/res/" + Str(ndata)
    ProcedureReturn "<td><a href=" + url$ + " target='_blank'>" + Str(ndata) + "</a></td>"
  EndProcedure
  
  Procedure.s FCellDataImage(bname$, tim)
    Define url$ = "http://t.4cdn.org/" + bname$ + "/thumb/" + Str(tim) + "s.jpg"
    Define imglink$ = "<img class='resizethumb' src=" + Chr(34) + url$ + Chr(34) + ">"
    ProcedureReturn "<td class=" + Chr(34) + "imagecol" + Chr(34) + ">" + imglink$ + "</td>"
  EndProcedure
  
  Procedure.s InsertMenu(List pboards$(), html_template$)
    Define menu$ = ""
    Define PH_menu$ = "<!--****menu****-->"
    ForEach pboards$()
      menu$ = menu$ + "<a href=" + pboards$() + ".html >/" + pboards$() + "/</a> "
    Next
    ProcedureReturn ReplaceString( html_template$, PH_menu$, menu$)
  EndProcedure
  
  Procedure GenerateHTML(templatefile$, outname$, List nestpboards$(), limit=-1, forcename$="")
    If ReadFile( 0, templatefile$ )
      ;read the template file
      Define str$ = ""
      While Eof(0) = 0
        str$ = str$ + ReadString( 0 )
      Wend
      CloseFile( 0 );
      
      ;generate html table
      Define PH_table$ = "<!--****table****-->"
      Define PH_board$ = "<!--****boardname****-->"
      Define PH_time$ = "<!--****time****-->"
      Define table$ = ""
      Define c = 0
      ForEach threads()
        table$ = table$ + "<tr>"
        table$ = table$ + FCellDataRank( ListIndex(threads()) + 1 )
        table$ = table$ + FCellData("/" + threads()\board + "/")
        table$ = table$ + FCellDataImage(threads()\board, threads()\tim)
        table$ = table$ + FCellDataComment( threads()\sub, threads()\com )
        table$ = table$ + FCellDataI( threads()\replies )
        table$ = table$ + FCellDataF( threads()\speed )
        table$ = table$ + FCellDataLink( threads()\no, threads()\board )
        table$ = table$ + "</tr>"
        If limit <> -1 : c = c + 1 : EndIf
        If limit <> -1 And c >= limit : Break : EndIf
      Next
      
      str$ = ReplaceString( str$, PH_table$, table$ )
      If forcename$ = ""
        str$ = ReplaceString( str$, PH_board$, "/" + boardname$ + "/")
      Else
        str$ = ReplaceString( str$, PH_board$, forcename$)
      EndIf
      str$ = InsertMenu(nestpboards$(), str$)
      str$ = ReplaceString( str$, PH_time$, FormatDate("GMT %mm/%dd/%yyyy %hh:%ii:%ss", getUTCDate()) )
      If CreateFile(0, outname$) = 0 : ProcedureReturn #False : EndIf
      WriteString( 0, str$ )
      CloseFile( 0 )
    Else
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure CreateBoardRank(List pboards$())
    NewList nestpboards$()
    CopyList( pboards$(), nestpboards$() )
    ForEach pboards$()
      ClearThreadList()
      SetBoard(pboards$())
      PrintN("processing " + pboards$() + "...")
      If DLThreadInfo() = #False : PrintN("Error occured while processing " + boardname$ + ". Trying Next") : Continue : EndIf
      SortStructuredList(threads(), #PB_Sort_Descending, OffsetOf(threadinfo\speed), TypeOf(threadinfo\speed))
      GenerateHTML("template.html", boardname$ + ".html", nestpboards$(), 100)
    Next
  EndProcedure
  
  Procedure CreateAllRank(List pboards$())
    NewList nestpboards$()
    CopyList( pboards$(), nestpboards$() )
    
    ClearThreadList()
    ForEach pboards$()
      SetBoard(pboards$())
      PrintN("processing " + pboards$() + "...")
      If DLThreadInfo() = #False : PrintN("Error occured while processing " + boardname$ + ". Trying Next") : Continue : EndIf
    Next
    SortStructuredList(threads(), #PB_Sort_Descending, OffsetOf(threadinfo\speed), TypeOf(threadinfo\speed))
    GenerateHTML("template.html", "index.html", nestpboards$(), 50, "4chan")
  EndProcedure
  
  Procedure Run()
    NewList pboards$()
    AddElement( pboards$() ) : pboards$() = "vg"
    AddElement( pboards$() ) : pboards$() = "vr"
    AddElement( pboards$() ) : pboards$() = "g"
    AddElement( pboards$() ) : pboards$() = "int"
    AddElement( pboards$() ) : pboards$() = "mlp"
    AddElement( pboards$() ) : pboards$() = "pol"
    AddElement( pboards$() ) : pboards$() = "sp"
    AddElement( pboards$() ) : pboards$() = "v"
    AddElement( pboards$() ) : pboards$() = "tv"
    AddElement( pboards$() ) : pboards$() = "r9k"
    PrintN("Creating rank for each board...")
    CreateBoardRank(pboards$())
    PrintN("Creating rank for all board...")
    CreateAllRank(pboards$())
    PrintN("done")
  EndProcedure
EndModule

InitNetwork()
OpenConsole()
Ikio::Run()
CloseConsole()
; IDE Options = PureBasic 5.42 LTS (MacOS X - x64)
; ExecutableFormat = Console
; CursorPosition = 67
; FirstLine = 53
; Folding = ------
; EnableXP
; Executable = macikioi
; CompileSourceDirectory