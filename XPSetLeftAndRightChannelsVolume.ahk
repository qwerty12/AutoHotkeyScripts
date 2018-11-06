#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.

Up::ShiftChannelVolume(1, 2, False)
Down::ShiftChannelVolume(1, -2, False)
Left::ShiftChannelVolume(0, -2, False)
Right::ShiftChannelVolume(0, 2, False)

ShiftChannelVolume(channel, adj, jump) {
	static mixerID, volID, finalDestination, Minimum, Maximum := -1, Steps, MIXER_OBJECTF_WAVEOUT := 0x10000000, mxl, mcd
	
	if (channel < 0)
		return

	if (Maximum == -1) {
		if (!(DllCall("winmm\waveOutMessage", "Ptr", WAVE_MAPPER := -1, "UInt", DRVM_MAPPER_PREFERRED_GET := 0x2015, "UInt*", WaveOutIDOfPreferredDevice, "UInt*", Status, "UInt") == 0
		&& DllCall("winmm\mixerGetID", "Ptr", WaveOutIDOfPreferredDevice, "UInt*", mixerID, "UInt", MIXER_OBJECTF_WAVEOUT, "UInt") == 0
		&& FindDevIDs(mixerID, volID, finalDestination, Minimum, Maximum, Steps))) {
			Maximum := -1
			return
		}
		VarSetcapacity(mxl, 280)
		VarSetcapacity(mcd, 24)
	}
	DllCall("ntdll\RtlZeroMemory", "Ptr", &mxl, "Ptr", 280)
	NumPut(280, mxl,, "UInt"), NumPut(finalDestination, mxl, 4, "UInt")

	adj := CLAMP(adj, jump ? 0 : -100, 100)

	if (DllCall("winmm\mixerOpen", "Ptr*", hmx, "UInt", mixerID, "UInt", 0, "UInt", 0, "UInt", MIXER_OBJECTF_WAVEOUT, "UInt") == 0) {
		if (DllCall("winmm\mixerGetLineInfo", "Ptr", hmx, "Ptr", &mxl, "UInt", 0, "UInt") == 0) {
			channels := NumGet(mxl, 28, "UInt")
			if (channel < channels) {
				DllCall("ntdll\RtlZeroMemory", "Ptr", &mcd, "Ptr", 24)
				VarSetcapacity(m, 4 * channels, 0)
				NumPut(24, mcd,, "UInt")
				NumPut(volID, mcd, 4, "UInt")
				NumPut(channels, mcd, 8, "UInt")
				NumPut(4, mcd, 16, "UInt")
				NumPut(&m, mcd, 20, "Ptr")
				
				if (DllCall("winmm\mixerGetControlDetailsW", "Ptr", hmx, "Ptr", &mcd, "UInt", 0, "UInt") == 0) {
					curVolume := Round((NumGet(m, 4 * channel, "UInt") / Maximum) * 100)
					newVol := jump ? adj : CLAMP(curVolume + adj, 0, 100)
					if (curVolume != newVol) {
						NumPut((Maximum - Minimum) * (newVol / 100.0), m, 4 * channel, "UInt") ; stolen from the AutoHotkey source
						DllCall("winmm\mixerSetControlDetails", "Ptr", hmx, "Ptr", &mcd, "UInt", 0, "UInt")
					}
				}
			}
		}
		DllCall("winmm\mixerClose", "Ptr", hmx)
	}
}

FindDevIDs(mixerID, ByRef volID, ByRef finalDestination, ByRef Minimum, ByRef Maximum, ByRef Steps)
{
	VarSetcapacity(mxcapsw, (cbmxcaps := 80))

	if (DllCall("winmm\mixerGetDevCapsW", "UInt", mixerID, "Ptr", &mxcapsw, "UInt", cbmxcaps) == 0) {
		if ((destinations := NumGet(mxcapsw, cbmxcaps - 4, "UInt")) > 0) {
			VarSetcapacity(mxl, (cbmxl := 280))
			NumPut(cbmxl, mxl,, "UInt")
			cbmc := 228
			cbmxlc := 24
			Loop %destinations% {
				dest := A_Index - 1
				NumPut(dest, mxl, 4, "UInt")
				if (DllCall("winmm\mixerGetLineInfoW", "Ptr", mixerID, "Ptr", &mxl, "UInt", 0, "UInt") == 0) {
					componentType := NumGet(mxl, 24, "UInt")
					if (componentType == 4 || componentType == 5 || componentType == 4104) { ; speakers, headphones & wave out 
						if ((controls := NumGet(mxl, 36, "UInt"))) { ; controls present
							finalDestination := dest
							VarSetcapacity(mc, controls * cbmc)
							VarSetcapacity(mxlc, cbmxlc, 0)
							NumPut(cbmxlc, mxlc,, "UInt")
							NumPut(NumGet(mxl, 12, "UInt"), mxlc, 4, "UInt")
							NumPut(controls, mxlc, 12, "UInt")
							NumPut(cbmc, mxlc, 16, "UInt")
							NumPut(&mc, mxlc, 20, "Ptr")
							
							if (DllCall("winmm\mixerGetLineControlsW", "UInt", mixerID, "Ptr", &mxlc, "UInt", 0, "UInt") == 0) {
								Loop %controls% {
									control := A_Index - 1
									if (NumGet(mc, 8 + (control * cbmc), "UInt") == 1342373889) { ; volume control
										Minimum := NumGet(mc, 180 + (control * cbmc), "UInt")
										Maximum := NumGet(mc, 184 + (control * cbmc), "UInt")
										Steps := NumGet(mc, 204 + (control * cbmc), "UInt")
										volID := NumGet(mc, 4 + (control * cbmc), "UInt")
										return True
									}
								}
							}
						}
					}
				}
			}
		}
	}

	return False
}

CLAMP(x, low, high)
{
	return (((x) > (high)) ? (high) : (((x) < (low)) ? (low) : (x)))
}