#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.

; Copy of https://www.voidtools.com/support/everything/sdk/c/
; Place Everything32.dll and Everything64.dll from the SDK (https://www.voidtools.com/downloads/) into the same directory as this script
EverythingDll := "Everything" . (A_PtrSize == 8 ? "64" : "32") . ".dll"
EverythingMod := DllCall("LoadLibrary", "Str", A_ScriptDir . "\" . EverythingDll, "Ptr")
DllCall(EverythingDll . "\Everything_SetSearch", "Str", "Taskmgr.exe")
DllCall(EverythingDll . "\Everything_Query", "Int", True)
Loop % DllCall(EverythingDll . "\Everything_GetNumResults", "UInt")
	MsgBox % DllCall(EverythingDll . "\Everything_GetResultFileName", "UInt", A_Index - 1, "Str") . " [" . DllCall(EverythingDll . "\Everything_GetResultPath", "UInt", A_Index - 1, "Str") . "]"
DllCall(EverythingDll . "\Everything_Reset")
DllCall("FreeLibrary", "Ptr", EverythingMod)