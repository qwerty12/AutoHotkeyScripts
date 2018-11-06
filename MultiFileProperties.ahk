#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; Shows the same thing that you get when you select more than one file and view their combined properties

; Credits: Remy Lebeau: https://stackoverflow.com/a/34551988

MultiFileProperties(filenames*) {
	static IID_IDataObject
	if (!VarSetCapacity(IID_IDataObject))
		VarSetCapacity(IID_IDataObject, 16), DllCall("ole32\CLSIDFromString", "WStr", "{0000010e-0000-0000-C000-000000000046}", "Ptr", &IID_IDataObject)

	ret := False
	if (!filenames.MaxIndex())
		return ret

    DllCall("shell32\SHGetDesktopFolder", "Ptr*", pDesktop)
    if (!pDesktop)
		return ret

	VarSetCapacity(pidl_list, filenames.MaxIndex() * A_PtrSize)
	filenameCount := 0, ParseDisplayName := NumGet(NumGet(pDesktop+0)+3*A_PtrSize)
	for _, filename in filenames
		filenameCount += DllCall(ParseDisplayName, "Ptr", pDesktop, "Ptr", 0, Ptr, 0, "WStr", filename, "Ptr", 0, "Ptr", &pidl_list+(filenameCount * A_PtrSize), "Ptr", 0) == 0

	if (filenameCount && DllCall(NumGet(NumGet(pDesktop+0)+10*A_PtrSize), "Ptr", pDesktop, "Ptr", 0, "UInt", filenameCount, "Ptr", &pidl_list, "Ptr", &IID_IDataObject, "Ptr", 0, "Ptr*", pDataObject) == 0) { ; GetUIObjectOf
		ret := DllCall("shell32\SHMultiFileProperties", "Ptr", pDataObject, "UInt", 0) == 0
		ObjRelease(pDataObject)
	}

	loop %filenameCount% {
		if ((pidl := NumGet(pidl_list, (A_Index - 1) * A_PtrSize, "Ptr")))
			DllCall("ole32\CoTaskMemFree", "Ptr", pidl)
	}
	ObjRelease(pDesktop)
	
	return ret
}

if (MultiFileProperties(A_ProgramFiles . "\Internet Explorer\iexplore.exe", A_WinDir . "\Explorer.exe", A_ScriptFullPath)) {
	MsgBox Wait for the properties window and then click OK here when done to end the script
} else {
	MsgBox Error
}