#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#NoTrayIcon
#SingleInstance force

; Create multiple Windows 10 virtual desktops first

; base script by k1dr0ck

gui, +AlwaysOnTop +HwndhwndGui
gui, add, button, x10 y5 h20 w35 gsub1, <-
gui, add, button, x55 y5 h20 w35 gsub2, ->
gui, show, x15 y680 h30 w100

return

sub1:
 {
   SendInput ^#{Left}
   movewindow(hwndGui)
 }
return

sub2:
 {
   SendInput ^#{Right}
   movewindow(hwndGui)
 }
return

guiclose:
 {
   exitapp
 }
return

movewindow(guiHwnd)
{
	static desktopID
	if (!VarSetCapacity(desktopID))
		VarSetCapacity(desktopID, 16)

	try if IVirtualDesktopManager := ComObjCreate("{aa509086-5ca9-4c25-8f95-589d3c07b48a}", "{a5cd92ff-29be-454c-8d04-d82879fb3f1b}") {
		Loop 10 { ; wait to see until our main GUI is not on the starting virtual desktop
			hr := DllCall(NumGet(NumGet(IVirtualDesktopManager+0), 3 * A_PtrSize), "Ptr", IVirtualDesktopManager, "Ptr", guiHwnd, "Int*", onCurrentDesktop)
			if (hr == "" || hr < 0) {
				ObjRelease(IVirtualDesktopManager)
				return
			}
			Sleep 100
			if (!onCurrentDesktop)
				break
		}
		if (!onCurrentDesktop) {
			gui tmp: +Hwndwtfms ; create a new temporary GUI belonging to our process on the new virtual desktop
			gui tmp: show
			hr := DllCall(NumGet(NumGet(IVirtualDesktopManager+0), 4 * A_PtrSize), "Ptr", IVirtualDesktopManager, "Ptr", wtfms, "Ptr", &desktopID) ; get the GUID of the virtual desktop hosting our temporary window
			Gui tmp: destroy
			if (hr == 0 && DllCall(NumGet(NumGet(IVirtualDesktopManager+0), 5 * A_PtrSize), "Ptr", IVirtualDesktopManager, "Ptr", guiHwnd, "Ptr", &desktopID) == 0) ; move the main window to the same desktop
				WinActivate ahk_id %guiHwnd% ; re-activate the window
		}
		ObjRelease(IVirtualDesktopManager)
	}
}