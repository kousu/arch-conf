(while true; do setxkbmap -option compose:rctrl; sleep 60; done) & # this motherfucker never sticks
(
systemctl --user import-environment DISPLAY XAUTHORITY
systemctl --user start --now graphical-session.target
trap 'systemctl --user stop graphical-session.target' EXIT
( i3 )
)
