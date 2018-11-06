SetRestrictedProcessDacl()
{
	ret := False

	hCurProc := DllCall("GetCurrentProcess", "Ptr")
	if (!DllCall("advapi32\OpenProcessToken", "Ptr", hCurProc, "UInt", TOKEN_QUERY := 0x0008, "Ptr*", hToken))
		return ret

	if (!_GetTokenInformation(hToken, TokenUser := 1, 0, 0, dwLengthNeeded))
		if (A_LastError == 122 && VarSetCapacity(TOKEN_USER, dwLengthNeeded)) ; ERROR_INSUFFICIENT_BUFFER
			if (_GetTokenInformation(hToken, TokenUser, &TOKEN_USER, dwLengthNeeded, dwLengthNeeded)) {
				SECURITY_MAX_SID_SIZE := 68
				SIDs := {"WinWorldSid": "1", "WinLocalSystemSid": "22", "WinBuiltinAdministratorsSid": "26"}
				for k, v in SIDs {
					SIDs.SetCapacity(k, (cbSid := SECURITY_MAX_SID_SIZE))
					if (!DllCall("advapi32\CreateWellKnownSid", "UInt", v+0, "Ptr", 0, "Ptr", SIDs.GetAddress(k), "UInt*", cbSid)) {
						DllCall("CloseHandle", "Ptr", hToken)
						return ret
					}
				}

				EA := [{ "grfAccessPermissions": PROCESS_ALL_ACCESS := (STANDARD_RIGHTS_REQUIRED := 0x000F0000) | (SYNCHRONIZE := 0x00100000) | 0xFFFF ; 0xFFF for XP and 2000
						,"grfAccessMode":        GRANT_ACCESS := 1
						,"grfInheritance":       NO_INHERITANCE := 0
						,"TrusteeForm":          TRUSTEE_IS_SID := 0
						,"TrusteeType":          TRUSTEE_IS_WELL_KNOWN_GROUP := 5
						,"ptstrName":            SIDs.GetAddress("WinLocalSystemSid")}
					  ,{ "grfAccessPermissions": PROCESS_ALL_ACCESS
						,"grfAccessMode":        GRANT_ACCESS
						,"grfInheritance":       NO_INHERITANCE
						,"TrusteeForm":          TRUSTEE_IS_SID
						,"TrusteeType":          TRUSTEE_IS_WELL_KNOWN_GROUP
						,"ptstrName":            SIDs.GetAddress("WinBuiltinAdministratorsSid")}
					  ,{ "grfAccessPermissions": PROCESS_QUERY_LIMITED_INFORMATION := 0x1000 | PROCESS_CREATE_PROCESS := 0x0080
						,"grfAccessMode":        GRANT_ACCESS
						,"grfInheritance":       NO_INHERITANCE
						,"TrusteeForm":          TRUSTEE_IS_SID
						,"TrusteeType":          TRUSTEE_IS_USER := 1
						,"ptstrName":            NumGet(TOKEN_USER,, "Ptr")} ; user script is running under
					  ,{ "grfAccessPermissions": PROCESS_ALL_ACCESS
						,"grfAccessMode":        DENY_ACCESS := 3
						,"grfInheritance":       NO_INHERITANCE
						,"TrusteeForm":          TRUSTEE_IS_SID
						,"TrusteeType":          TRUSTEE_IS_WELL_KNOWN_GROUP
						,"ptstrName":            SIDs.GetAddress("WinWorldSid")}]

				padding := A_PtrSize == 8 ? 4 : 0
				cbEXPLICIT_ACCESS_W := (4 * 3) + padding + (A_PtrSize + (4 * 3) + padding + A_PtrSize)
				VarSetCapacity(EXPLICIT_ACCESS_W, cbEXPLICIT_ACCESS_W * EA.MaxIndex(), 0)
				for i, v in EA {
					thisEA := cbEXPLICIT_ACCESS_W * (i - 1)
					NumPut(v.grfAccessPermissions, EXPLICIT_ACCESS_W, thisEA, "UInt")
					NumPut(v.grfAccessMode, EXPLICIT_ACCESS_W, thisEA + 4, "UInt")
					NumPut(v.grfInheritance, EXPLICIT_ACCESS_W, thisEA + (4 * 2), "UInt")
					NumPut(v.TrusteeForm, EXPLICIT_ACCESS_W, thisEA + ((4 * 3) + padding + A_PtrSize + 4), "UInt")
					NumPut(v.TrusteeType, EXPLICIT_ACCESS_W, thisEA + ((4 * 3) + padding + A_PtrSize + (4 * 2)), "UInt")
					NumPut(v.ptstrName, EXPLICIT_ACCESS_W, thisEA + ((4 * 3) + padding + A_PtrSize + (4 * 3) + padding), "Ptr")				
				}
						
				if (!DllCall("advapi32\SetEntriesInAcl", "UInt", EA.MaxIndex(), "Ptr", &EXPLICIT_ACCESS_W, "Ptr", 0, "Ptr*", pNewDacl)) {
					ret := !DllCall("Advapi32\SetSecurityInfo", "Ptr", hCurProc, "UInt", SE_KERNEL_OBJECT := 6, "UInt", DACL_SECURITY_INFORMATION := 0x00000004, "Ptr", 0, "Ptr", 0, "Ptr", pNewDacl, "Ptr", 0)
					DllCall("LocalFree", "Ptr", pNewDacl, "Ptr")
				}
			}
	
	DllCall("CloseHandle", "Ptr", hToken)
	return ret
}

_GetTokenInformation(TokenHandle, TokenInformationClass, ByRef TokenInformation, TokenInformationLength, ByRef ReturnLength, _tokenInfoType := "Ptr") {
	return DllCall("advapi32\GetTokenInformation", "Ptr", TokenHandle, "UInt", TokenInformationClass, _tokenInfoType, TokenInformation, "UInt", TokenInformationLength, "UInt*", ReturnLength)
}