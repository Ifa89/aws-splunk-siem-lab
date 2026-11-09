# Splunk searches

Run these in **Search & Reporting**. Set the time picker to match (most were run over **Last 24 hours**).

## Confirm data is arriving

Hosts and indexes reporting right now:

```spl
index=* earliest=-15m | stats count by index, host
```

```spl
index=main host="ip-172-31-32-46" (source="/var/log/syslog" OR source="/var/log/auth.log")
```

```spl
index=main host="ip-172-31-32-46" | stats count by source, sourcetype
```

```spl
index=wineventlog* host="EC2AMAZ-O58QAED" | stats count by source
```

## Security-focused searches

Linux `sudo` activity:

```spl
index=main source="/var/log/auth.log" "sudo:" "COMMAND="
| rex "sudo:\s+(?<sudo_user>\S+)\s+:.*COMMAND=(?<command>.*)"
| table _time host sudo_user command
```

Failed SSH logins:

```spl
index=main source="/var/log/auth.log" ("Failed password" OR "Invalid user")
| rex "from (?<src_ip>\d{1,3}(?:\.\d{1,3}){3})"
| stats count by src_ip
| sort - count
```

Windows logons, successful (4624) and failed (4625):

```spl
index=wineventlog source="WinEventLog:Security" (EventCode=4624 OR EventCode=4625)
| stats count by EventCode, Account_Name
```

Windows services installed or changed state (7045, 7036):

```spl
index=wineventlog source="WinEventLog:System" (EventCode=7045 OR EventCode=7036)
| table _time host EventCode Message
```

Event volume over time by source (good as a dashboard panel):

```spl
index=main OR index=wineventlog | timechart span=1h count by source
```

## Live demo: generate an event and find it

Linux (Ubuntu UF Server):

```bash
logger "LIVE DEMO from Ubuntu UF"
```

```spl
index=main host="ip-172-31-32-46" "LIVE DEMO"
```

Windows (PowerShell on Windows2019 Server):

```powershell
eventcreate /T INFORMATION /ID 999 /L APPLICATION /D "LIVE DEMO from Windows UF"
```

```spl
index=wineventlog host="EC2AMAZ-O58QAED" EventCode=999
```
