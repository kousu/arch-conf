# Configuration Management via Package Management (for arch!)

This is my first attempt at trying to do configuration management via packages.

`ansible`, `terraform`, `kubernetes`, all that junk is effective but overly complicated. Why add the complexity when OSes already come with a system for controlling what files and software are on your disk: its package manager?

Here I'm doing this with [Arch's PKGBUILD format](https://wiki.archlinux.org/wiki/PKGBUILD). So, that means you have to be using Arch to use this particular set up.  The main novelty here is that

## Prereqs

You should be running ArchLinux.

You will need to have `pacman` and `base-devel` installed.

## Building

1. `makepkg -d`

You need `-d` because .. reasons (TODO explain)

## Installation

2. `makepkg -d && sudo pacman -U kousu-nigiri-*.pkg.tar.zst`

I'm going to look into what running my own repo looks like; maybe I can do it on Github Pages? That would be nice and easy.

To make a nice clean system do:

```
pacman -Qe | sudo xargs pacman -D --asdeps && sudo pacman -D --asexplicit kousu-nigiri &&
pacman -Qttdq | sudo xargs pacman -Rns --noconfirm
```

This should mean that the *only* files on the system are:

- those in /home
- those in /var
- those that are implied by this package

To verify this, [use one of the tips from archwiki](https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#Identify_files_not_owned_by_any_package):

```
# find /etc /usr /opt | LC_ALL=C pacman -Qqo - 2>&1 >&- >/dev/null | cut -d ' ' -f 5-
```

or `pacreport --unowned-files`

i.e. it should be as if you've done a fresh installation, every time.

## Updates


If you make changes, bump the version number by editing one of these lines in `PKGBUILD`:

```
pkgver=v0.1.2
```

```
pkgrel=2
```

and re-run `makepkg -d` .... or you can skip the edit and run `makepkg -df` (but when you *publish* a new version you should make sure to bump it so `pacman` will understand it should be doing an upgrade).


Then just install the updated package:

```
makepkg -d && \
 sudo pacman -U kousu-nigiri-*.pkg.tar.zst && \
 (pacman -Qtdq | sudo pacman -Rcns) && \
 sudo pacman -Sc && \
 sudo reboot
```

(`pacman -Qtdq | ...` is to remove orphaned packages; it's the equivalent of `apt autoremove`)



## Discussion

The big upside to pushing configuration management into packages is that it makes updates reliable. I only know `ansible` in depth but my understanding is this is true of `terraform` and `puppet` and `chef` as well: it's not a declarative language, it's a procedural one; it's just slightly more reliable shell scripting; it consists of statements of *actions* not of *states*. Because they are, fundamentally, procedural languauges there is no clean way to *undo* what any of them have done. This means a system can be in one of four states:

1. blank (i.e. a fresh install)
2. up to date (i.e. fresh install -> current latest deployment applied)
3. out of date (i.e. fresh install -> older deployment)
3. somewhere in between (i.e. fresh install -> older deployment -> latest deployment)

That last state leaves lurking bugs. An concrete example of how: Ubuntu >=18.04 is shipping `netplan`, which keeps its config in `/etc/netplan/*.yml`. If you tell ansible to deploy `/etc/netplan/01-default.yml`, then later decide to make some changes and rename it to `/etc/netplan/01-ethernet.yml` and redeploy, now you have *two* network configurations, and your system be knocked offline -- without a warning -- the next time it reboots. To manage this you *must* be vigilant for this sort of oversight, and in this case you need to make sure the old name gets deleted everywhere:

a. manually remove them all: `for system in $SYSTEMS; do ssh root@$SYSTEM.example.net rm /etc/netplan/01-default.yml; done`
b. use ansible's ad-hoc command to remove them all (something like, I haven't checked this for typos): `ansible -m file -a 'path: /etc/netplan/01-default.yml, state: absent`))
b. add the same `file` command to your deploy script *for the entire future*; but b. has the problem that

Now, 80% of the time, updates are done within existing files, and in that case ansible fully overwrites their contents and there's no ambiguity. But in some ways that's even worse, because it means it's not necessarily obvious when you've created such an intermediate state.

I'm not totally sure but I think the reason the popular config management tools don't get flak for this oversight is that they are generally run on fresh VMs/containers; an out of date system just gets erased, then redeployed with the latest script.

By pushing the configuration management work into the package manager, a system can only be in the first three states: blank, up to date, or out of date, and bringing it up to date is a reliable one-step command.

Another upside is just parsimony: by reducing the amount of software involved, the overall system is faster to deploy and simpler to manage. (installing an ansible control machine takes up about a gig, once you get all the extra collections you need for a realistic deployment; with pacman, the deploying machine either just needs `pacman` (for `makepkg`) for building the packages, or maybe doesn't need to have anything installed since you can separate the *build* work from the *deployment* work).

Another upside is that you can port off the configuration of a system easily: it's just `pacman -Qd > packages.txt`; to reinstall on a rebuilt/different machine, just `pacman -S - < packages.txt`). You don't need to dig around in `/etc/` running `diff` on things to try to figure out what you've changed, because everything you've changed *is already written down in a package somewhere*.

The downside to doing this is that it's not portable to other OSes. However, I have a defense: while ansible and friends promise to be somewhat cross-platform, they aren't and can't be: at a minimum the names of packages are different from distro to distro, the name of the package manager changes, the particular paths you need to use changes, and the workarounds needed to combine different versions of software packages changes depending on the distro/OS you're running on. So any configuration management tool cannot really be independent on its target OS. Leaning instead into the OS by using its native package manager makes things simpler.

Another downside is that there are some operations that _do_ need to be procedural, like: `c_rehash` (to rebuild some symlinks in `/etc/ssl/certs`), `update-mime-database` (filling in `/usr/share/mime/`), or `useradd` (which... really should be able to be done declaratively, but it's not because Unix is old and didn't know declarative wisdom), or `mkinitcpio`. Arch can handle these, using (package-specific) [`post_install` scripts](https://wiki.archlinux.org/title/PKGBUILD#install) and (system-wide) [`/usr/share/libalpm/hooks/`](https://wiki.archlinux.org/title/Pacman#Hooks): on every few upgrades you will see these hooks run to translate changes in the files on disk (the static, declarative part) to the procedural steps needed to match, but you need to identify these; to that all I can say is: find ways, and choose software, that doesn't need it, as much as possible.


## Working with this

The trick is to express configuration as config files instead of as commands that change state. So, instead of `systemctl enable`, directly create symlinks in `/etc/systemd`; instead of `ip addr add` use a tool like `iwd`, `netctl`, `netplan`, `NetworkManager`, and figure out and *deploy* the config files it would write for itself; instead of ``. Pick your apps and daemons that understand `.d` directories (e.g. ..., ..., ..., `/etc/cron.d/`, ...), make use of them: they are there specifically so multiple packages can combine their efforts without stepping on each other.

## Related Work

* ansible
* puppet
* chef
* guix
* nix
* terraform? I guess?
* keeping a careful notebook like [this guy](http://howardism.org/Technical/Emacs/literate-devops.html)
* crying into a small jar full of tears

## Future Work

* Adapt this approach for debian systems
  * perhaps with the help (or at least guidance and some code snippets) of [pacur](https://github.com/pacur).
    pacur's thing is that it backports Arch's PKGBUILD format into something compatible; so it's sort of like a packaging transpiler? But you still need to like, deal with platform-specific stuff, you just in theory can learn a single language+toolchain to do all platforms with.
