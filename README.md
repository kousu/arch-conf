# Configuration Management via Package Management (for arch!)

This is my first attempt at trying to do configuration management via packages.

`ansible`, `terraform`, `kubernetes`, all that junk is effective but overly complicated. Why add the complexity when OSes already come with a system for controlling what files and software are on your disk: its package manager?


Here I'm doing this with [Arch's PKGBUILD format](https://wiki.archlinux.org/wiki/PKGBUILD). So, that means you have to be using Arch to use this particular set up.  The main novelty here is that

This automates as many parts of https://wiki.archlinux.org/Installation_guide that it can, including the all important "suggestions"
to actually install suites of useful software. In that sense this is something like [Manjaro](TODO), but without (yet) its own installer.
It also includes my personal UI customization preferences. And it's copiously commented so that you can learn the pointers I've collected in my little dustpan over years on the internet.


## Prereqs

You should be [running ArchLinux](https://wiki.archlinux.org/title/Installation_guide)
with `sudo` and `base-devel` installed:

```
pacman -S --needed --noconfirm sudo base-devel
```

Also, you're gonna have to have `git` so add that:

```
pacman -S --needed git
```

Then download this repo:

```
git clone https://github.com/kousu/arch-conf && cd arch-conf/device-nigiri
```

(the rest assumes you're working inside of this folder)


## Building

Build a top-level package and all its dependencies:

```
./build.sh kousu-device-nigiri
```

Output goes to `${PKGDEST}`, and that folder will be a valid pacman repo.
This path can be set in /etc/makepkg.conf, but is `.` if not specified.

You can install packages one by one with `pacman -U pkg/whatever-version.tar.zst`
but I **recommend** that you "Publish" after you build:

```
sudo mkdir -p /var/cache/pacman/site
sudo cp -r ./pkg/. /usr/cache/pacman/site/
```

You can add that repo for using configuring your host system itself:

```
# /etc/pacman.conf
[site]
SigLevel = Optional TrustAll
Server = file:///var/cache/pacman/site
````

To use the packages, do the _first time install_ of your root package(s):

```
pacman -Sy kousu-device-${HOSTNAME}
```

But in _regular use_ as you make updates:

```
./build.sh kousu-device-${HOSTNAME} &&
sudo cp -r ./pkg/. /usr/cache/pacman/site/ &&
sudo pacman -Syu
```


You can also pre-build **all** the packages:

```
ls | grep -v aur | xargs -n1 ./build.sh
```

Or you can build a single package _without_ its dependencies, say, if you are working on it in detail:

```
cd package_name/
makepkg -sr
```

`-s` installs missing dependencies from the official Arch repos,
but it doesn't know about these _local_ packages,
so for any _local_ dependencies you will need to figure out the
order yourself by trial and error, **or** you could cheat and use:

```
makepkg -d
```

which, for these packages, is probably honestly fine.
`-d` is risky with complex packages that have subtle build-time
dependencies but there aren't any of those here.


### Signing off

Before you build you may want to edit `/etc/makepkg.conf` to set `PACKAGER` and/or `GPGKEY`.

### Build Methods

Arch's core package build command is `makepkg`, but it has variants and wrappers
which provide different levels of speed.
In `build.sh` we use `makechrootpkg` but you can play with swapping

| Core build command | Isolation level | Reliability | Speed[^timing] |
| ------------------ | --------------- | ----------- | -------------- |
| `makechrootpkg -c` | Each build fully containerized | Very high | ~30 minutes |
| `makechrootpkg` | Containerized, but builds reuse the container | High | ~10 minutes |
| `makepkg -sr`[^containercancel] | Builds happen on the host. Dependencies are removed when done with the build, so it should come out clean, but it **will** `pacman -Syu` your live system and **will** temporarily edit your /etc/pacman.conf. :skull: | Low. Build behaviour might accidentally depend or fail on the set of packages on the host, run into weird bugs due to host customizations, or produce broken packages if their dependencies have been renamed/split/retired while still installed on the host | ~1minute [^measure_timing] |
| `makepkg -d` [^pacmanconfdont] | Builds happen on the host. No dependencies are installed, however  **will** temporarily edit your /etc/pacman.conf | Low. Does not examine the host system so it shouldn't be able to be affected by customizations on the host system, neither does it examine the state of Arch's repos, so it's likely to produce broken packages as dependencies get renamed/split/retired. | ~30s |

[^containercancel]: If you switch to this, you also have to switch the lines that edit /etc/pacman.conf to edit the host system, and you can comment out the lines that create the container.
[^pacmanconfdont]: If you switch to this, you can comment out the lines that edit /etc/pacman.conf.
[^timing]: These are for running a full build, as described above.
[^measure_timing]: This was measured on a machine that also had versions of most of these packages installed already. On a dedicated build machine it should be closer to `makechrootpkg`, except for the time lost building the initial container.


## Installation

First, set up a [local repo](https://man.archlinux.org/man/pacman.conf.5#USING_YOUR_OWN_REPOSITORY)

```
$ sudo mkdir -p /var/cache/pacman/site
$ sudo repo-add /var/cache/pacman/site/site.db.tar.zst
$ tee -a /etc/pacman.conf >/dev/null <<EOF
[site]
# the arch devtools magically recognize directories in the containerized
# pacman.conf and _bind mount_ them to the same paths inside as out.
Server = file:///var/cache/pacman/site
# Disable signature checking on local packages -- because we don't have signing configured
SigLevel = Optional TrustAll
[site]
EOF
```

Then copy the built packages into it (if you are bootstrapping a different system then find a way to copy the `pkg/` folder over to it):

```
$ sudo cp -r pkg/. /var/cache/pacman/site  # don't ignore the "."!
```

Then you can install from it; I recommend picking only a single top-level package;
so that it is the only explicitly installed package on your system and if you decide
to switch out the details any irrelevant parts can be identified and cleaned up automatically.

```
$ sudo pacman -Sy kousu-device-nigiri
```

### Manual

In a pinch you can of course install packages manually without the extra steps of using a separate repo folder,
but this is without automatic dependency resolution:

```
cd pkg/ # or cd ${package_name}/ if you used makepkg
sudo pacman -U ${package_name}-*.pkg.tar.zst [${package_name_2}-*.pkg.tar.zst ...]
```

### pikaur

You can also use [`pikaur`](https://aur.archlinux.org/packages/pikaur) to build and install everything.
In some ways maybe this is the easier choice as it

1. Can handle the `aur-*` packages

however it is:

1. annoying to install, which can make it annoying to bootstrap a fresh system from
2. unable to chase down local dependencies, so updates are tedious

```
curl -JLO https://aur.archlinux.org/cgit/aur.git/snapshot/pikaur.tar.gz
tar -xvf pikaur.tar.gz
cd pikaur
makepkg -si
```

Then to install everything:

```
pikaur -Pi */PKGBUILD
```

to install only a subset of packages, just replace the glob with manually picking the packages you want.


## Development

On a system you are building and testing these packages on,
I recommend setting this up as a local repo as if you were installing from it.

Then your development iteration loops like:

```
$ # edit packages
$ ./build.sh
$ sudo cp -r pkg/. /var/cache/pacman/site  # don't ignore the '.'!
$ sudo pacman -Syu  # update packages
$ # test system
$ # repeat
```

> [!warning]
>
> You **could** skip the second line by instead
>
> 1. `sudo chown $USER /var/cache/pacman/site`
> 2. Edit `/etc/makepkg.conf` to set`PKGDEST=/var/cache/pacman/site`
>
> Then builds automatically appear in your package repo. Neat, right?
>
> But it is unsafe: anyone with access to your account can slip a
> malicious package in. Don't build this habit,



## Users

Installing this package *does not* create a user, because I am not sure how to use the sysusers hook, because I decided to keep my dotfiles in /etc/skel so they could be shared between multiple accounts, and because there's no safe way to automate setting a password anyway so you might as well just do the adduser step separately too.

You should do:

```
# adduser -G wheel,network -m your-chosen-username
# passwd -de your-chosen-username
```

`-m` will make sure to deploy the dotfiles from /etc/skel.

The groups here are important! `wheel` means `sudo` rights, `network` means `iwd` and `NetworkManager` rights.

`-de` means that you will have to pick a password the first time you log in.


## Keeping the System State Pristine

My goal here is that your system's configuration recorded in `pacman -Qe` should be pretty minimal,
and that the deployed system is at all times identical -- or close to identical -- to the system
you would have if you erased and reinstalled from scratch.

`pacman -Qe`, the list of software that was directly installed, should be rooted at `kousu-device-nigiri`,
perhaps with a few extras for things from the [AUR](#AUR):

```
$ pacman -Qqe
kousu-device-nigiri
pikaur
zoom
```

To keep this list clean, you can run

```
pacman -Qqe | grep -vFf <(pacman -Qqm) | pacman -D --asdeps -
```

> This marks every package as a dependency
> except (`grep -v`) those not packaged by Arch (`pacman -Qm`)
> i.e. this package, any AUR packages, and any other ad-hoc package.
>
> `grep -vFf` is a [set-substraction operation](https://catonmat.net/set-operations-in-unix-shell)

The goal is to have every package on the system implied by this one top-level package,
and to minimize configuration drift -- the difference between the files on the existing system and the system you would have if you reinstalled from scratch.

(Configuration drift covers: all of `/etc`, some parts of `/var`; it doesn't cover user data in `/home`; it should perhaps cover user-specific configuration, AKA dotfiles, like `/home/*/.config/`, `/home/*/.bashrc`, `~/.vimrc`, but I'm covering those by `/etc/skel/` since this is meant as a personal system). 

Drift in packages:

1. Run the above; then find orphans: `pacman -Qqttd`: these are top-level packages that are missing; move any you use into PKGBUILD, reinstall. Repeat to see if the list has shrunk. Repeat until the list is empty, or you don't want to keep anything else; then  in that case see below.

```
pacman -Qqe | grep -vFf <(pacman -Qqm) | pacman -D --asdeps -
pacman -Qttdq # examine this list: it's packages you've installed but not recorded in PKGBUILD
if ( there are packages to keep ); then
  vi PKGBUILD   # add packages to this; bump the version number
  makepkg -d
  pacman -U *.zst
fi

# remove everything *else*
# TODO: I could put this (very destructive) command in the .install script to force the system to respect the current config-management state
pacman -Qttdq | sudo pacman -Rns --noconfirm -
```

Drift in contents (/etc, /var, /srv, /opt, etc, but not /home):
1. ? (use ..diff?
1. Maybe `paccheck` (https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#Listing_all_changed_files_from_packages)
3. `find /etc /usr /opt | LC_ALL=C pacman -Qqo - 2>&1 >&- >/dev/null | cut -d ' ' -f 5-` (https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#Identify_files_not_owned_by_any_package)
4. `lostfiles`

`pacman -Qttd`, the list of [orphans](TODO), should be empty. Orphans can occur when you do `pacman -R` instead of `pacman -Rs` -- removing a top level package you installed, but leaving dependencies that came with it -- or when the dependency web changes during an update.
This package installs a [pacman hook](https://wiki.archlinux.org/wiki/Pacman#Hooks) that will report orphans and remind you that to clean them up you ucan do:


The pacman cache is often one of the largest pieces on the system.

A clean system should mean that the *only* files on the system are:

- those that are implied by this package
- those in /var
- those in /home

To verify that this is so, [use one of the tips from archwiki](https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#Identify_files_not_owned_by_any_package):

```
# find /etc /usr /opt | LC_ALL=C pacman -Qqo - 2>&1 >&- >/dev/null | cut -d ' ' -f 5-
```

or maybe more accurately:

```
ls / | grep -E -v 'home|var|run|proc|sys' | (cd /; xargs find) | LC_ALL=C pacman -Qqo - 2>&1 >&- >/dev/null | cut -d ' ' -f 5-
```

or `pacreport --unowned-files`

This list should also come out empty. Meaning that you can do a 'user reset' by wiping (or renaming) `/home/$USER`, and a "factory reset" by wiping `/var`, and that those are in fact proper resets.


TODO:

* [ ] add a hook/cronjob that reminds you to/does run `pacman -Qqe | grep -v kousu | grep -v pikaur | pacman -D --asdeps` to keep the system config actually clean
* [ ] add a hook/cronjob that reminds you to/does run `pacman -Sc`


## AUR

Dealing with [AUR](https://aur.archlinux.org) packages is tricky.

If we depend on them directly then there's a bootstrapping problem: a fresh system
with just `pacman` won't have `base-devel` installed so can't build packages, nor
can it find the AUR packages unless `pacman` is wrapped by `pikaur`.

You I _could_ bootstrap `pikaur` onto the system and replace `makepkg -d` with it `pikaur -P`.
This snippet will do that:

```
pacman -S base-devel --noconfirm &&
pacman -S python-commonmark pyalpm --noconfirm &&
 curl -JLO https://aur.archlinux.org/cgit/aur.git/snapshot/pikaur.tar.gz &&
 tar -zxvf pikaur.tar.gz &&
 cd pikaur &&
 makepkg &&
 pacman -Rns python-commonmark &&
 pacman --noconfirm -U pikaur*.pkg.tar.zst &&
pikaur -P
```

Then we could depend on AUR packages too. But it's inelegant.

For now, I think what I'm going to do is plan to put the AUR packages into a separate
PKGBUILD, along with these bootstrapping instructions.
Maybe I could even pull them into `post_install`? Check if `pikaur` is installed and if not, do this?


## Dotfiles

I've decided to keep dotfiles under /etc/skel/, since these are single-user systems, or at least
systems that start single user and can be customized with these dotfiles as a starting point.

Another option would be to use PKGBUILD's `sysusers` feature to actually create user accounts,
and then fill their contents in. But I haven't explored that. I suspect it will be weird.

But, doing it this way means dotfiles needs special handling during an update. This one-liner will update their contents:

```
(cd /etc/skel/; find -type f -exec echo cp --parents {} ~/ \;)
```

## Development

### Container builds

Sometimes shit fucks up. Do this:

```
sudo rm -r /var/lib/archbuild/site/
```

and/or add in `c` to `makechrootpkg -c` in `build.sh`. But even then sometimes you just gotta nuke it.

### `pkgver`

The version is automatically generated from git. There are soe quirks to it.

This is the snippet that you should use in every PKGBUILD:

```
_pkgver() {
  [ -r "$startdir"/.pkgver ] && cat "$startdir"/.pkgver || (echo "r$(git rev-list --count HEAD).commit=$(git describe --always --dirty | sed s/-/+/g)")
}
pkgver="$(_pkgver)"
pkgrel=1
```

1. `.pkgver` is used by `build.sh`; the containerized build forgets the git repo, so when building containerized that makes sure the version number survives
2. This assigns to `pkgver` _eagerly_.

    `makepkg`/`makechrootpkg` have a feature that `pkgver` can be a function `pkgver()`
    in which case it is run _after_ `prepare()` to generate a version dynamically from
    the source code, and then once that's done it will _write back_ a hardcoded `pkgver=` line.

    But this causes a thorny infinite loop:

    1. Edits and commits happen
    2. A build happens
    3. The build writes back to PKGBUILD, **dirtying** the repo
    4. To clean the repo, either you need to make another commit which will cause a loop, commit --amend which will still cause the commit hash to change and still cause the next build to dirty the repo, or undo the updated version string.

    The reason for this is that the `pkgver()` structure wasn't meant
    to be used the way I'm using it here. It was meant for git repos
    downloaded as a source. The outer repo, the one with the PKGBUILD in it,
    is not the source of the version number.

    All that is to say: don't use `pkgver()` here, it will be a bad time.
    But we can get the same effect by assigning to `pkgver` eagerly; that works
    for us because we don't need to download anything.
3. If we ever start making release tags, we could version with

   ```
   $(git describe --tags).r$(git rev-list --count HEAD).commit=$(git describe --always --dirty | sed s/-/+/g)
   ```

    but if we did that we should also set `epoch=1`


### Contents

Because the goal here isn't to package pre-existing software for use on Arch,
but rather to customize a complete Arch system, most of the work is done kept in files,
directly in `src/`, instead of using PKGBUILD's `sources=()` array, and what doesn't
fit in as a file is done as a `.install` script hook.

> [!warning]
>
> `package()` is run in `$srcdir`, however `$srcdir != 'src/'`, at least not necessarily.
> Instead, because we're not using `sources`, every `package()` function here starts by enforcing
> `cd ${startdir}/src`

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

The trick is to express configuration as much as possible as config files instead of as commands that change state. So, instead of `systemctl enable`, directly create symlinks in `/etc/systemd`; instead of `ip addr add` use a tool like `iwd`, `netctl`, `netplan`, `NetworkManager`, and figure out and *deploy* the config files it would write for itself; instead of ``. Pick your apps and daemons that understand `.d` directories (e.g. ..., ..., ..., `/etc/cron.d/`, ...), make use of them: they are there specifically so multiple packages can combine their efforts without stepping on each other.

In the rare cases you cannot express configuration as files on the system, use a post-install script, or maybe deploy cronjobs (or systemd timers, if that's your thing).

## Related Work

* ansible
* puppet
* chef
* guix
* nix
* terraform? I guess?
* keeping a careful notebook like [this guy](http://howardism.org/Technical/Emacs/literate-devops.html)
* crying into a small jar full of tears
* https://github.com/CyberShadow/aconfmgr - Arch specific

## Future Work

* Adapt this approach for debian systems
  * perhaps with the help (or at least guidance and some code snippets) of [pacur](https://github.com/pacur).
    pacur's thing is that it backports Arch's PKGBUILD format into something compatible; so it's sort of like a packaging transpiler? But you still need to like, deal with platform-specific stuff, you just in theory can learn a single language+toolchain to do all platforms with.
