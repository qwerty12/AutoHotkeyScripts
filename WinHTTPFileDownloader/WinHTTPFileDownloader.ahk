#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SetWorkingDir D:\ ; My RAMDisk, you'll probably want AHK's default of %A_ScriptDir%
SetBatchLines -1
ListLines Off

#Include Class_TaskDialog.ahk

if (hModule := WinHttp_Init()) ; load winhttp library. Will fail if not running on a Unicode build of AHK
	hSession := WinHttp_Open("WinHTTP Example/1.0", "WINHTTP_ACCESS_TYPE_NO_PROXY", "WINHTTP_NO_PROXY_NAME", "WINHTTP_NO_PROXY_BYPASS") ; Open WinHttp session - set User Agent and proxy settings

if (hSession)
	hConnect := WinHttp_Connect(hSession, "download.microsoft.com", "INTERNET_DEFAULT_HTTP_PORT") ; Not relevant here, but it's worth noting the same connection can be used for multiple requests from the same site to speed up things

if (hConnect)
	hRequest := WinHttp_OpenRequest(hConnect,, "/download/0/4/C/04C805CC-4C04-4D76-BE80-7D67B951CF73/waik_supplement_en-us.iso") ; the path to access from the domain above. WinHttpCrackUrl() (which is not wrapped here) can break down a full URL

/*
if (hSession)
	hConnect := WinHttp_Connect(hSession, "127.0.0.1", 8080)

if (hConnect)
	hRequest := WinHttp_OpenRequest(hConnect,, "/waik_supplement_en-us.iso")
*/

; Adding resuming support is, I believe, bytes=%bytesDownloaded%-450673718 and opening the already-existing file in append mode
if (hRequest)
	bResults := WinHttp_SendRequest(hRequest, "Range: bytes=336336896-450673718") ; Add header to download the specified range. I *think* adding additional headers is a matter of delimiting them in the same string with `r`n

if (bResults)
	bResults := DllCall("winhttp\WinHttpReceiveResponse", "Ptr", hRequest, "Ptr", NULL)

if (bResults)
{
	; Get response headers
	
	; Determine size of buffer to store headers in
	if (!WinHttp_QueryHeaders(hRequest, WINHTTP_QUERY_RAW_HEADERS_CRLF := 22, WINHTTP_HEADER_NAME_BY_INDEX := 0, 0, dwSize := 0, WINHTTP_NO_HEADER_INDEX := 0))
	{
		if (A_LastError == 0x7A) ; ERROR_INSUFFICIENT_BUFFER
		{
			VarSetCapacity(outBuffer, dwSize + 2) ; allocate space needed for the actual headers
			if (WinHttp_QueryHeaders(hRequest, WINHTTP_QUERY_RAW_HEADERS_CRLF, WINHTTP_HEADER_NAME_BY_INDEX, &outBuffer, dwSize, WINHTTP_NO_HEADER_INDEX))
			{
				; call WinHttp_QueryHeaders again to actually get the response headers now that there's a buffer with enough space to store the result
				responseHeaders := StrGet(&outBuffer, "UTF-16")
				
				; I'm sure there's a quicker way than this somewhere to get just the Content-Length...
				y := SubStr(responseHeaders, InStr(responseHeaders, "Content-Length: "))
				if (y)
					Content_Length := StrSplit(SubStr(y, 1, InStr(y, "`r") - 1), ":", " ")[2]
				
				; If the file already exists, you could compare the size of that file with the Content_Length above to see if the file is already downloaded in its entirety
			}
		}
	}
}

if (bResults)
{
	fileName := "7x86winpe.wim" ; save file with this name

	TD := New TaskDialog(FormatTitle("0.00 MB"),, "Downloading " . filename, ["Cancel"])
	TD.SetProgressBar("NONMARQUEE")
	TD.SetAlwaysOnTop()
	TD.SetCallbackFunc("TaskDialogCustomCallback")
	TD.AllowCancel()

	TD.Show() ; blocks, hence the SetTimer awkwardness in the callback
}
 
