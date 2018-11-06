Download from https://gist.github.com/qwerty12/4b3f41eb61724cd9e8f2bb5cc15c33c2

On Windows 10, it will set the laptop's monitor brightness and show the brightness OSD present there.

Showing the OSD might be a bit iffy, however:
* On Windows 10, the OSD window responds to a SHELLHOOK message to show the OSD on demand. However, the window to send said message to doesn't exist until it's created by pressing the brightness/volume buttons (the former only available physically), or if an undocumented function provided by the shell over COM is called. To create the window if needed, this tries the latter first and then falls back to quickly muting/unmuting the volume. I suspect with every new Windows 10 service pack major update, the GUIDs needed to call the COM method will change, like how they did for the IPolicyConfig interface and "IVirtualDesktopManagerInternal". The SID and IID is correct for 14393.693.
* On Windows 8, I'm hoping the behaviour is the same, but I haven't checked
* On Windows 7, there is no OSD to speak of

To use, paste the contents of the Gist into your file or save the raw contents of the Gist as something like, say, BrightnessSetter.ahk in a default AutoHotkey library folder. And then do something like this:

    #include <BrightnessSetter> ; if you saved the class as its own file
    BrightnessSetter.SetBrightness(-10)

If an own instance of the BrightnessSetter class is created, then it will monitor the AC insertion state. That's optional, however.

There's really only one method that actually does anything, the SetBrightness method. Its parameters:
* increment - how much to increase or decrease the current brightness by. If jump is set, then increment is considered to be an absolute value
* jump - sets the brightness directly instead of working relatively with the current brightness value. False by default
* showOSD - determines if the OSD should be shown. To match the behaviour of the physical brightness keys, BrightnessSetter shows the OSD regardless of whether the brightness was actually changed. True by default
* autoDcOrAc - set to -1 if you want BrightnessSetter to determine the power source and set the brightness for the active power source, 0 if you want the brightness value for when battery power is active to be changed, and 1 for the brightness value when a charger is plugged in. -1 by default
* forceDifferentScheme - by default, BrightnessSetter works on the active power plan. If you want the brightness for a non-active power plan to be set, you can pass a pointer to the appropriate GUID structure for it. Linear Spoon has an excellent post here on using PowerEnumerate to get all the power plans on the system along with their GUIDs. 0 by default to force using the active scheme

Credits:
* YashMaster for the shellhook mechanism and brightness validity tests I pretty much copied (and possibly messed up): https://github.com/YashMaster/Tweaky
