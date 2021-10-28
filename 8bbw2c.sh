#!/usr/bin/env sh
#
# ###################################################################################
# File: 8bbw2c.sh
# Project: image2c - B/W image to 8-bit C/C++ array (see $VERS)
# File Created: Monday, 29th June 2020 1:25:24 am
# Author: sk
# Last Modified: Thursday, 28th October 2021 5:05:56 pm
# Modified By: Sergey Ko
# License: CC-BY-NC-4.0 (https://creativecommons.org/licenses/by-nc/4.0/legalcode)
# ###################################################################################
# CHANGELOG:
# ###################################################################################
#
ARGS=$@
INVT=0
TYPDFS=0
DR=$(pwd)
DO="/out"
DI="/in"
DRO=$DR$DO
DRI=$DR$DI
VERS="1.1"
GDT=$(date +"%d.%m.%Y %H:%m:%S")
# functions
function help {
    echo "\033[32mUSAGE:\033[0m "$0" [-options] [filemame]\n"
    echo "- Options:"
    echo "  ------------------------------------------------"
    echo "   \033[1m-w\033[0m <value>      image width (obligatory)"
    echo "   \033[1m-h\033[0m <value>      image height (obligatory)"
    echo "   \033[1m-i\033[0m              invert image colors"
    echo "   \033[1m-td\033[0m             include typedefs in output file"
    echo "  ------------------------------------------------"
    echo "   \033[1m-ls\033[0m             list all files from input dir,"
    echo "                   suitable for convertion"
    echo "   \033[1m-cleanout\033[0m       to clean only \033[4moutput\033[0m directory"
    echo "   \033[1m-clean\033[0m          to clean \033[4mALL\033[0m project directories"
    echo "  ------------------------------------------------"
    echo "\n\033[33mDESCRIPTION:\033[0m The script converts two color B/W image bin files\n\
             into 8-bit compressed C-format. \n\
             To avoid unexpected results, please use only grayscaled images.\n"
    exit 0
}
function error {
    echo "\n    \033[41m Error: \033[0m "$1"\n"
}
function lsinp {
    if find $DRI -mindepth 1 -type f | read; then
        echo "    image files found:"
        for l in $(find $DRI -name '*' -exec file {} \; | \
            grep -o -E '^.+: \w+ image' | awk '/(.)+\: (.+)/{print $1}' | \
            sed 's:\:::')
        do
            echo "      "$(basename "$l")
        done
    else
        echo "    No suitable files detected in \033[100m ."$DI" \033[0m"
    fi
}
function final_cleanup {
    rm $FT > /dev/null 2>&1
}
# check for magick
if [ -z $(command -v convert) ]; then
    error "please install ImageMagick"
    exit 0
fi

# before all check if there any arguments
if [ -z "$ARGS" ]; then
    TW=$(stty size | awk '{print $2}')
    echo ""
    echo "   \033[44;30;1m v"$VERS" \033[0m" | { N=$(((TW/2)-5)); perl -pe "s/^/' 'x$N/e" ; }
    echo ""
    help
    exit 0
fi
# args
np=""
for n in $ARGS; do
    if [ "$np" = "-w" ]; then
        W=$n
    elif [ "$np" = "-h" ]; then
        H=$n
    elif [ "$np" = "-i" ]; then
        INVT=1
    elif [ "$n" = "-td" ]; then
        TYPDFS=1
    elif [ "$n" = "-cleanout" ]; then
        echo ""
        if find $DRO -mindepth 1 | read; then
            rm $(echo $DRO"/*") > /dev/null 2>&1
            echo "    \033[100m ."$DO" \033[0m - emptied"
        else
            echo "    \033[100m ."$DO" \033[0m - no content"
        fi
        echo ""
        exit 0
    elif [ "$n" = "-clean" ]; then
        echo ""
        if find $DRO -mindepth 1 | read; then
            rm $(echo $DRO"/*") > /dev/null 2>&1
            echo "    \033[100m ."$DO" \033[0m - emptied"
        else
            echo "    \033[100m ."$DO" \033[0m - no content"
        fi
        if find $DRI -mindepth 1 | read; then
            rm $(echo $DRI"/*") > /dev/null 2>&1
            echo "    \033[100m ."$DI"  \033[0m - emptied"
        else
            echo "    \033[100m ."$DI"  \033[0m - no content"
        fi
        echo ""
        exit 0
    elif [ "$n" = "-ls" ]; then
        echo ""
        lsinp
        echo ""
        exit 0
    fi
    np=$n
done
unset np

