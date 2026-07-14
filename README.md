# momiji-dots

Provisioning repo for the HP 255 G10 (Arch + Hyprland + Caelestia).
Full instructions: [RUNBOOK.md](RUNBOOK.md) in this repo.

| File | Destination | When |
|---|---|---|
| packages.txt | pacman stdin | Phase 7 |
| etc/hosts | /etc/hosts | Phase 5 |
| boot/loader.conf | /boot/loader/loader.conf | Phase 5 |
| boot/arch.conf.template | /boot/loader/entries/arch.conf | Phase 5, fill UUID from blkid |
| etc/getty-autologin.conf | /etc/systemd/system/getty@tty1.service.d/autologin.conf | Phase 7 |
| home/fish/10-tty1-hyprland.fish | ~/.config/fish/conf.d/ | Phase 7 |
| home/caelestia/hypr-vars.lua | ~/.config/caelestia/ | Phase 9 |
| wallpapers/maple.png | ~/Pictures/Wallpapers/ | Phase 10 |
| etc/wifi-powersave.conf | /etc/NetworkManager/conf.d/ | Appendix A, on symptoms only |
| etc/rtw89.conf | /etc/modprobe.d/ | Appendix A, on symptoms only |
| etc/sleep-hibernate.conf | /etc/systemd/sleep.conf.d/hibernate.conf | Appendix C, optional |
| etc/logind-lid.conf | /etc/systemd/logind.conf.d/lid.conf | Appendix C, optional |

Never commit wifi passwords to this repo.
