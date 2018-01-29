#!/usr/bin/env bash
#########################################################################
# File Name: extdp
# Author: minyu
# mail: minyu7374@gmail.com
# Created Time: Sat 27 Jan 2018 8:21:32 AM CST
#########################################################################
buildin_dpname="eDP-1-1" 
buildin_width=3840
buildin_height=2160

declare -A width_scale_dic
declare -A height_scale_dic

width_scale_dic[1920]=1.75
height_scale_dic[1080]=1.75
height_scale_dic[1200]=1.5

width_scale_dic[1600]=2.25
height_scale_dic[900]=2.25

width_scale_dic[1366]=2.5
width_scale_dic[1024]=3.5
height_scale_dic[768]=2.5

# 方向参数还是不要写进xrandr命令里，通过fb和pos的控制更准确，加入方向反而会有重叠。
# positions=("right-of" "left-of" "over" "below" "same-as")
rotates=("normal" "inverted" "right" "left")

max() 
{
    v=$1; shift
    while [ -n "$1" ]; do
        if [ "$1" -gt "$v" ]; then v=$1; fi
        shift 
    done
    echo "$v"
}

# 不在字典内的分辨率，先用这个公式（只是自己拍脑袋定的，没有数学依据)估算
# 个人强迫症，要求scale保证是 0.25 的倍数
near_scale()
{
    s=$(echo "scale=2;$2/$1*0.85" | bc)
    m=$(echo "($s/0.25)+1.0"| bc | cut -d. -f1)
    echo "$m*0.25" | bc
}

extdp-info() 
{
    xrandr | grep -A 1 '\bconnected' | grep -v '^--$' |awk '{if (NR%2==1) {name=$1} else {split($1, resolution, "x"); print name, resolution[1], resolution[2]}}' | grep -v "$buildin_dpname"
}

extdp-scale()
{
    width=$1
    height=$2
    
    width_scale=${width_scale_dic["$width"]}
    height_scale=${height_scale_dic["$height"]}
    

    if [ -z "$width_scale" ]; then
        width_scale=$(near_scale "$width" "$buildin_width")
    fi
    if [ -z "$height_scale" ]; then
        height_scale=$(near_scale "$height" "$buildin_height")
    fi

    echo "$width_scale" "$height_scale"
}

extdp-exec()
{
    name=$1          # DP-1/DP-3
    width=$2
    height=$3
    width_scale=$4
    height_scale=$5
    position=$6      # 0: right 1: left 2: over 3: below 4:same
    rotate=$7        # 0: normal(0°) 1: inverted(180°) 2: right(90°) 3: left(270°)

    panning_width=$(echo "$width*$width_scale" | bc | cut -d. -f1)
    panning_height=$(echo "$height*$height_scale" | bc | cut -d. -f1)
    
    case "$rotate" in
        0);&
        1)
            # 0° / 180°
            fb_ext_width=$panning_width
            fb_ext_height=$panning_height
            ;;
        2);&
        3)
            # 90° / 270°
            fb_ext_width=$panning_height
            fb_ext_height=$panning_width
            ;;
        *)
            echo "wrong rotate" >&2
            exit 1
            ;;
    esac
    
    case "$position" in
        0);&
        1)
            # right / left
            fb_width=$((buildin_width+fb_ext_width))
            fb_height=$(max "$buildin_height" "$fb_ext_height")
            ;;
        2);&
        3)
            # over / below
            fb_height=$((buildin_height+fb_ext_height))
            fb_width=$(max "$buildin_width" "$fb_ext_width")
            ;;
        4)
            # same
            fb_height=$(max "$buildin_height" "$fb_ext_height")
            fb_width=$(max "$buildin_width" "$fb_ext_width")
            ;;
        *)
            echo "wrong position" >&2
            exit 1
            ;;
    esac

    case "$position" in
        0)
            # right
            in_pos_x=0
            in_pos_y=0
            ext_pos_x=$buildin_width
            ext_pos_y=0
            ;;
        1)
            # left
            ext_pos_x=0
            ext_pos_y=0
            in_pos_x=$fb_ext_width
            in_pos_y=0
            ;;
        2)
            # over
            ext_pos_x=0
            ext_pos_y=0
            in_pos_x=0
            in_pos_y=$fb_ext_height
            ;;
        3)
            # below
            in_pos_x=0
            in_pos_y=0
            ext_pos_x=0
            ext_pos_y=$buildin_height
            ;;
        4)
            # same
            in_pos_x=0
            in_pos_y=0
            ext_pos_x=0
            ext_pos_y=0
            ;;
    esac
    
    # 针对NVIDIA的bug (https://askubuntu.com/questions/704503/scale-2x2-in-xrandr-causes-the-display-to-not-display-anything/979551#979551)
    # 个人笔记本上(安装的Gentoo)是这样命名的，其他系统或笔记本可能不同
    meta_mode=${name/DP/DPY}
    nvidia-settings --assign CurrentMetaMode="${meta_mode}: nvidia-auto-select @${width}x${height} +${ext_pos_x}+${ext_pos_y} {ViewPortIn=${width}x${height}, ViewPortOut=${width}x${height}+${ext_pos_x}+${ext_pos_y}, ForceFullCompositionPipeline=On}"

    ext_rotate=${rotates["$rotate"]}
    # ext_postion=${positions["$position"]}
    eval "xrandr --fb ${fb_width}x${fb_height} --output ${buildin_dpname} --auto --pos ${in_pos_x}x${in_pos_y} --output $name --mode ${width}x${height} --panning ${panning_width}x${panning_height}+${ext_pos_x}+${ext_pos_y} --scale ${width_scale}x${height_scale} --pos ${ext_pos_x}x${ext_pos_y} --rotate ${ext_rotate}" # --${ext_postion} ${buildin_dpname}
}

