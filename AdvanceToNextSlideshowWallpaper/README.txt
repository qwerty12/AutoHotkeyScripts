Scripts to advance to next background slideshow picture in the background upon pressing Windows + n

For Windows 8 and 10, this is a simple affair, thanks to the built-in interface for doing so.

For Windows 7, this is a different matter entirely. As there is no documented interface for this, this uses ShellContextMenu to display the Desktop right-click menu invisibly in AutoHotkey's process where it selects the "next slideshow background" option.
Far more resource consuming and slower. Because loading a ton of shell DLLs into AutoHotkey brings up the memory usage to at least 20 MB, the Windows 7 script is configured to restart 10 seconds after Windows + n was last pressed.