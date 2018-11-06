try if ((BhoAbp := ComObjCreate("{FFCB3198-32F3-4E8B-9539-4324694ED664}", "{FC4801A3-2BA9-11CF-A229-00AA003D7352}"))) {
	DllCall(NumGet(NumGet(BhoAbp+0)+3*A_PtrSize), "Ptr", BhoAbp, "Ptr", wb)
}
...
if (BhoAbp) {
	; When it's time to release the your ActiveX WebBrowser object:
	DllCall(NumGet(NumGet(BhoAbp+0)+3*A_PtrSize), "Ptr", BhoAbp, "Ptr", 0)
	ObjRelease(BhoAbp)
}