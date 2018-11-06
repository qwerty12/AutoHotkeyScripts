#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#SingleInstance Off

Process, Exist, wmplayer.exe
if (!ErrorLevel) {
	MsgBox Run Windows Media Player first. Exiting
	ExitApp
}

wmp := ComObjCreate("WMPlayer.OCX")

rms := IWMPRemoteMediaServices_CreateInstance()
ocs := ComObjQuery(rms, "{00000118-0000-0000-C000-000000000046}")

ole := ComObjQuery(wmp, "{00000112-0000-0000-C000-000000000046}")
DllCall(NumGet(NumGet(ole+0)+3*A_PtrSize), "Ptr", ole, "Ptr", ocs)

states := {0: "Undefined", 1: "Stopped", 2: "Paused", 3: "Playing"}
state := states[wmp.playState]

DllCall(NumGet(NumGet(ole+0)+3*A_PtrSize), "Ptr", ole, "Ptr", 0)
for _, obj in [ole, ocs, rms]
	ObjRelease(obj)
wmp := ""

MsgBox %state%

; ---

IWMPRemoteMediaServices_CreateInstance()
{
	global IWMPRemoteMediaServices_size := ((A_PtrSize + 4) * 4) + 4
	static vtblUnk, vtblRms, vtblIsp, vtblOls
		 , vtblPtrs := 0

	if (!VarSetCapacity(vtblUnk)) {
		extfuncs := ["QueryInterface", "AddRef", "Release"]

		VarSetCapacity(vtblUnk, extfuncs.Length() * A_PtrSize)

		for i, name in extfuncs
			NumPut(RegisterCallback("IUnknown_" . name), vtblUnk, (i-1) * A_PtrSize)
	}
	if (!VarSetCapacity(vtblRms)) {
		extfuncs := ["GetServiceType", "GetApplicationName", "GetScriptableObject", "GetCustomUIMode"]

		VarSetCapacity(vtblRms, (3 + extfuncs.Length()) * A_PtrSize)
		DllCall("ntdll\RtlMoveMemory", "Ptr", &vtblRms, "Ptr", &vtblUnk, "Ptr", A_PtrSize * 3)

		for i, name in extfuncs
			NumPut(RegisterCallback("IWMPRemoteMediaServices_" . name, "Fast"), vtblRms, (2+i) * A_PtrSize)
	}
	if (!VarSetCapacity(vtblIsp)) {
		VarSetCapacity(vtblIsp, 4 * A_PtrSize)
		DllCall("ntdll\RtlMoveMemory", "Ptr", &vtblIsp, "Ptr", &vtblUnk, "Ptr", A_PtrSize * 3)
		NumPut(RegisterCallback("IServiceProvider_QueryService", "Fast"), vtblIsp, A_PtrSize * 3)
	}
	if (!VarSetCapacity(vtblOls)) {
		extfuncs := ["SaveObject", "GetMoniker", "GetContainer", "ShowObject", "OnShowWindow", "RequestNewObjectLayout"]
		VarSetCapacity(vtblOls, (3 + extfuncs.Length()) * A_PtrSize)
		DllCall("ntdll\RtlMoveMemory", "Ptr", &vtblOls, "Ptr", &vtblUnk, "Ptr", A_PtrSize * 3)

		for i, name in extfuncs
			NumPut(RegisterCallback("IOleClientSite_" . name, "Fast"), vtblOls, (2+i) * A_PtrSize)
	}
	if (!vtblPtrs)
		vtblPtrs := [&vtblUnk, &vtblRms, &vtblIsp, &vtblOls]

	pObj := DllCall("GlobalAlloc", "UInt", 0x0000, "Ptr", IWMPRemoteMediaServices_size, "Ptr")
	for i, ptr in vtblPtrs {
		off := (A_PtrSize * (i - 1)) + (4 * (i - 1))
		NumPut(ptr, pObj+0, off, "Ptr")
		NumPut(off, pObj+0, off + A_PtrSize, "UInt")
	}
	NumPut(1, pObj+0, IWMPRemoteMediaServices_size - 4, "UInt")

	return pObj
}

