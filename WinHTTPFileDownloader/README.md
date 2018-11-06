![WinHTTPFileDownloader](https://i.imgur.com/HTqb6b6.png)

A very messy script that downloads a segment of waik_supplement_en-us.iso, written for https://autohotkey.com/boards/viewtopic.php?f=5&t=17370

There is no buffering mechanism to speak of, it downloads a hardcoded segment from a file determined from a hardcoded URL path to a hardcoded filename.

just me's [Class_TaskDialog](https://autohotkey.com/boards/viewtopic.php?f=6&t=5711) is needed. 

For something that actually works, you might consider https://github.com/potmdehex/WinInet-Downloader instead.