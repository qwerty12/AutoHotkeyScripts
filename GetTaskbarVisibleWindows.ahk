#NoEnv
#Include <PopupMenuUtils>

if (A_ScriptName == "GetTaskbarVisibleWindows.ahk") {
	Menu, Tray, NoIcon
	SetBatchLines -1
	ListLines, Off
	for _, hwnd in GetTaskbarVisibleWindows() {
		WinGetClass wndClass, ahk_id %hwnd%
		WinGetTitle wndTitle, ahk_id %hwnd%
		x .= wndClass . " - " . (wndTitle ? wndTitle : Format("{:x}", hwnd)) . "`n"
		/* ScClose("ahk_id " . hwnd) 
		*/
	}
	MsgBox % x
	ExitApp
}

; Based off code from the following projects:
; * https://sourceforge.net/projects/taskswitchxp/
; * https://github.com/kvakulo/Switcheroo

GetTaskbarVisibleWindows(limit:=0, checkDisabled:=True, checkEmptyTitle:=False
					    ,checkNoActivate:=True, checkImmediateOwnerVisibility:=True
					    ,checkITaskListDeleted:=True, useAudioRouterAlgo:=True)
{
	static sevenOrBelow := A_OSVersion ~= "WIN_(7|XP|VISTA)", rect, PropEnumProcEx := 0, cleanup := {base: {__Delete: "GetTaskbarVisibleWindows"}}
	static WS_DISABLED := 0x08000000, WS_EX_TOOLWINDOW := 0x00000080, WS_EX_APPWINDOW := 0x00040000, WS_EX_CONTROLPARENT := 0x00010000, WS_EX_NOREDIRECTIONBITMAP := 0x00200000, WS_EX_NOACTIVATE := 0x08000000
	static GA_ROOTOWNER := 3, GW_OWNER := 4, DWMWA_CLOAKED := 14

	if (PropEnumProcEx && A_EventInfo == PropEnumProcEx && checkNoActivate >= 4096 && IsWindow(limit)) {
		if (checkDisabled && StrGet(checkDisabled) == "ApplicationViewCloakType") {
			NumPut(checkEmptyTitle != 1, checkNoActivate+0, "Int")
			return False
		}
		return True
	}

	if (!cleanup) {
		if (PropEnumProcEx)
			DllCall("GlobalFree", "Ptr", PropEnumProcEx, "Ptr"), PropEnumProcEx := 0
		return
	}

	if (!VarSetCapacity(rect)) {
		VarSetCapacity(rect, 16)
		if (!sevenOrBelow)
			PropEnumProcEx := RegisterCallback(A_ThisFunc, "Fast", 4)
	}

	shell := 0 ; DllCall("GetShellWindow", "Ptr")

	ret := []
	prevDetectHiddenWindows := A_DetectHiddenWindows

	DetectHiddenWindows Off

	WinGet id, list,,, Program Manager
	Loop %id% {
		hwnd := id%A_Index%

		if (limit && limit == ret.MaxIndex())
			break

		if (checkEmptyTitle) {
			WinGetTitle wndTitle, ahk_id %hwnd%
			if (!wndTitle)
				continue
		}

		if (checkDisabled) {
			WinGet dwStyle, Style, ahk_id %hwnd%
			if (dwStyle & WS_DISABLED)
				continue
		}

		if (checkITaskListDeleted && DllCall("GetProp", "Ptr", hwnd, "Str", "ITaskList_Deleted", "Ptr"))
			continue 

		if (DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", &rect) && !DllCall("IsRectEmpty", "Ptr", &rect)) {
			if (!shell) {
				hwndRootOwner := DllCall("GetAncestor", "Ptr", hwnd, "UInt", GA_ROOTOWNER, "Ptr")
			} else {
				hwndTmp := hwnd
				Loop {
					hwndRootOwner := hwndTmp
					hwndTmp := DllCall("GetWindow", "Ptr", hwndTmp, "UInt", GW_OWNER, "Ptr")
				} until (!hwndTmp || hwndTmp == shell)
			}

			WinGet dwStyleEx, ExStyle, ahk_id %hwndRootOwner%
			if (hwnd != hwndRootOwner)
				WinGet dwStyleEx2, ExStyle, ahk_id %hwnd%
			else
				dwStyleEx2 := dwStyleEx

			hasAppWindow := dwStyleEx2 & WS_EX_APPWINDOW
			if (checkNoActivate)
				if ((dwStyleEx2 & WS_EX_NOACTIVATE) && !hasAppWindow)
					continue

			if (checkImmediateOwnerVisibility) {
				hwndOwner := DllCall("GetWindow", "Ptr", hwnd, "UInt", GW_OWNER, "Ptr")
				if (!(!hwndOwner || !DllCall("IsWindowVisible", "Ptr", hwndRootOwner)))
					continue
			}				

			if (!(dwStyleEx & WS_EX_TOOLWINDOW) || hasAppWindow || (!(dwStyleEx2 & WS_EX_TOOLWINDOW) && dwStyleEx2 & WS_EX_CONTROLPARENT)) {
				if (useAudioRouterAlgo && !is_main_window(hwnd))
					continue			
				if (!sevenOrBelow) {
					WinGetClass wndClass, ahk_id %hwnd%
					if (wndClass == "Windows.UI.Core.CoreWindow")
						continue
					if (wndClass == "ApplicationFrameWindow") {
						hasAppropriateApplicationViewCloakType := !PropEnumProcEx
						if (PropEnumProcEx)
							DllCall("EnumPropsEx", "Ptr", hwnd, "Ptr", PropEnumProcEx, "Ptr", &hasAppropriateApplicationViewCloakType)
						if (!hasAppropriateApplicationViewCloakType)
							continue
					} else {
						if (dwStyleEx & WS_EX_NOREDIRECTIONBITMAP) 
							continue
						if (!DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwndRootOwner, "UInt", DWMWA_CLOAKED, "UInt*", isCloaked, "Ptr", 4) && isCloaked)
							continue
					}
				}
				ret.push(hwnd)
			}
		}
	}
	
	DetectHiddenWindows %prevDetectHiddenWindows%
	return ret
}

