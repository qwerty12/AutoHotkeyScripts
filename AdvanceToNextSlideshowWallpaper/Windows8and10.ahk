#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.

#n::
	if (pDesktopWallpaper && DllCall(NumGet(NumGet(pDesktopWallpaper+0)+16*A_PtrSize), "Ptr", pDesktopWallpaper, "Ptr", 0, "UInt", 0) != -2147023174) ; IDesktopWallpaper::AdvanceSlideshow - https://msdn.microsoft.com/en-us/library/windows/desktop/hh706947(v=vs.85).aspx
		return
	ObjRelease(pDesktopWallpaper)
	if ((pDesktopWallpaper := ComObjCreate("{C2CF3110-460E-4fc1-B9D0-8A1C0C9CC4BD}", "{B92B56A9-8B55-4E14-9A89-0199BBB6F93B}")))
		goto %A_ThisHotkey%
return