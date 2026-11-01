# scholar-hindex-tracker

A single PowerShell script that logs your Google Scholar citation count and h-index, one line per run:

```
2026-11-01 09:00 | Citations: 25213 | h-index: 73
```

## Use

1. Download `scholar-hindex-tracker.ps1`.
2. Edit its "1. Configuration" section with your Google Scholar author ID and a free [SerpApi](https://serpapi.com) key (the script header explains how to get both).
3. Run it: `powershell -ExecutionPolicy Bypass -File .\scholar-hindex-tracker.ps1`
4. To log every day, create a Windows scheduled task (the script header has a ready-made example that runs daily at 09:00).

The task only runs while your computer is on; with the "start when available" option it runs as soon as the computer wakes up.

The log (`scholar_history.txt`) is written next to the script.

## Author and license

Enrique Alba ([@Enrique-Alba-uma](https://github.com/Enrique-Alba-uma)). MIT License, see [LICENSE](LICENSE).
