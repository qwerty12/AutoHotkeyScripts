#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.

; An alternative to selecting a .theme file by double-clicking on it and then closing the resulting personalisation window afterwards manually

; Source: C:\Windows\diagnostics\system\AERO\CL_Utility.ps1

MsgBox This will change your Windows theme to Windows 7's classic one. Exit now from the tray menu if you do not want this.

themePath := A_WinDir . "\Resources\Ease of Access Themes\classic.theme" ; Change as needed
if (FileExist(themePath))
{
	try themeManager := ComObjCreate(CLSID_IThemeManager := "{C04B329E-5823-4415-9C93-BA44688947B0}", IID_IThemeManager := "{0646EBBE-C1B7-4045-8FD0-FFD65D3FC792}")	
	if (themeManager) {
		themeBstr := DllCall("oleaut32\SysAllocString", "WStr", themePath, "Ptr")
		if (themeBstr) {
			DllCall(NumGet(NumGet(themeManager+0)+4*A_PtrSize), "Ptr", themeManager, "Ptr", themeBstr) ; ::ApplyTheme
			DllCall("oleaut32\SysFreeString", "Ptr", themeBstr)
		}
		ObjRelease(themeManager)
	}
}	
