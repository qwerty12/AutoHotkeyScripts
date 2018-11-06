#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.

; DllCall("ole32.dll\OleUninitialize")
; DllCall("combase.dll\RoInitialize", "UInt", RO_INIT_MULTITHREADED := 1)

filename := "C:\Users\Me\Pictures\Wallpapers\affinity_street_romain_trystram_01.jpg"

if (FileExist(filename)) {
	; 1. Create StorageFile obj for pic
	VarSetCapacity(IIDStorageFileStatics, 16), VA_GUID(IIDStorageFileStatics := "{5984C710-DAF2-43C8-8BB4-A4D3EACFD03F}")
	StorageFile := new HSTRING("Windows.Storage.StorageFile")
	if (!DllCall("combase.dll\RoGetActivationFactory", "Ptr", StorageFile.str, "Ptr", &IIDStorageFileStatics, "Ptr*", instStorageFile)) {
		if (!DllCall(NumGet(NumGet(instStorageFile+0)+6*A_PtrSize), "Ptr", instStorageFile, "Ptr", (_ := new HSTRING(filename)).str, "Ptr*", sfileasyncwrapper)) {
			; 2. Said SF obj gets created async. Keep checking (in a sync manner) to see if actual SF obj is created
			; Yes, this isn't a good way, but it's not like I usually expect COM objects to be returned async
			sfileasyncinfo := ComObjQuery(sfileasyncwrapper, IID_IAsyncInfo := "{00000036-0000-0000-C000-000000000046}")
			while (!DllCall(NumGet(NumGet(sfileasyncinfo+0)+7*A_PtrSize), "Ptr", sfileasyncinfo, "UInt*", status) && !status)
				Sleep 100
			if (status != 1)
				ExitApp 1
			ObjRelease(sfileasyncinfo)

			; 3. It has! Finally take pointer to sf obj
			DllCall(NumGet(NumGet(sfileasyncwrapper+0)+8*A_PtrSize), "Ptr", sfileasyncwrapper, "Ptr*", sfile)
			
			; 4. Create LockScreen obj
			VarSetCapacity(IIDLockScreenStatics, 16), VA_GUID(IIDLockScreenStatics := "{3EE9D3AD-B607-40AE-B426-7631D9821269}")
			lockScreen := new HSTRING("Windows.System.UserProfile.LockScreen")
			if (!DllCall("combase.dll\RoGetActivationFactory", "Ptr", lockScreen.str, "Ptr", &IIDLockScreenStatics, "Ptr*", instLockScreen)) {
				; Tell ls obj to set ls pic from sf obj
				DllCall(NumGet(NumGet(instLockScreen+0)+8*A_PtrSize), "Ptr", instLockScreen, "Ptr", sfile, "Ptr*", Operation)

				sfileasyncinfo := ComObjQuery(Operation, IID_IAsyncInfo := "{00000036-0000-0000-C000-000000000046}")
				while (!DllCall(NumGet(NumGet(sfileasyncinfo+0)+7*A_PtrSize), "Ptr", sfileasyncinfo, "UInt*", status) && !status)
					Sleep 100
				ObjRelease(sfileasyncinfo)

				ObjRelease(Operation)
				ObjRelease(instLockScreen)
			}
			
			ObjRelease(sfile)
			ObjRelease(sfileasyncwrapper)
		}
		ObjRelease(instStorageFile)
	}
}

class HSTRING {
	static lpWindowsCreateString := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "combase.dll", "Ptr"), "AStr", "WindowsCreateString", "Ptr")
	static lpWindowsDeleteString := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "combase.dll", "Ptr"), "AStr", "WindowsDeleteString", "Ptr")

	__New(sourceString, length := 0) {
		this.str := !DllCall(HSTRING.lpWindowsCreateString, "WStr", sourceString, "UInt", length ? length : StrLen(sourceString), "Ptr*", string) ? string : 0
	}

	__Delete() {
		DllCall(HSTRING.lpWindowsDeleteString, "Ptr", this.str)
	}
}

; From Lexikos' VA.ahk: Convert string to binary GUID structure.
VA_GUID(ByRef guid_out, guid_in="%guid_out%") {
    if (guid_in == "%guid_out%")
        guid_in :=   guid_out
    if  guid_in is integer
        return guid_in
    VarSetCapacity(guid_out, 16, 0)
	DllCall("ole32\CLSIDFromString", "wstr", guid_in, "ptr", &guid_out)
	return &guid_out
}