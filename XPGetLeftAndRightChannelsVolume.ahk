#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.

WaveOutIDOfPreferredDevice := mixerID := 0
if (DllCall("winmm\waveOutMessage", "Ptr", WAVE_MAPPER := -1, "UInt", DRVM_MAPPER_PREFERRED_GET := 0x2015, "UInt*", WaveOutIDOfPreferredDevice, "UInt*", Status, "UInt") == 0
	&& DllCall("winmm\mixerGetID", "Ptr", WaveOutIDOfPreferredDevice, "UInt*", mixerID, "UInt", MIXER_OBJECTF_WAVEOUT := 0x10000000, "UInt") == 0
	&& FindDevIDs(mixerID, volID, finalDestination)) {
		if (DllCall("winmm\mixerOpen", "Ptr*", hmx, "UInt", mixerID, "UInt", 0, "UInt", 0, "UInt", MIXER_OBJECTF_WAVEOUT, "UInt") == 0) {
			VarSetcapacity(mxl, 280, 0)
			NumPut(280, mxl,, "UInt")
			NumPut(finalDestination, mxl, 4, "UInt")
			if (DllCall("winmm\mixerGetLineInfo", "Ptr", hmx, "Ptr", &mxl, "UInt", 0, "UInt") == 0) {
				channels := NumGet(mxl, 28, "UInt")
				VarSetcapacity(mcd, 24, 0)
				VarSetcapacity(m, 4 * channels, 0)
				NumPut(24, mcd,, "UInt")
				NumPut(volID, mcd, 4, "UInt")
				NumPut(channels, mcd, 8, "UInt")
				NumPut(4, mcd, 16, "UInt")
				NumPut(&m, mcd, 20, "Ptr")
				if (DllCall("winmm\mixerGetControlDetailsW", "Ptr", hmx, "Ptr", &mcd, "UInt", 0, "UInt") == 0) {
					Loop % channels
						MsgBox % Round((NumGet(m, 4 * (A_Index - 1), "UInt") / 0xFFFF) * 100)
				}
			}
			DllCall("winmm\mixerClose", "Ptr", hmx)
		}
}

FindDevIDs(mixerID, ByRef volID, ByRef finalDestination)
{
	VarSetcapacity(mxcapsw, (cbmxcaps := 80))
	ret := False

	if (DllCall("winmm\mixerGetDevCapsW", "UInt", mixerID, "Ptr", &mxcapsw, "UInt", cbmxcaps) == 0) {
		if ((destinations := NumGet(mxcapsw, cbmxcaps - 4, "UInt")) > 0) {
			VarSetcapacity(mxl, (cbmxl := 280))
			dest := 0
			while (!ret && dest < destinations) {		
				NumPut(cbmxl, mxl,, "UInt")
				NumPut(dest, mxl, 4, "UInt")
				if (DllCall("winmm\mixerGetLineInfoW", "Ptr", mixerID, "Ptr", &mxl, "UInt", 0, "UInt") == 0) {
					componentType := NumGet(mxl, 24, "UInt")
					if (componentType == 4 || componentType == 5 || componentType == 4104) { ; speakers, headphones & wave out 
						if ((controls := NumGet(mxl, 36, "UInt")) && !ret) { ; controls present
							finalDestination := dest
							control := 0
							cbmc := 228
							VarSetcapacity(mc, controls * cbmc)
							VarSetcapacity(mxlc, (cbmxl := 24), 0)
							NumPut(cbmxl, mxlc,, "UInt")
							NumPut(NumGet(mxl, 12, "UInt"), mxlc, 4, "UInt")
							NumPut(controls, mxlc, 12, "UInt")
							NumPut(cbmc, mxlc, 16, "UInt")
							NumPut(&mc, mxlc, 20, "Ptr")
							
							if (DllCall("winmm\mixerGetLineControlsW", "UInt", mixerID, "Ptr", &mxlc, "UInt", 0, "UInt") == 0) {
								while (!ret && control < controls) {
									if (NumGet(mc, 8 * control, "UInt") == 1342373889) {
										ret := True
										volID := NumGet(mc, 4 * control, "UInt")
									}
									control += 1
								}
							}
						}
					}
				}
				dest += 1
			}
		}
	}

	return ret
}