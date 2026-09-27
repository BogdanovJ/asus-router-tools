# Security

- Never commit a Telegram bot token or chat ID.
- Keep `/jffs/configs/router-tools.conf` mode `600`.
- Treat any token pasted into chat, logs, screenshots, shell history, or a Git commit as exposed and rotate it with BotFather.
- The watchdog intentionally writes NVRAM and can restart the WireGuard server. Review it before use on a different ASUS model/firmware.
- Do not expose router administration or SSH directly to the public Internet merely to use these scripts.
- Public WireGuard keys are not private credentials, but this repo maps peers by VPN IP instead, avoiding unnecessary device identifiers in source control.

## Accidental Git secret commit
Removing a token in a later commit does not remove it from Git history. Rotate the token first, then rewrite repository history if necessary.