IUnknown_QueryInterface(this_, riid, ppvObject)
{
	static IID_IUnknown, IID_IWMPRemoteMediaServices, IID_IServiceProvider, IID_IOleClientSite
	if (!VarSetCapacity(IID_IUnknown))
		VarSetCapacity(IID_IUnknown, 16), VarSetCapacity(IID_IWMPRemoteMediaServices, 16), VarSetCapacity(IID_IServiceProvider, 16), VarSetCapacity(IID_IOleClientSite, 16)
		,DllCall("ole32\CLSIDFromString", "WStr", "{00000000-0000-0000-C000-000000000046}", "Ptr", &IID_IUnknown)
		,DllCall("ole32\CLSIDFromString", "WStr", "{CBB92747-741F-44FE-AB5B-F1A48F3B2A59}", "Ptr", &IID_IWMPRemoteMediaServices)
		,DllCall("ole32\CLSIDFromString", "WStr", "{6d5140c1-7436-11ce-8034-00aa006009fa}", "Ptr", &IID_IServiceProvider)
		,DllCall("ole32\CLSIDFromString", "WStr", "{00000118-0000-0000-C000-000000000046}", "Ptr", &IID_IOleClientSite)

	if (DllCall("ole32\IsEqualGUID", "Ptr", riid, "Ptr", &IID_IUnknown)) {
		off := NumGet(this_+0, A_PtrSize, "UInt")
		NumPut(this_ - off, ppvObject+0, "Ptr")
		IUnknown_AddRef(this_)
		return 0 ; S_OK
	}

	if (DllCall("ole32\IsEqualGUID", "Ptr", riid, "Ptr", &IID_IWMPRemoteMediaServices)) {
		off := NumGet(this_+0, A_PtrSize, "UInt")
		NumPut((this_ - off)+(A_PtrSize + 4), ppvObject+0, "Ptr")
		IUnknown_AddRef(this_)
		return 0 ; S_OK
	}

	if (DllCall("ole32\IsEqualGUID", "Ptr", riid, "Ptr", &IID_IServiceProvider)) {
		off := NumGet(this_+0, A_PtrSize, "UInt")
		NumPut((this_ - off)+((A_PtrSize + 4) * 2), ppvObject+0, "Ptr")
		IUnknown_AddRef(this_)
		return 0 ; S_OK
	}

	if (DllCall("ole32\IsEqualGUID", "Ptr", riid, "Ptr", &IID_IOleClientSite)) {
		off := NumGet(this_+0, A_PtrSize, "UInt")
		NumPut((this_ - off)+((A_PtrSize + 4) * 3), ppvObject+0, "Ptr")
		IUnknown_AddRef(this_)
		return 0 ; S_OK
	}

	NumPut(0, ppvObject+0, "Ptr")
	return 0x80004002 ; E_NOINTERFACE
}

IUnknown_AddRef(this_)
{
	global IWMPRemoteMediaServices_size
	off := NumGet(this_+0, A_PtrSize, "UInt")
	iunk := this_-off
	NumPut((_refCount := NumGet(iunk+0, IWMPRemoteMediaServices_size - 4, "UInt") + 1), iunk+0, IWMPRemoteMediaServices_size - 4, "UInt")
	return _refCount
}

IUnknown_Release(this_) {
	global IWMPRemoteMediaServices_size
	off := NumGet(this_+0, A_PtrSize, "UInt")
	iunk := this_-off
	_refCount := NumGet(iunk+0, IWMPRemoteMediaServices_size - 4, "UInt")
	if (_refCount > 0) {
		NumPut(--_refCount, iunk+0, IWMPRemoteMediaServices_size - 4, "UInt")
		if (_refCount == 0)
			DllCall("GlobalFree", "Ptr", iunk, "Ptr")
	}
	return _refCount
}

IWMPRemoteMediaServices_GetServiceType(this_, pbstrType)
{
	NumPut(DllCall("oleaut32\SysAllocString", "WStr", "Remote", "Ptr"), pbstrType+0, "Ptr")
	return 0
}

IWMPRemoteMediaServices_GetApplicationName(this_, pbstrName)
{
	NumPut(DllCall("oleaut32\SysAllocString", "WStr", "qwerty12's long-ass AHK script for something that should've been simple: the case for using foobar2000", "Ptr"), pbstrName+0, "Ptr")
	return 0
}

IWMPRemoteMediaServices_GetScriptableObject(this_, pbstrName, ppDispatch)
{
	return 0x80004001
}
IWMPRemoteMediaServices_GetCustomUIMode(this_, pbstrFile)
{
	return 0x80004001
}

IServiceProvider_QueryService(this_, guidService, riid, ppvObject)
{
	return IUnknown_QueryInterface(this_, riid, ppvObject)
}

IOleClientSite_SaveObject(this_)
{
	return 0x80004001
}

IOleClientSite_GetMoniker(this_, dwAssign, dwWhichMoniker, ppmk)
{
	return 0x80004001
}

IOleClientSite_GetContainer(this_, ppContainer)
{
	NumGet(0, ppContainer+0, "Ptr")
	return 0x80004002
}

IOleClientSite_ShowObject(this_)
{
	return 0x80004001
}

IOleClientSite_OnShowWindow(this_, fShow)
{
	return 0x80004001
}

IOleClientSite_RequestNewObjectLayout(this_)
{
	return 0x80004001
}