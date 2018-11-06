#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetBatchLines, -1
ListLines, Off
#KeyHistory 0

#n::
	ShellContextMenu("Desktop", 1)
	SetTimer, EmptySet, -10000
return

EmptySet:
	Run "%A_AhkPath%" /restart "%A_ScriptFullPath%"
return

; Remake for unicode of Sean's ShellContextMenu by Deo: http://www.autohotkey.com/board/topic/65563-ahk-l-shell-context-menu/
; ANSI fixes and porting of fragman's additions of directly launching idn and debugging (http://www.autohotkey.com/board/topic/20376-invoking-directly-contextmenu-of-files-and-folders/page-4#entry303574) by qwerty12
ShellContextMenu(sPath, idn := "", win_hwnd := 0, ShellContextMenuDebug := false)
{
	if (!sPath)
		return
	pIShellFolder := 0
	pIContextMenu := 0
	idnValid := false
	if idn is Integer
		idnValid := true

	if (!idnValid && !win_hwnd) {
		Gui, SHELL_CONTEXT:New, +hwndwin_hwnd
		Gui, Show
	}

	if (spath == "Desktop") {
		DllCall("shell32\SHGetDesktopFolder", "PtrP", pIShellFolder) 
		DllCall(VTable(pIShellFolder, 8), "Ptr", pIShellFolder, "Ptr", 0, "Ptr", GUID4String(IID_IContextMenu,"{000214E4-0000-0000-C000-000000000046}"), "PtrP", pIContextMenu) ; CreateViewObject
	} else {
		If sPath Is Not Integer
			DllCall("shell32\SHParseDisplayName", "WStr", A_IsUnicode ? sPath : StrGet(&sPath,, "utf-8"), "Ptr", 0, "PtrP", pidl, "UInt", 0, "UIntP", 0) ;This function is the preferred method to convert a string to a pointer to an item identifier list (PIDL).
		Else
			DllCall("shell32\SHGetFolderLocation", "Ptr", 0, "Int", sPath, "Ptr", 0, "Uint", 0, "PtrP", pidl)
		DllCall("shell32\SHBindToParent", "Ptr", pidl, "Ptr", GUID4String(IID_IShellFolder,"{000214E6-0000-0000-C000-000000000046}"), "PtrP", pIShellFolder, "PtrP", pidlChild)
		DllCall(VTable(pIShellFolder, 10), "Ptr", pIShellFolder, "Ptr", 0, "Uint", 1, "Ptr*", pidlChild, "Ptr", GUID4String(IID_IContextMenu,"{000214E4-0000-0000-C000-000000000046}"), "Ptr", 0, "Ptr*", pIContextMenu) ;IShellFolder->GetUIObjectOf
		CoTaskMemFree(pidl)
	}
	ObjRelease(pIShellFolder), pIShellFolder := 0

	hMenu := DllCall("CreatePopupMenu")
	idnMIN := 1 ;idnValid Or debug ? 1 : 3
	;IContextMenu->QueryContextMenu
	;http://msdn.microsoft.com/en-us/library/bb776097%28v=VS.85%29.aspx
	DllCall(VTable(pIContextMenu, 3), "Ptr", pIContextMenu, "Ptr", hMenu, "UInt", 0, "UInt", idnMIN, "UInt", 0x7FFF, "UInt", 0x100)   ;CMF_EXTENDEDVERBS

	if (!idnValid) {
		ComObjError(0)
			global pIContextMenu2 := ComObjQuery(pIContextMenu, IID_IContextMenu2:="{000214F4-0000-0000-C000-000000000046}")
			global pIContextMenu3 := ComObjQuery(pIContextMenu, IID_IContextMenu3:="{BCFCE0A0-EC17-11D0-8D10-00A0C90F2719}")
			e := A_LastError ;GetLastError()
		ComObjError(1)
		if (e != 0)
			goTo, StopContextMenu
		global WPOld := DllCall(A_PtrSize == 8 ? "SetWindowLongPtr" : "SetWindowLong", "Ptr", win_hwnd ? win_hwnd : A_ScriptHwnd, "Int", -4, "Ptr", RegisterCallback("ShellContextMenuWindowProc"), "Ptr")
		DllCall("GetCursorPos", "Int64*", pt)
		DllCall("InsertMenu", "Ptr", hMenu, "UInt", 0, "UInt", 0x0400|0x800, "Ptr", 2, "Ptr", 0)
		DllCall("InsertMenu", "Ptr", hMenu, "UInt", 0, "UInt", 0x0400|0x002, "Ptr", 1, "Ptr", &sPath)

		idn := DllCall("TrackPopupMenuEx", "Ptr", hMenu, "Uint", 0x0100|0x0001, "Int", pt << 32 >> 32, "Int", pt >> 32, "Ptr", win_hwnd ? win_hwnd : A_ScriptHwnd, "Ptr", 0)
	}

	/*
	typedef struct _CMINVOKECOMMANDINFOEX {
	DWORD   cbSize;          0
	DWORD   fMask;           4
	HWND    hwnd;            8
	LPCSTR  lpVerb;          8+A_PtrSize
	LPCSTR  lpParameters;    8+2*A_PtrSize
	LPCSTR  lpDirectory;     8+3*A_PtrSize
	int     nShow;           8+4*A_PtrSize
	DWORD   dwHotKey;        12+4*A_PtrSize
	HANDLE  hIcon;           16+4*A_PtrSize
	LPCSTR  lpTitle;         16+5*A_PtrSize
	LPCWSTR lpVerbW;         16+6*A_PtrSize
	LPCWSTR lpParametersW;   16+7*A_PtrSize
	LPCWSTR lpDirectoryW;    16+8*A_PtrSize
	LPCWSTR lpTitleW;        16+9*A_PtrSize
	POINT   ptInvoke;        16+10*A_PtrSize
	} CMINVOKECOMMANDINFOEX, *LPCMINVOKECOMMANDINFOEX;
	http://msdn.microsoft.com/en-us/library/bb773217%28v=VS.85%29.aspx
	*/
	struct_size := 16+11*A_PtrSize
	VarSetCapacity(pici, struct_size, 0)
	NumPut(struct_size, pici, 0, "Uint")         ;cbSize
	NumPut((A_IsUnicode ? 0x00004000 : 0) | 0x20000000 | 0x00100000, pici, 4, "UInt")   ;fMask
	NumPut(win_hwnd ? win_hwnd : A_ScriptHwnd, pici, 8, "UPtr")       ;hwnd
	NumPut(1, pici, 8+4*A_PtrSize, "Uint")       ;nShow
	NumPut(idn-idnMIN, pici, 8+A_PtrSize, "UPtr")     ;lpVerb
	if (A_IsUnicode)
		NumPut(idn-idnMIN, pici, 16+6*A_PtrSize, "UPtr")  ;lpVerbW
	if (!idnValid)
		NumPut(pt, pici, 16+10*A_PtrSize, "UPtr")    ;ptInvoke

	DllCall(VTable(pIContextMenu, 4), "Ptr", pIContextMenu, "Ptr", &pici)   ; InvokeCommand

	if (!idnValid) {
		if (ShellContextMenuDebug) {
			VarSetCapacity(sName, 522)
			DllCall(VTable(pIContextMenu, 5), "Ptr", pIContextMenu, "UInt", idn-idnMIN, "UInt", 0x00000000, "UIntP", 0, "Str", sName, "Uint", 260)   ; GetCommandString
			if (A_IsUnicode)
				sName := StrGet(&sName,, "utf-8")
			OutputDebug, idn: %idn% command string: %sName%
		}
		DllCall("GlobalFree", "Ptr", DllCall("SetWindowLongPtr", "Ptr", win_hwnd ? win_hwnd : A_ScriptHwnd, "Int", -4, "Ptr", WPOld, "UPtr"))
	}
StopContextMenu:
	DllCall("DestroyMenu", "Ptr", hMenu)
	if (!idnValid) {
		ObjRelease(pIContextMenu3), ObjRelease(pIContextMenu2)
		pIContextMenu3 := pIContextMenu2 := WPOld := 0
	}
	ObjRelease(pIContextMenu), pIContextMenu := 0
	Gui, SHELL_CONTEXT:Destroy
	VarSetCapacity(pici, 0)
	return idn
}

