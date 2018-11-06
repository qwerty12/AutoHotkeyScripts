#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.

; AppUserID string source: https://stackoverflow.com/questions/32150759/how-to-enumerate-the-installed-storeapps-and-their-id-in-windows-8-and-10
IApplicationActivationManager := ComObjCreate("{45BA127D-10A8-46EA-8AB7-56EA9078943C}", "{2e941141-7f97-4756-ba1d-9decde894a3d}")
DllCall(NumGet(NumGet(IApplicationActivationManager+0)+3*A_PtrSize), "Ptr", IApplicationActivationManager, "Str", "microsoft.windowscommunicationsapps_8wekyb3d8bbwe!microsoft.windowslive.calendar", "Str", 0, "UInt", 0, "IntP", processId)
ObjRelease(IApplicationActivationManager)
ExitApp