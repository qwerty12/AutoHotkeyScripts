#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#NoTrayIcon

; Credits: torvin - https://stackoverflow.com/a/40921638

try {
	ITipInvocation := ComObjCreate("{4ce576fa-83dc-4F88-951c-9d0782b4e376}", "{37c994e7-432b-4834-a2f7-dce1f13b834b}")
	DllCall(NumGet(NumGet(ITipInvocation+0)+3*A_PtrSize), "Ptr", ITipInvocation, "Ptr", DllCall("GetDesktopWindow", "Ptr"))
	ObjRelease(ITipInvocation)
} catch {
	Run %A_ProgramFiles%\Common Files\microsoft shared\ink\TabTip.exe, %A_ProgramFiles%\Common Files\microsoft shared\ink\, UseErrorLevel
}