Scripts specific to my X230 laptop.

EnableTrackPointAndButtonsOnlyWhenFnIsHeld - does what it says. You can press Escape to exit the script at any time. Credits:

* The people in this thread https://autohotkey.com/board/topic/65849-controlling-synaptics-touchpad-using-com-api/

* Synaptics for their SDK - specifically the Disabler program

LenovoBatterySetRegisterThresholds - asks the IBM power management driver directly to set the battery thresholds, removing the only reason I might have had to keep Lenovo's UWP abomination around.
The method used comes from RE work by XYUU. See his blog post [here](https://zhuanlan.zhihu.com/p/20706403) and his application [here](https://github.com/XYUU/BatteryUtils).

Things to be aware of:

* When you run it, it will set the thresholds right away. You should change them before running the script for the first time.

* This script just asks the IBM driver to set the thresholds and then exits. It is not persistent. And for that matter, the threshold setting changes it makes might not always be remembered by the EC. I run this on startup.

* If you don't like the script, just have it set your thresholds back to the original values (0, 100) and delete it - it leaves nothing else lying around

* Lenovo software itself might reset the thresholds. I uninstalled Lenovo Settings, the ThinkPad Settings Dependency package and Lenovo System Interface Foundation

* If the script is run elevated (not a requirement), it will try to make sure the IBM power management driver is started

I do have an AutoHotkey script that makes the microphone LED blink when the CapsLock key is pressed, but [this](https://gitlab.com/valinet/thinkpad-leds-control) is a better program for it.