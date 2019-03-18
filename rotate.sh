#!/bin/bash
#set -x

DP=$(xrandr | grep primary | awk '{print $1}')

declare -A MATRIX_DICT
MATRIX_DICT=(
    [normal]='1 0 0 0 1 0 0 0 1' 
    [left]='0 -1 1 1 0 0 0 0 1' 
    [right]='0 1 0 -1 0 1 0 0 1' 
    [inverted]='-1 0 1 0 -1 1 0 0 1'
)

function rotate
{
    xrandr --output "$1" --rotate "$2"

    TRANSFORM='Coordinate Transformation Matrix'
    MATRIX=(${MATRIX_DICT["$2"]})
    xinput list | grep pointer | grep -v 'Virtual core' | grep -o 'id=[0-9]*' | sed 's/id=//' | xargs -I{}  xinput set-prop {} "$TRANSFORM" "${MATRIX[@]}"
}

if [ -z "$1" ] || [ -z "${MATRIX_DICT[$1]}" ] ; then
    opts=$(echo "${!MATRIX_DICT[*]}" | sed 's/ /\|/g')
    echo -e "Usage:\n\t$0 [$opts]"

    echo
    exit 1
fi

rotate "$DP" "$1"
