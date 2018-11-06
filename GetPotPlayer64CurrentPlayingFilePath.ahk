#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.

; Play a file in PotPlayer and press q at the window
; Credits:
; * The Old New Thing & Lexikos for the MsgWaitForMultipleObjectsEx code
; * http://cafe.daum.net/pot-tool/N88T/65 for providing an English version of the SDK

class PotPlayerCurrentFile
{
	static _WM_COPYDATA := 0x004A, _POT_COMMAND := _WM_USER := 0x0400, _POT_GET_PLAYFILE_NAME := 0x6020

	GetFullPath(hwnd, dwTimeout)
	{
		static MsgWaitForMultipleObjectsEx := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32.dll", "Ptr"), "AStr", "MsgWaitForMultipleObjectsEx", "Ptr")
		fn := ""

		WinGetClass, clazz, ahk_id %hwnd%
		if (InStr(clazz, "PotPlayer")) {
			r := 0xFFFFFFFF
			,this.hEvent := DllCall("CreateEvent", "Ptr", 0, "Int", True, "Int", False, "Ptr", 0, "Ptr")
			,this.potPlayerHwnd := hwnd
			,this.cdReceiver := ObjBindMethod(this, "_On_WM_COPYDATA")
			,OnMessage(this._WM_COPYDATA, this.cdReceiver, -1)
			
			if (this._MessagePotPlayer(dwTimeout)) {
				dwStart := A_TickCount
				while ((dwElapsed := A_TickCount - dwStart) < dwTimeout) {
					r := DllCall(MsgWaitForMultipleObjectsEx, "UInt", 1, "Ptr*", this.hEvent, "UInt", dwTimeout - dwElapsed, "UInt", 0x4FF, "UInt", 0x4, "UInt")
					if (r == 0 || r == 0xFFFFFFFF || r == 258)
						break
					Sleep -1
				}
				;OutputDebug % A_ThisFunc . ": " . (A_TickCount - dwStart) . " milliseconds have elapsed"
			}

			OnMessage(this._WM_COPYDATA, this.cdReceiver, 0) ,this.cdReceiver := ""
			,DllCall("CloseHandle", "Ptr", this.hEvent), this.hEvent := 0
			if (r == 0)
				fn := this.PotPlayerFilename
		}

		this := ""
		return fn
	}

	_MessagePotPlayer(ByRef Timeout := 5000)
	{
		Critical On
		;dwStart := A_TickCount
		PostMessage, % this._POT_COMMAND, % this._POT_GET_PLAYFILE_NAME, %A_ScriptHwnd%,, % "ahk_id " . this.potPlayerHwnd,,,, %Timeout%
		;Timeout -= A_TickCount - dwStart
		ret := ErrorLevel == 0
		Critical Off
		return ret
	}

	_On_WM_COPYDATA(wParam, lParam, msg, hwnd)
	{
		if (lParam && hwnd == A_ScriptHwnd && wParam == this.potPlayerHwnd && NumGet(lParam+0,, "UPtr") == this._POT_GET_PLAYFILE_NAME) {
			StringLength := NumGet(lParam+0, A_PtrSize, "UInt")
			,StringAddress := NumGet(lParam+0, 2*A_PtrSize, "Ptr")
			,this.PotPlayerFilename := StrGet(StringAddress, StringLength, "UTF-8")
			,DllCall("SetEvent", "Ptr", this.hEvent)
			return True
		}
		return False
	}
}

PotPlayer64_GetCurrentFilePath(hwnd, replyTimeout := 1100)
{
	return PotPlayerCurrentFile.GetFullPath(hwnd, replyTimeout)
}

#If ((hwnd := WinActive("ahk_class PotPlayer64")))
q::MsgBox % PotPlayer64_GetCurrentFilePath(hwnd)
#If