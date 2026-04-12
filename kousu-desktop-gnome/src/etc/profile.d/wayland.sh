# needed to get most KDE/QT apps to play nice under Wayland
if [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
    export QT_QPA_PLATFORM=xcb
fi