if (!bResults)
	MsgBox Error %A_LastError% has occurred
 
WinHttp_CloseHandle(hRequest)
WinHttp_CloseHandle(hConnect)
WinHttp_CloseHandle(hSession)
 
WinHttp_Deinit(hModule)
ExitApp

TaskDialogCustomCallback(H, N, W, L, D)
{
	global shouldCancel
	if (N == 0) ; TDN_CREATED
	{
		SetTimer, StartDownloading, -5
	}
	else if (N == 2) ; TDN_BUTTON_CLICKED
	{
		shouldCancel := true
	}
	return 0
}

StartDownloading()
{
	global fileName, hRequest, TD, Content_Length, shouldCancel
	hFile := FileOpen(fileName, "w") ; open the file named in the first argument for writing
	Loop
	{
		if (shouldCancel)
			break
		; A buffering/caching mechanism, like HttpRequest has, instead of instantly writing the recieved to the disk would be nice
		if (!WinHttp_QueryDataAvailable(hRequest, dwSize))
		{
			TD.TDM_SET_PROGRESS_BAR_STATE("ERROR")
			TD.TDM_UPDATE_ELEMENT_TEXT("MAIN", "Error " . A_LastError . " in WinHttpQueryDataAvailable")
			shouldCancel := true
			break
		}
		if (VarSetCapacity(pszOutBuffer, dwSize + 1, 0) < dwSize + 1)
		{
			OutputDebug Out of memory
			ExitApp
		}
		if (!WinHttp_ReadData(hRequest, &pszOutBuffer, dwSize, dwDownloaded))
		{
			TD.TDM_SET_PROGRESS_BAR_STATE("ERROR")
			TD.TDM_UPDATE_ELEMENT_TEXT("MAIN", "Error " . A_LastError . " in WinHttpReadData")
			; shouldCancel := true
		}
		else
		{
			hFile.RawWrite(pszOutBuffer, dwDownloaded) ; write the downloaded bytes to the file

			totalDownloaded += dwDownloaded
			pct := Ceil((totalDownloaded * 100) / Content_Length)
			if (pct != lastPct || pct >= 100) { ; Just for that last update
				TD.TDM_SET_PROGRESS_BAR_POS(pct), lastPct := pct
				TD.TDM_UPDATE_ELEMENT_TEXT("MAIN", FormatTitle(FormatBytes(totalDownloaded))) ; Move outside of the if block for more frequent updates at the cost of more CPU usage
			}
		}
		if (dwSize <= 0)
			break
	}
	if (!shouldCancel)
		SetTimer, CloseTD, -3000
	hFile.Close()
}

FormatTitle(bytes)
{
	global Content_Length
	return "Downloaded " . bytes . (Content_Length ? " of " . FormatBytes(Content_Length) : "")
}

; By SKAN
FormatBytes(bytes) {
	VarSetCapacity(pszBuf, 32)
	return DllCall("Shlwapi\StrFormatByteSizeW", "Int64", bytes, "Ptr", &pszBuf, "UInt", 32, "WStr")
}

CloseTD()
{
	global TD
	TD.TDM_CLICK_BUTTON(8) ; Manually trigger click of the cancel button
}

; --- Incomplete, bad wrapper library follows

WinHttp_Init()
{
	if (!A_IsUnicode)
		return 0
	return DllCall("LoadLibrary", "Str", "winhttp.dll", "Ptr")
}

WinHttp_Deinit(hModule)
{
	DllCall("FreeLibrary", "Ptr", hModule)
}

WinHttp_CloseHandle(hInternet)
{
	if (hInternet)
		DllCall("winhttp\WinHttpCloseHandle", "Ptr", hInternet)
}

