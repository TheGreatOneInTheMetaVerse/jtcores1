#!/bin/bash
# Show the pause screen

../../../bin/jtcommando_msg.py

function check_hex_file {
    if [ ! -e $1 ]; then
        if [ ! -e ../../mist/$1 ]; then
            echo Missing HEX files for PAUSE screen. Attempting to generate them:
            olddir=$(pwd)
            cd ../../../bin
            python avatar.py
            cd $olddir
        fi
        echo INFO: Created symbolic link to $1
        ln -s ../../mist/$1
    fi
}

# check_hex_file avatar.hex
# check_hex_file avatar_xy.hex
# check_hex_file avatar_pal.hex
# check_hex_file avatar_obj.hex

# use -d AVATARS to add AVATAS to simulation:
if ! go.sh -frame 1 $*  -video -mist -d DIP_TEST -nosnd \
    -d NOMAIN -d ALWAYS_PAUSE -d NOSCR -d SCANDOUBLER_DISABLE; then
    exit 1
fi

for i in *png; do
    convert $i -crop 290x260+50+0 -rotate -90 -resize 300%x300% $i
done