# Troubleshooting notes

Issues I hit while building the lab, and how each was resolved.

| Symptom | Cause | Fix |
|---|---|---|
| Existing instances didn't match the spec (t3.micro / t3.small, us-east-1c/1d) | Built earlier for another purpose | Rebuilt all three. Instance type can be changed while stopped, but the Availability Zone can't be changed after launch. t3.micro also has only 1 GB RAM, too little for Splunk Enterprise. |
| Launch wizard showed a rule for **All TCP 0-65535 from 0.0.0.0/0** | Default rule left in the wizard | Changed rule 1 to SSH (22) before launching |
| `dpkg: error: cannot access archive 'splunkforwarder-*.deb'` on the forwarder host | Downloaded the 1.3 GB Splunk Enterprise package instead of the Universal Forwarder | Deleted it and downloaded the URL containing `universalforwarder` |
| `^[[200~wget ...~` and `wget: command not found` | Bracketed-paste escape codes from the terminal | Pasted the command again |
| A path appeared at the shell prompt by itself | In PuTTY, highlighting copies and right-click pastes | Ctrl+C to clear the line |
| Forwarder connected but `auth.log` / `syslog` didn't index | UF runs as `splunkfwd`; those files are `syslog:adm` mode 640 | `sudo usermod -aG adm splunkfwd`, then restart the forwarder |
| `Invoke-WebRequest : Missing an argument for parameter 'Uri'` | Multi-line paste over RDP split the command; also opened PowerShell (x86) | Opened 64-bit PowerShell and ran each line separately, storing the URL in `$url` |
| `Login failed` from `splunk list forward-server -auth ...` | The install command still had the placeholder password, so that became the real password | Used the password actually set at install (and you can change it with `splunk edit user admin -password <new> -auth admin:<old>`) |
| PowerShell parse errors when a password was typed on the command line | Characters like `@`, `(`, `;`, `%` are special in PowerShell | Use letters and numbers, or wrap the value in single quotes |
| Windows events would be dropped | Forwarder targets `index = wineventlog`, which didn't exist yet | Created the index on the Splunk Server first |
| `https://<ip>:8000` wouldn't load | Splunk Web uses plain HTTP by default | `http://<ip>:8000` |
| Event times about 5 hours ahead of my clock | EC2 instances use UTC; my screenshots are Eastern | No change needed |
| Public IP changed after restarting the Learner Lab | Auto-assigned public IPs aren't static | Forwarders use the private IP so they're unaffected; look up the new public IP for PuTTY, RDP and Splunk Web (or attach an Elastic IP) |

## Quick health checks

```bash
# Splunk Server
sudo systemctl status Splunkd --no-pager
sudo ss -tlnp | grep -E ':8000|:9997'

# Linux forwarder
sudo /opt/splunkforwarder/bin/splunk list forward-server
sudo tail -n 50 /opt/splunkforwarder/var/log/splunk/splunkd.log | grep -iE "tcpout|error|warn"
```

```powershell
# Windows forwarder
Get-Service SplunkForwarder
Get-Content "C:\Program Files\SplunkUniversalForwarder\var\log\splunk\splunkd.log" -Tail 50 | Select-String "TcpOutput|ERROR|WARN"
```

Which hosts have reported to Splunk in the last 15 minutes:

```spl
index=* earliest=-15m | stats count latest(_time) as last_seen by host | convert ctime(last_seen)
```
