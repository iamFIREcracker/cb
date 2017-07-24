# INSTALL:
#
#   * source this script
#
#       . /path/to/cb.sh
#
#   * that's it!
# USE:
# 
#   * cb                  # outputs the content of the clipboard
#   * fortune | cb        # Pipes fortune's output into the clipboard
#   * cb --force-paste    # forces cb to start in 'paste' mode
#   * cb --listen         # starts a clipboard daemon -- handy when trying to
#                         # update the clipboard from a remote ssh session

_CB_REMOTE_PASTE_REQUEST_TOKEN=AKDJF8U4389HSDHF3H9RH39FJSKDHFJH983QR98HAUFHA

_cb_copy() {
    if env | grep --quiet -F SSH_TTY; then
        nc localhost ${_CB_REMOTE_PORT:-5556}
    elif [ -e /dev/clipboard ]; then
        putclip
    else
        pbcopy
    fi
}

_cb_paste() {
    if env | grep --quiet -F SSH_TTY; then
        echo -n ${_CB_REMOTE_PASTE_REQUEST_TOKEN} | nc localhost ${_CB_REMOTE_PORT:-5556}
    elif [ -e /dev/clipboard ]; then
        getclip
    else
        pbpaste
    fi
}

_cb_listen() {
    echo "Listening on port ${_CB_REMOTE_PORT:-5556}..."
    while (true); do
        python <<END
import socket, subprocess

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('localhost', ${_CB_REMOTE_PORT:-5556}))
s.listen(1)
remote, _ = s.accept()
input = ''
while True:
    data = remote.recv(1024)
    if not data:
        break
    input += data
if input == '${_CB_REMOTE_PASTE_REQUEST_TOKEN}':
    clipboard = subprocess.check_output(['$0',  '--force-paste'])
    remote.sendall(clipboard)
    print 'Pasted'
    print clipboard
else:
    process = subprocess.Popen(['$0'], stdin=subprocess.PIPE)
    process.communicate(input)
    process.poll()
    print 'Copied'
    print input
remote.close()
s.close()
END
        if [ $? -ne 0 ]; then
            break
        fi
    done
}

_cb() {
    if [ "$1" = "--force-paste" ]; then
        _cb_paste
    elif [ "$1" = "--listen" ]; then
        _cb_listen
    else
        test -t 0 && _cb_paste || _cb_copy
    fi
}

alias ${_CB_CMD:-cb}='_cb 2>&1'
