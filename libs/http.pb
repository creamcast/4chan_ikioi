; HTTPQuery & SimpleHTTP Library by DarkPlayer & PureFan

; Comment out the following line if you dont want to use EnableExplicit for your own code
EnableExplicit

#HTTP_ERROR_INVALID_QUERY       = -1    ; Your query was invalid
#HTTP_ERROR_INVALID_RESPONSE    = -2    ; The response of the server was invalid or is not supported

#HTTP_ERROR_CONNECT_FAILED      = -3    ; Failed to establish connection
#HTTP_ERROR_CONNECTION_ABORTED  = -4    ; Connection was aborted in the middle of a transmission
#HTTP_ERROR_CONNECTION_TIMEOUT  = -5    ; Timeout occured!

#HTTP_ERROR_OUT_OF_MEMORY       = -6    ; Out of memory
#HTTP_ERROR_ZLIB_DOESNT_WORK    = -7

; Enable gzip compression
#HTTP_ENABLE_GZIP_COMPRESSION   = #True

CompilerIf #HTTP_ENABLE_GZIP_COMPRESSION
  ; Use one of the following two commands to load the zip packer!
  
  UsePNGImageDecoder()
  ; UseZipPacker()
  
  ;- Zlib compression
  
  Prototype.i z_alloc_func(*opaque, items.i, size.i)
  Prototype.i z_free_func(*opaque, *address)
  
  Macro InsertPadding(nr)
     CompilerIf   #PB_Compiler_Processor = #PB_Processor_x64
        padding#nr.l
     CompilerEndIf
  EndMacro
  
  Structure z_stream
    *next_in;         /* next input byte */
    avail_in.l;       /* number of bytes available at next_in */
    InsertPadding(1)
    total_in.i;       /* total nb of input bytes read so far */
  
    *next_out;        /* next output byte should be put there */
    avail_out.l;      /* remaining free space at next_out */
     InsertPadding(2)
    total_out.i;      /* total nb of bytes output so far */
  
    *msg;             /* last error message, NULL if no error */
    *state;           /* not visible by applications */
  
    zalloc.z_alloc_func;  /* used to allocate the internal state */
    zfree.z_free_func;   /* used to free the internal state */
    *opaque;          /* private data object passed to zalloc and zfree */
  
    data_type.l;      /* best guess about the data type: binary or text */
    InsertPadding(3)
    adler.i;          /* adler32 value of the uncompressed data */
    reserved.i;       /* reserved for future use */
  EndStructure
  
  #ZLIB_VERSION    = "1.2.4"
  
  ; Allowed flush vales; see deflate() and inflate() below for details
  #Z_NO_FLUSH      = 0
  #Z_PARTIAL_FLUSH = 1 
  #Z_SYNC_FLUSH    = 2
  #Z_FULL_FLUSH    = 3
  #Z_FINISH        = 4
  #Z_BLOCK         = 5
  #Z_TREES         = 6
  
  ; Return codes for the compression/decompression functions. Negative values are errors, positive values are used for special but normal events. 
  #Z_OK            = 0
  #Z_STREAM_END    = 1
  #Z_NEED_DICT     = 2
  #Z_ERRNO         = -1
  #Z_STREAM_ERROR  = -2
  #Z_DATA_ERROR    = -3
  #Z_MEM_ERROR     = -4
  #Z_BUF_ERROR     = -5
  #Z_VERSION_ERROR = -6
  
  ; Compression levels
  #Z_NO_COMPRESSION        = 0
  #Z_BEST_SPEED            = 1
  #Z_BEST_COMPRESSION      = 9
  #Z_DEFAULT_COMPRESSION   = -1
  
  ; Compression strategy - see deflateInit2() below for details. 
  #Z_FILTERED           = 1
  #Z_HUFFMAN_ONLY       = 2
  #Z_RLE                = 3
  #Z_FIXED              = 4
  #Z_DEFAULT_STRATEGY   = 0
  
  ; Possible values of the data_type field (though see inflate()). 
  #Z_BINARY  = 0
  #Z_TEXT    = 1
  #Z_ASCII   = #Z_TEXT   
  #Z_UNKNOWN = 2
  
  ; The deflate compression method (the only one supported in this version). 
  #Z_DEFLATED  = 8
  
  ; For initializing zalloc, zfree, opaque. 
  #Z_NULL  = 0 
  
  #MAX_WBITS = 15
  
  ImportC ""
    zlibVersion.i()
    
    inflateInit_.i(*strm.z_stream, version.p-ascii, stream_size.i)
    inflateInit2_.i(*strm.z_stream, windowBits.l, version.p-ascii, stream_size.i)
    inflate.i(*strm.z_stream, flush.i)
    inflateEnd.i(*strm.z_stream);
    
    deflateInit_.i(*strm.z_stream, level.i, version.p-ascii, stream_size.i)
    deflate.i(*strm.z_stream, flush.i)
    deflateEnd.i(*strm.z_stream)
    deflateReset.i(*strm.z_stream)
    
    zlibCompileFlags.i()
  EndImport
  
  Macro inflateInit(strm)
    inflateInit_((strm), #ZLIB_VERSION, SizeOf(z_stream))
  EndMacro
  
  Macro inflateInit2(strm, windowBits)
    inflateInit2_((strm), (windowBits), #ZLIB_VERSION, SizeOf(z_stream))
  EndMacro
CompilerEndIf


; Structure used for RequestHeaders / PostData / ResponseHeaders
Structure HTTPQuery_KeyValue
  key.s
  value.s
EndStructure

; Structure to save the status of an HTTP request
Structure HTTPQuery
  
  ; Query arguments
  method.s
  host.s
  port.i
  path.s
  List RequestHeaders.HTTPQuery_KeyValue()
  
  ; Post data
  rawPostData.s
  List PostData.HTTPQuery_KeyValue()
  
  ; Timeouts
  timeout_sendRequest.i
  timeout_recvHeader.i
  timeout_read.i
  
  ; Flags
  max_redirects.i
  
  ; The network connection (as long as data is transmitted)
  connection.i
  
  ; Buffer to receive data
  outputBufferLength.i
  *outputBuffer.BYTE
  outputBufferPos.i
  
  ; Statuscode and response headers
  statuscode.i
  List ResponseHeaders.HTTPQuery_KeyValue()
  
  ; Used for parsing etc.
  totalContentLength.i
  totalBytesReceived.i
  contentLength.i
  transferEncoding.s
  contentEncoding.s
  chunkSize.i
  
  CompilerIf #HTTP_ENABLE_GZIP_COMPRESSION
    use_zlib.i
    zlib.z_stream
  CompilerEndIf
  
EndStructure

Structure Base64Table
   entry.c[0]
EndStructure

Structure Base64Input
   b.a[3]
EndStructure

DataSection
   base64Table:
   Data.s "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
EndDataSection


; Creates a random boundary for multipart messages
Procedure.s randomBoundary(length.i = 32)
  Protected string.s = ""
  Protected chartable.s = ""
  Protected i.i
  
  For i = 'a' To 'z'
    chartable + Chr(i)
  Next
  For i = 'A' To 'Z'
    chartable + Chr(i)
  Next
  For i = '0' To '9'
    chartable + Chr(i)
  Next
  
  For i = 1 To length
    string + Mid(chartable, Random(Len(chartable)-1) + 1, 1)
  Next
  
  ProcedureReturn string
EndProcedure

; Encodes a url
; IMPORTANT NOTE: The PureBasic implementation of URLEncoder is completely useless and doesnt do what the name suggests!
Procedure.s encodeURL_UTF8(input.s)
   Protected result.s = ""
   Protected bufferLength = StringByteLength(input, #PB_UTF8) 
   Protected *buffer.BYTE = AllocateMemory(bufferLength + 1) ;+1 for NULL Character

   If *buffer = 0
     Debug "Unable to allocate memory"
      ProcedureReturn ""
   EndIf
   
   ; Convert string to utf8
   PokeS(*buffer, input, -1, #PB_UTF8)
   
   ; Do the encoding
   Protected *pos.BYTE = *buffer
   While *pos\b <> 0
     Protected char.b = *pos\b
     
      If (char >= 'A' And char <= 'Z') Or (char >= 'a' And char <= 'z') Or (char >= '0' And char <= '9')  Or char = '-' Or char = '_' Or char = '.' Or char = '~'
        result + Chr(char)
      Else
         result + "%" + RSet(Hex(Char), 2, "0")
      EndIf
      
      *pos + SizeOf(BYTE)
   Wend

   FreeMemory(*buffer)
   
   ; Return result
   ProcedureReturn result
EndProcedure


; Encodes only unallowed characters in an url
Procedure.s encodeURLWeak_UTF8(input.s)
   Protected result.s = ""
   Protected bufferLength = StringByteLength(input, #PB_UTF8) 
   Protected *buffer.BYTE = AllocateMemory(bufferLength + 1) ;+1 for NULL Character

   If *buffer = 0
     Debug "Unable to allocate memory"
      ProcedureReturn ""
   EndIf
   
   ; Convert string to utf8
   PokeS(*buffer, input, -1, #PB_UTF8)
   
   ; Do the encoding
   Protected *pos.BYTE = *buffer
   While *pos\b <> 0
     Protected char.b = *pos\b
     
      If (char >= 'A' And char <= 'Z') Or (char >= 'a' And char <= 'z') Or (char >= '0' And char <= '9')  Or char = '-' Or char = '_' Or char = '.' Or char = '~'
        result + Chr(char)
      
      ; Additionally dont encode the following characters, which might make sense in an URL
      ElseIf char = '!' Or (char >= '#' And char <= ',') Or char = '/' Or char = ':' Or char = ';' Or char = '=' Or char = '?' Or char = '@' Or char = '[' Or char = ']'
      	result + Chr(char)
      	        
      Else
         result + "%" + RSet(Hex(Char), 2, "0")
      EndIf
      
      *pos + SizeOf(BYTE)
   Wend

   FreeMemory(*buffer)
   
   ; Return result
   ProcedureReturn result
EndProcedure

; Base 64 Encoder
; IMPORTANT NOTE: The PureBasic implementation of Base64Encoder doesnt provide any way to get exact amount of memory required.
; Moreover the annotations in the documentation dont make any sense: "with a minimum size of 64 bytes" ?!
; This implementation does exactly what it should, and returns the result as a PureBasic string!
Procedure.s encodeBase64(*inputMemory.BYTE, length.i)
  Protected *table.Base64Table       = ?base64Table
  Protected *inputData.Base64Input   = *inputMemory
   Protected result.s                        = ""
   Protected endTag.s                        = ""
   Protected i.i
   
   ; Get end tag
   If length % 3 = 1
     endTag = "=="
   ElseIf length % 3 = 2
     endTag = "=" 
   EndIf
   
   ; As long as we have more input
   While length > 0
     
     ; Read input value as 24 bit number
      Protected inputValue.i = 0
      For i = 0 To length
         If (i >= 3) :   Break : EndIf
         inputValue + (*inputData\b[i] << (16-i*8))   
      Next
      
      ; Write as four 6 bit numbers
      For i = 0 To length
         If (i >= 4) :   Break : EndIf
         result + Chr(*table\entry[(inputValue >> (18-i*6)) & 63])
      Next
      
      length          - 3
      *inputData    + 3
   Wend

   ProcedureReturn result + endTag
EndProcedure

; First converts the string input to UTF8, then calls the Base 64 Encoder above
Procedure.s encodeBase64_UTF8(input.s)
   Protected bufferLength = StringByteLength(input, #PB_UTF8)
   Protected *buffer.BYTE = AllocateMemory(bufferLength + 1)
   Protected result.s
   
   If *buffer = 0
     Debug "Unable to allocate memory"
      ProcedureReturn ""
   EndIf
   
   PokeS(*buffer, input, -1, #PB_UTF8)
   result = encodeBase64(*buffer, bufferLength)
   
   FreeMemory(*buffer)
   
   ProcedureReturn result
EndProcedure

; Extract the value from a field like "value; param1=arg1; param2=arg2"
Procedure.s header_getValue(header.s)
  Protected trn.i = FindString(header, ";")
  If trn = 0
    ProcedureReturn header
  Else
    ProcedureReturn Mid(header, 1, trn-1)
  EndIf
EndProcedure

; Extract the argument for a specific param from a field like "value; param1=arg1; param2=arg2"
Procedure.s header_getParam(header.s, param.s, defaultValue.s = "")
  Protected trn.i = FindString(header, ";")
  If trn = 0
    ProcedureReturn defaultValue
  EndIf
  
  Protected nexttrn.i
  Protected keyvalue.s, key.s, value.s
  
  ; If the current position is inside the header string
  While trn <= Len(header)
    
    ; Search for next ;
    nexttrn = FindString(header, ";", trn + 1)
    If nexttrn = 0
      nexttrn = Len(header) + 1
    EndIf
    
    ; Parse key=value
    keyvalue  = Trim(Mid(header, trn + 1, nexttrn-trn-1))
    trn       = FindString(keyvalue, "=")
    If trn <> 0
      If LCase(Mid(keyvalue, 1, trn-1)) = LCase(param)
        ProcedureReturn Mid(keyvalue, trn+1)
      EndIf
    EndIf
    
    trn = nexttrn
  Wend
  
  ProcedureReturn defaultValue
EndProcedure

; Searches for a newline in a specific memory block
Procedure.i memoryFindNewline(*memory.BYTE, memoryLength)
  Protected i.i = 0
  
  While memoryLength-i >= 2 ; We need at least 2 bytes to detect CRLF
    
    If *memory\b = 13
      *memory + SizeOf(BYTE)
      i       + 1
      
      If *memory\b = 10
        *memory + SizeOf(BYTE)
        i + 1
      EndIf
      
      ProcedureReturn i
      
    ElseIf *memory\b = 10
      *memory + SizeOf(BYTE)
      i       + 1
      
      ProcedureReturn i
    EndIf
    
    *memory + SizeOf(BYTE)
    i       + 1
  Wend
  
  ProcedureReturn 0
EndProcedure

; Add header to the list of request headers or replace existing one
Procedure HTTPQuery_AddRequestHeader(*http.HTTPQuery, key.s, value.s)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn 0
  EndIf
  
  ; Replace if this key already exists
  ForEach *http\RequestHeaders()
    If LCase(*http\RequestHeaders()\key) = LCase(key)
      
      *http\RequestHeaders()\key   = key
      *http\RequestHeaders()\value = value
      ProcedureReturn 1
      
    EndIf
  Next
  
  AddElement(*http\RequestHeaders())
  *http\RequestHeaders()\key   = key
  *http\RequestHeaders()\value = value
EndProcedure

; Read one specific header from the list of request headers
Procedure.s HTTPQuery_GetRequestHeader(*http.HTTPQuery, key.s, defaultValue.s = "")
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn defaultValue
  EndIf
  
  ; Search for key
  ForEach *http\RequestHeaders()
    If LCase(*http\RequestHeaders()\key) = LCase(key)
      ProcedureReturn *http\RequestHeaders()\value
    EndIf
  Next
  
  ProcedureReturn defaultValue
EndProcedure

; Add header to the list of response headers or replace existing one
Procedure HTTPQuery_AddResponseHeader(*http.HTTPQuery, key.s, value.s)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn 0
  EndIf
  
  ; Replace if this key already exists
  ForEach *http\ResponseHeaders()
    If LCase(*http\ResponseHeaders()\key) = LCase(key)
      
      *http\ResponseHeaders()\key   = key
      *http\ResponseHeaders()\value = value
      ProcedureReturn 1
      
    EndIf
  Next
  
  AddElement(*http\ResponseHeaders())
  *http\ResponseHeaders()\key   = key
  *http\ResponseHeaders()\value = value
EndProcedure

; Read one specific header from the list of response headers
Procedure.s HTTPQuery_GetResponseHeader(*http.HTTPQuery, key.s, defaultValue.s = "")
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn defaultValue
  EndIf
  
  ; Search for key
  ForEach *http\ResponseHeaders()
    If LCase(*http\ResponseHeaders()\key) = LCase(key)
      ProcedureReturn *http\ResponseHeaders()\value
    EndIf
  Next
  
  ProcedureReturn defaultValue
EndProcedure


; Splits the given path into hostname, port, path, etc.
Procedure HTTPQuery_ParsePath(*http.HTTPQuery, path.s)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn 0
  EndIf
  
  Protected trn.i
  Protected hostname.s
  Protected userpass.s, user.s, pass.s
  
  If LCase(Left(path.s, 8)) = "https://"
    Debug "Https not supported, will use fallback to http"
    path = "http://" + Mid(path, 9)
  EndIf
  
  ; User has a separate http-field
  If LCase(Left(path.s,7)) = "http://"
    
    ; Split hostname <-> path
    trn = FindString(path, "/", 8)
    If trn = 0
      trn = Len(path) +1
    EndIf
    *http\path = Mid(path, trn)
    hostname.s = Mid(path, 8, trn-8)
    
    ; Split login data <-> hostname
    trn = FindString(hostname, "@")
    If trn <> 0
      
      userpass.s = Mid(hostname, 1, trn-1)
      hostname = Mid(hostname, trn+1)
      
      ; Append base 64 encoded userpass
      HTTPQuery_AddRequestHeader(*http, "Authorization", "Basic " + encodeBase64_UTF8(userpass))
      
    EndIf
    
    ; Split hostname <-> port
    trn = FindString(hostname, ":")
    If trn <> 0
      *http\port = Val(Mid(hostname, trn+1))
      hostname = Mid(hostname, 1, trn-1)
    EndIf
    
    *http\host = hostname
    
  Else
    *http\path = path
  EndIf
  
  ; Ensure that path starts with /
  If Left(*http\path, 1) <> "/"
    *http\path = "/" + *http\path
  EndIf
  
  ; Automatically fix the URL if it is given incorrect
  *http\path = encodeURLWeak_UTF8(*http\path)
  
  ; Update host field
  HTTPQuery_AddRequestHeader(*http, "Host", *http\host)
EndProcedure

; Appends a query string like "a=b&c=d" to the path
Procedure HTTPQuery_AddQueryString(*http.HTTPQuery, query.s)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn 0
  EndIf
  
  Protected trn.i
  
  trn = FindString(*http\path, "?")
  If trn = 0
    *http\path + "?"
  Else
    *http\path + "&"
  EndIf
  
  *http\path + query
EndProcedure

; Appends another key-value pair at the end of the path. Key and value will be encoded properly first.
Procedure HTTPQuery_AddQueryField(*http.HTTPQuery, key.s, value.s)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn 0
  EndIf
  
  Protected query.s = encodeURL_UTF8(key) + "=" + encodeURL_UTF8(value)
  ProcedureReturn HTTPQuery_AddQueryString(*http, query)
EndProcedure


; Create a new HTTPQuery object. Host and Port can be used to overwrite the default values or the values extracted from the path.
; If a query is given, it is appended to the path.
; IMPORTANT NOTE: Free the object to prevent a memory leak! 
Procedure HTTPQuery_New(path.s, method.s = "GET", host.s = "", port.i = -1, query.s = "")  
  Protected *http.HTTPQuery = AllocateMemory(SizeOf(HTTPQuery))
  
  If *http = 0
    Debug "Unable to allocate memory for HTTPQuery"
    ProcedureReturn 0
  EndIf
  
  ; Initialize lists
  InitializeStructure(*http, HTTPQuery)
  
  ; Ensure that method is uppercase
  method = UCase(method)
  
  If method <> "GET" And method <> "POST" And method <> "HEAD"
    Debug "Invalid request method given, will use GET instead"
    method = "GET"
  EndIf
  
  ; Save some parameters
  *http\method  = method
  *http\host    = ""
  *http\port    = 80
  *http\path    = "/"
  
  ; Parse path
  HTTPQuery_ParsePath(*http, path)
  
  ; Overwrite host
  If host <> "":
    *http\host = host
  EndIf
  
  ; Overwrite port
  If port <> -1:
    *http\port = port
  EndIf
  
  If query <> "":
    HTTPQuery_AddQueryString(*http, query)
  EndIf  
  
  ; Add default header fields
  HTTPQuery_AddRequestHeader(*http, "Accept", "*/*")
  HTTPQuery_AddRequestHeader(*http, "Connection", "close")
  
  CompilerIf #HTTP_ENABLE_GZIP_COMPRESSION
    HTTPQuery_AddRequestHeader(*http, "Accept-Encoding", "gzip, deflate")
  CompilerEndIf
  
  ; Setup max redirects
  *http\max_redirects = 10
  
  ; Setup default timeout values
  *http\timeout_sendRequest = 20000
  *http\timeout_recvHeader  = 20000
  *http\timeout_read        = 5000
  
  ; Initialize critical values
  *http\statuscode    = 0
  *http\outputBuffer  = 0
  
  ProcedureReturn *http
EndProcedure

; Frees a HTTPQuery object
Procedure HTTPQuery_Free(*http.HTTPQuery)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn 0
  EndIf
  
  If *http\connection <> 0
    CloseNetworkConnection(*http\connection)
    *http\connection = 0
  EndIf
  
  If *http\outputBuffer <> 0
    FreeMemory(*http\outputBuffer)
    *http\outputBuffer = 0
  EndIf
  
  CompilerIf #HTTP_ENABLE_GZIP_COMPRESSION
    If *http\use_zlib
      inflateEnd(*http\zlib)
      *http\use_zlib = #False
    EndIf
  CompilerEndIf
  
  ClearStructure(*http, HTTPQuery)
  FreeMemory(*http)
EndProcedure

; Adds PostData fields to the internal list
Procedure HTTPQuery_AddPostDataField(*http.HTTPQuery, key.s, value.s)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn 0
  EndIf
  
  AddElement(*http\PostData())
  *http\PostData()\key    = key
  *http\PostData()\value  = value
EndProcedure

; Assigns a string containing raw post data
Procedure HTTPQuery_SetRawPostData(*http.HTTPQuery, rawPostData.s)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn 0
  EndIf
  
  *http\rawPostData = rawPostData
EndProcedure

; Change the maximum number of redirects
Procedure HTTPQuery_SetMaxRedirects(*http.HTTPQuery, max_redirects.i = 10)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn 0
  EndIf
  
  *http\max_redirects = max_redirects
EndProcedure

; Opens the connection and follows redirects, until a stable connection is established
; Returns <> 0 if everything is okay
Procedure HTTPQuery_Open(*http.HTTPQuery)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn 0
  EndIf
  
  If *http\connection <> 0
    Debug "Connection already opened"
    ProcedureReturn 0
  EndIf
  
  While #True
  
    If *http\host = ""
      *http\statuscode = #HTTP_ERROR_CONNECT_FAILED
      Debug "No hostname given, unable to establish connection"
      ProcedureReturn 0
    EndIf
    
    If Len(*http\rawPostData) And ListSize(*http\PostData()) > 0
      Debug "Mixing rawPostData and other postData not allowed in this implementation!"
      ProcedureReturn 0
    EndIf
    
    If *http\outputBuffer = 0
      *http\outputBufferLength  = 1024*1024
      *http\outputBuffer        = AllocateMemory(*http\OutputBufferLength)
    EndIf
    
    ; In each case flush buffer in order to drop previous requests
    *http\outputBufferPos = 0
    
    ; Failed to allocate output buffer
    If *http\outputBuffer = 0
      *http\statuscode = #HTTP_ERROR_OUT_OF_MEMORY
      Debug "Failed to allocate output buffer"
      ProcedureReturn 0
    EndIf
    
    ; Connect ...
    *http\connection = OpenNetworkConnection(*http\host, *http\port, #PB_Network_TCP)
    
    If *http\connection = 0
      *http\statuscode = #HTTP_ERROR_CONNECT_FAILED
      Debug "Failed to open connection to " + *http\host
      ProcedureReturn 0  
    EndIf
    
    Protected contentType.s
    Protected boundary.s
    
    Protected *postData.BYTE = 0
    Protected postDataLength = 0
    
    Protected request.s
    Protected *requestData.BYTE = 0
    Protected requestDataLength = 0
    
    Protected timeout.i
    Protected bytesProcessed.i
    Protected temp.i
    
    Protected endofheader.i
    Protected header.s
    Protected firstline.i
    Protected newline.i
    
    Protected trn.i
    
    ; POST data
    If *http\method = "POST"
      
      ; Get the contentType or set if not given
      contentType.s = Trim(HTTPQuery_GetRequestHeader(*http, "Content-Type"))
      
      If header_getValue(contentType) = "multipart/form-data"
        
        ; Get boundary
        boundary = header_getParam(contentType, "boundary")
        
        ; No boundary given, create a new one
        If boundary = ""
          boundary = randomBoundary()
          contentType + "; boundary=" + boundary
          HTTPQuery_AddRequestHeader(*http, "Content-Type", contentType)
        EndIf
        
      ElseIf contentType = "application/x-www-form-urlencoded"
        ; Everything okay!
              
      Else
        
        If contentType <> ""
          Debug "Warning: Unknown contentType given, I will use application/x-www-form-urlencoded instead"
        EndIf 
         
        contentType = "application/x-www-form-urlencoded"
        HTTPQuery_AddRequestHeader(*http, "Content-Type", contentType)
      EndIf
      
      ; Convert PostData to rawPostData
      If ListSize(*http\PostData())
        *http\rawPostData = ""
        
        If header_getValue(contentType) = "multipart/form-data"
          
          ForEach *http\PostData()
            *http\rawPostData + "--" + boundary + #CRLF$
            *http\rawPostData + "Content-Disposition: form-data; name=" + Chr(34) + *http\PostData()\key + Chr(34) + #CRLF$
            *http\rawPostData + #CRLF$
            *http\rawPostData + *http\PostData()\value + #CRLF$
          Next
          
          ; End of multipart message
          *http\rawPostData + "--" + boundary + "--"
            
        Else ; "application/x-www-form-urlencoded"
          
          ForEach *http\PostData()
            If *http\rawPostData <> ""
              *http\rawPostData + "&"
            EndIf
            *http\rawPostData + encodeURL_UTF8(*http\PostData()\key) + "=" + encodeURL_UTF8(*http\PostData()\value)
          Next
          
        EndIf
  
        ; Fallback to rawPostData
        ClearList(*http\PostData())
      EndIf
      
      ; Encode data properly and set Content-Length header
      If Len(*http\rawPostData)
        postDataLength  = StringByteLength(*http\rawPostData, #PB_UTF8)
        *postData       = AllocateMemory(postDataLength + 1)
        
        If *postData <> 0
          PokeS(*postData, *http\RawPostData, -1, #PB_UTF8)
          
          HTTPQuery_AddRequestHeader(*http, "Content-Length", Str(postDataLength))
        EndIf 
      EndIf
      
    EndIf
    
    
    ;Debug "'" + *http\rawPostData + "'"
    
    ; Connection established, send our request
    request.s = *http\method + " " + *http\path + " HTTP/1.1" + #CRLF$
    
    ForEach *http\RequestHeaders()
      request.s + *http\RequestHeaders()\key + ": " + *http\RequestHeaders()\value + #CRLF$
    Next
    
    request.s + #CRLF$
    
    ;Debug "'" + request + "'"
    
    ; Convert request to *requestData
    requestDataLength = StringByteLength(request, #PB_UTF8)
    *requestData      = AllocateMemory(requestDataLength + 1)
    
    If *requestData <> 0
      PokeS(*requestData, request, -1, #PB_UTF8)
    EndIf
    
    ; Start timer ...
    timeout = ElapsedMilliseconds() + *http\timeout_sendRequest
    
    If *requestData = 0
      Debug "Failed to allocate memory for header, giving up"
      
      CloseNetworkConnection(*http\connection)
      *http\connection = 0
      *http\statuscode  = #HTTP_ERROR_OUT_OF_MEMORY
    EndIf
    
    ; Send header
    If *requestData <> 0
      
      ; Send the header!
      If *http\connection <> 0
        bytesProcessed = 0
        
        While bytesProcessed < requestDataLength
          temp = SendNetworkData(*http\connection, *requestData + bytesProcessed, requestDataLength - bytesProcessed)
          
          If temp > 0
            bytesProcessed + temp
          EndIf
          
          If ElapsedMilliseconds() > timeout
            Debug "Timeout when sending HTTP request, giving up"
            
            CloseNetworkConnection(*http\connection)
            *http\connection = 0
            *http\statuscode = #HTTP_ERROR_CONNECTION_TIMEOUT
            Break
          EndIf
          
          ; Wait a bit if we are too fast in sending the header
          Delay(1)
        Wend
      EndIf
      
      FreeMemory(*requestData)
      *requestData = 0
    EndIf
    
    ; Send post data if given
    If *postData <> 0
      
      ; Send the post data
      If *http\connection <> 0
        bytesProcessed = 0
        
        While bytesProcessed < postDataLength
          temp = SendNetworkData(*http\connection, *postData + bytesProcessed, postDataLength - bytesProcessed)
          
          If temp > 0
            bytesProcessed + temp
          EndIf
          
          If ElapsedMilliseconds() > timeout
            Debug "Timeout when sending HTTP request, giving up"
            
            CloseNetworkConnection(*http\connection)
            *http\connection = 0
            *http\statuscode = #HTTP_ERROR_CONNECTION_TIMEOUT
            Break
          EndIf
          
          ; Wait a bit if we are too fast in sending the header
          Delay(1)
        Wend
      EndIf
      
      FreeMemory(*postData)
      *postData = 0
    EndIf
    
    ; Parse events
    If *http\connection <> 0 And *http\outputBuffer <> 0
      firstline     = #True
      endofheader   = #False
      
      ClearList(*http\ResponseHeaders())
      
      ; Start timer
      timeout       = ElapsedMilliseconds() + *http\timeout_recvHeader      
      
      While Not endofheader
        Protected event.i = NetworkClientEvent(*http\connection)
        
        If event = #PB_NetworkEvent_Disconnect
          CloseNetworkConnection(*http\connection)
          *http\connection = 0
          Break
          
        ElseIf event = #PB_NetworkEvent_Data
          
          If *http\outputBufferPos >= *http\outputBufferLength
            Debug "Buffer overflow, dropping previous data"
            *http\outputBufferPos = 0
          EndIf
          
          temp = ReceiveNetworkData(*http\connection, *http\outputBuffer + *http\outputBufferPos, *http\outputBufferLength - *http\outputBufferPos)
          
          If temp > 0
            *http\outputBufferPos + temp
          EndIf
          
          While *http\outputBufferPos > 0
            newline = memoryFindNewline(*http\outputBuffer, *http\outputBufferPos)
            If newline = 0
              Break
            EndIf
            
            header.s = PeekS(*http\outputBuffer, newline, #PB_UTF8)
            
            ; Remove linebreak at the end
            If Right(header, 2) = #CRLF$
              header = Mid(header, 1, Len(header)-2)
            ElseIf Right(header, 1) = Chr(13) Or Right(header, 1) = Chr(10)
              header = Mid(header, 1, Len(header)-1)
            EndIf
            
            ;Debug "Header: '" + header + "'"
            
            If firstline
              firstline = #False
              
              ; If no statuscode is found, this is also invalid response
              *http\statuscode = #HTTP_ERROR_INVALID_RESPONSE
              
              ; Extract and save the statuscode
              trn = FindString(header, " ")
              If trn <> 0:
                header = Mid(header, trn+1)
                
                trn = FindString(header, " ")
                If trn <> 0
                  
                  temp = Val(Mid(header, 1, trn-1))
                  If temp <= 0
                    *http\statuscode = #HTTP_ERROR_INVALID_RESPONSE
                  Else
                    *http\statuscode = temp
                  EndIf
                  
                EndIf
              EndIf
              
            ElseIf Len(header) > 0
              
              ; Extract and save header fields
              trn = FindString(header, ":")
              If trn <> 0:
                HTTPQuery_AddResponseHeader(*http, Mid(header, 1, trn-1), Trim(Mid(header, trn+1)) )
              EndIf
            
            EndIf
              
            ; Reduce length in buffer by the amount we have just parsed
            MoveMemory(*http\outputBuffer + newline, *http\outputBuffer, *http\outputBufferPos - newline)
            *http\outputBufferPos - newline
            
            ; Break loop if this was the last header field
            If Len(header) = 0
              If *http\statuscode = 100
                
                firstline = #True
                ClearList(*http\ResponseHeaders())
                
                Continue
              EndIf
              
              ; End of header, parse remaining stuff
              endofheader = #True
              Break
            EndIf
            
          Wend
          
        EndIf
        
        If endofheader
          Break
        EndIf
        
        If ElapsedMilliseconds() > timeout
          Debug "Timeout when sending HTTP request, giving up"
          
          CloseNetworkConnection(*http\connection)
          *http\connection = 0
          *http\statuscode = #HTTP_ERROR_CONNECTION_TIMEOUT
          Break
        EndIf
        
        Delay(1)
      Wend
      
    EndIf
    
    ; Post-process what to do next ...
    If *http\max_redirects > 0 And (*http\statuscode = 301 Or *http\statuscode = 302)
      Protected location.s = HTTPQuery_GetResponseHeader(*http, "Location")
      If location <> ""
        
        Debug "Redirecting to location '" + location + "'"
        
        ; Follow the redirect
        *http\max_redirects - 1
        
        ; Close the original connection
        If *http\connection <> 0
          CloseNetworkConnection(*http\connection)
          *http\connection = 0
        EndIf
        
        ; Parse the new location
        HTTPQuery_ParsePath(*http, location)
        
        ; One more iteration, try again with new location!
        Continue
      EndIf
    EndIf
    
    ; Setup content length to zero
    *http\contentLength       = 0
    *http\totalContentLength  = 0
    
    CompilerIf #HTTP_ENABLE_GZIP_COMPRESSION
      If *http\use_zlib
        inflateEnd(*http\zlib)
        *http\use_zlib = #False
      EndIf
    CompilerEndIf
    
    ; Some kind of valid statuscode ...
    If *http\statuscode >= 0
      *http\contentLength       = Val(HTTPQuery_GetResponseHeader(*http, "Content-Length", "-1"))
      *http\transferEncoding    = HTTPQuery_GetResponseHeader(*http, "Transfer-Encoding")
      *http\contentEncoding     = HTTPQuery_GetResponseHeader(*http, "Content-Encoding")
      *http\chunkSize           = -1
      
      ; Ignore contentLength if transfer encoding is given
      If *http\transferEncoding <> ""
        *http\contentLength = -1
      EndIf
      
      ; Remember total length
      *http\totalContentLength  = *http\contentLength
      *http\totalBytesReceived  = 0
      
      CompilerIf #HTTP_ENABLE_GZIP_COMPRESSION
        If *http\contentEncoding <> ""
          
            With *http\zlib
             \zalloc = #Z_NULL
             \zfree  = #Z_NULL
             \opaque = #Z_NULL
             
             \next_in  = #Z_NULL
             \avail_in = 0
             \total_in = 0
             
             \next_out   = #Z_NULL
             \avail_out  = 0
             \total_out  = 0
           EndWith         
          
           If inflateInit2(*http\zlib, #MAX_WBITS+32) = #Z_OK
             *http\use_zlib = #True
             
           Else
             *http\statuscode = #HTTP_ERROR_ZLIB_DOESNT_WORK
             
            CloseNetworkConnection(*http\connection)
            *http\connection = 0
             EndIf
         
        EndIf        
      CompilerEndIf
      
      ProcedureReturn 1  
    EndIf
    
    ; Immediately quit if we get here
    Break
  Wend
  
  ProcedureReturn 0
EndProcedure

; Closes an opened connection - not necessary if you want to free the HTTPQuery object immediately afterwards
Procedure HTTPQuery_Close(*http.HTTPQuery)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn 0
  EndIf
  
  If *http\connection <> 0
    CloseNetworkConnection(*http\connection)
    *http\connection = 0
  EndIf
  
  If *http\outputBuffer <> 0
    FreeMemory(*http\outputBuffer)
    *http\outputBuffer = 0
  EndIf
  
  CompilerIf #HTTP_ENABLE_GZIP_COMPRESSION
    If *http\use_zlib
      inflateEnd(*http\zlib)
      *http\use_zlib = #False
    EndIf
  CompilerEndIf
  
  ; Additionally flush lists
  ClearList(*http\ResponseHeaders())
  
  ; Reset statuscode
  *http\statuscode    = 0
  
  ProcedureReturn 1
EndProcedure

; Internally eads the requested number of bytes from the network connection and handles transfer encoding
Procedure HTTPQuery__Read_(*http.HTTPQuery, *outputBuffer.BYTE, outputLength.i, nonBlocking.i = #False)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn 0
  EndIf
  
  If *http\outputBuffer = 0
    Debug "Unable to read data, no connection opened"
    ProcedureReturn 0
  EndIf
    
  Protected temp.i
  Protected bytesAvailable.i  = 0
  Protected newline.i
  
  ; Setup timeout
  Protected timeout.i         = ElapsedMilliseconds() + *http\timeout_read
  
  ; As long as we have some content length remaining (or dont know the number of bytes)
  While (*http\contentLength = -1 Or *http\contentLength > 0) And outputLength > 0
    
    ; We got some data or still have some data in cache
    While *http\outputBufferPos > 0 And outputLength > 0
      
      If *http\transferEncoding = "chunked"
        
        ; if we dont know the actual chunk size ...
        If *http\chunkSize <= 0
          
          newline = memoryFindNewline(*http\outputBuffer, *http\outputBufferPos)
          If newline = 0
            Break
          EndIf
          
          If *http\chunkSize = 0
            *http\chunkSize = -1
            
          ElseIf *http\chunkSize = -1
            
            ; PureBasic will ignore the newline chars ... I hope
            *http\chunkSize = Val("$" + PeekS(*http\outputBuffer, newline, #PB_UTF8))
            If *http\chunkSize = 0
              
              ; End of file - set content length to zero!
              *http\contentLength = 0
            EndIf
          EndIf
            
          ; Remove this line from the buffer
          MoveMemory(*http\outputBuffer + newline, *http\outputBuffer, *http\outputBufferPos - newline)
          *http\outputBufferPos - newline
          
        ElseIf *http\chunkSize > 0
          
          ; We can safely copy data to the output buffer
          temp = outputLength
          If temp > *http\chunkSize
            temp = *http\chunkSize
          EndIf
          If temp > *http\outputBufferPos
            temp = *http\outputBufferPos
          EndIf
          
          ; Copy the desired number of bytes
          CopyMemory(*http\outputBuffer, *outputBuffer, temp)
          bytesAvailable + temp
          *outputBuffer  + temp
          outputLength   - temp
          
          ; Keep track of all bytes received
          *http\totalBytesReceived + temp
          
          ; Move them and update the current position in the buffer
          If temp < *http\outputBufferPos
            MoveMemory(*http\outputBuffer + temp, *http\outputBuffer, *http\outputBufferPos - temp)
          EndIf
          *http\outputBufferPos - temp
          
          ; Remaining chunksize ...
          *http\chunkSize - temp
          
          ; We actually dont need to update contentLength, as chunked encoding doesnt support a contentLength
        EndIf
        
      ; No transfer encoding is used
      Else
        temp = outputLength
        If *http\contentLength <> -1 And temp > *http\contentLength
          temp = *http\contentLength
        EndIf
        If temp > *http\outputBufferPos
          temp = *http\outputBufferPos
        EndIf
        
        ; Copy the desired number of bytes
        CopyMemory(*http\outputBuffer, *outputBuffer, temp)
        bytesAvailable + temp
        *outputBuffer  + temp
        outputLength   - temp
        
        ; Keep track of all bytes received
        *http\totalBytesReceived + temp
        
        ; Move them and update the current position in the buffer
        If temp < *http\outputBufferPos
          MoveMemory(*http\outputBuffer + temp, *http\outputBuffer, *http\outputBufferPos - temp)
        EndIf
        *http\outputBufferPos - temp
        
        If *http\contentLength <> -1
          *http\contentLength - temp
        EndIf
        
      EndIf
      
    Wend
    
    ; Break if connection is closed or we are ready
    If *http\connection = 0 Or outputLength = 0
      Break
    EndIf
    
    ; Parse new network events
    Protected event.i = NetworkClientEvent(*http\connection)
      
    If event = #PB_NetworkEvent_Disconnect Or ElapsedMilliseconds() > timeout
      
      ; If no content length is given, and no chunked encoding is used, this means end of file!
      If *http\transferEncoding = "chunked"
        If *http\contentLength <> 0
          Debug "The connection aborted/timed out during the transfer!"
          If event = #PB_NetworkEvent_Disconnect
            *http\statuscode = #HTTP_ERROR_CONNECTION_ABORTED
          Else
            *http\statuscode = #HTTP_ERROR_CONNECTION_TIMEOUT
          EndIf
        EndIf
      
      Else
        If *http\contentLength = -1 Or *http\outputBufferPos < *http\contentLength            
          
          If *http\contentLength <> -1
            Debug "The connection aborted/timed out during the transfer!"
            If event = #PB_NetworkEvent_Disconnect
              *http\statuscode = #HTTP_ERROR_CONNECTION_ABORTED
            Else
              *http\statuscode = #HTTP_ERROR_CONNECTION_TIMEOUT
            EndIf
          EndIf
          
          *http\contentLength = *http\outputBufferPos
        EndIf
      EndIf
      
      ; Close network connection
      CloseNetworkConnection(*http\connection)
      *http\connection = 0
      
    ElseIf event = #PB_NetworkEvent_Data
      temp = ReceiveNetworkData(*http\connection, *http\outputBuffer + *http\outputBufferPos, *http\outputBufferLength - *http\outputBufferPos)

      If temp > 0
        *http\outputBufferPos + temp
      EndIf
      
    Else ; Idle -> Delay
    
    	If nonBlocking
    		Break
    	EndIf
    
      Delay(1)
      
    EndIf
    
  Wend
  
  ; Close the connection if we reached EOF
  If *http\contentLength = 0 And *http\connection <> 0
    CloseNetworkConnection(*http\connection)
    *http\connection = 0
  EndIf   
  
  ProcedureReturn bytesAvailable
EndProcedure

; Return #True if EOF is reached, only for internal use
Procedure HTTPQuery__EOF_(*http.HTTPQuery)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn #True
  EndIf
  
  If *http\outputBuffer = 0
    Debug "Unable to get EOF, no connection opened"
    ProcedureReturn #True
  EndIf
  
  ; ContentLength is zero
  If *http\contentLength = 0
    ProcedureReturn #True
  EndIf
  
  ; Connection closed and no data remaining
  If *http\connection = 0 And *http\outputBufferPos = 0
    ProcedureReturn #True
  EndIf
  
  ProcedureReturn #False
EndProcedure

CompilerIf #HTTP_ENABLE_GZIP_COMPRESSION
  
  ; Call this to read any desired amount from a file ... the data will be gzip/deflate decoded if necessary
  Procedure HTTPQuery_Read(*http.HTTPQuery, *outputBuffer.BYTE, outputLength.i, nonBlocking.i = #False)
    If *http = 0
      Debug "No valid HTTPQuery object given"
      ProcedureReturn #True
    EndIf
    
    If Not *http\use_zlib
      ProcedureReturn HTTPQuery__Read_(*http, *outputBuffer, outputLength, nonBlocking)
    EndIf
    
    ; Fast path
    If outputLength = 0
      ProcedureReturn 0
    EndIf
    
    Protected flush.i
    Protected temp.i
    
    Protected bufferLength  = 1024
    Protected *buffer       = AllocateMemory(bufferLength)
    
    ; Setup output pointers
    *http\zlib\next_out   = *outputBuffer
    *http\zlib\avail_out  = outputLength
    
    ; Wait until we get the desired number of output bytes
    While *http\zlib\avail_out > 0
      
      ; Fill up input if we run out of memory
      If *http\zlib\avail_in = 0
        temp = HTTPQuery__Read_(*http, *buffer, bufferLength, nonBlocking)
        
        ; This will only be the case if nonBlocking = #True
        If temp = 0
        	Break
        EndIf
        
        *http\zlib\next_in    = *buffer
        *http\zlib\avail_in   = temp
      EndIf
      
      ; If the original stream finished, we send EOF
      flush = #Z_NO_FLUSH
      If HTTPQuery__EOF_(*http)
        flush = #Z_FINISH
      EndIf
    
      temp = inflate(*http\zlib, flush)
      If temp <> #Z_OK
        ; Does zlib have a message for us?
         If temp <> #Z_STREAM_END And *http\zlib\msg
           Debug "Zlib raised the following error: " + PeekS(*http\zlib\msg, -1, #PB_Ascii)
           *http\statuscode = #HTTP_ERROR_ZLIB_DOESNT_WORK
         EndIf
         
         ; Ensure that no further buffers are feed to zlib
         *http\zlib\avail_in = 0
         *http\contentLength = 0
         
         Break
      EndIf
    
    Wend
    
    ; Return number of bytes available
    ProcedureReturn *http\zlib\next_out - *outputBuffer   
  EndProcedure
  
  ; Returns #True if EOF is reached
  Procedure HTTPQuery_EOF(*http.HTTPQuery)
    If *http = 0
      Debug "No valid HTTPQuery object given"
      ProcedureReturn #True
    EndIf
    
    If Not *http\use_zlib
      ProcedureReturn HTTPQuery__EOF_(*http)
    EndIf
    
    ; We have triggered EOF and zlib has parsed everything - ready!
    If HTTPQuery__EOF_(*http) And *http\zlib\avail_in = 0
      ProcedureReturn #True
    EndIf
    
    ProcedureReturn #False
  EndProcedure
  
CompilerElse
  
  Macro HTTPQuery_Read(http, outputBuffer, outputLength, nonBlocking)
    HTTPQuery__Read_(http, outputBuffer, outputLength, nonBlocking)
  EndMacro
  
  Macro HTTPQuery_EOF(http)
    HTTPQuery__EOF_(http)
  EndMacro
  
CompilerEndIf

; Returns the statuscode of the network connection - this can either be a HTTP Statuscode like 404 for File Not Found
; or an internal error code (negative numbers, see top of this file)
Procedure.i HTTPQuery_GetStatuscode(*http.HTTPQuery)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn 0
  EndIf
  
  ProcedureReturn *http\statuscode
EndProcedure

; Returns the progress of the download as a number from 0.0 to 1.0 (only works if the total length is known)
Procedure.f HTTPQuery_GetProgress(*http.HTTPQuery)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn 0.0
  EndIf
  
  If *http\outputBuffer = 0
    Debug "Unable to determine progress, no connection opened"
    ProcedureReturn 0.0
  EndIf
  
  ; The connection has been aborted, show a progres of zero, as we have to start again!
  If *http\statuscode = #HTTP_ERROR_CONNECTION_ABORTED
    ProcedureReturn 0.0
  EndIf
  
  ; We dont know the total length
  If *http\totalContentLength = -1
    ProcedureReturn 0.0
  EndIf
  
  ; Calculate remaining data
  ProcedureReturn (*http\totalContentLength - *http\contentLength) * 1.0 / *http\totalContentLength
EndProcedure

; Returns the number of received bytes (only content)
; Please keep in mind that for compressed Data the number of uncompressed bytes is returned
Procedure.i HTTPQuery_GetTotalBytesReceived(*http.HTTPQuery)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn 0
  EndIf
  
  If *http\outputBuffer = 0
    Debug "Unable to determine progress, no connection opened"
    ProcedureReturn 0
  EndIf
  
  ; The connection has been aborted, show a progres of zero, as we have to start again!
  If *http\statuscode = #HTTP_ERROR_CONNECTION_ABORTED
    ProcedureReturn 0
  EndIf

  ProcedureReturn *http\totalBytesReceived
EndProcedure


; Returns the size if the server transmitted a Content-Length header or (-1) if the length is unknown
; Please note: This is not directly to the number of bytes you can read, when gzip/deflate is activated!
Procedure.i HTTPQuery_GetTotalContentLength(*http.HTTPQuery)
  If *http = 0
    Debug "No valid HTTPQuery object given"
    ProcedureReturn -1
  EndIf
  
  If *http\outputBuffer = 0
    Debug "Unable to determine progress, no connection opened"
    ProcedureReturn -1
  EndIf
  
  ; The connection has been aborted, show a progres of zero, as we have to start again!
  If *http\statuscode = #HTTP_ERROR_CONNECTION_ABORTED
    ProcedureReturn -1
  EndIf
   
  ; Return totalContentLength or -1
  ProcedureReturn *http\totalContentLength
EndProcedure

; Adds a key-value-pair to the end of the path and returns the modified path. Both key and value is urlencoded first
Procedure.s SimpleHTTP_AddQueryField(path.s, key.s, value.s)
  Protected query.s = encodeURL_UTF8(key) + "=" + encodeURL_UTF8(value)
  Protected trn.i
  
  trn = FindString(path, "?")
  If trn = 0
    path + "?"
  Else
    path + "&"
  EndIf
  
  path + query
  ProcedureReturn path  
EndProcedure 


Procedure HTTP_GETDATA(*retbuffer, path.s, bufferlen.i = 1048576, maxOutputSize.i = 1024*1024)
  Protected result.s = ""
  
  Protected bufferLength.i = bufferlen
  Protected *buffer
  Protected temp.i
  
  Protected *http = HTTPQuery_New(path)

  If *http
    
    ; Establish the connection
    If HTTPQuery_Open(*http)
      
      *buffer = AllocateMemory(bufferLength)
      If *buffer
        
        Define datasize = 0
        While Not HTTPQuery_EOF(*http) And Len(result) < maxOutputSize
          temp    = HTTPQuery_Read(*http, *buffer, bufferLength)
          result  + PeekS(*buffer, temp, #PB_UTF8)
          datasize = datasize + temp  
        Wend
      EndIf
      
      ; Connection terminated before we finished normally?
      If HTTPQuery_GetStatuscode(*http) < 0
        ProcedureReturn #False
      EndIf
        
      HTTPQuery_Close(*http)
    EndIf
    If datasize <= MemorySize(*retbuffer)
      CopyMemory(*buffer, *retbuffer, datasize)
    EndIf
    HTTPQuery_Free(*http)
  EndIf
  
  ProcedureReturn datasize
EndProcedure


; Performs a GET request of the given URL and returns the result as a string
Procedure.s SimpleHTTP_GET(path.s, bufferlen.i = 1048576, maxOutputSize.i = 1024*1024)
  Protected result.s = ""
  
  Protected bufferLength.i = bufferlen
  Protected *buffer
  Protected temp.i
  
  Protected *http = HTTPQuery_New(path)

  If *http
    
    ; Establish the connection
    If HTTPQuery_Open(*http)
      
      *buffer = AllocateMemory(bufferLength)
      If *buffer
        While Not HTTPQuery_EOF(*http) And Len(result) < maxOutputSize
          temp    = HTTPQuery_Read(*http, *buffer, bufferLength)
          result  + PeekS(*buffer, temp, #PB_UTF8)
          
        Wend
      EndIf
      
      ; Connection terminated before we finished normally?
      If HTTPQuery_GetStatuscode(*http) < 0
        result = ""
      EndIf
        
      HTTPQuery_Close(*http)
    EndIf
  
    HTTPQuery_Free(*http)
  EndIf
  
  ProcedureReturn result
EndProcedure

; Performs a POST request of the given URL and returns the result as a string
Procedure.s SimpleHTTP_POST(path.s, List PostData.HTTPQuery_KeyValue(), multipart.i = #False, maxOutputSize.i = 1024*1024)
  Protected result.s = ""
  
  Protected bufferLength.i = 4096
  Protected *buffer
  Protected temp.i
  
  Protected *http = HTTPQuery_New(path, "POST")

  If *http
    
    ; Just copy POST data to internal structure
    ForEach PostData()
      HTTPQuery_AddPostDataField(*http, PostData()\key, PostData()\value)
    Next
    
    ; Request in multipart/form-data mode (boundary is generated by HTTPQuery_Open)
    If multipart
      HTTPQuery_AddRequestHeader(*http, "Content-Type", "multipart/form-data")
    EndIf
    
    ; Establish the connection
    If HTTPQuery_Open(*http)
      
      *buffer = AllocateMemory(bufferLength)
      If *buffer
        
        While Not HTTPQuery_EOF(*http) And Len(result) < maxOutputSize
          temp    = HTTPQuery_Read(*http, *buffer, bufferLength)
          result  + PeekS(*buffer, temp, #PB_UTF8)
        Wend
        
      EndIf
      
      ; Connection terminated before we finished normally?
      If HTTPQuery_GetStatuscode(*http) < 0
        result = ""
      EndIf
        
      HTTPQuery_Close(*http)
    EndIf
  
    HTTPQuery_Free(*http)
  EndIf
  
  ProcedureReturn result
EndProcedure

; Performs a POST request using the raw data provided as a string
Procedure.s SimpleHTTP_POST_RAW(path.s, rawPostData.s = "", maxOutputSize.i = 1024*1024)
  Protected result.s = ""
  
  Protected bufferLength.i = 4096
  Protected *buffer
  Protected temp.i
  
  Protected *http = HTTPQuery_New(path, "POST")

  If *http
    
    ; Just copy POST data to internal structure
    HTTPQuery_SetRawPostData(*http, rawPostData)
    
    ; Establish the connection
    If HTTPQuery_Open(*http)
      
      *buffer = AllocateMemory(bufferLength)
      If *buffer
        
        While Not HTTPQuery_EOF(*http) And Len(result) < maxOutputSize
          temp    = HTTPQuery_Read(*http, *buffer, bufferLength)
          result  + PeekS(*buffer, temp, #PB_UTF8)
        Wend
        
      EndIf
      
      ; Connection terminated before we finished normally?
      If HTTPQuery_GetStatuscode(*http) < 0
        result = ""
      EndIf
        
      HTTPQuery_Close(*http)
    EndIf
  
    HTTPQuery_Free(*http)
  EndIf
  
  ProcedureReturn result
EndProcedure

; Downloads the given URL to the given local filename. If overwrite is #True the file is silently overwritten if it already exists
; Returns the on-the-fly computed md5 sum of the file if everything was okay
; You can use this to directly verify if everything was okay
Procedure.s SimpleHTTP_GET_File(path.s, filename.s, overwrite.i = #False)
  Protected bufferLength.i = 1024 * 1024
  Protected *buffer
  Protected temp.i
  
  Protected fp.i
  Protected md5.i

  If Not overwrite And FileSize(filename) >= 0
    Debug "File '" + filename + "' already exists"
    ProcedureReturn ""
  EndIf        
  
  Protected *http = HTTPQuery_New(path)

  If *http
    
    ; Establish the connection
    If HTTPQuery_Open(*http)
      
      *buffer = AllocateMemory(bufferLength)
      If *buffer
        
        fp = CreateFile(#PB_Any, filename)
        If fp
          
          Debug "Downloading to file '" + filename + "'"
          
          ;md5 = ExamineMD5Fingerprint(#PB_Any)
          md5 = 1
          While Not HTTPQuery_EOF(*http)
            Debug "Progress: " + StrF(HTTPQuery_GetProgress(*http))
            
            temp    = HTTPQuery_Read(*http, *buffer, bufferLength)
            WriteData(fp, *buffer, temp)
            
            ; Update md5 fingerprint
            ;NextFingerprint(md5, *buffer, temp)
          Wend
          
          CloseFile(fp)
        EndIf
        
        
      EndIf
      
      ; Connection terminated before we finished normally?
      If HTTPQuery_GetStatuscode(*http) < 0
        ;FinishFingerprint(md5)
        md5 = 0
      EndIf
        
      HTTPQuery_Close(*http)
    EndIf
  
    HTTPQuery_Free(*http)
  EndIf
  
  If md5
    ProcedureReturn "1";FinishFingerprint(md5)
  EndIf
  
  ProcedureReturn ""
EndProcedure

; Performs a GET request of the given URL and returns the result as a list of lines
Procedure SimpleHTTP_GET_Lines(path.s, List Lines.s(), maxLineNumbers.i = 1024*1024)
  Protected okay.i          = #False
  Protected bufferLength.i  = 4096
  Protected *buffer
  Protected bufferPos.i
  Protected temp.i
  Protected newline.i
  Protected line.s
  
  Protected *http = HTTPQuery_New(path)
  
  ClearList(Lines())
  
  If *http
    
    ; Establish the connection
    If HTTPQuery_Open(*http)
      
      *buffer = AllocateMemory(bufferLength)
      If *buffer
        
        okay = #True
        
        bufferPos = 0
        
        While Not HTTPQuery_EOF(*http) And ListSize(Lines()) < maxLineNumbers
          
          ; Force flush before running out of buffer
          If bufferPos >= bufferLength
            AddElement(Lines())
            Lines() = PeekS(*buffer, bufferPos, #PB_UTF8)
            bufferPos = 0
          EndIf
          
          temp    = HTTPQuery_Read(*http, *buffer + bufferPos, bufferLength - bufferPos)
          If temp > 0
            bufferPos + temp
          EndIf
          
          While bufferPos > 0
            newline = memoryFindNewLine(*buffer, bufferPos)
            If newline = 0
              Break
            EndIf
            
            line = PeekS(*buffer, newline, #PB_UTF8)
            
            ; Remove linebreak at the end
            If Right(line, 2) = #CRLF$
              line = Mid(line, 1, Len(line)-2)
            ElseIf Right(line, 1) = Chr(13) Or Right(line, 1) = Chr(10)
              line = Mid(line, 1, Len(line)-1)
            EndIf
            
            AddElement(Lines())
            Lines() = line
            
            MoveMemory(*buffer + newline, *buffer, bufferPos - newline)
            bufferPos - newline            
          Wend

        Wend
        
        ; Parse remaining stuff
        If bufferPos > 0
          line = PeekS(*buffer, bufferPos, #PB_UTF8)
          
          ; Remove undetected linebreak at the end
          If Right(line, 2) = #CRLF$
            line = Mid(line, 1, Len(line)-2)
          ElseIf Right(line, 1) = Chr(13) Or Right(line, 1) = Chr(10)
            line = Mid(line, 1, Len(line)-1)
          EndIf
          
          AddElement(Lines())
          Lines() = line
        EndIf
        
      EndIf
      
      ; Connection terminated before we finished normally?
      If HTTPQuery_GetStatuscode(*http) < 0
        okay = #False
      EndIf
        
      HTTPQuery_Close(*http)
    EndIf
  
    HTTPQuery_Free(*http)
  EndIf
  
  ProcedureReturn okay
EndProcedure
; IDE Options = PureBasic 5.30 (MacOS X - x64)
; CursorPosition = 1705
; FirstLine = 1683
; Folding = ---------
; EnableXP
; CompileSourceDirectory