#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.

full_command_line := DllCall("GetCommandLine", "str")

if not (A_IsAdmin or RegExMatch(full_command_line, " /restart(?!\S)"))
{
    try
    {
        if A_IsCompiled
            Run *RunAs "%A_ScriptFullPath%" /restart
        else
            Run *RunAs "%A_AhkPath%" /restart "%A_ScriptFullPath%"
    }
    ExitApp
}
LogonDesktop_ProcessIdToSessionId(LogonDesktop_GetCurrentProcessId(), scriptProcessSessionId)

if ((wtsapi32 := DllCall("LoadLibrary", "Str", "wtsapi32.dll", "Ptr"))) {
	if (DllCall("wtsapi32\WTSEnumerateSessionsEx", "Ptr", WTS_CURRENT_SERVER_HANDLE := 0, "UInt*", 1, "UInt", 0, "Ptr*", pSessionInfo, "UInt*", wtsSessionCount)) {
		WTS_CONNECTSTATE_CLASS := {0: "WTSActive", 1: "WTSConnected", 2: "WTSConnectQuery", 3: "WTSShadow", 4: "WTSDisconnected", 5: "WTSIdle", 6: "WTSListen", 7: "WTSReset", 8: "WTSDown", 9: "WTSInit"}
		cbWTS_SESSION_INFO_1 := A_PtrSize == 8 ? 56 : 32
		Loop % wtsSessionCount {
			currSessOffset := cbWTS_SESSION_INFO_1 * (A_Index - 1) ;, ExecEnvId := NumGet(pSessionInfo+0, currSessOffset, "UInt")
			currSessOffset += 4, State := NumGet(pSessionInfo+0, currSessOffset, "UInt")
			currSessOffset += 4, SessionId := NumGet(pSessionInfo+0, currSessOffset, "UInt")
			currSessOffset += A_PtrSize ; , SessionName := StrGet(NumGet(pSessionInfo+0, currSessOffset, "Ptr"))
			currSessOffset += A_PtrSize ;, HostName := StrGet(NumGet(pSessionInfo+0, currSessOffset, "Ptr"))
;			currSessOffset += A_PtrSize, UserName := StrGet(NumGet(pSessionInfo+0, currSessOffset, "Ptr"))
;			currSessOffset += A_PtrSize, DomainName := StrGet(NumGet(pSessionInfo+0, currSessOffset, "Ptr"))
;			currSessOffset += A_PtrSize, FarmName := StrGet(NumGet(pSessionInfo+0, currSessOffset, "Ptr"))

			if (SessionId && SessionId != scriptProcessSessionId)
				DllCall("wtsapi32\WTSLogoffSession", "Ptr", WTS_CURRENT_SERVER_HANDLE, "UInt", SessionId, "Int", False)
		}
		DllCall("wtsapi32\WTSFreeMemoryEx", "UInt", WTSTypeSessionInfoLevel1 := 2, "Ptr", pSessionInfo, "UInt", wtsSessionCount)
	}
	DllCall("FreeLibrary", "Ptr", wtsapi32)
}

LogonDesktop_GetCurrentProcessId() {
	static dwProcessId := DllCall("GetCurrentProcessId", "UInt") ; well, it's not like this one is going to change each time we call it
	return dwProcessId
}

LogonDesktop_ProcessIdToSessionId(dwProcessId, ByRef dwSessionId)
{
	static ProcessIdToSessionId := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandleW", "WStr", "kernel32.dll", "Ptr"), "AStr", "ProcessIdToSessionId", "Ptr")
	return DllCall(ProcessIdToSessionId, "UInt", dwProcessId, "UInt*", dwSessionId)
}