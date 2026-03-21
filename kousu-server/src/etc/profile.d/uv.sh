
# make python-uv install somewhere sensible
# this makes `sudo uv tool install ...` place the libs (actually the venvs) in /usr/local/lib/${package}/lib/
# and the executables in /usr/local/bin so they work
if [ $EUID -eq 0 ]; then
  export UV_TOOL_DIR=/usr/local/lib
  export UV_TOOL_BIN_DIR=/usr/local/bin
fi
