#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SetBatchLines, -1
ListLines, Off
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#KeyHistory 0
#NoTrayIcon
#SingleInstance Force

main(), return

main()
{
	global exe := A_ScriptDir . "\goodbyedpi.exe", arguments := "-e 8 -s"
	     , gdpiOutput, processHandleSwitch := " /procToTerminateHandle:", processWaitTimeout := 2000
	     , startTorStr := "Start &Tor", stopTorStr := "Stop &Tor"

	cmdLine := DllCall("GetCommandLineW", "WStr")
	if (InStr(cmdLine, processHandleSwitch)) {
		; I can't stop child processes from fucking inheriting the IGNORE_CTRL_C flag from the PEB, so have said flag set in a child process which is then summarily ended
		if ((hProcess := StrSplit(cmdLine, processHandleSwitch, " """"")[2])) {
			if ((gdpiPid := DllCall("GetProcessId", "Ptr", hProcess, "UInt")))
				_StopGoodbyeDPI(hProcess, gdpiPid)
			DllCall("CloseHandle", "Ptr", hProcess)
		}

		ExitApp
	}

	if not (A_IsAdmin or RegExMatch(cmdLine, " /restart(?!\S)"))
	{
		try
		{
			if !A_IsCompiled
				Run *RunAs "%A_AhkPath%" /restart "%A_ScriptFullPath%"
			else
				Run *RunAs "%A_ScriptFullPath%" /restart
		}
		ExitApp
	}

	if (!VarSetCapacity(gdpiOutput))
		VarSetCapacity(gdpiOutput, 8192)

	Menu, Tray, NoStandard
	Menu, Tray, Add, &Start/Stop GoodbyeDPI, ToggleGoodbyeDPI
	Menu, Tray, Add, View GoodbyeDPI output, ShowGoodbyeDPIOutput
	Menu, Tray, Add
	Menu, Tray, Add, %startTorStr%, Tor
	Menu, Tray, Add
	Menu, Tray, Add, Edit This Script, Edit
	Menu, Tray, Add, E&xit, ExitApp
	Menu, Tray, Default, 2&
	OnMessage(0x404, "AHK_NOTIFYICON")

	setTrayState(False)
	,OnExit("AtExit")
	Menu, Tray, Icon
}

AtExit(ExitReason, ExitCode)
{
	global ctx, processWaitTimeout, stopTorStr
	OnExit(A_ThisFunc, 0)
	Tor(stopTorStr)
	if (IsObject(ctx))
		if (DllCall("WaitForSingleObject", "Ptr", NumGet(ctx["pi"]+0,0,"Ptr"), "UInt", 0) == 258) {
			processWaitTimeout := 500
			,ToggleGoodbyeDPI(True, False)
		}
	AHK_TERMNOTIFY(0)
	if (ExitReason == "Shutdown")
		UnloadWinDivert()
	return 0
}

ToggleGoodbyeDPI(useWTFMS := True, useTerminateSubprocess := True)
{
	static cbStartupInfoEx := A_PtrSize == 8 ? 112 : 72
	global exe, arguments, ctx, twGlobal := 0, gdpiOutput, processHandleSwitch, processWaitTimeout
	
	if (IsObject(ctx)) {
		hProcess := NumGet(ctx["pi"]+0,0,"Ptr")
		if (useTerminateSubprocess) {
			useTerminateSubprocess := False
			,DllCall("InitializeProcThreadAttributeList", "Ptr", 0, "UInt", 1, "UInt", 0, "Ptr*", size)
			if (size) {
				VarSetCapacity(AttributeList, size + A_PtrSize)

				if (DllCall("InitializeProcThreadAttributeList", "Ptr", &AttributeList, "UInt", 1, "UInt", 0, "Ptr*", size)) {
					NumPut(hProcess, AttributeList, size, "Ptr")
					if (DllCall("UpdateProcThreadAttribute", "Ptr", &AttributeList, "UInt", 0, "UPtr", 0x00020002, "Ptr", &AttributeList+size, "Ptr", A_PtrSize, "Ptr", 0, "Ptr", 0)) {
						if (DllCall("SetHandleInformation", "Ptr", hProcess, "UInt", 0x00000001, "UInt", 0x00000001)) {
							VarSetCapacity(pi, 24, 0)
							,VarSetCapacity(info, cbStartupInfoEx, 0)
							,NumPut(cbStartupInfoEx, info,, "UInt")
							,NumPut(&AttributeList, info, cbStartupInfoEx - A_PtrSize, "Ptr")

							if (DllCall("CreateProcess", "Str", A_AhkPath, "Str", """" . A_AhkPath . """" . " /force """ . A_ScriptFullPath . """" . processHandleSwitch . hProcess, "Ptr", 0, "Ptr", 0, "Int", True, "UInt", 0x00080000, "Ptr", 0, "Ptr", 0, "Ptr", &info, "Ptr", &pi)) {
								Menu, Tray, Disable, 1&
								hSubProcess := NumGet(pi,, "Ptr")
								,DllCall("CloseHandle", "Ptr", NumGet(pi, A_PtrSize, "Ptr"))
								,MsgSleep(hSubProcess, processWaitTimeout)
								,DllCall("CloseHandle", "Ptr", hSubProcess)
								,useTerminateSubprocess := True
							}
						}
					}
					DllCall("DeleteProcThreadAttributeList", "Ptr", &AttributeList)
				}
			}
		}
		if (!useTerminateSubprocess)
			_StopGoodbyeDPI(hProcess, NumGet(ctx["pi"]+0, 2 * A_PtrSize, "UInt"))
	} else {
		Menu, Tray, Disable, 1&
		gdpiOutput := ""
		,ctx := StdoutToVar_CreateProcess("""" . exe . """" . (arguments ? A_Space . arguments : ""),, A_ScriptDir . "\NoStdoutBuffering.dll")
	
		if (IsObject(ctx)) {
			twGlobal := TermWait_WaitForProcTerm(A_ScriptHwnd, NumGet(ctx["pi"]+0,0,"Ptr"))
			,setTrayState(True)
			,GetGoodbyeDPIOutput()
		} else {
			MsgBox Process creation failed
			Menu, Tray, Enable, 1&
			return
		}
	}
	if (useWTFMS)
		WTFMS()
	else
		WinActivate % "ahk_id " . GetTaskbarVisibleWindows(1)[1]
}

; From kon
AHK_NOTIFYICON(wParam, lParam)
{
	global stopTorStr, startTorStr
	if (lParam == 0x205) {
		try Menu, Tray, Rename, 4&, % Tor("") ? stopTorStr : startTorStr
	} else if (lParam == 0x0207) {
		ToggleGoodbyeDPI(False)
	}
}

Tor(mode)
{
	global stopTorStr, startTorStr
	static SERVICE_STATUS, SERVICE_NO_CHANGE := 0xffffffff
	if (!VarSetCapacity(SERVICE_STATUS))
		VarSetCapacity(SERVICE_STATUS, 28)

	if (mode == stopTorStr)
		stopTor := True
	else if (mode == startTorStr)
		startTor := True
	else
		getStatus := True

	if ((HSC := DllCall("Advapi32.dll\OpenSCManager", "Ptr", 0, "Ptr", 0, "UInt", 0x000F0000 | 0x0001, "UPtr"))) {
		Loop {
			if ((HSV := DllCall("Advapi32.dll\OpenService", "Ptr", HSC, "Str", "tor", "UInt", 0x000F0000 | 0x0002 | 0x0004 | 0x0010 | 0x0020, "UPtr"))) {
				if (getStatus) {
					if (DllCall("Advapi32.dll\QueryServiceStatus", "Ptr", HSV, "Ptr", &SERVICE_STATUS))
						dwCurrentState := NumGet(SERVICE_STATUS, 4, "UInt")
				} else {
					; toggle: if (dwCurrentState == 0x00000004)
					if (stopTor) {
						DllCall("Advapi32.dll\ChangeServiceConfig", "Ptr", HSV, "UInt", SERVICE_NO_CHANGE, "UInt", 4, "UInt", SERVICE_NO_CHANGE, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0)
						DllCall("Advapi32.dll\ControlService", "Ptr", HSV, "UInt", 0x00000001, "Ptr", &SERVICE_STATUS)
					}
					else if (startTor) {
						if (A_Index == 1) {
							DllCall("Advapi32.dll\ChangeServiceConfig", "Ptr", HSV, "UInt", SERVICE_NO_CHANGE, "UInt", 3, "UInt", SERVICE_NO_CHANGE, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0)
						} else {
							DllCall("Advapi32.dll\StartService", "Ptr", HSV, "UInt", 0, "Ptr", 0)
							DllCall("Advapi32.dll\ChangeServiceConfig", "Ptr", HSV, "UInt", SERVICE_NO_CHANGE, "UInt", 4, "UInt", SERVICE_NO_CHANGE, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0)
						}
					}
				}
				DllCall("Advapi32.dll\CloseServiceHandle", "Ptr", HSV)
			}
			if (!startTor || A_Index != 1)
				break
		}
		DllCall("Advapi32.dll\CloseServiceHandle", "Ptr", HSC)
	}
	
	return dwCurrentState == 0x00000004
}

_StopGoodbyeDPI(hProcess, gdpiPid)
{
	global processWaitTimeout

	shouldKill := True
	if (DllCall("AttachConsole", "UInt", gdpiPid)) {
		DllCall("SetConsoleCtrlHandler", "Ptr", 0, "Int", True)
		,generated := DllCall("GenerateConsoleCtrlEvent", "UInt", 0, "UInt", 0)
		,DllCall("FreeConsole")
		if (generated)
			shouldKill := DllCall("WaitForSingleObject", "Ptr", hProcess, "UInt", processWaitTimeout, "UInt") != 0
	}
	if (shouldKill) {
		if ((ExitProcess := ProcAddressFromRemoteProcess(hProcess, "kernel32.dll", "ExitProcess"))) {
			if ((hRemoteThread := DllCall("CreateRemoteThread", "Ptr", hProcess, "Ptr", 0, "Ptr", 0, "Ptr", ExitProcess, "Ptr", 1, "UInt", 0, "Ptr", 0, "Ptr"))) {
				DllCall("CloseHandle", "Ptr", hRemoteThread)
				shouldKill := DllCall("WaitForSingleObject", "Ptr", hProcess, "UInt", processWaitTimeout, "UInt") != 0
			}
		}
	}
	if (shouldKill)
		DllCall("TerminateProcess", "Ptr", hProcess, "UInt", 0)
}

setTrayState(on)
{
	global exe, gdpiOutput
	static offIcon := A_ScriptDir . "\off.ico"
	try {
		Menu, Tray, Enable, 1&
		if (!on) {
			Menu, Tray, Icon, %offIcon%
			Menu, Tray, Tip, GoodbyeDPI stopped
			if (gdpiOutput)
				Menu, Tray, Rename, 2&, &View last GoodbyeDPI output
			else
				Menu, Tray, Disable, 2&
			Menu, Tray, Rename, 1&, &Start GoodbyeDPI
		} else {
			Menu, Tray, Icon, %exe%
			Menu, Tray, Tip, GoodbyeDPI started
			Menu, Tray, Rename, 1&, &Stop GoodbyeDPI
			Menu, Tray, Rename, 2&, &View GoodbyeDPI output
			Menu, Tray, Enable, 2&
		}
	}
}

AHK_TERMNOTIFY(pGlobal)
{
	global ctx, twGlobal
	if (!pGlobal)
		pGlobal := twGlobal
	TermWait_StopWaiting(pGlobal)
	,StdoutToVar_Cleanup(ctx)
	,twGlobal := 0, ctx := ""
	,setTrayState(False)
}

GetGoodbyeDPIOutput()
{
	global ctx, gdpiOutput

	if (!DllCall("PeekNamedPipe", "Ptr", ctx.hStdOutRd, "Ptr", 0, "UInt", 0, "Ptr", 0, "UIntP", nTot, "Ptr", 0) || !nTot)
		return

	VarSetCapacity(sTemp, nTot+2)
	,DllCall( "ReadFile", Ptr,ctx.hStdOutRd, Ptr,&sTemp, UInt,nTot, PtrP,nSize, Ptr,0 )
	,gdpiOutput .= StrGet(&sTemp, nSize, "CP0")
}

ShowGoodbyeDPIOutput()
{
	global gdpiOutput

	GetGoodbyeDPIOutput()

	if (gdpiOutput)
		MsgBox %gdpiOutput%
}

; ---

StdoutToVar_CreateProcess(sCmd, sDir:="", dllPath:="") {
	; https://autohotkey.com/boards/viewtopic.php?t=791
	; Author .......: Sean (http://goo.gl/o3VCO8), modified by nfl and by Cyruz. Modified by qwerty12 to add quick and dirty DLL injection, and to abstract the pipe reading logic into its own function
	; License ......: WTFPL - http://www.wtfpl.net/txt/copying/

    DllCall( "CreatePipe",           PtrP,hStdOutRd, PtrP,hStdOutWr, Ptr,0, UInt,0 )
    DllCall( "SetHandleInformation", Ptr,hStdOutWr, UInt,1, UInt,1                 )

	pi := DllCall("GlobalAlloc", "UInt", 0x0040, "Ptr", (A_PtrSize == 4) ? 16 : 24, "Ptr")
	si := DllCall("GlobalAlloc", "UInt", 0x0040, "Ptr", (siSz := (A_PtrSize == 4) ? 68 : 104), "Ptr")
    NumPut( siSz,      si+0,  0,                          "UInt" )
    NumPut( 0x100,     si+0,  (A_PtrSize == 4) ? 44 : 60, "UInt" )
    NumPut( hStdOutWr, si+0,  (A_PtrSize == 4) ? 60 : 88, "Ptr"  )
    NumPut( hStdOutWr, si+0,  (A_PtrSize == 4) ? 64 : 96, "Ptr"  )

    If ( !DllCall( "CreateProcess", Ptr,0, Ptr,&sCmd, Ptr,0, Ptr,0, Int,True, UInt,(CREATE_NO_WINDOW := 0x08000000 | CREATE_SUSPENDED := 0x00000004)
                                  , Ptr,0, Ptr,sDir?&sDir:0, Ptr,si, Ptr,pi ) )
        Return 0
      , DllCall( "CloseHandle", Ptr,hStdOutWr )
      , DllCall( "CloseHandle", Ptr,hStdOutRd )
      , DllCall("GlobalFree", "Ptr", si, "Ptr")
      , DllCall("GlobalFree", "Ptr", pi, "Ptr")

    DllCall( "CloseHandle", Ptr,hStdOutWr ) ; The write pipe must be closed before reading the stdout.

	ret := {"pi": pi, "si": si, "hStdOutRd": hStdOutRd}

	ok := True
	if (FileExist(dllPath)) {
		static GetBinaryType := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "kernel32.dll", "Ptr"), "AStr", A_IsUnicode ? "GetBinaryTypeW" : "GetBinaryTypeA", "Ptr")
			  ,LoadLibrary := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "kernel32.dll", "Ptr"), "AStr", A_IsUnicode ? "LoadLibraryW" : "LoadLibraryA", "Ptr")
		ok := False
		cbDllPath := VarSetCapacity(dllPath)

		if ((DllCall(GetBinaryType, "Str", StrSplit(sCmd, """", """")[2], "UInt*", BinaryType))) {
			if ((BinaryType == 6 && A_PtrSize == 8) || (BinaryType == 0 && A_PtrSize == 4)) {
				if ((pRemoteDllPath := DllCall("VirtualAllocEx", "Ptr", (hProcess := NumGet(pi+0,0,"Ptr")), "Ptr", 0, "Ptr", cbDllPath, "UInt", MEM_COMMIT := 0x00001000, "UInt", PAGE_READWRITE := 0x04, "Ptr"))) {
					if (DllCall("WriteProcessMemory", "Ptr", hProcess, "Ptr", pRemoteDllPath, "Ptr", &dllPath, "Ptr", cbDllPath, "Ptr", 0)) {
						if (hRemoteThread := DllCall("CreateRemoteThread", "Ptr", hProcess, "Ptr", 0, "Ptr", 0, "Ptr", LoadLibrary, "Ptr", pRemoteDllPath, "UInt", 0, "Ptr", 0, "Ptr")) {
							DllCall("WaitForSingleObject", "Ptr", hRemoteThread, "UInt", 0xFFFFFFFF) ; don't use MsgWaitForMultipleObjectsEx here and let this block. There's gonna be problems anyway if this fails - having the AutoHotkey script blocked is no problem
							DllCall("CloseHandle", "Ptr", hRemoteThread)
							ok := True
						}
					}
					DllCall("VirtualFreeEx", "Ptr", hProcess, "Ptr", pRemoteDllPath, "Ptr", 0, "UInt", MEM_RELEASE := 0x8000)
				}
			}
		}
	}

	if (ok)
		DllCall("ResumeThread", "Ptr", NumGet(pi+0,A_PtrSize))
	else {
		DllCall("TerminateProcess", "Ptr", hProcess, "UInt", 1)
		StdoutToVar_Cleanup(ret)
		ret := 0
	}

    Return ret
}

StdoutToVar_Cleanup(stvCtx)
{
	if (IsObject(stvCtx)) {
		DllCall( "CloseHandle",        Ptr,NumGet(stvCtx["pi"]+0,0)                  )
		DllCall( "CloseHandle",        Ptr,NumGet(stvCtx["pi"]+0,A_PtrSize)          )
		DllCall( "CloseHandle",        Ptr,stvCtx.hStdOutRd                     )
		
		DllCall("GlobalFree", "Ptr", stvCtx["si"], "Ptr")
		DllCall("GlobalFree", "Ptr", stvCtx["pi"], "Ptr")
	}
}

TermWait_WaitForProcTerm(hWnd, hProcess, ByRef sDataIn:="") {
	; Author .......: Cyruz (http://ciroprincipe.info) & SKAN (http://goo.gl/EpCq0Z)
	; License ......: WTFPL - http://www.wtfpl.net/txt/copying/
	static addrCallback := RegisterSyncCallback("AHK_TERMNOTIFY")

	if (hProcess < 1)
		return 0

	szDataIn := VarSetCapacity(sDataIn)
	pGlobal	 := DllCall("GlobalAlloc", "UInt", 0x0040, "UInt", (A_PtrSize == 8 ? 32 : 20) + szDataIn, "Ptr")

	NumPut(hWnd, pGlobal+0,, "Ptr")
	NumPut(hProcess, pGlobal+0, A_PtrSize == 8 ? 16 : 12, "Ptr")
	
	DllCall("RtlMoveMemory", "Ptr", pGlobal+(A_PtrSize == 8 ? 32 : 20), "Ptr", &sDataIn, "Ptr", szDataIn)
	if (!DllCall("RegisterWaitForSingleObject", "Ptr", pGlobal+(A_PtrSize == 8 ? 24 : 16), "Ptr", hProcess, "Ptr", addrCallback
						  , "Ptr", pGlobal, "UInt", 0xFFFFFFFF, "UInt", 0x00000004 | 0x00000008)) {  ; INFINITE, WT_EXECUTEINWAITTHREAD | WT_EXECUTEONLYONCE
		DllCall("GlobalFree", "Ptr", pGlobal, "Ptr")
		return 0
	}
	return pGlobal
}

TermWait_StopWaiting(pGlobal) {
	if (pGlobal) {
		DllCall("UnregisterWait", "Ptr", NumGet(pGlobal+0, A_PtrSize == 8 ? 24 : 16, "Ptr"))
		DllCall("GlobalFree", "Ptr", pGlobal, "Ptr")
	}
}

RegisterSyncCallback(FunctionName, Options:="", ParamCount:="")
{
	; Author: lexikos (https://autohotkey.com/boards/viewtopic.php?t=21223)
    if !(fn := Func(FunctionName)) || fn.IsBuiltIn
        throw Exception("Bad function", -1, FunctionName)
    if (ParamCount == "")
        ParamCount := fn.MinParams
    if (ParamCount > fn.MaxParams && !fn.IsVariadic || ParamCount+0 < fn.MinParams)
        throw Exception("Bad param count", -1, ParamCount)
    
    static sHwnd := 0, sMsg, sSendMessageW
    if !sHwnd
    {
        Gui RegisterSyncCallback: +Parent%A_ScriptHwnd% +hwndsHwnd
        OnMessage(sMsg := 0x8000, Func("RegisterSyncCallback_Msg"))
        sSendMessageW := DllCall("GetProcAddress", "ptr", DllCall("GetModuleHandle", "str", "user32.dll", "ptr"), "astr", "SendMessageW", "ptr")
    }
    
    if !(pcb := DllCall("GlobalAlloc", "uint", 0, "ptr", 96, "ptr"))
        throw
    DllCall("VirtualProtect", "ptr", pcb, "ptr", 96, "uint", 0x40, "uint*", 0)
    
    p := pcb
    if (A_PtrSize = 8)
    {
        /*
        48 89 4c 24 08  ; mov [rsp+8], rcx
        48 89 54'24 10  ; mov [rsp+16], rdx
        4c 89 44 24 18  ; mov [rsp+24], r8
        4c'89 4c 24 20  ; mov [rsp+32], r9
        48 83 ec 28'    ; sub rsp, 40
        4c 8d 44 24 30  ; lea r8, [rsp+48]  (arg 3, &params)
        49 b9 ..        ; mov r9, .. (arg 4, operand to follow)
        */
        p := NumPut(0x54894808244c8948, p+0)
        p := NumPut(0x4c182444894c1024, p+0)
        p := NumPut(0x28ec834820244c89, p+0)
        p := NumPut(  0xb9493024448d4c, p+0) - 1
        lParamPtr := p, p += 8
        
        p := NumPut(0xba, p+0, "char") ; mov edx, nmsg
        p := NumPut(sMsg, p+0, "int")
        p := NumPut(0xb9, p+0, "char") ; mov ecx, hwnd
        p := NumPut(sHwnd, p+0, "int")
        p := NumPut(0xb848, p+0, "short") ; mov rax, SendMessageW
        p := NumPut(sSendMessageW, p+0)
        /*
        ff d0        ; call rax
        48 83 c4 28  ; add rsp, 40
        c3           ; ret
        */
        p := NumPut(0x00c328c48348d0ff, p+0)
    }
    else ;(A_PtrSize = 4)
    {
        p := NumPut(0x68, p+0, "char")      ; push ... (lParam data)
        lParamPtr := p, p += 4
        p := NumPut(0x0824448d, p+0, "int") ; lea eax, [esp+8]
        p := NumPut(0x50, p+0, "char")      ; push eax
        p := NumPut(0x68, p+0, "char")      ; push nmsg
        p := NumPut(sMsg, p+0, "int")
        p := NumPut(0x68, p+0, "char")      ; push hwnd
        p := NumPut(sHwnd, p+0, "int")
        p := NumPut(0xb8, p+0, "char")      ; mov eax, &SendMessageW
        p := NumPut(sSendMessageW, p+0, "int")
        p := NumPut(0xd0ff, p+0, "short")   ; call eax
        p := NumPut(0xc2, p+0, "char")      ; ret argsize
        p := NumPut((InStr(Options, "C") ? 0 : ParamCount*4), p+0, "short")
    }
    NumPut(p, lParamPtr+0) ; To be passed as lParam.
    p := NumPut(&fn, p+0)
    p := NumPut(ParamCount, p+0, "int")
    return pcb
}

RegisterSyncCallback_Msg(wParam, lParam)
{
    if (A_Gui != "RegisterSyncCallback")
        return
    fn := Object(NumGet(lParam + 0))
    paramCount := NumGet(lParam + A_PtrSize, "int")
    params := []
    Loop % paramCount
        params.Push(NumGet(wParam + A_PtrSize * (A_Index-1)))
    return %fn%(params*)
}

UnloadWinDivert()
{
	return
	; Note: doing the following prevents GoodbyeDPI from being loaded again. In the case of fast startup, the driver kernel state of this most probably persists, which is why I don't do this even on shutdown
	if ((SCM := DllCall("Advapi32\OpenSCManager", "Ptr", 0, "Ptr", 0, "UInt", 0xF003F, "Ptr"))) {
		if ((SVC := DllCall("Advapi32\OpenService", "Ptr", SCM, "Str", "WinDivert1.3", "UInt", 0x0001 | 0x0002 | 0x0004 | 0x0020, "Ptr"))) {
			DllCall("Advapi32\DeleteService", "Ptr", SVC)
			VarSetCapacity(SERVICE_STATUS, 28)
			DllCall("Advapi32.dll\ControlService", "Ptr", SVC, "UInt", 0x00000001, "Ptr", &SERVICE_STATUS)
			DllCall("Advapi32\CloseServiceHandle", "Ptr", SVC)
		}
		DllCall("Advapi32\CloseServiceHandle", "Ptr", SCM)
	}

}

WTFMS()
{
	; Author: robertcollier4: https://autohotkey.com/board/topic/91577-taskbarnavigation-switch-windows-in-taskbar-order-alt-tab-replacement/
	hwnd := DllCall("GetForegroundWindow", "Ptr")
	loop {
		hwnd := DllCall("GetWindow", "Ptr", hwnd, "Ptr", 2, "Ptr")
	} until (DllCall("IsWindowVisible", "Ptr", hwnd))
	if (!DllCall("IsIconic", "Ptr", hwnd))
		if (!DllCall("SetForegroundWindow", "Ptr", hwnd))
			DllCall("SwitchToThisWindow", "Ptr", hwnd, "UInt", 1)
}

MsgSleep(hObject, dwTimeout)
{
	static MsgWaitForMultipleObjectsEx := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandleW", "WStr", "user32.dll", "Ptr"), "AStr", "MsgWaitForMultipleObjectsEx", "Ptr")
	; Based on code by Raymond Chen, from https://blogs.msdn.microsoft.com/oldnewthing/20060126-00/?p=32513, and from Lexikos: https://autohotkey.com/board/topic/27515-fileextract-fileextract-tomem-counterpart-of-fileinstall/
	; Assumes waiting will be done on one object, but adding support for more if needed is trivial
	r := 0xFFFFFFFF, dwStart := A_TickCount
	while ((dwElapsed := A_TickCount - dwStart) < dwTimeout) {
		r := DllCall(MsgWaitForMultipleObjectsEx, "UInt", 1, "Ptr*", hObject, "UInt", dwTimeout - dwElapsed, "UInt", 0x4FF, "UInt", 0x6, "UInt")
		if (r == 0 || r == 0xFFFFFFFF || r == 258)
			break
		Sleep -1
	}
	return r
}

; Very little error checking. TBH, I'd be surprised if someone actually uses this, so...
ProcAddressFromRemoteProcess(hProcess, sModuleName, targetFuncName, ByRef Magic := 0)
{
	if (!hProcess || !sModuleName || !targetFuncName)
		return 0

	MAX_PATH := 260
	INFINITE := 0xffffffff
	LIST_MODULES_DEFAULT := 0x00
	Loop {
		if (!DllCall("psapi\EnumProcessModulesEx", "Ptr", hProcess, "Ptr", 0, "UInt", 0, "UInt*", cbNeeded, "UInt", LIST_MODULES_DEFAULT))
			throw
		VarSetCapacity(hModules, cbNeeded, 0)
	} until (DllCall("psapi\EnumProcessModulesEx", "Ptr", hProcess, "Ptr", &hModules, "UInt", cbNeeded, "UInt*", cbNeeded, "UInt", LIST_MODULES_DEFAULT))			

	VarSetCapacity(modName, (MAX_PATH + 2) * 2)
	Loop % cbNeeded / A_PtrSize {
		if (DllCall("psapi\GetModuleBaseName", "Ptr", hProcess, "Ptr", NumGet(hModules, A_PtrSize * (A_Index - 1), "Ptr"), "Str", modName, "UInt", MAX_PATH)) {
			if (modName = sModuleName) {
				hModule := NumGet(hModules, A_PtrSize * (A_Index - 1), "Ptr")
				break
			}
		}
	}

	if (!hModule)
		return 0

	; MarkHC: https://www.unknowncheats.me/forum/1457119-post3.html
	IMAGE_DOS_SIGNATURE := 0x5A4D, IMAGE_NT_SIGNATURE := 0x4550
	if (DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", hModule, "UShort*", header, "Ptr", 2, "Ptr*", br) && br == 2 && header == IMAGE_DOS_SIGNATURE) {
		if (DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", hModule+60, "Int*", e_lfanew, "Ptr", 4, "Ptr*", br) && DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", hModule+e_lfanew, "UInt*", Signature, "Ptr", 4, "Ptr*", br)) {
			if (Signature == IMAGE_NT_SIGNATURE) {
				DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", hModule+e_lfanew+24, "UShort*", Magic, "Ptr", 2, "Ptr*", br)
				DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", hModule+e_lfanew+24+(Magic == (IMAGE_NT_OPTIONAL_HDR64_MAGIC := 0x20b) ? 112 : 96), "UInt*", exportTableRVA, "Ptr", 4, "Ptr*", br)
				DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", hModule+exportTableRVA+20, "UInt*", NumberOfFunctions, "Ptr", 4, "Ptr*", br)
				DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", hModule+exportTableRVA+24, "UInt*", NumberOfNames, "Ptr", 4, "Ptr*", br)
				DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", hModule+exportTableRVA+28, "UInt*", AddressOfFunctions, "Ptr", 4, "Ptr*", br)
				DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", hModule+exportTableRVA+32, "UInt*", AddressOfNames, "Ptr", 4, "Ptr*", br)
				DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", hModule+exportTableRVA+36, "UInt*", AddressOfNameOrdinals, "Ptr", 4, "Ptr*", br)
				
				VarSetCapacity(functions, NumberOfFunctions * 4)
				DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", hModule+AddressOfFunctions, "Ptr", &functions, "Ptr", NumberOfFunctions * 4, "Ptr*", br)
				VarSetCapacity(exports, NumberOfNames * 4)
				DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", hModule+AddressOfNames, "Ptr", &exports, "Ptr", NumberOfNames * 4, "Ptr*", br)
				VarSetCapacity(ordinals, NumberOfNames * 2)
				DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", hModule+AddressOfNameOrdinals, "Ptr", &ordinals, "Ptr", NumberOfNames * 2, "Ptr*", br)
				
				Loop % NumberOfNames {
					addr := NumGet(exports, 4 * (A_Index - 1), "UInt")
					i := 0, funcName := ""
					while (true) {
						DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", hModule+addr+i, "Int*", letter, "Ptr", 1, "Ptr*", br)
						if (!letter)
							break
						funcName .= Chr(letter)
						i += 1
					}
					if (funcName == targetFuncName) {
						ordinal := NumGet(ordinals, 2 * (A_Index - 1), "UShort")
						return NumGet(functions, 4 * ordinal, "UInt") + hModule
					}
				}
			}
		}
	}
	return 0
}

Edit() {
	Edit
}

ExitApp() {
	ExitApp
}
