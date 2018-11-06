#NoEnv
SetBatchLines -1
ListLines Off
#NoTrayIcon	
 
TABLETMODESTATE_DESKTOPMODE := 0x0
TABLETMODESTATE_TABLETMODE := 0x1
 
TabletModeController_GetMode(TabletModeController, ByRef mode) {
	return DllCall(NumGet(NumGet(TabletModeController+0),3*A_PtrSize), "Ptr", TabletModeController, "UInt*", mode)
}
 
TabletModeController_SetMode(TabletModeController, _TABLETMODESTATE, _TMCTRIGGER := 4) {
	return DllCall(NumGet(NumGet(TabletModeController+0),4*A_PtrSize), "Ptr", TabletModeController, "UInt", _TABLETMODESTATE, "UInt", _TMCTRIGGER)	
}
 
 MsgBox This will put Windows 10 into Tablet Mode. Exit now from the tray menu if you do not want this. (You can go back from the Windows 10 settings or by running this script again.)

ImmersiveShell := ComObjCreate("{C2F03A33-21F5-47FA-B4BB-156362A2F239}", "{00000000-0000-0000-C000-000000000046}")
TabletModeController := ComObjQuery(ImmersiveShell, "{4fda780a-acd2-41f7-b4f2-ebe674c9bf2a}", "{4fda780a-acd2-41f7-b4f2-ebe674c9bf2a}")
 
if (TabletModeController_GetMode(TabletModeController, mode) == 0)
	TabletModeController_SetMode(TabletModeController, mode == TABLETMODESTATE_DESKTOPMODE ? TABLETMODESTATE_TABLETMODE : TABLETMODESTATE_DESKTOPMODE)
 
ObjRelease(TabletModeController), TabletModeController := 0
ObjRelease(ImmersiveShell), ImmersiveShell := 0 ; Can be freed after TabletModeController is created, instead	