; Based off https://github.com/audiorouterdev/audio-router
is_main_window(handle)
{
	static WS_CHILD := 0x40000000, WS_OVERLAPPED := 0x00000000, WS_POPUP := 0x80000000
	static WS_EX_WINDOWEDGE := 0x00000100, WS_EX_CLIENTEDGE := 0x00000200, WS_EX_DLGMODALFRAME := 0x00000001, WS_EX_OVERLAPPEDWINDOW := WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE
	WinGet Style, Style, ahk_id %handle%
	WinGet Style, ExStyle, ahk_id %handle%

    if (Style & WS_CHILD)
        return FALSE

    i := 0
    if(Style & WS_OVERLAPPED)
        i++
    if(Style & WS_POPUP)
    {
        i--
        if(DllCall("GetParent", "Ptr", handle))
            i--
    }
    if(ExStyle & WS_EX_OVERLAPPEDWINDOW)
        i++
    if(ExStyle & WS_EX_CLIENTEDGE)
        i--
    if(ExStyle & WS_EX_DLGMODALFRAME)
        i--
    return (i >= 0)
}

; Based off https://stackoverflow.com/a/4688414
GetTaskbarVisibleWindows_IsWindowVisible(m_hWnd)
{
	static GetWindowRect := PopupMenuUtils_user32_handle("GetWindowRect"), rgn := 0, rtView, RectInRegion := DllCall("GetProcAddress", Ptr, DllCall("GetModuleHandle", Str, "gdi32.dll", "Ptr"), AStr, "RectInRegion", "Ptr"), cleanup := {base: {__Delete: "GetTaskbarVisibleWindows_IsWindowVisible"}}

	if (!cleanup) {
		if (rgn)
			DllCall("Gdi32\DeleteObject", "Ptr", rgn), rgn := 0
		return
	}

	if (!rgn)
		VarSetCapacity(rtView, 16), VarSetCapacity(rtDesktop, 16), DllCall(GetWindowRect, "Ptr", DllCall("GetDesktopWindow", "Ptr"), "Ptr", &rtDesktop), rgn := DllCall("Gdi32\CreateRectRgn", "Int", NumGet(rtDesktop, 0, "Int"), "Int", NumGet(rtDesktop, 4, "Int"), "Int", NumGet(rtDesktop, 8, "Int"), "Int", NumGet(rtDesktop, 12, "Int"), "Ptr")

	return DllCall(GetWindowRect, "Ptr", m_hWnd, "Ptr", &rtView) && DllCall(RectInRegion, "Ptr", rgn, "Ptr", &rtView)
}
