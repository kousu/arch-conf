# `kousu-matlab`

The albatross around all of our necks.

See the [top level](../README.md) for build instructions.

> [!warning]
>
> This DOES NOT WORK yet.  I'm sorry. It's like 90% there but there's some glitches.
>
> The process [here on the Arch forums](https://bbs.archlinux.org/viewtopic.php?pid=2268137#p2268137) works as of 2025-10.
> This package attempts to replicate that but something is wrong.
> The ServiceHost doesn't get launched or maybe torn down cleanly
> if it's launched by script and not manually. Maybe it NEEDS a tty attached?
> and then some data seems to get corrupted and it refuses to work right
> until it's torn down and rebuilt.
> Also maybe the authorization process needs to write to the matlab install folder??
>
> Anyway basically doing it by hand following that post works,
> doing the exact same steps by script fails mysteriously. Sorry.

## License Authorization

To use matlab you need a [MathWorks account](https://www.mathworks.com/) with an activated license.

The first time you run `matlab` it will download and install [MathWorksServiceHost](https://github.com/mathworks-ref-arch/administer-mathworks-service-host/blob/498c5991046ed629eb24575b45ec968712ea3d39/README.md), which, among other things, verifies your license at all times, and then it will probably quit.

> [!tip]
> You need to do this in a GUI

Check that it downloaded the service to `~/.MathWorks` (it should nearly 1GB) and that it created `~/.config/autostart/mathworks-service-host.desktop`.

```
$ du -hs ~/.MathWorks/
841M	/home/kousu/.MathWorks/
$ cat ~/.config/autostart/mathworks-service-host.desktop 
[Desktop Entry]
Type=Application
Name=Mathworks Service Host
Exec=/home/user/.MathWorks/ServiceHost/-mw_shared_installs/v2025.8.1.1/bin/glnxa64/MathWorksServiceHost service --realm-id companion@prod@production
Terminal=false
```

**Log out and back in again** to make the autostart run.

> [!tip] Manual run
>
> **If** you are not using a desktop environment that honours ~/.config/autostart, then open that file and run it manually, e.g. (but compare this to what's in your .desktop file)
> 
> ```
> $ ~/.MathWorks/ServiceHost/-mw_shared_installs/*/bin/glnxa64/MathWorksServiceHost service --realm-id companion@prod@production &
> ```

Verify it is running with

```
pgrep -laf MathWorks
```

Run `matlab` again and it should prompt you to log in to your license.
Once you do...it might crash again. Because fuck the MPAA I guess?

But run `matlab` a third time and it will probably ask you to log in again and once you do that it should work.

ifdk man, closed source is weird.