ShellContextMenuWindowProc(hWnd, nMsg, wParam, lParam)
{
	Global pIContextMenu2, pIContextMenu3, WPOld
	If pIContextMenu3 { ;IContextMenu3->HandleMenuMsg2
		If !DllCall(VTable(pIContextMenu3, 7), "Ptr", pIContextMenu3, "Uint", nMsg, "Ptr", wParam, "Ptr", lParam, "Ptr*", lResult)
			return lResult
	}
	Else If pIContextMenu2 { ;IContextMenu2->HandleMenuMsg
		If !DllCall(VTable(pIContextMenu2, 6), "Ptr", pIContextMenu2, "Uint", nMsg, "Ptr", wParam, "Ptr", lParam)
			return 0
	}
	return DllCall("user32.dll\CallWindowProcW", "Ptr", WPOld, "Ptr", hWnd, "Uint", nMsg, "Ptr", wParam, "Ptr", lParam)
}

VTable(ppv, idx)
{
	Return NumGet(NumGet(ppv+0)+A_PtrSize*idx)
}

GUID4String(ByRef CLSID, String)
{
	VarSetCapacity(CLSID, 16, 0)
	return DllCall("ole32\CLSIDFromString", "WStr", String, "Ptr", &CLSID) >= 0 ? &CLSID : ""
}

CoTaskMemFree(pv)
{
	return DllCall("ole32\CoTaskMemFree", "Ptr", pv)
}
