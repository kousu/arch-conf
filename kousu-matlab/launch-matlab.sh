#!/bin/sh

# system-wide
# DOESN'T WORK
#/usr/local/MATLAB/R2025a/bin/matlab "$@"

# per-user
~/.MathWorks/ServiceHost/-mw_shared_installs/v*/bin/glnxa64/MathWorksServiceHost service --realm-id companion@prod@production &
~/.local/MATLAB/R2025b/bin/matlab "$@"
