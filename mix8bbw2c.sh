#!/usr/bin/env sh
#
# ###################################################################################
# File: mixer_8bbw2c.sh
# Project: image2c (<<projectversion>>)
# File Created: Monday, 29th June 2020 1:25:24 am
# Author: sk
# Last Modified: Thursday, 28th October 2021 5:06:00 pm
# Modified By: Sergey Ko
# License: CC-BY-NC-4.0 (https://creativecommons.org/licenses/by-nc/4.0/legalcode)
# ###################################################################################
# CHANGELOG:
# 2020-07-02	added alpha color option
# 2020-07-24	improvements (the smalles image is the base btm, etc)
# ###################################################################################
#
ARGS=$@
INVT=0
TYPDFS=0
DR=$(pwd)
DO="/out"
DI="/mix"
DT="/.tmp"
DRO=$DR$DO
DRI=$DR$DI
DRT=$DR$DT
VERS="1.3"
GDT=$(date +"%d.%m.%Y %H:%m:%S")
# functions
function help {
    echo "\033[32mUSAGE:\033[0m "$0" [[-option]|[name]]\n"
    echo "- Options:"
    echo "  ------------------------------------------------"
    echo "   \033[1m-i\033[0m                invert image colors"
    echo "   \033[1m-td\033[0m               include typedefs in output file"
    echo "  ------------------------------------------------"
    echo "   \033[1m-ls\033[0m               list all files from input dir,"
    echo "                     suitable for convertion"
    echo "   \033[1m-help\033[0m             show this help"
    echo "  ------------------------------------------------"
    echo "\n\033[33mDESCRIPTION:\033[0m The script using images from \033[1m."$DI"\033[0m directory\n\
             and converts them into 8-bit compressed C/C++ array. \n\
             To avoid unexpected results, please use only grayscaled\n\
             images with equal dimmensions.\n"
    exit 0
}
function error {
    echo "\n    \033[41m Error: \033[0m "$1"\n"
}
function lsinp {
    if find $DRI -mindepth 1 -type f | read; then
        echo "    image files found:"
        for l in $(find ./in -name '*' -exec file {} \; | \
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
    rm -R "$DRT" > /dev/null 2>&1
}
# check for magick
if [ -z $(command -v convert) ]; then
    error "please install ImageMagick"
    exit 0
fi

# if no args specified
if [ -z "$ARGS" ]; then
    error "name your creation!"
    exit 0
fi

# check initial data
for n in $ARGS; do
    if [ "$n" = "-ls" ]; then
        echo ""
        lsinp
        echo ""
        exit 0
    elif [ "$n" = "-i" ]; then
        INVT=1
    elif [ "$n" = "-help" ] || [ "$n" = "-h" ]; then
        TW=$(stty size | awk '{print $2}')
        echo ""
        echo "   \033[44;30;1m v"$VERS" \033[0m" | { N=$(((TW/2)-5)); perl -pe "s/^/' 'x$N/e" ; }
        echo ""
        help
        exit 0
    elif [ "$n" = "-td" ]; then
        TYPDFS=1
    else
        # name given
        PNAME=$n
    fi
done

# if not enough args
if [ "$#" -lt 2 ]; then
    error "still not enough data, try -help(-h)"
    exit 0
fi

# check the temp directory
# create it if not exists, clean if not empty
if [ ! -d $DRT ]; then
    mkdir $DRT
elif [ "$(ls -A $DRT)" ]; then
    rm -R $(echo $DRT"/*") > /dev/null 2>&1
fi

# paths & names (input file should be an image)
FO=$DRO"/"$PNAME".h"
if test -f "$FO"; then
    (rm $FO) > /dev/null 2>&1
fi
touch $FO
# array of the source files
declare -a FSMPS
# array of the temp files
declare -a FTMPS
# array of the filenames
declare -a FDBMS
# array of cunk paths
declare -a FTCHUNKS
IMGW0=0
IMGH0=0
IMGW1=0
IMGH1=0
CNTR0=0
CNTR1=0
CNTR2=0
CMD1=""
# inversion clause
MSG1="non-inverted"
if [ $INVT -eq 1 ]; then
    CMD1="-negate"
    MSG1="\033[1minverted\033[0m"
fi

##################
# images to binary
##################
# for mf in $(find $DRI -name '*' -exec file {} \; | \
#             grep -o -E '^.+: \w+ image' | awk '/(.)+\: (.+)/{print $1}' | \
#             sed 's:\:::')
for mf in $(ls -rSB $DRI); do
    mf=$(echo $(file $DRI"/"$mf) | grep -o -E '^.+: \w+ image' | awk '/(.)+\: (.+)/{print $1}' | \
            sed 's:\:::')
    FSMPS[$CNTR0]=$mf
    NM=$(basename "$mf" | sed 's/\.[^.]*$//')
    FTMPS[$CNTR0]=$DRT"/"$NM"_tmp."$[($RANDOM%100)]
    T1=$(identify -ping -format '%w %h' $mf)
    IMGW1=$(echo $T1 | awk '{print $1}')
    IMGH1=$(echo $T1 | awk '{print $2}')
    if [ $IMGH1 -ne $IMGH0 ] || [ $IMGW0 -ne $IMGW1 ] && [ $IMGH0 -gt 0 ] && [ $IMGW0 -gt 0 ]; then
        error "source images are different size..."
        final_cleanup
        exit 0
    fi
    # doing conversion
    (convert $mf +flip -strip $CMD1 -colorspace Gray \
        -threshold 90% -define bmp:subtype=RGB565 bmp2:- | \
        dd bs=26 skip=1  > ${FTMPS[$CNTR0]}) > /dev/null 2>&1

    if [ ! -s "${FTMPS[$CNTR0]}" ]; then
        error "something went wrong. check the source images..."
        final_cleanup
        exit 0
    fi

    # save the destination bitmap name
    FDBMS[$CNTR0]=$NM

    CNTR0=$((CNTR0+1))
    IMGH0=$IMGH1
    IMGW0=$IMGW1
done

# temporary FTMPS files count
CNTR1=${#FTMPS[@]}
# temporary FTMPS file size count (base btm added)
CNTR2=$((IMGW0*IMGH0*2))
# temporary counter for FTMPS files
# skip the very first TMP file since it's a base btm
CNTR3=1
# general purpose cntr
CNTR4=0
# size in bytes of all images (after conversion) together
SIZETT=$(((IMGW0*IMGH0*2*${#FSMPS[@]})))
# count of bytes saved (before compression)
SIZEBC=$CNTR2
# count of bytes at the end of all procedures
SIZEFL=0
# temporary counter for FTMPS file bytes
CNTR0=0
# difference array for the reference file
BA0=""
BA0PS=0
BA0PE=0
# difference array for current file
BA1=""
BA1PS=0
##################
# seek differences
##################
CHUNKCNTR=0
CHUNKPATH0=""
# reference file
RAW0=($(cat "${FTMPS[0]}" | hexdump -v -e '/2 "%04X "' 2>&1))
# for each image file that found
while [ $CNTR3 -lt $CNTR1 ]; do
    # take one file as a reference and compare the others with it
    RAW1=($(cat "${FTMPS[$CNTR3]}" | hexdump -v -e '/2 "%04X "' 2>&1))
    # start comparison (CNTR2 - image btm lenght)
    while [ $CNTR0 -le $CNTR2 ]; do
        # everything but the last byte
        if [ $CNTR0 -ne $CNTR2 ] && [ "${RAW0[$CNTR0]}" != "${RAW1[$CNTR0]}" ]; then
            # start difference array
            # check if the chunk already exists
            CHUNKPATH0=$(echo $DRT"/"${FDBMS[$CNTR3]}".chunk")
            if [ ! -f "$CHUNKPATH0" ]; then
                touch $CHUNKPATH0
                FTCHUNKS[$CHUNKCNTR]=$CHUNKPATH0
                CHUNKCNTR=$((CHUNKCNTR+1))
            fi
            # save start position
            if [ $BA1PS -eq 0 ]; then
                BA1PS=$CNTR0
            fi
            BA1=$BA1" "${RAW1[$CNTR0]}
            # statistics
            SIZEBC=$((SIZEBC+2))
        else
            # the last byte of the chunk (when $CNTR0 -eq $CNTR2)
            if [ -n "$CHUNKPATH0" ]; then
                # Attention: each row in chunk begins with [16bit start][16bit length]
                # then color bytes will follow [16bit color][16bit color]...
                echo $(printf "%04X" $BA1PS)" "$(printf "%04X" $((CNTR0-BA1PS)))$BA1 >> $CHUNKPATH0
                BA1=""
                BA1PS=0
                CHUNKPATH0=""
            fi
        fi
        # next word
        CNTR0=$((CNTR0+1))
    done
    CNTR0=0
    # next tmp file
    CNTR3=$((CNTR3+1))
done
RAW1=""

##################
# typedefs
##################
if [ $TYPDFS -eq 1 ]; then
    # echo "typedef struct {\n\
    # const uint16_t * bitmap;\n\
    # uint8_t         width;\n\
    # uint8_t         height;\n} bw8b_t;\n" >> $FO
    echo "typedef struct {\n\
    const uint8_t * bitmap;  //* base bitmap \n\
    const uint8_t * chunk;   //* chunk to be replaced inside of the bitmap\n\
    uint16_t        width;   //* bitmap width\n\
    uint16_t        height;  //* bitmap height\n\
    uint16_t        length;  //* chunk length\n} chunk8b_t;\n" >> $FO
fi

##################
# compressing
##################
echo "\n- Input: all files from ."$DI" \033[1m=>\033[0m 8-bit chunked compressed "$MSG1" map"
# begin FO
HDR="/**\n * fmt: 8-bit B/W chunked compressed image map\
\n * img: "$PNAME"\n * bmp: "$PNAME"_bmp ("$MSG1")\n * gen: \
"${0/\.\/}" (v."$VERS") at "$GDT"\n*/\nconst uint8_t \
"${FDBMS[0]}"_base_bmp[] PROGMEM = {"
echo "$HDR" >> $FO
##################
# base bitmap
##################
CFB=""
CEC=0
BF=""
CNTR3=0
CNTR0=0
RAW0=$(cat "${FTMPS[0]}" | hexdump -v -e '/2 "%04X "' 2>&1)
for c in $RAW0; do
    CNTR0=$((CNTR0+5)) # 4 digits and space
    # very first byte
    if [ "$CFB" = "" ]; then
        CFB=$c
    fi
    if [ "$CFB" != "$c" ] || [ $CEC -ge 255 ] || [ $CNTR0 -ge ${#RAW0} ]; then
        if [ $CNTR0 -ge ${#RAW0} ]; then
            CEC=$((CEC+1))
        fi
        BF=$BF"0x"${CFB:0:2}",0x"$(printf "%02X" $CEC)","
        CFB=$c
        CEC=1
        CNTR3=$((CNTR3+2))
        if [ $CNTR3 -gt 0 ] && [ $((CNTR3%16)) -eq 0 ]; then
            echo $BF >> $FO
            BF=""
        fi
        # statistics
        SIZEFL=$((SIZEFL+2))
    else
        CEC=$((CEC+1))
    fi
done
# handling abnormalities
if [ -n "$BF" ]; then
    echo $BF >> $FO
    BF=""
fi
echo "};\n" >> $FO

echo "const chunk8b_t "${FDBMS[0]}"_chunk PROGMEM = {\n\
    "${FDBMS[0]}"_base_bmp,\n\
    0,\n\
    "$IMGW0", "$IMGH0", 0\n};\n" >> $FO

##################
# chunk bitmaps
##################
CNTR4=0 # skip first chunk
while [ $CNTR4 -lt ${#FTCHUNKS[@]} ]; do
    # read chunk line by line
    echo "const uint8_t "${FDBMS[$((CNTR4+1))]}"_chunk_bmp[] PROGMEM = {" >> $FO
    CHUNKLEN=0
    while read RAW1; do
        CNTR3=0
        CFB=""
        CEC=0
        BF=""
        # by line
        CNTR0=0
        for b in $RAW1; do
            CNTR0=$((CNTR0+5))  # 4 digits and space
            # skip first 4 bytes of every line
            # those are [16bit for width][16bit for height]
            if [ $CNTR3 -lt 4 ]; then
                BF=$BF"0x"${b::2}",0x"${b:2:4}","
                # statistics
                SIZEFL=$((SIZEFL+2))
                CHUNKLEN=$((CHUNKLEN+2))
            else
                # the following are [8bit color][8bit length]
                if [ "$CFB" != "$b" ] || [ $CEC -ge 255 ] || [ $CNTR0 -ge ${#RAW1} ]; then
                    # multiple equal values at the end
                    if [ $CNTR0 -ge ${#RAW1} ] && [ "$CFB" == "$b" ]; then
                        CEC=$((CEC+1))
                    fi
                    # very first byte
                    if [ "$CFB" = "" ]; then
                        CFB=$b
                        CEC=$((CEC+1))
                        if [ $CNTR0 -ge ${#RAW1} ]; then
                            BF=$BF"0x"${CFB:0:2}",0x"$(printf "%02X" $CEC)","
                            # statistics
                            SIZEFL=$((SIZEFL+2))
                        fi
                    else
                        BF=$BF"0x"${CFB:0:2}",0x"$(printf "%02X" $CEC)","
                        # the very last word
                        if [ $CNTR0 -ge ${#RAW1} ] && [ "$CFB" != "$b" ]; then
                            BF=$BF"0x"${b:0:2}",0x01,"
                            # statistics
                            SIZEFL=$((SIZEFL+2))
                        fi
                        CFB=$b
                        CEC=1
                        CHUNKLEN=$((CHUNKLEN+2))
                        # statistics
                        SIZEFL=$((SIZEFL+2))
                    fi
                else
                    CEC=$((CEC+1))
                fi
                # skip a new line byte
                if [ $CNTR0 -ge ${#RAW1} ]; then
                    if [ -n "$BF" ]; then
                        echo $BF >> $FO
                        BF=""
                    fi
                    break;
                fi
            fi
            CNTR3=$((CNTR3+2))
        done
    done < ${FTCHUNKS[$CNTR4]}
    # adding chunk array
    echo "};\n" >> $FO
    echo "const chunk8b_t "${FDBMS[$((CNTR4+1))]}"_chunk PROGMEM = {\n\
    "${FDBMS[0]}"_base_bmp,\n\
    "${FDBMS[$((CNTR4+1))]}"_chunk_bmp,\n\
    "$IMGW0", "$IMGH0", "$CHUNKLEN"\n};\n" >> $FO
    CNTR4=$((CNTR4+1))
done
# TODO: wrong results when compression is more than 100%
CELV=$((100-((SIZEFL*100)/SIZEBC)))

echo "// image size "$SIZEFL" byte(s) (compr.: "$CELV"%)\n" >> $FO

# stats
echo "    \033[33m"${#FSMPS[@]}"\033[0m images found"
echo "    \033[33m"$SIZETT"\033[0m bytes total of source images"
echo "    \033[32m"$((SIZETT-SIZEBC))"\033[0m bytes trimmed using chunks"
echo "    \033[32m"$SIZEFL"\033[0m bytes map created"
echo "    \033[35m"$CELV"%\033[0m compression level"
echo "    \033[35m"$((SIZETT-SIZEFL))"\033[0m bytes of saved space"
echo "- Output: \033[90m"$FO"\033[0m\n"

##################
# cleanup
##################
final_cleanup
# unset FSMPS FTMPS FDBMS RAW0 RAW1

exit 0