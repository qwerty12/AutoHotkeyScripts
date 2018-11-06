Very basic tray script to start/stop ValdikSS's [GoodbyeDPI](https://github.com/ValdikSS/GoodbyeDPI). 

The script tries to stop GoodbyeDPI correctly by having Windows send Ctrl+C to the script.

Extract GoodbyeDPI's exe and WinDivert DLL and driver into the same folder. Edit the script to change the arguments it starts GoodbyeDPI with.

If Tor is installed as a service, it can start/stop it too.

To get around the problem explained on https://www.codeproject.com/Articles/16163/Real-Time-Console-Output-Redirection so that this script can view its output without hanging, GoodbyeDPI injects a DLL called NoStdoutBuffering.dll into GoodbyeDPI's process. NoStdoutBuffering (the source is included in the 7z file) is a very simple DLL that uses the excellent [MinHook](https://github.com/TsudaKageyu/minhook) library to hook isatty to stop the CRT logic of not flushing when stdout is a pipe.

The included compiled NoStdoutBuffering.dll is for 64-bit only. If you're using a 64-bit Windows OS, it's recommended you only run this script with a 64-bit AutoHotkey.