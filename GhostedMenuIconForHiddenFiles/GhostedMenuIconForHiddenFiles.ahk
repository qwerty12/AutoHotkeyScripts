#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; Show a menu of the first n files matching a pattern, and their icons.
pattern = %A_ScriptDir%\*
n = 15

VarSetCapacity(ICONINFO, (cbICONINFO := 32)), VarSetCapacity(BITMAP, 32)
; Allocate memory for a SHFILEINFOW struct.
VarSetCapacity(fileinfo, fisize := A_PtrSize + 688)

Loop, Files, %pattern%, FD
{
    ; Add a menu item for each file.
    Menu F, Add, %A_LoopFileName%, donothing
    
    ; Get the file's icon.
    if DllCall("shell32\SHGetFileInfoW", "wstr", A_LoopFileFullPath
        , "uint", 0, "ptr", &fileinfo, "uint", fisize, "uint", 0x100 | SHGFI_ATTRIBUTES := 0x000000800)
    {
        hicon := NumGet(fileinfo, 0, "ptr")
		dwAttributes := NumGet(fileinfo, A_PtrSize + 4, "UInt")
		if (dwAttributes & SFGAO_GHOSTED := 0x00008000) {
			if (DllCall("GetIconInfo", "Ptr", hicon, "Ptr", &ICONINFO)) {
				hbmColor := NumGet(ICONINFO, cbICONINFO - A_PtrSize, "Ptr")
				hbmMask := NumGet(ICONINFO, cbICONINFO - (A_PtrSize * 2), "Ptr")

				if (DllCall("GetObject", "Ptr", hbmColor, "Int", A_PtrSize == 8 ? 32 : 24, "Ptr", &BITMAP)) {
					width := NumGet(BITMAP, 4, "Int")
					height := NumGet(BITMAP, 8, "Int")

					if ((im := IL_Create(1, 0, True))) {
						if ((idx := DllCall("ImageList_Add", "Ptr", im, "Ptr", hbmColor, "Ptr", hbmMask)) != -1) {
							rgbBk := DllCall("GetSysColor", "UInt", COLOR_MENU := 4, "UInt")
							rgbFg := RGB(255, 255, 255)
							scrdc := DllCall("GetDC", "Ptr", A_ScriptHwnd, "Ptr")
							hdc := DllCall("CreateCompatibleDC", "Ptr", scrdc, "Ptr")
							
							DllCall("SelectObject", "Ptr", hdc, "Ptr", hbmMask, "Ptr")
							if (DllCall("ImageList_DrawEx", "Ptr", im, "Int", idx, "Ptr", hdc, "Int", 2, "Int", 0, "Int", width, "Int", height, "UInt", rgbBk, "UInt", rgbFg, "UInt", ILD_MASK := 0x00000010 | ILD_BLEND50 := 0x00000004)) {
								DllCall("SelectObject", "Ptr", hdc, "Ptr", hbmColor, "Ptr")
								DllCall("ImageList_DrawEx", "Ptr", im, "Int", idx, "Ptr", hdc, "Int", 0, "Int", 0, "Int", width, "Int", height, "UInt", rgbBk, "UInt", rgbFg, "UInt", ILD_BLEND50 := 0x00000004)
								DllCall("SelectObject", "Ptr", hdc, "Ptr", 0, "Ptr")

								DllCall("DestroyIcon", "Ptr", hicon)
								hicon := DllCall("CreateIconIndirect", "Ptr", &ICONINFO, "Ptr")
							}
							DllCall("DeleteDC", "Ptr", hdc)
							DllCall("ReleaseDC", "Ptr", 0, "Ptr", scrdc)
						}
						IL_Destroy(im)
					}
				}

				if (hbmColor)
					DllCall("DeleteObject", "Ptr", hbmColor)

				if (hbmMask)
					DllCall("DeleteObject", "Ptr", hbmMask)
			}
		}
        ; Set the menu item's icon.
        Menu F, Icon, %A_Index%&, HICON:%hicon%
        ; Because we used ":" and not ":*", the icon will be automatically
        ; freed when the program exits or if the menu or item is deleted.
    }
}
until A_Index = n
Menu F, Show
donothing:
return

RGB(r,g,b)
{
	return (r)|(g << 8)|(b << 16)
}