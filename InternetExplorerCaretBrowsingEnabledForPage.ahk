#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.

; Select an Internet Explorer tab and press q while this script is running

OLECMDF_SUPPORTED := 0x1
OLECMDF_ENABLED := 0x2
OLECMDF_LATCHED := 0x4

VarSetCapacity(CGID_MSHTML, 16)
DllCall("ole32\CLSIDFromString", "WStr", "{de4ba900-59ca-11cf-9592-444553540000}", "Ptr", &CGID_MSHTML)

q::
oWB := WBGet("ahk_id " . WinExist("A"))
; https://msdn.microsoft.com/en-us/library/cc849093(v=vs.85).aspx
IOleCommandTarget := ComObjQuery(oWB.Document, "{b722bccb-4e68-101b-a2bc-00aa00404770}")
VarSetCapacity(OLECMD, 8, 0), NumPut(IDM_CARETBROWSINGMODE := 2436, OLECMD,, "UInt")
if (DllCall(NumGet(NumGet(IOleCommandTarget+0)+3*A_PtrSize), "Ptr", IOleCommandTarget, "Ptr", &CGID_MSHTML, "UInt", 1, "Ptr", &OLECMD, "Ptr", 0) >= 0)
	MsgBox % "Caret browsing active: " . (NumGet(OLECMD, 4, "UInt") & OLECMDF_LATCHED ? "True" : "False")

newSetting := -1 ; -1: toggle, False: disable, True:enable
if (newSetting == -1) {
	pVar := 0
} else {
	VarSetCapacity(VARIANT, 24, 0)
	NumPut(VT_BOOL := 11, VARIANT,, "UShort")
	NumPut(newSetting ? -1 : False, VARIANT, 8, "Short")
	pVar := &VARIANT
}
DllCall(NumGet(NumGet(IOleCommandTarget+0)+4*A_PtrSize), "Ptr", IOleCommandTarget, "Ptr", &CGID_MSHTML, "UInt", IDM_CARETBROWSINGMODE, "UInt", OLECMDEXECOPT_DONTPROMPTUSER := 2, "Ptr", pVar, "Ptr", 0)
ObjRelease(IOleCommandTarget)
oWB := ""
return

;[WBGet function for AHK v1.1]
;WBGet function - AutoHotkey Community
;https://autohotkey.com/boards/viewtopic.php?f=6&t=39869

WBGet(WinTitle="ahk_class IEFrame", Svr#=1) {               ;// based on ComObjQuery docs
   static msg := DllCall("RegisterWindowMessage", "str", "WM_HTML_GETOBJECT")
        , IID := "{0002DF05-0000-0000-C000-000000000046}"   ;// IID_IWebBrowserApp
;//     , IID := "{332C4427-26CB-11D0-B483-00C04FD90119}"   ;// IID_IHTMLWindow2
   SendMessage msg, 0, 0, Internet Explorer_Server%Svr#%, %WinTitle%
   if (ErrorLevel != "FAIL") {
      lResult:=ErrorLevel, VarSetCapacity(GUID,16,0)
      if DllCall("ole32\CLSIDFromString", "wstr","{332C4425-26CB-11D0-B483-00C04FD90119}", "ptr",&GUID) >= 0 {
         DllCall("oleacc\ObjectFromLresult", "ptr",lResult, "ptr",&GUID, "ptr",0, "ptr*",pdoc)
         return ComObj(9,ComObjQuery(pdoc,IID,IID),1), ObjRelease(pdoc)
      }
   }
}