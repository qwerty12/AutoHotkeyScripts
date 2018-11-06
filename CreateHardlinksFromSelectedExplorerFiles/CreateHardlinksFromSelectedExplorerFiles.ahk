#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance Force

; apparently not needed for hard links
/*
; From AutoHotkey's Process docpage
Process, Exist  ; sets ErrorLevel to the PID of this running script
; Get the handle of this script with PROCESS_QUERY_INFORMATION (0x0400)
h := DllCall("OpenProcess", "UInt", 0x0400, "Int", false, "UInt", ErrorLevel, "Ptr")
; Open an adjustable access token with this process (TOKEN_ADJUST_PRIVILEGES = 32)
DllCall("Advapi32.dll\OpenProcessToken", "Ptr", h, "UInt", 32, "PtrP", t)
VarSetCapacity(ti, 16, 0)  ; structure of privileges
NumPut(1, ti, 0, "UInt")  ; one entry in the privileges array...
; Retrieves the locally unique identifier of the debug privilege:
DllCall("Advapi32.dll\LookupPrivilegeValue", "Ptr", 0, "Str", "SeCreateSymbolicLinkPrivilege", "Int64P", luid)
NumPut(luid, ti, 4, "Int64")
NumPut(2, ti, 12, "UInt")  ; enable this privilege: SE_PRIVILEGE_ENABLED = 2
; Update the privileges of this process with the new access token:
r := DllCall("Advapi32.dll\AdjustTokenPrivileges", "Ptr", t, "Int", false, "Ptr", &ti, "UInt", 0, "Ptr", 0, "Ptr", 0)
DllCall("CloseHandle", "Ptr", t)  ; close this access token handle to save memory
DllCall("CloseHandle", "Ptr", h)  ; close this process handle to save memory
*/

#If ((expWnd := validExplorerWindow(WinExist("A"), expWndType)))
^+c::
hardLinkSourceFiles := getExplorerSelectedFiles(expWnd, expWndType)
if ((hardlinkSourceCount := hardLinkSourceFiles.MaxIndex()))
	TrayTip,, % hardlinkSourceCount . (hardlinkSourceCount == 1 ? " file" : " files") . " selected for hard linking"
return

^+v::
if ((hardLinkSourceFiles.MaxIndex()) && (expPath := getExplorerWindowPath(expWnd, expWndType))) {
	expPath .= "\"
	for idx, file in hardLinkSourceFiles
		if (!DllCall("CreateHardLink", "Str", expPath . file.Name, "Str", file.Path, "Ptr", 0))
			hardLinkSourceFiles.RemoveAt(idx)
	selectFilesInFolder(expWnd, expWndType, hardLinkSourceFiles)
	hardLinkSourceFiles := ""
}
#If
return

validExplorerWindow(hwnd, ByRef outType)
{
	outType := 0
	if (hwnd) {
		WinGetClass wndClass, ahk_id %hwnd%
		if (wndClass == "CabinetWClass")
			outType := 1
		else if (wndClass == "Progman" || wndClass == "WorkerW")
			outType := 2
		
		if (outType)
			return hwnd
	}
	return 0
}

getExplorerWindowPath(hwnd, hwndType)
{
	; qwerty12's https://autohotkey.com/boards/viewtopic.php?f=5&t=31135
	static IID_IShellFolder, STRRET, path, SIGDN_FILESYSPATH := 0x80058000
	if (!VarSetCapacity(IID_IShellFolder))
		VarSetCapacity(IID_IShellFolder, 16), DllCall("ole32\CLSIDFromString", "WStr", "{000214E6-0000-0000-C000-000000000046}", "Ptr", &IID_IShellFolder)
		,VarSetCapacity(STRRET, 272), VarSetCapacity(path, 262 * (!!A_IsUnicode + 1))

	if (hwndType == 2)
		return A_Desktop
	else if (hwndType == 1) {
		shellWindows := ComObjCreate("Shell.Application").Windows
		for window in shellWindows {
			if (window.hwnd == hwnd) {
				try {
					isp := ComObjQuery(window, "{6d5140c1-7436-11ce-8034-00aa006009fa}")
					tlb := ComObjQuery(isp, "{4C96BE40-915C-11CF-99D3-00AA004AE837}", "{000214E2-0000-0000-C000-000000000046}")
					if (DllCall(NumGet(NumGet(tlb+0)+15*A_PtrSize), "Ptr", tlb, "Ptr*", isv) < 0)
						throw
					ifv := ComObjQuery(isv, "{cde725b0-ccc9-4519-917e-325d72fab4ce}")
					if (DllCall(NumGet(NumGet(ifv+0)+5*A_PtrSize), "Ptr", ifv, "Ptr", &IID_IShellFolder, "Ptr*", isf) < 0)
						throw
					if (DllCall(NumGet(NumGet(isf+0)+11*A_PtrSize), "Ptr", isf, "Ptr", 0, "UInt", SIGDN_FILESYSPATH, "Ptr", &STRRET) < 0)
						throw
					if (DllCall("shlwapi\StrRetToBuf", "Ptr", &STRRET, "Ptr", 0, "Str", path, "UInt", 260))
						throw
					return path
				} catch {
					return 0
				} finally {
					for _, obj in [isf, ifv, isv, tlb, isp]
						if (obj)
							ObjRelease(obj)
				}
			}
		}
	}
	
	return 0
}

getExplorerSelectedFiles(hwnd, hwndType)
{
	ret := 0
	
	items := getFolderDocument(hwnd, hwndType).SelectedItems

	if (items.Count) {
		ret := []
		for Item in items
			if (!Item.IsFolder) ; you can't hardlink folders
				ret.push({Path: Item.Path, Name: Item.Name})
	}

	return ret
}

getFolderDocument(hwnd, hwndType)
{
	;Based on Rapte_of_Suzaku's https://autohotkey.com/board/topic/60985-get-paths-of-selected-items-in-an-explorer-window/ and Lexikos' https://autohotkey.com/boards/viewtopic.php?t=9618
	static _hwnd
	Document := 0
	shellWindows := ComObjCreate("Shell.Application").Windows

	if (hwndType == 1) {
		for window in shellWindows {
			if (window.hwnd == hwnd) {
				Document := window.Document
				break
			}
		}
	} else if (hwndType == 2) {
		if (!VarSetCapacity(_hwnd))
			VarSetCapacity(_hwnd, 4, 0)
		desktop := shellWindows.FindWindowSW(0, "", 8, ComObj(0x4003, &_hwnd), 1)
		Document := desktop.Document
	}

	return Document
}

selectFilesInFolder(hwnd, hwndType, namesOfFiles)
{
	; Based on Lexikos' https://autohotkey.com/boards/viewtopic.php?t=9618
    
    Document := getFolderDocument(hwnd, hwndType)
    items := Document.SelectedItems
    Loop % items.Count
        Document.SelectItem(items.Item(A_Index-1), 0)
	for _, file in namesOfFiles
		Document.SelectItem(items.Item(file.Name), 1)
}