#NoTrayIcon
#NoEnv
Process, Priority, , A
#SingleInstance Off
NERR_Success := 0

if (!A_IsAdmin)
	ExitApp

; This is the equivalent of "net share 1=C:\1 /GRANT:%USERNAME%,READ /GRANT:%USERNAME%,CHANGE /USERS:2 /CACHE:None"

userName := A_UserName
shi502_netname := "1"
shi502_path := "C:\1"

if (DllCall("Netapi32\NetShareCheck", "Ptr", 0, "WStr", shi502_netname, "UInt*", 0) == NERR_Success) ; if this succeeds, it means the folder is already shared
	ExitApp

CSC_MASK_EXT := 0x2030, CSC_CACHE_NONE := 0x0030
SECURITY_DESCRIPTOR_REVISION := 1, ACL_REVISION := 2
ACCESS_READ := 0x01, ACCESS_WRITE := 0x02, ACCESS_CREATE := 0x04, ACCESS_EXEC := 0x08, ACCESS_DELETE := 0x10, ACCESS_ATRIB := 0x20
; thanks to ctusch: https://stackoverflow.com/a/17236838
FILE_READ_DATA := FILE_LIST_DIRECTORY := 0x1
FILE_EXECUTE := FILE_TRAVERSE := 0x20
FILE_WRITE_DATA := FILE_ADD_FILE := 0x2
FILE_APPEND_DATA := FILE_ADD_SUBDIRECTORY := 0x4
SHARE_READ := FILE_LIST_DIRECTORY | FILE_READ_EA := 0x8 | FILE_TRAVERSE | FILE_READ_ATTRIBUTES := 0x80 | READ_CONTROL := 0x20000 | SYNCHRONIZE := 0x100000
SHARE_CHANGE := FILE_ADD_FILE | FILE_ADD_SUBDIRECTORY | FILE_WRITE_EA := 0x10 | FILE_WRITE_ATTRIBUTES := 0x100 | DELETE := 0x10000
SHARE_FULLCONTROL := FILE_DELETE_CHILD := 0x40 | WRITE_DAC := 0x40000 | WRITE_OWNER := 0x80000

; prepare SD with a DACL containing one ACE: your user gets Read and Change access to the share
VarSetCapacity(SecurityDescriptor, 40, 0)
if (!DllCall("advapi32\InitializeSecurityDescriptor", "Ptr", &SecurityDescriptor, "UInt", SECURITY_DESCRIPTOR_REVISION))
	ExitApp
cbAcl := 8 + (12 * 1) ; sizeof(ACL) + ((sizeof(ACCESS_ALLOWED_ACE)) * NUM_OF_ACES)
DllCall("sechost\LookupAccountNameLocalW", "WStr", userName, "Ptr", 0, "UInt*", cbSid := 0, "Ptr", 0, "UInt*", cbDomain := 0, "UInt*", 0)
if (A_LastError != 122)
	ExitApp
VarSetCapacity(Sid, cbSid, 0), VarSetCapacity(domain, cbDomain)
if (!DllCall("sechost\LookupAccountNameLocalW", "WStr", userName, "Ptr", &Sid, "UInt*", cbSid, "Ptr", &domain, "UInt*", cbDomain, "UInt*", 0))
	ExitApp
cbAcl += cbSid - 4 ; for (int i = 0; i < NUM_OF_ACES; i++) cbAcl += GetLengthSid(psids[i]) - sizeof(DWORD); // aka: - sizeof(ACE->SidStart)
cbAcl := (cbAcl + (4 - 1)) & 0xfffffffc ; Align cbAcl to a DWORD
if (VarSetCapacity(Acl, cbAcl, 0) != cbAcl)
	ExitApp
if (!DllCall("advapi32\InitializeAcl", "Ptr", &Acl, "UInt", cbAcl, "UInt", ACL_REVISION))
	ExitApp
if (!DllCall("advapi32\AddAccessAllowedAce", "Ptr", &Acl, "UInt", ACL_REVISION, "UInt", SHARE_READ | SHARE_CHANGE, "Ptr", &Sid))
	ExitApp
if (!DllCall("advapi32\SetSecurityDescriptorDacl", "Ptr", &SecurityDescriptor, "Int", True, "Ptr", &Acl, "Int", False))
	ExitApp

; prepare SHARE_INFO_502 struct
VarSetCapacity(SHARE_INFO_502, 72, 0)
NumPut(&shi502_netname, SHARE_INFO_502, 0, "Ptr")
NumPut((shi502_permissions := ACCESS_READ | ACCESS_WRITE | ACCESS_CREATE | ACCESS_EXEC | ACCESS_DELETE | ACCESS_ATRIB), SHARE_INFO_502, 24, "UInt")
NumPut((shi502_max_uses := 2), SHARE_INFO_502, 28, "UInt")
NumPut(&shi502_path, SHARE_INFO_502, 40, "Ptr")
NumPut(&(shi502_passwd := ""), SHARE_INFO_502, 48, "Ptr")
NumPut(&SecurityDescriptor, SHARE_INFO_502, 64, "Ptr")

if (DllCall("Netapi32\NetShareAdd", "Ptr", 0, "UInt", 502, "Ptr", &SHARE_INFO_502, "Ptr", 0, "UInt") == NERR_Success) {
	; disable caching
	if (DllCall("Netapi32\NetShareGetInfo", "Ptr", 0, "WStr", shi502_netname, "UInt", 1005, "Ptr*", SHARE_INFO_1005, "UInt") == NERR_Success) {
		NumPut((shi1005_flags := (NumGet(SHARE_INFO_1005+0,, "UInt") & ~CSC_MASK_EXT) | CSC_CACHE_NONE), SHARE_INFO_1005+0,, "UInt")
		DllCall("Netapi32\NetShareSetInfo", "Ptr", 0, "WStr", shi502_netname, "UInt", 1005, "Ptr", SHARE_INFO_1005, "Ptr", 0, "UInt")
		DllCall("Netapi32\NetApiBufferFree", "Ptr", SHARE_INFO_1005)
	}
}