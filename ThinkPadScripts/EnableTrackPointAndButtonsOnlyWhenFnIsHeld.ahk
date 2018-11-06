#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
AutoTrim, Off
ListLines, Off
SetBatchLines, -1
#KeyHistory 0

SP_DisableState := 0x10000171
SynAPI := ComObjCreate("SynCtrl.SynAPICtrl")
SynAPI.Initialize
SynDev := ComObjCreate("SynCtrl.SynDeviceCtrl")
SynDev.Select(SynAPI.FindDevice(SE_ConnectionAny := 0, SE_DeviceIBMCompatibleStick := 4, 0))
OnExit("AtExit")
SynDev.SetLongProperty(SP_DisableState, True) ; force TrackPoint to be disabled at startup of script
return

SC163::
SynDev.SetLongProperty(SP_DisableState, False) ; enable device when Fn pressed
return

SC163 up:: ; Replace 159 with your key's value.
SynDev.SetLongProperty(SP_DisableState, True) ; disable device when Fn key released
return

Esc::ExitApp

AtExit() {
	global SynDev, SP_DisableState
	SynDev.SetLongProperty(SP_DisableState, False) ; re-enable TP at exit of script
}