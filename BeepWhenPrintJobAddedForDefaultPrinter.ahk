#NoEnv
PRINTER_CHANGE_ADD_JOB := 0x00000100 ; FindFirstPrinterChangeNotification
INVALID_HANDLE_VALUE := -1

; MsgWaitForMultipleObjectsEx constants:
WAIT_OBJECT_0 := 0x00000000, WAIT_FAILED := INFINITE := 0xFFFFFFFF, MWMO_ALERTABLE := 0x0002, MWMO_INPUTAVAILABLE := 0x0004
QS_INPUT := (QS_MOUSE := (QS_MOUSEMOVE := 0x0002 | QS_MOUSEBUTTON := 0x0004)) | QS_KEY := 0x0001 | QS_RAWINPUT := 0x0400 ; QS_TOUCH and QS_POINTER are included on Windows 8+ AFAIK in WinUser.h
QS_ALLINPUT := QS_INPUT | QS_POSTMESSAGE := 0x0008 | QS_TIMER := 0x0010 | QS_PAINT := 0x0020 | QS_HOTKEY := 0x0080 | QS_SENDMESSAGE := 0x0040

hModWinspool := DllCall("LoadLibrary", "Str", "winspool.drv", "Ptr")

; Get default printer name
if (DllCall("winspool.drv\GetDefaultPrinter", "Ptr", 0, "UInt*", cchDefPrinter))
	ExitApp 1
VarSetCapacity(defaultPrinterName, cchDefPrinter * (A_IsUnicode + 1))
DllCall("winspool.drv\GetDefaultPrinter", "Ptr", &defaultPrinterName, "UInt*", cchDefPrinter)

if (!DllCall("winspool.drv\OpenPrinter", "Ptr", &defaultPrinterName, "Ptr*", hDefaultPrinter, "Ptr", 0))
	ExitApp 1
OnExit("cleanup")

if ((hDefaultPrinterChange := DllCall("winspool.drv\FindFirstPrinterChangeNotification", "Ptr", hDefaultPrinter, "UInt", PRINTER_CHANGE_ADD_JOB, "UInt", PRINTER_NOTIFY_CATEGORY_2D := 0x000000, "Ptr", 0, "Ptr")) == INVALID_HANDLE_VALUE)
	ExitApp 1

bKeepMonitoring := True
while (bKeepMonitoring) {
	; Bastardised from Lexikos' FileExtract
	r := DllCall("MsgWaitForMultipleObjectsEx", "UInt", 1, "Ptr*", hDefaultPrinterChange, "UInt", INFINITE, "UInt", QS_ALLINPUT, "UInt", MWMO_ALERTABLE | MWMO_INPUTAVAILABLE, "UInt"), Sleep 0
	if (!bKeepMonitoring || r == WAIT_FAILED) {
		break
	} else if (r == WAIT_OBJECT_0) {
		if ((DllCall("winspool.drv\FindNextPrinterChangeNotification", "Ptr", hDefaultPrinterChange, "UInt*", dwChange, "Ptr", 0, "Ptr", 0)) && dwChange & PRINTER_CHANGE_ADD_JOB)
			SoundBeep ; replace this for something stronger
	}
}

cleanup()
{
	global watchPrinter, hDefaultPrinter, hDefaultPrinterChange, hModWinspool, bKeepMonitoring, INVALID_HANDLE_VALUE
	;Critical On
	bKeepMonitoring := False
	;PostMessage, 0x0000,,,, ahk_id %A_ScriptHwnd%
	;Sleep -1
	if (hDefaultPrinterChange != INVALID_HANDLE_VALUE)
		DllCall("winspool.drv\FindClosePrinterChangeNotification", "Ptr", hDefaultPrinterChange), hDefaultPrinterChange := INVALID_HANDLE_VALUE
	if (hDefaultPrinter)
		DllCall("winspool.drv\ClosePrinter", "Ptr", hDefaultPrinter), hDefaultPrinter := 0
	if (hModWinspool)
		DllCall("FreeLibrary", "Ptr", hModWinspool), hModWinspool := 0
	;Critical Off
}