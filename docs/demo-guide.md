# Live demo guide

This walkthrough takes 8 to 10 minutes. The main part is writing a log entry on each server and finding it in Splunk a few seconds later.

## Before the demo

1. Start the Learner Lab and wait for the green dot.
2. In EC2, confirm all three instances are **Running**. Start any that are stopped.
3. Note the new public IPs. They change on every lab restart. Private IPs stay the same, so the forwarders reconnect on their own.
4. Log in to Splunk Web at `http://<Splunk public IP>:8000`.
5. Run `index=* earliest=-15m | stats count by host`. Both `ip-172-31-32-46` and `EC2AMAZ-O58QAED` should be listed.
6. Have PuTTY (Ubuntu UF Server), an RDP session with PowerShell, and the Splunk Search tab open. Increase terminal font sizes.

## Demo flow

1. Architecture (1 min): three EC2 instances in us-east-1a. The forwarders send over the private network to the Splunk Server on 9997, and analysts use Splunk Web on 8000.
2. AWS console (1 min): show the EC2 list with three t2.medium instances in us-east-1a, then the Splunk Server's Security tab with inbound 22, 8000, and 9997 limited to 172.31.0.0/16.
3. Splunk Server (1 min): show the home page, then **Settings > Forwarding and receiving** with receiving on 9997.
4. Linux forwarder, live (2 min):
   ```bash
   sudo /opt/splunkforwarder/bin/splunk list forward-server
   logger "LIVE DEMO from Ubuntu UF"
   ```
   ```spl
   index=main host="ip-172-31-32-46" "LIVE DEMO"
   ```
5. Windows forwarder, live (2 min):
   ```powershell
   Get-Service SplunkForwarder
   eventcreate /T INFORMATION /ID 999 /L APPLICATION /D "LIVE DEMO from Windows UF"
   ```
   ```spl
   index=wineventlog host="EC2AMAZ-O58QAED" EventCode=999
   index=wineventlog* | stats count by source
   ```
6. SIEM use case, Windows logons (1 min):
   ```spl
   index=wineventlog source="WinEventLog:Security" (EventCode=4624 OR EventCode=4625)
   | stats count by EventCode, Account_Name
   ```

## Likely questions

- Why the private IP? Traffic stays inside the VPC, 9997 isn't exposed to the internet, and the address doesn't change when the lab restarts.
- Why t2.medium? Splunk Enterprise needs about 4 GB of RAM.
- Why a separate `wineventlog` index? It keeps Windows data apart from Linux data. The index also has to exist before data arrives, or the indexer drops the events.
- How is the Universal Forwarder different from Splunk Enterprise? The forwarder is a small agent that collects logs and sends them on. It doesn't index or search anything.

## Backup plan

If the lab won't start, walk through the screenshots in this repo.
