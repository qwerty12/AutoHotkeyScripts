#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#NoTrayIcon

MODE_GET_STATUS := 0
,MODE_TOGGLE_KEEP_ON_DEVICE := 1
,MODE_FREE_SPACE := 2

mode := MODE_GET_STATUS

if 0 < 1
{
    MsgBox This script requires at least 1 incoming parameter.
    ExitApp 1
}
else if 0 = 2
{
	firstParam = %1%
	if (firstParam = "/keepondevice")
		mode := MODE_TOGGLE_KEEP_ON_DEVICE
	else if (firstParam = "/freespace")
		mode := MODE_FREE_SPACE
	else
		ExitApp 1
}
else if 0 > 2
{
	ExitApp 1
}

RegRead, UserFolder, HKEY_CURRENT_USER\Software\Microsoft\OneDrive, UserFolder
if (ErrorLevel || !InStr(FileExist(UserFolder), "D"))
	ExitApp 1
SetWorkingDir %UserFolder%

if (mode == MODE_GET_STATUS)
	filenameParam = %1%
else
	filenameParam = %2%
if (!FileExist(filenameParam))
	ExitApp 1

VarSetCapacity(dwTypeData, 2050)
,VarSetCapacity(IID_IDataObject, 16)
,DllCall("ole32\CLSIDFromString", "WStr", "{0000010e-0000-0000-C000-000000000046}", "Ptr", &IID_IDataObject)

DoOrDie(DllCall("shell32\SHGetDesktopFolder", "Ptr*", pDesktop))
filenames := [DllCall("shlwapi\PathCombineW", "Ptr", &dwTypeData, "Ptr", &UserFolder, "Ptr", &filenameParam, "WStr")]
VarSetCapacity(pidl_list, filenames.MaxIndex() * A_PtrSize)
filenameCount := 0, ParseDisplayName := NumGet(NumGet(pDesktop+0)+3*A_PtrSize)
for _, filename in filenames
	filenameCount += DllCall(ParseDisplayName, "Ptr", pDesktop, "Ptr", 0, Ptr, 0, "WStr", filename, "Ptr", 0, "Ptr", &pidl_list+(filenameCount * A_PtrSize), "Ptr", 0) >= 0x00
if (!filenameCount)
	ExitApp 1
DoOrDie(DllCall(NumGet(NumGet(pDesktop+0)+10*A_PtrSize), "Ptr", pDesktop, "Ptr", 0, "UInt", filenameCount, "Ptr", &pidl_list, "Ptr", &IID_IDataObject, "Ptr", 0, "Ptr*", pDataObject))

fsctxmenu := ComObjCreate("{CB3D0F55-BC2C-4C1A-85ED-23ED75B5106B}", "{000214E4-0000-0000-C000-000000000046}")
fsshextinit := ComObjQuery(fsctxmenu, "{000214E8-0000-0000-C000-000000000046}")
DoOrDie(DllCall(NumGet(NumGet(fsshextinit+0)+3*A_PtrSize), "Ptr", fsshextinit, "Ptr", 0, "Ptr", pDataObject, "Ptr", 0))

DoOrDie(DllCall(NumGet(NumGet(fsctxmenu+0)+3*A_PtrSize), "Ptr", fsctxmenu, "Ptr", (hMenu := DllCall("CreatePopupMenu", "Ptr")), "UInt", 0, "UInt", 0, "UInt", 0x7FFF, "UInt", 0x00000080))
VarSetCapacity(MENUITEMINFOW, (cbMENUITEMINFOW := A_PtrSize == 8 ? 72 : 44))
Loop % DllCall("GetMenuItemCount", "Ptr", hMenu, "Int") {
	DllCall("ntdll\RtlZeroMemory", "Ptr", &MENUITEMINFOW, "Ptr", cbMENUITEMINFOW)
	,NumPut(cbMENUITEMINFOW, MENUITEMINFOW, 0, "UInt")
	,NumPut(0x00000002 | 0x00000001 | 0x00000040, MENUITEMINFOW, 4, "UInt")
	,NumPut(1024, MENUITEMINFOW, A_PtrSize == 8 ? 64 : 40, "UInt")
	,NumPut(&dwTypeData, MENUITEMINFOW, A_PtrSize == 8 ? 56 : 36, "Ptr")
	if ((DllCall("GetMenuItemInfo", "Ptr", hMenu, "UInt", A_Index - 1, "Int", True, "Ptr", &MENUITEMINFOW, "Int")) && (cch := NumGet(MENUITEMINFOW, A_PtrSize == 8 ? 64 : 40, "UInt"))) {
		fState := NumGet(MENUITEMINFOW, 12, "UInt") 
		,idn := NumGet(MENUITEMINFOW, 16, "UInt")
		,menulabel := StrGet(&dwTypeData, cch, "UTF-16")
		if (menulabel == "Always keep on this device") {
			if (mode == MODE_GET_STATUS)
				msg .= (StrLen(msg) ? "`n" : "") . filenameParam . " is " . (fState & 0x00000008 != 0x00000008 ? "not " : "") . "set to always be kept on this device"
			else if (mode == MODE_TOGGLE_KEEP_ON_DEVICE)
				break
		} else if (menulabel == "Free up space") {
			cannotBeSelected := fState & 0x00000001 || fState & 0x00000002
			if (mode == MODE_GET_STATUS) {
				msg .= (StrLen(msg) ? "`n" : "") . filenameParam . " can" . (cannotBeSelected ? "not " : " ") . "be freed to make space"
			} else if (mode == MODE_FREE_SPACE) {
				if (cannotBeSelected)
					mode := -1
				break
			}
		}
	}
}

if (mode == MODE_GET_STATUS) {
	msgbox %msg%
} else if (mode == MODE_TOGGLE_KEEP_ON_DEVICE || mode == MODE_FREE_SPACE) {
	VarSetCapacity(info, (cbCMINVOKECOMMANDINFO := A_PtrSize == 8 ? 56 : 36), 0)
	,NumPut(cbCMINVOKECOMMANDINFO, info, 0, "UInt")
	,NumPut(0x00000100, info, 4, "UInt")
	,NumPut(A_ScriptHwnd, info, 8, "Ptr")
	,NumPut(idn, info, A_PtrSize == 8 ? 16 : 12, "UPtr")
	,DoOrDie(DllCall(NumGet(NumGet(fsctxmenu+0)+4*A_PtrSize), "Ptr", fsctxmenu, "Ptr", &info)) ; IContextMenu::InvokeCommand
	Sleep -1
}

DllCall("DestroyMenu", "Ptr", hMenu)
,ObjRelease(fsshextinit)
,ObjRelease(fsctxmenu)
,ObjRelease(pDataObject)
Loop %filenameCount% {
	if ((pidl := NumGet(pidl_list, (A_Index - 1) * A_PtrSize, "Ptr")))
		DllCall("ole32\CoTaskMemFree", "Ptr", pidl)
}
ObjRelease(pDesktop)
ExitApp

DoOrDie(hr)
{
	if (hr == "" || hr < 0)
		ExitApp 1
}