WinHttp_Open(userAgent, proxyType := "WINHTTP_ACCESS_TYPE_DEFAULT_PROXY", proxyName := "", proxyBypass := "", flags := "")
{
	if (!userAgent)
		return 0
	
	if proxyType not in WINHTTP_ACCESS_TYPE_NO_PROXY,WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,WINHTTP_ACCESS_TYPE_NAMED_PROXY
		return 0

	if (!proxyName || proxyName == "WINHTTP_NO_PROXY_NAME")
	{
		pnType := "Ptr"
		proxyName := _WinHttp_DWordFromWHConstant("WINHTTP_NO_PROXY_NAME")
	}
	else
	{
		pnType := "WStr"
	}

	if (!proxyBypass || proxyBypass == "WINHTTP_NO_PROXY_BYPASS")
	{
		pbType := "Ptr"
		proxyBypass := _WinHttp_DWordFromWHConstant("WINHTTP_NO_PROXY_BYPASS")
	}
	else
	{
		pbType := "WStr"
	}

	if (flags && flags != "WINHTTP_FLAG_ASYNC")
		return 0
	else
		flags := flags ? _WinHttp_DWordFromWHConstant("WINHTTP_FLAG_ASYNC") : 0

	return DllCall("winhttp\WinHttpOpen", "WStr", userAgent
										   ,"UInt", _WinHttp_DWordFromWHConstant(proxyType)
										   ,pnType, proxyName
										   ,pbType, proxyBypass
										   ,"UInt", flags
										   ,"Ptr")
}

WinHttp_Connect(hSession, ServerName, ServerPort := "INTERNET_DEFAULT_PORT")
{
	if (!hSession || !ServerName)
		return 0
	
	if ServerPort is not integer
	{
		if ServerPort not in INTERNET_DEFAULT_PORT,INTERNET_DEFAULT_HTTP_PORT,INTERNET_DEFAULT_HTTPS_PORT
			return 0
		ServerPort := _WinHttp_DWordFromWHConstant(ServerPort)
	}

	return DllCall("winhttp\WinHttpConnect", "Ptr", hSession
											  ,"WStr", ServerName
											  ,"UInt", ServerPort
											  ,"UInt", 0
											  ,"Ptr")
}

WinHttp_OpenRequest(hConnect, verb := "GET", objectName := "", httpVersion := "", referrer := "WINHTTP_NO_REFERER", acceptTypes := "WINHTTP_DEFAULT_ACCEPT_TYPES", flags := "")
{
	if (!hConnect || !objectName) ; don't ask
		return 0
	
	if (!referrer || referrer == "WINHTTP_NO_REFERER")
		referrer := _WinHttp_DWordFromWHConstant("WINHTTP_NO_REFERER")

	if (!acceptTypes || acceptTypes == "WINHTTP_DEFAULT_ACCEPT_TYPES")
		acceptTypes := _WinHttp_DWordFromWHConstant("WINHTTP_DEFAULT_ACCEPT_TYPES")

	if (flags)
	{
		if (!InStr(flags, "|"))
			flags := flags . "|"
		flagsSplit := StrSplit(flags, "|", " `r`n`t")
		actualFlags := 0
		Loop % flagsSplit.MaxIndex()
		{
			if (flagsSplit[A_Index])
			{
				if flagsSplit[A_Index] not in WINHTTP_FLAG_SECURE,WINHTTP_FLAG_ESCAPE_PERCENT
										  ,WINHTTP_FLAG_NULL_CODEPAGE,WINHTTP_FLAG_BYPASS_PROXY_CACHE
										  ,WINHTTP_FLAG_REFRESH,WINHTTP_FLAG_ESCAPE_DISABLE,WINHTTP_FLAG_ESCAPE_DISABLE_QUERY
				{
					return 0
				}
				else
				{
					actualFlags := actualFlags | _WinHttp_DWordFromWHConstant(flagsSplit[A_Index])
				}
			}
		}
	}
	else
	{
		actualFlags := 0
	}

	return DllCall("winhttp\WinHttpOpenRequest", "Ptr", hConnect
													  ,"WStr", verb
													  ,"WStr", objectName
													  ,httpVersion ? "WStr" : "Ptr", httpVersion ? httpVersion : 0
													  ,referrer ? "WStr" : "Ptr", referrer
													  ,acceptTypes ? "WStr" : "Ptr", acceptTypes
													  ,"UInt", actualFlags
													  ,"Ptr")
}

