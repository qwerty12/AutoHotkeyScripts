; https://autohotkey.com/board/topic/16457-controlling-popup-menues/

PopupMenuUtils_user32_handle(fn)
{
	static u32 := DllCall("GetModuleHandle", Str, "user32.dll", "Ptr")
	return DllCall("GetProcAddress", "Ptr", u32, "AStr", fn, "Ptr")
}

PopupMenuUtils_MF_BYPOSITION() {
	return 0x00000400
}

PopupMenuUtils_GetMenuItemCount(hMenu)
{
	static GetMenuItemCount := PopupMenuUtils_user32_handle("GetMenuItemCount")
	return DllCall(GetMenuItemCount, "Ptr", hMenu, "Int")
}

;PopupMenuUtils_GetMenuString(hMenu, nPos)
;{
;	static GetMenuStringW := PopupMenuUtils_user32_handle("GetMenuStringW"), byp := PopupMenuUtils_MF_BYPOSITION()
;	if ((hMenu) && (length := DllCall(GetMenuStringW, "Ptr", hMenu, "UInt", nPos, "Ptr", 0, "Int", 0, "UInt", byp))) {
;		length += 1, VarSetCapacity(lpString, (length * 2) + 2)
;		if (DllCall(GetMenuStringW, "Ptr", hMenu, "UInt", nPos, "WStr", lpString, "Int", length, "UInt", byp))
;			return lpString
;	}
;	return ""
;}

PopupMenuUtils_GetMenuString(hMenu, nPos)
{
	static lpString, GetMenuStringW := PopupMenuUtils_user32_handle("GetMenuStringW"), byp := PopupMenuUtils_MF_BYPOSITION()
	if !VarSetCapacity(lpString)
		VarSetCapacity(lpString, 1024) ; what sort of idiot makes a menu item have ~510 characters, anyway?
	if (DllCall(GetMenuStringW, "Ptr", hMenu, "UInt", nPos, "WStr", lpString, "Int", 511, "UInt", byp))
		return lpString
}

PopupMenuUtils_GetMenuState(hMenu, nPos)
{
	static GetMenuState := PopupMenuUtils_user32_handle("GetMenuState"), byp := PopupMenuUtils_MF_BYPOSITION()
	return DllCall(GetMenuState, "Ptr", hMenu, "UInt", nPos, "UInt", byp, "UInt")
}

PopupMenuUtils_ItemIsChecked(State) {
	return !!(State & 0x00000008) ; MF_CHECKED
}

PopupMenuUtils_ItemIsDisabled(State) {
	return !!(State & 0x00000002 || State & 0x00000001) ; MF_DISABLED || MF_GRAYED
}

PopupMenuUtils_ItemIsPopup(State) {
	return !!(State & 0x00000010) ; MF_POPUP
}

PopupMenuUtils_GetMenuItemID(hMenu, nPos) {
	return DllCall("GetMenuItemID", "Ptr", hMenu, "int", nPos, "UInt")
}

PopupMenuUtils_GetHmenuFromHwnd(hWnd)
{
	static SendMessagePtr := PopupMenuUtils_user32_handle(A_IsUnicode ? "SendMessageW" : "SendMessageA")
	return DllCall(SendMessagePtr, "Ptr", hWnd, "UInt", 0x01E1, "Ptr", 0, "Ptr", 0, "Ptr") ; MN_GETHMENU
}

PopupMenuUtils_GetMenu(hwnd) {
	return DllCall("GetMenu", "Ptr", hwnd, "Ptr")
}

PopupMenuUtils_GetSubmenu(hMenu, nPos) {
	return DllCall("GetSubMenu", "Ptr", hMenu, "int", nPos, "Ptr")
}

PopupMenuUtils_WinHasMenu(WinTitle:="") {
	return !!PopupMenuUtils_GetMenu(WinExist(WinTitle))
}