# paths & names (input file should be an image)
SC="${@: -1}"
FI=$DRI"/"$SC
NM=$(basename "$SC" | sed 's/\.[^.]*$//')
FO=$DRO"/"$NM".h"
FT=$DRO"/"$NM"_tmp."$[($RANDOM%100)]
CEST=""

# check the input file
if ! file "$FI" | grep -qE 'image|bitmap'; then
    error "input file is not an image"
    exit 0
fi

# check arguments
if [ -z "$W" ] || [ -z "$H" ]; then
    error "image Width or Height is not specified. Check arguments."
    help
fi

# check input file
if ! test -f "$FI"; then
    error "no such file :("
    lsinp
    echo ""
    help
fi

# check output file
if test -f "$FO"; then
    (rm $FO) > /dev/null 2>&1
fi
touch $FO
touch $FT
####################
# prepare the source
####################
# TODO: threshold for color images
CMD1=""
MSG1="non-inverted"
if [ $INVT -eq 1 ]; then
    CMD1="-negate"
    MSG1="\033[1minverted\033[0m"
fi
(convert $FI +flip -strip $CMD1 -colorspace Gray \
-threshold 90% -define bmp:subtype=RGB565 bmp2:- | \
dd bs=26 skip=1  > $FT) > /dev/null 2>&1

if [ ! -s "$FT" ]; then
    error "something went wrong. check the source image..."
    final_cleanup
    exit 0
fi

##################
# typedefs
##################
if [ $TYPDFS -eq 1 ]; then
    echo "typedef struct {\n\
    const uint8_t * bitmap;\n\
    uint16_t        width;\n\
    uint16_t        height;\n} bw8b_t;\n" >> $FO
fi

###################
# begin output file
###################
HDR="/**\n * fmt: 8-bit B/W compressed image map"
HDR=$HDR"\n * img: "$NM"\n * bmp: "$NM"_bmp ("$MSG1")\n * gen: \
"${0/\.\/}" (v."$VERS") at "$GDT"\n*/\nconst uint8_t \
"$NM"_bmp[] PROGMEM = {"
echo "$HDR" >> $FO

RAW=$(cat $FT | hexdump -v -e '/2 "%04X "' 2>&1)
CFB=""
CEC=0
FSIZECMP=0
FSIZE=0
FISIZE=$(wc -c < "$FI" | sed -e 's: ::g')
BF=""
CNTR0=0

#### STRUCTURE (COMPRESSED): [0xCOLOR],[0xCOUNT],[0xCOLOR],[0xCOUNT]...
for c in $RAW; do
    # very first byte
    CNTR0=$((CNTR0+5))
    if [ "$CFB" != "$c" ] || [ $CEC -ge 255 ] || [ $CNTR0 -ge ${#RAW} ]; then
        if [ "$CFB" = "" ]; then
            CFB=$c
            CEC=$((CEC+1))
        else
            # the very last word
            if [ $CNTR0 -ge ${#RAW} ] && [ "$CFB" == "$c" ]; then
                CEC=$((CEC+1))
            fi
            BF=$BF"0x"${CFB:0:2}",0x"$(printf "%02X" $CEC)","
            CFB=$c
            CEC=1
            FSIZECMP=$((FSIZECMP+2))
            if [ $FSIZECMP -gt 0 ] && [ $((FSIZECMP%16)) -eq 0 ]; then
                echo $BF >> $FO
                BF=""
            fi
        fi
    else
        CEC=$((CEC+1))
    fi
    FSIZE=$((FSIZE+2))
done
# take care about the abnormalities
if [ -n "$BF" ]; then
    echo $BF >> $FO
    BF=""
fi

echo "\n- Input: ."$DI"/"$SC" \033[1m=>\033[0m 8-bit compressed "$MSG1" map"

echo "};\n" >> $FO

echo "const bw8b_t "$NM" PROGMEM = {\n\
    "$NM"_bmp,\n\
    "$W", "$H"\n};\n" >> $FO

CELV=$((100-((FSIZECMP*100)/FSIZE)))

echo "// image size "$FSIZECMP" byte(s) (compr.: "$CELV"%)\n" >> $FO

# stats
echo "    \033[33m"$FISIZE"\033[0m bytes source image"
echo "    \033[33m"$FSIZE"\033[0m bytes total"
echo "    \033[32m"$FSIZECMP"\033[0m bytes image created"
echo "    \033[35m"$CELV"%\033[0m compression level"
echo "- Output: \033[90m"$FO"\033[0m\n"

##################
# cleanup
##################
final_cleanup

exit 0