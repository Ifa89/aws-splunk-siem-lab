# Live demo guide

A plan for showing the lab live in about 8 to 10 minutes. The strongest moment is creating a log entry on each server and watching it appear in Splunk seconds later.

## Before the demo

1. Start the Learner Lab and wait for the green dot.
2. In EC2, confirm all three instances are **Running**. Start any that are stopped.
3. Note the **new public IPs**. They change on every lab restart. Private IPs stay the same, so the forwarders reconnect on their own.
4. Log in to Splunk Web at `http://<Splunk public IP>:8000`.
5. Run `index=* earliest=-15m | stats count by host`. Both `ip-172-31-32-46` and `EC2AMAZ-O58QAED` should be listed.
6. Have PuTTY (Ubuntu UF Server), an RDP session with PowerShell, and the Splunk Search tab open. Increase terminal font sizes.

## Demo flow

1. **Architecture (1 min).** Three EC2 instances in us-east-1a. Forwarders send over the private network to the Splunk Server on 9997. Analysts use Splunk Web on 8000.
2. **AWS console (1 min).** EC2 list: three t2.medium instances in us-east-1a. Splunk Server > Security tab: inbound 22, 8000, and 9997 limited to 172.31.0.0/16.
3. **Splunk Server (1 min).** Home page, then **Settings > Forwarding and receiving** to show receiving on 9997.
4. **Linux forwarder, live (2 min).**
   ```bash
   sudo /opt/splunkforwarder/bin/splunk list forward-server
   logger "LIVE DEMO from Ubuntu UF"
   ```
   ```spl
   index=main host="ip-172-31-32-46" "LIVE DEMO"
   ```
5. **Windows forwarder, live (2 min).**
   ```powershell
   Get-Service SplunkForwarder
   eventcreate /T INFORMATION /ID 999 /L APPLICATION /D "LIVE DEMO from Windows UF"
   ```
   ```spl
   index=wineventlog host="EC2AMAZ-O58QAED" EventCode=999
   index=wineventlog* | stats count by source
   ```
6. **SIEM use case (1 min).**
   ```spl
   index=wineventlog source="WinEventLog:Security" (EventCode=4624 OR EventCode=4625)
   | stats count by EventCode, Account_Name
   ```

## Likely questions

- **Why the private IP?** Traffic stays inside the VPC, 9997 isn't exposed to the internet, and it doesn't change when the lab restarts.
- **Why t2.medium?** Splunk Enterprise needs about 4 GB of RAM.
- **Why a separate `wineventlog` index?** Keeps Windows data apart from Linux data, and an index must exist or the indexer drops the events.
- **Universal Forwarder vs Splunk Enterprise?** The UF is a lightweight agent that only collects and ships data. It doesn't index or search.

## Backup plan

If the lab won't start, walk through the screenshots in this repo.
