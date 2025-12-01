# Bugs

- [ ] For some reason, kousu-base/kousu-base.install and kousu-desktop/kousu-desktop.install aren't getting run anymore
- [ ] GNOME/gdm: does NOT source /etc/profile
    - and this breaks tab-to-same-directory in the terminal because /etc/profile.d/vte.sh isn't loaded
    - there's a lot of discussion about this bullshit going back years, e.g.
      - https://github.com/hyprwm/Hyprland/issues/2581
      - https://github.com/rmarquis/pacaur/issues/638#issuecomment-277485530
      - https://bugzilla.gnome.org/show_bug.cgi?id=736660
      - https://bbs.archlinux.org/viewtopic.php?id=218197
      - https://lwn.net/Articles/709769/
      - https://github.com/void-linux/void-packages/issues/8613
   - actually wayland does respect /etc/profile.d
      the problem is /etc/profile.d/vte.sh doesn't respect wayland
      /etc/profile.d/{localbin,podman-docker}.sh and my own ssh-agent.sh are all loaded correctly.
      it's that specific script. it bails out if not run under a terminal it knows about and in an interactive session. so just being a login session won't do it.
      - arch's rec is https://wiki.archlinux.org/title/GNOME/Tips_and_tricks#New_terminals_adopt_current_directory to do exactly what I did. that seems shitty.
	I guess the issue is that it used to be standard for VTE terminals to themselves be login shells.

