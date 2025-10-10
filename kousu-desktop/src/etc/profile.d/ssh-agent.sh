# start ssh-agent on login

# This fixes a static path for $SSH_AUTH_SOCK and boots
# ssh-agent but only if it's not already listening there.
# This should no matter how the session is spawned: ssh, tty, gdm.

if ! [ -d ~/.ssh ]; then
    mkdir ~/.ssh && chmod 700 ~/.ssh
fi

export SSH_AUTH_SOCK=~/.ssh/agent
if ! ( test -S "$SSH_AUTH_SOCK" && nc -z -U "$SSH_AUTH_SOCK" ) >/dev/null 2>&1; then
    # do a quick-check with test -S but then nc to confirm if ssh-agent is actually listening to its socket.
    # nc there and rm here make this more reliable because a crashed agent won't always clean up its socket file.
    rm -f "$SSH_AUTH_SOCK" && \
    ssh-agent -a "$SSH_AUTH_SOCK" >/dev/null
fi

# print known ssh keys, if any are loaded
# unfortuantely there's no way to show the timeout on each except to wait for one to expire
ssh-add -l | awk '/has no identities/ { exit }; NR==1 && ! /has no identities/ { print ""; print "Unlocked SSH keys:" }; { print }'
