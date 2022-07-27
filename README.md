# server-guardian
This is a simple bash script that monitor the server high cpu, ram usage, the hard disk free space, postgresql status, apache2 status and check the systemctl services status.

If the ram or cpu usage is greather then limit or a service is failed or the disk usage is greather then limit, send a message to telegram user

## How to use
- `sudo chown -R root:root /path/to/server-guardian`
- `sudo cp /path/to/server-guardian/.config.demo /path/to/server-guardian/.config` 
- edit .config file and type your telegram bot key and chat or adjust the options
- `sudo chmod 600 /path/to/server-guardian/.config`
- `sudo chmod 754 /path/to/server-guardian/guardian.sh`
- `sudo touch /etc/systemd/system/guardian.service`
- `sudo chmod 664 /etc/systemd/system/guardian.service`
- edit guardian.service file
```
[Unit]
Description=server-guardian
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
ExecStart=/path/to/server-guardian/guardian.sh > /dev/null 2>&1`

[Install]
WantedBy=multi-user.target
```
- `sudo systemctl start guardian.service`
- `sudo systemctl enable guardian.service`

### Options
`--warn-every` Minutes number between each alert
    
`--watch-cpu` 1 to enable or 0 to disable the high cpu usage
    
`--watch-ram` 1 to enable or 0 to disable the high ram usage
    
`--watch-services` 1 to enable or 0 to disable the services failed alert
    
`--watch-hard-disk` 1 to enable or 0 to disable the hard disk free space alert

`--watch-apache2` 1 to enable or 0 to disable the services failed alert

`--watch-postgresql` 1 to enable or 0 to disable the services failed alert

`--url` URL used by curl to check apache2 service

`--pg_host` Host to check postgresql service

`--pg_database` Database to check postgresql service

`--pg_port` Port to check postgresql service

`--pg_user` User to check postgresql service
    
`--cpu-warning-level` 
- **high**: to receive an alert if the load average of last minute is greater than cpu core number. 
- **medium**: watch the value of the latest 5 minutes. (default)
- **low**: watch the value of the latest 15 minuts.
    
`--memory-limit` Memory percentage limit
    
`--disk-space-limit` disk space percentage limit
    
`--config` path to custom config file with telegram bot key and telegram chat id options
    
`--config-telegram-variable-token` the token variable name (not the token key) stored in custom config file (ex: TELEGRAM_TOKEN_CUSTOM_NAME)
    
`--config-telegram-variable-chatid` the chat id variable name (not the id) stored in custom config file (ex: TELEGRAM_CHAT_ID_CUSTOM_NAME)
    
`-h, --help` show this help