extdp-auto() {
    extdp_info=$(extdp-info)
    if [ -z "$extdp_info" ]; then
        echo "find no external display"
        exit 0
    fi
    extdp_info_arr=($extdp_info)
    # read -a extdp_info_arr <<< "$extdp_info"
    extdp_name=${extdp_info_arr[0]}
    extdp_width=${extdp_info_arr[1]}
    extdp_height=${extdp_info_arr[2]}
    
    scales=$(extdp-scale "$extdp_width" "$extdp_height") 
    scales_arr=($scales)
    # echo ${scales[@]}
    width_scale=${scales_arr[0]}
    height_scale=${scales_arr[1]}
    
    extdp-exec "$extdp_name" "$extdp_width" "$extdp_height" "$width_scale" "$height_scale" 1 0
}

# extdp-auto
temp=$(getopt -o aimshN:W:H:X:Y:P:R: --long auto,info,manual,suggest,help,dpname:,width:,height:,width-scale:,height-scale:,postion:rotate: -n "$0" -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$temp"

auto=false
info=false
manual=false
suggest=false
help=false
options_count=0

N="DP-1"
W=1920
H=1080
X=${width_scale_dic["$W"]}
Y=${height_scale_dic["$H"]}
P=0
R=0

while true ; do
    case "$1" in
        -a|--auto) 
            auto=true; ((options_count++)); shift ;;
        -i|--info) 
            info=true; ((options_count++)); shift ;;
        -m|--manual)
            manual=true; ((options_count++)); shift ;;
        -s|--suggest)
            suggest=true; ((options_count++)); shift ;;
        -h|--help)
            help=true; ((options_count++)); shift ;;
        -N|--dpname)
            if [ -n "$2" ] ; then N=$2; fi; shift 2 ;;
        -W|--width)
            if [ -n "$2" ] ; then W=$2; fi; shift 2 ;;
        -H|--height)
            if [ -n "$2" ] ; then H=$2; fi; shift 2 ;;
        -X|--width-scale)
            if [ -n "$2" ] ; then X=$2; fi; shift 2 ;;
        -Y|--height-scale)
            if [ -n "$2" ] ; then Y=$2; fi; shift 2 ;;
        -P|--postion)
            if [ -n "$2" ] ; then P=$2; fi; shift 2 ;;
        -R|--rotate)
            if [ -n "$2" ] ; then R=$2; fi; shift 2 ;;
        --) 
            shift ; break ;;
        *) 
            echo "Internal error!" >&2; exit 1 ;;
    esac
done

help-info()
{
    echo -e "Usage:\n\t$0 <OPTION> [PARAM]..."
    echo -e "Example:\n\t$0 -m -N 'DP-1' -W 1920 -H 1080 -X 1.75 -Y 1.75 -P 1 -R 0"
    echo '
    OPTION:
        -a, --auto          auto detect the external display and scale it on left of the laptop
        -i, --info          get info(name and resolution) about the external display
        -m, --manual        scale the external display by the params manual given(will use all of the params)
        -s, --suggest       give a scale suggest based on the params W and H
        -h, --help          show help info
    PARAM:
        -N, --dpname        name of the external display
        -W, --width         width of the external display resolution(default: 1920)
        -H, --height        height of the external display resolution(default: 1080)
        -X, --width-scale   scale of width
        -Y, --height-scale  scale of height
        -P, --postion       external display position relative to the laptop
                                0: right(default) 1: left 2: over 3: below 4: same
        -R, --rotate        let the external display to be rotated in the specified direction
                                0: normal(default, 0°) 1: inverted(180°) 2: right(90°) 3: left(270°)
    '
}

if [ $options_count -eq 0 ]; then
    echo -e "You must specify one of the '-aimsh'.\n  try '$0 -h' or '$0 --help' for more information." >&2
    exit 1
fi

if [ $options_count -gt 1 ]; then
    echo "You can only specify one of the '-aimsh'" >&2
    exit 1
fi

if [ $auto = true ]; then extdp-auto; exit; fi
if [ $info = true ]; then ext_info=$(extdp-info); if [ -n "$info" ]; then echo "$ext_info"; else "find no external display"; fi; exit; fi
if [ $manual = true ]; then extdp-exec "$N" "$W" "$H" "$X" "$Y" "$P" "$R"; exit; fi
if [ $suggest = true ]; then extdp-scale "$W" "$H"; exit; fi
if [ $help = true ]; then help-info; exit; fi
