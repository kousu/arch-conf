# GNOME env TODO

* [ ] BUG: /etc/profile.d/vte.sh isn't getting loaded under GNOME (is anything in /etc/profile.d?)
    - [ ] missing vte.sh is breaking lots of features of the terminal; particularly the one that lets a new tab stay in the same folder
* [ ] There's no system tray for older applets.
    - [ ] Workrave is broken (or at least, easy to accidentally turn off which is basically broken for it) because of this
      - there's a Workrave GNOME extension but it's disable "because it's incompatible with GNOME 49"
* [ ] Software (i.e. AppStream) is read only
* [ ] Filling GNOME settings defaults
  - see TODO.dconf/ (generated with `dconf dump /`)
  - https://help.gnome.org/admin/system-admin-guide/stable/dconf-custom-defaults.html.en
