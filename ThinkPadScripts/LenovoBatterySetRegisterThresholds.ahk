#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
AutoTrim, Off
ListLines, Off
SetBatchLines, -1
SetFormat, FloatFast, 0.6
SetFormat, IntegerFast, D
#KeyHistory 0

; adapted from heresy's lib
Service_Start(ServiceName)
{
    if (!A_IsAdmin)
        return true
    result := false

    SCM_HANDLE := DllCall("advapi32\OpenSCManager", "Ptr", 0, "Ptr", 0, "UInt", 0x1, "Ptr")
    if (SCM_HANDLE) {
        if (SC_HANDLE := DllCall("advapi32\OpenService", "Ptr", SCM_HANDLE, "Str", ServiceName, "UInt", 0x10, "Ptr")) {
            result := DllCall("advapi32\StartService", "Ptr", SC_HANDLE , "UInt", 0, "Ptr", 0)
            DllCall("advapi32\CloseServiceHandle", "Ptr", SC_HANDLE)
        }
        DllCall("advapi32\CloseServiceHandle", "Ptr", SCM_HANDLE)
        if (!SC_HANDLE) ; Service not found
            ErrorLevel := -4
    }
    if (result)
        ErrorLevel := 0
    return result
}

; all credits to XYUU
WatchLenovoBatteryKey_SetRegisterThresholds(bId, start, stop)
{
    ; yes, this is ugly, but w/e - I'm not a programmer :-)
    start := ((start >= 1 && start <= 100)) ? start - 1 : (start == 0 ? start : -1)
    stop := ((stop >= 0 && start <= 100)) ? (stop == 100 ? 0x00 : stop) : -1

    if (start != -1 || stop != -1)
    {
        INVALID_HANDLE_VALUE := -1
        GENERIC_READ         := 0x80000000 ;, GENERIC_WRITE := 0x40000000
        FILE_SHARE_READ      := 0x00000001 ;, FILE_SHARE_WRITE := 0x00000002

        Service_Start("IBMPMDRV") ; make sure the IBM Power Management driver is running
        IBMPmDrv := DllCall("CreateFile", "Str", "\\.\IBMPmDrv", "UInt", GENERIC_READ, "UInt", FILE_SHARE_READ, "Ptr", 0, "UInt", OPEN_EXISTING := 3, "UInt", 0, "Ptr", 0, "Ptr")
        if (IBMPmDrv && IBMPmDrv != INVALID_HANDLE_VALUE)
        {
            currStartValue := currStopValue := 0x00

            ; get the current threshold values 
            for i, ioctl in [GET_BATTERY_THRESH_START := 0x22262C, GET_BATTERY_THRESH_STOP := 0x222634]
            {
                VarSetCapacity(GET_BATTERY_THRESH_IN, reqBufSzGetIn := 4, 0), VarSetCapacity(GET_BATTERY_THRESH_OUT, reqBufSzGetOut := 4, 0)
                NumPut(bId, GET_BATTERY_THRESH_IN,, "UChar")
                if ((DllCall("DeviceIoControl", "Ptr", IBMPmDrv, "UInt", ioctl, "Ptr", &GET_BATTERY_THRESH_IN, "UInt", reqBufSzGetIn, "Ptr", &GET_BATTERY_THRESH_OUT, "UInt", reqBufSzGetOut, "UInt*", actualOutSz, "Ptr", 0)) && actualOutSz == reqBufSzGetOut) {
                    if (ioctl == GET_BATTERY_THRESH_START)
                        currStartValue := NumGet(GET_BATTERY_THRESH_OUT,, "UChar")
                    else if (ioctl == GET_BATTERY_THRESH_STOP)
                        currStopValue := NumGet(GET_BATTERY_THRESH_OUT,, "UChar")
                }
            }

            ; set the new thresholds if they're different
            for i, ioctl in [SET_BATTERY_THRESH_START := 0x222630, SET_BATTERY_THRESH_STOP := 0x222638]
            {
                val := -1
                if (ioctl == SET_BATTERY_THRESH_START)
                {
                    if (start != currStartValue)
                        val := start
                }
                else if (ioctl == SET_BATTERY_THRESH_STOP)
                {
                    if (stop != currStopValue)
                        val := stop
                }

                if (val > -1)
                {
                    VarSetCapacity(SET_BATTERY_THRESH_IN, reqBufSz := 4, 0)
                    NumPut(val, SET_BATTERY_THRESH_IN,, "UChar"), NumPut(bId, SET_BATTERY_THRESH_IN, 1, "UChar")
                    DllCall("DeviceIoControl", "Ptr", IBMPmDrv, "UInt", ioctl, "Ptr", &SET_BATTERY_THRESH_IN, "UInt", reqBufSz, "Ptr", 0, "UInt", 0, "Ptr", 0, "Ptr", 0)
                }
            }

            DllCall("CloseHandle", "Ptr", IBMPmDrv)
        }
    }
}

MsgBox This will set your battery charging thresholds to start at 20`% and to stop at 90`%. Exit now from the tray menu if you do not want this.

WatchLenovoBatteryKey_SetRegisterThresholds(0x01, 20, 90) ; DEFAULT_BATTERY_ID == 0x01, see https://github.com/teleshoes/tpacpi-bat/blob/master/battery_asl#L200