WinHttp_SendRequest(hRequest, headers := "WINHTTP_NO_ADDITIONAL_HEADERS", headersLength := -1
					, optionalData := "WINHTTP_NO_REQUEST_DATA", optionalDataLength := 0, totalLength := 0
					, context := 0)
{
	if (!headers || headers == "WINHTTP_NO_ADDITIONAL_HEADERS")
		headers := _WinHttp_DWordFromWHConstant("WINHTTP_NO_ADDITIONAL_HEADERS")

	if (!optionalData || optionalData == "WINHTTP_NO_REQUEST_DATA")
		optionalData := _WinHttp_DWordFromWHConstant("WINHTTP_NO_REQUEST_DATA")

	return DllCall("winhttp\WinHttpSendRequest", "Ptr", hRequest
													  ,headers ? "WStr" : "Ptr", headers
													  ,"UInt", headers ? headersLength : 0
													  ,optionalData ? "WStr" : "Ptr", optionalData
													  ,"UInt", optionalDataLength
													  ,"UInt", totalLength
													  ,"Ptr", context)
}

WinHttp_QueryDataAvailable(hRequest, ByRef dwNumberOfBytesAvailable)
{
	if (!IsByRef(dwNumberOfBytesAvailable))
		return false
	return DllCall("winhttp\WinHttpQueryDataAvailable", "Ptr", hRequest, "UInt*", dwNumberOfBytesAvailable)
}

WinHttp_ReadData(hRequest, pointerToBuffer, bufferSize, ByRef dwDownloaded)
{
	return DllCall("winhttp\WinHttpReadData", "Ptr", hRequest, "Ptr", pointerToBuffer, "UInt", bufferSize, "UInt*", dwDownloaded)
}

WinHttp_QueryHeaders(hRequest, infoLevel, name, ptrBuffer, ByRef bufferSize, headerIndex)
{
	if (!IsByRef(bufferSize))
		return false
	; Sorry, too many flags here for me to, uhm, neatly wrap
	return DllCall("winhttp\WinHttpQueryHeaders", "Ptr", hRequest, "UInt", infoLevel, "Ptr", name, "Ptr", ptrBuffer, "UInt*", bufferSize, "Ptr", headerIndex)
}

_WinHttp_DWordFromWHConstant(constant)
{
    static something := { "WINHTTP_NO_PROXY_NAME"   : 0
						  ,"WINHTTP_NO_PROXY_BYPASS" : 0 
						  ,"WINHTTP_ACCESS_TYPE_DEFAULT_PROXY" : 0
						  ,"WINHTTP_ACCESS_TYPE_NO_PROXY" : 1
						  ,"WINHTTP_ACCESS_TYPE_NAMED_PROXY"     : 3
						  ,"WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY" : 4
						  ,"INTERNET_DEFAULT_PORT" : 0
						  ,"INTERNET_DEFAULT_HTTP_PORT" : 80
						  ,"INTERNET_DEFAULT_HTTPS_PORT" : 443
						  ,"WINHTTP_NO_REFERER" : 0
						  ,"WINHTTP_DEFAULT_ACCEPT_TYPES" : 0
						  ,"WINHTTP_NO_ADDITIONAL_HEADERS" : 0
						  ,"WINHTTP_NO_REQUEST_DATA"  : 0
						  ,"WINHTTP_FLAG_ASYNC" : 0x10000000
						  ,"WINHTTP_FLAG_SECURE" : 0x00800000
						  ,"WINHTTP_FLAG_ESCAPE_PERCENT" : 0x00000004
						  ,"WINHTTP_FLAG_NULL_CODEPAGE" : 0x00000008
						  ,"WINHTTP_FLAG_BYPASS_PROXY_CACHE" : 0x00000100
						  ,"WINHTTP_FLAG_REFRESH" : 0x00000100
						  ,"WINHTTP_FLAG_ESCAPE_DISABLE" : 0x00000040
						  ,"WINHTTP_FLAG_ESCAPE_DISABLE_QUERY" : 0x00000080}

	return something[constant]
}