WARNING: I do not use OneDrive myself. I have not tested this with any file over 200 KB... *Make sure you have backups of any important files stored outside of OneDrive!*

A hack that loads the OneDrive context menu shell extension into AutoHotkey, where AHK can then select menu items directly - the extension tells the OneDrive client to perform the action.

To find out if a file is set to always remain stored on your PC and/or whether the space used (if any) by said file can be freed, run the script with just the target's filename as the script's sole argument. `Example: Untitled.ahk "Documents\New Text Document.txt"`

To toggle a file's always-remain-on-your-PC status, run the script with /keepondevice as the first argument, followed by the target's filename as the second argument. Example: `Untitled.ahk /keepondevice "Documents\New Text Document.txt"`

To have a file cleared from your PC, run the script with /freespace as the first argument, followed by the target's filename as the second argument. Example: `Untitled.ahk /freespace "Documents\New Text Document.txt"`

* This is the bare minimum to do something like this this way. Adding in support to toggle multiple files' always-remain-on-your-PC status / freeing multiple files is probably possible by reworking my bad command-line logic and adding the extra filenames to the filenames array.
    * But not for the getting a file's current status operation! Select multiple files in your OneDrive folder of varying sync statuses, right-click and observe the inconsistencies. This script determines the current status for one file by seeing if the relevant menu is (un)checked / enabled / disabled. Yeah...
