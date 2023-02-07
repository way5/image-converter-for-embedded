#!/usr/bin/env sh
# ###################################################################################
# File: img2bin.sh
# Project: img2bin - converts image into RGB565 binary or C/C++ data structure
# File Created: Monday, 30th January 2023 1:04:16 pm
# Author: sk
# Last Modified: Friday, 3rd February 2023 12:13:51 am
# Modified By: Sergey Ko
# License: CC-BY-NC-4.0 (https://creativecommons.org/licenses/by-nc/4.0/legalcode)
# ###################################################################################
# CHANGELOG:
# ###################################################################################
ARGS=$@
ALPHA=0
ALPHAC=0
BGC=""
BPP=2
CE=0
COMPR=0
DR=$(cd $(dirname "$0") && pwd)
DO="/out"
DI="/in"
DRT=$DR"/.tmp"
DISBF=0
DRO=$DR$DO
DRI=$DR$DI
FORMAT0="RGB565"
GDT=$(date +"%d/%m/%Y %H:%m:%S")
H=0
HO=0
CNTR0=0
CNTR1=0
RESIZE=0
RAW=""
TMP0=""
TMP1=""
TMP2=""
VERS="1.3"
W=0
WO=0
# functions
function help {
    echo "\033[32mUSAGE:\033[0m "$0" [-options] [filemame]\n"
    echo "- Options:"
    echo "  ----------------------------------------------------------"
    echo "   \033[1m-r\033[0m  <width>:<height>     resize output image"
    echo "   \033[1m-b\033[0m  <value>              bytes per pixel (default: 2)"
    echo "   \033[1m-c\033[0m                       save as C/C++ hex array"
    echo "   \033[1m-bg\033[0m                      background color (HEX color)"
    echo "   \033[1m-d\033[0m                       preserve original color sequence\n\
                            (RGB) in output arrays"
    # echo "   \033[1m-z\033[0m                       compress data"
    echo "  ----------------------------------------------------------"
    echo "   \033[1m-ls\033[0m                      list all files from input dir,"
    echo "                            suitable for convertion"
    echo "   \033[1m-clean\033[0m                   clean up only \033[4moutput\033[0m directory"
    echo "   \033[1m-purge\033[0m                   clean up \033[4mALL\033[0m project directories"
    echo "  ----------------------------------------------------------"
    echo "\n\033[33mDESCRIPTION:\033[0m Converts image into RGB565 binary or C/C++ data structure.\n"
    exit 0
}
function error {
    echo "\n    \033[41m Error: \033[0m "$1"\n"
}
function lsinp {
    if find $DRI -mindepth 1 -type f -name '*.jpg' -or -name '*.png' | read; then
        echo "    here is what we have:"
        for l in $(find $DRI -type f -name '*.jpg' -or -name '*.png'); do
            echo "      "$(basename "$l")
            #  | sed -E -r 's/\.(jpg|png)//')
        done
    else
        echo "    No suitable images detected in \033[100m ."$DI" \033[0m"
    fi
}
function newtmp {
    echo $DRT"/"$((1 + $RANDOM % 99999))
}
# @brief Converts RGB888 hex into RGB565
# @params string $1 - rgb888
# @return decimal rgb565 
function rgb888to565 {
    BGC="$(echo $1 | sed -r 's/(0x|\#)//g' | sed -r 's/(.{2})/\1 /g')"
    BGC=($BGC)
    RC=$(echo "obase=10;ibase=16;${BGC[0]}" | bc)
    GC=$(echo "obase=10;ibase=16;${BGC[1]}" | bc)
    BC=$(echo "obase=10;ibase=16;${BGC[2]}" | bc)
    RC=$((RC & 248))
    RC=$((RC << 8))
    GC=$((GC & 252))
    GC=$((GC << 5))
    BC=$((BC >> 3))
    echo $((RC | GC | BC))
}
# @brief Converts RGB565 hex into BGR565 hex value
# @params string $1 - rgb565
# @return string - HEX bgr565
function rgb565bgr {
    RGB_="$(echo $1 | sed -r 's/(0x|\#)//g' | sed -r 's/(.{2})/\1 /g')"
    RGB_=($RGB_)
    if [ ${#RGB_[@]} -le 0 ]; then
        echo "     \033[31m(!) wrong rgb565 input: $1\033[0m"
        exit 0
    fi
    RGC=$(echo "obase=10;ibase=16;${RGB_[0]}" | bc)
    GBC=$(echo "obase=10;ibase=16;${RGB_[1]}" | bc)
    RC=$((RGC >> 3))
    BC=$((GBC & 31))
    GC=$((((RGC & 7) << 3) | (GBC >> 5)))
    ## combining
    BC=$((BC << 11))
    GC=$((GC << 5))
    printf "%0$((BPP*2))X" $((BC | GC | RC))
}
# @brief Converts RGB888 hex into BGR888 hex value
# @params string $1 - rgb888
# @return string bgr888
function rgb888bgr {
    RGB_="$(echo $1 | sed -r 's/(0x|\#)//g' | sed -r 's/(.{2})/\1 /g')"
    RGB_=($RGB_)
    if [ ${#RGB_[@]} -le 0 ]; then
        echo "     \033[31m(!) wrong rgb888 input: $1\033[0m"
        exit 0
    fi
    CLR=""
    for c in $RGB_; do
        CLR="$c$CLR"
    done
    echo "obase=10;ibase=16;$CLR" | bc
}
function formatHdrBitmap {
    ROW=$(echo "$1" | xargs | sed -r 's/ /,0x/g')
    echo "        0x$ROW," >> $FO
}

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
    if [ "$np" = "-r" ]; then
        RESIZE=1
        if ! [[ "$n" =~ ^([0-9])+\:([0-9])+$ ]]; then
            error "new image dimensions are invalid. Use: \033[27m-r W:H\033[0m"
            exit 0
        fi
        IFS=':'
        read -ra WHA <<< "$n"
        WO=${WHA[0]}
        HO=${WHA[1]}
        IFS=$' \t\n'
    elif [ "$np" = "-b" ]; then
        BPP=$n
        if [ $n -eq 2 ]; then
            FORMAT0="RGB565"
        elif [ $n -eq 3 ]; then
            FORMAT0="RGB888"
        else
            error "wrong bytes per pixel value, \033[27mcan use: 2, 3 bytes\033[0m"
            exit 0
        fi
    elif [ "$np" = "-c" ]; then
        CE=1
    elif [ "$np" = "-bg" ]; then
        BGC=$n
    elif [ "$np" = "-z" ]; then
        COMPR=1
    elif [ "$np" = "-d" ]; then
        DISBF=1
    elif [ "$n" = "-clean" ]; then
        echo ""
        if [ "$(ls -A ${DRO})" ]; then
            rm $(echo $DRO"/*") > /dev/null 2>&1
            echo "    \033[100m ."$DO" \033[0m - emptied"
        else
            echo "    \033[100m ."$DO" \033[0m - no content"
        fi
        echo ""
        exit 0
    elif [ "$n" = "-purge" ]; then
        echo ""
        if [ "$(ls -A $DRO)" ]; then
            rm $(echo $DRO"/*") > /dev/null 2>&1
            echo "    \033[100m ."$DO" \033[0m - emptied"
        else
            echo "    \033[100m ."$DO" \033[0m - no content"
        fi
        if [ "$(ls -A $DRI)" ]; then
            rm $(echo $DRI"/*") > /dev/null 2>&1
            echo "    \033[100m ."$DI"  \033[0m - emptied"
        else
            echo "    \033[100m ."$DI"  \033[0m - no content"
        fi
        echo ""
        exit 0
    elif [ "$n" == "-ls" ]; then
        echo ""
        lsinp
        echo ""
        exit 0
    fi
    np=$n
done
## check if resize set
if [ $RESIZE -eq 1 ] && [[ $HO -eq 0 || $WO -eq 0 ]]; then
    error "-r (resize) invoked, you must specify desirable dimensions. Usage: -r w:h"
    exit 0
fi
unset WHA
unset np

# check the temp directory
# create it if not exists, clean if not empty
if [ ! -d $DRT ]; then
    mkdir $DRT
elif [ "$(ls -A $DRT)" ]; then
    rm -r $(echo "$DRT/*") > /dev/null 2>&1
fi

# paths & names
SC="${@: -1}"
FI=$DRI"/"$SC
NM=$(basename "$FI" | sed -E -r 's/\.(jpg|png)//')
TMP0=$(newtmp)
TMP1=$(newtmp)
TMP2=$(newtmp)

# check input file
if ! test -f "$FI"; then
    error "no such file: "$(basename "$FI")" :("
    lsinp
    echo ""
    exit 0
fi

# dimensions
H=$(identify -format "%[fx:h]" $FI)
W=$(identify -format "%[fx:w]" $FI)

###################
# begin output file
###################
echo "\n    Input: \033[32m"$FI"\033[0m"
echo "      - original: "$W" x "$H" pix"
if [ $RESIZE -ne 0 ]; then
    #shrink
    printf "      - resizing to %d x %d" $WO $HO
    magick $FI -colorspace RGB -filter spline -resize $WO"x"$HO\> -unsharp 0x1+0.7+0.02 $TMP0
    # update dimensions
    HO=$(identify -format "%[fx:h]" $TMP0)
    WO=$(identify -format "%[fx:w]" $TMP0)
    echo " (real: "$WO" x "$HO")"
else
    cp $FI $TMP0
fi
# dominant color
# if [[ $ALPHA -eq 0 || "$ALPHA" == "false" ]]; then
if [ "$BGC" = "" ]; then
    # cp $TMP0 $TMP2
    convert $TMP0 -depth 8 -flip -strip -type TrueColor -define bmp:subtype=$FORMAT0 BMP:- > $TMP2
    BGC="$(convert $TMP2 -depth 8 +dither -colors 10 -define histogram:unique-colors=true -format "%c" histogram:info: | \
    sed -n 's/^[ ]*\(.*\):.*[#]\([0-9a-fA-F]*\) .*$/\1,#\2/p' | sort -n -k 1 | tail -n1 | sed -re 's/([0-9]+)\,\#//g')"
    BGC_=$BGC
    if [ $BPP -eq 2 ]; then
        BGC=$(rgb888to565 "$BGC")
    else
        BGC=$(echo "obase=10;ibase=16;$BGC" | bc)
    fi
    BGC_X=$(printf "%0"$((BPP*2))"X" $BGC)
    echo "      - dominant color #"$BGC_" ($FORMAT0: 0x"$BGC_X")"
else
    BGC=$(echo "obase=10;ibase=16;$BGC" | bc)
    BGC_X=$(printf "%0"$((BPP*2))"X" $BGC)
    echo "      - using custom background $FORMAT0: 0x"$BGC_X
fi
    ## RGB to BGR
if [ $DISBF -ne 1 ]; then
    # BGC=$(echo "obase=16;ibase=10;"$(rgb565bgr "$BGC_X") | bc)
    BGC=$(rgb565bgr "$BGC_X")
else
    echo "      - keeping original color sequence (RGB)"
fi
unset BGC_X
unset BGC_
# fi

echo "      - convertinng to "$FORMAT0
convert $TMP0 -depth 8 -flip -strip -type TrueColor -define bmp:subtype=$FORMAT0 BMP:- | \
# tail -c $((WO*HO*BPP)) > $TMP1
# header is 138 bytes for BMP, 26 bytes for BMP2
dd bs=1 skip=138 of=$TMP1 2>/dev/null

# detecting transparency
if [[ "$(identify -format '%[channels]' $FI)" =~ ^(s)?rgba$ ]]; then
    # if [ $CE -eq 1 ]; then
    #     ALPHA="true"
    # else
        ALPHA=1
    # fi
    echo "      - alpha channel detected"
else
    # if [ $CE -eq 1 ]; then
    #     ALPHA="false"
    # else
        ALPHA=0
    # fi
fi

echo "      - transform into RAW pixels"
if [ $DISBF -ne 1 ]; then
echo "      \033[1;34m(i) sit tight, it will take a while...\033[0m"
fi

## output type
#### STRUCTURE (NO COMPRESSION): [0xCOLOR],[0xCOLOR],...
####TODO STRUCTURE (COMPRESSED): [0xCOLOR],[0xCOUNT],[0xCOLOR],[0xCOUNT]...
CNTR0=0
CNTR1=1
ROW=""
PIXB=""
if [ $CE -eq 1 ]; then
    ## c/c++ byte array
    FO=$DRO"/"$NM".h"

    RAW="/**\n * Format: "$FORMAT0" ("$BPP"bpp)\n * Source: "$SC"\n * Date: "$GDT"\n * Generator: "${0/\.\/}" (v."$VERS")\n * ToDo: replace \"splash_bitmap_t\" in display.h\n*/\n"
    RAW=$RAW"struct __attribute__ ((packed, aligned(4))) {\n\
    uint8_t         compressed = 0;\n\
    uint16_t        width = $WO;\n\
    uint16_t        height = $HO;\n\
    uint16_t        bg_color = 0x"$(printf "%0"$((BPP*2))"X" $BGC)";\n\
    uint8_t         alpha = $ALPHA;\n\
    uint16_t        alpha_color = 0x"$(printf "%0"$((BPP*2))"X" 0)";\n\
    uint16_t        xpos;\n\
    uint16_t        ypos;\n\
    const uint8_t   bitmap[$((WO*HO*BPP))] = {"
    echo "$RAW" > $FO

    # RAW=$(cat $TMP1 | xxd -p -l100 | fold -w2) or sed -r 's/(.{2})/\1 /g'
    RAW="$(cat $TMP1 | hexdump -v -e '/1 "%02X "' 2>&1)"
    for b in $RAW; do
        # BGR to RGB
        if [ $CNTR1 -lt $BPP ]; then
            if [ $DISBF -ne 1 ]; then
                PIXB="$PIXB$b"
            else 
                PIXB="$PIXB,0x$b"
            fi
            CNTR1=$((CNTR1+1))
            # echo $CNTR1
            # continue
        else
            # converting into BGR
            if [ $DISBF -ne 1 ]; then
                # echo $PIXB
                if [ $BPP -eq 2 ]; then
                    PIXB=$(rgb565bgr $PIXB | sed -r 's/(.{2})/\1 /g')
                else
                    PIXB=$(rgb888bgr $PIXB | sed -r 's/(.{2})/\1 /g')
                fi
                # echo $PIXB
                ROW=$ROW$PIXB
                PIXB="$b"
            else
                ROW="$ROW$PIXB"
                PIXB="0x$b,"
            fi
            CNTR1=1
        fi
        if [[ ( $CNTR0 -ne 0 ) && ($BPP -eq 2 && $((CNTR0%24)) -eq 0) || ($BPP -eq 3 && $((CNTR0%27)) -eq 0) ]]; then
            formatHdrBitmap "$ROW"
            ROW=""
        fi
        CNTR0=$((CNTR0+1))
    done
    # remaining data
    if [ "$ROW" != "" ]; then
        formatHdrBitmap "$ROW"
    fi
    # continue output
    RAW="    };\n} splashBitmap;"
    echo "$RAW" >> $FO
else
    ## binary file
    FO=$DRO"/"$NM".bin"
    RAW=$(printf "%04X %04X %04X %04X %0"$((BPP*2))"X %0"$((BPP*2))"X" $COMPR $WO $HO $ALPHA $BGC $ALPHAC)
    printf "$RAW" | xxd -p -r > $FO
    ### WARNING: may not work for large files
    RAW=$(cat $TMP1 | hexdump -v -e '/1 "%02X "' 2>&1)
    for b in $RAW; do
        # doing BGR to RGB
        if [ $CNTR1 -lt $BPP ]; then
            PIXB="$PIXB$b"
            CNTR1=$((CNTR1+1))
        else
            if [ $DISBF -ne 1 ]; then
                if [ $BPP -eq 2 ]; then
                    PIXB=$(rgb565bgr $PIXB)
                else
                    PIXB=$(rgb888bgr $PIXB)
                fi
            fi
            ROW="$ROW$PIXB"
            PIXB="$b"
            CNTR1=1
        fi
        # flush data
        if [[ $CNTR0 -ne 0 && $((CNTR0%256)) -eq 0 ]]; then
            printf "$ROW" | xxd -r -p >> $FO
            ROW=""
        fi
        CNTR0=$((CNTR0+1))
    done
    # remaining data
    if [ "$ROW" != "" ]; then
        printf "$ROW" | xxd -r -p >> $FO
    fi
    ## check file size
    FSBSRC=$(wc -c < $FO | sed 's: ::g')
    echo "      - file size: "$FSBSRC" byte(s), header "$((FSBSRC-CNTR0))" byte(s)"
fi
TBL0=$((CNTR0/BPP))
TBL1=$((WO*HO))
if [ $TBL0 -ne $TBL1 ]; then
echo "\033[1;31m      (!) looks like source file has unexpected data, read: "$TBL0", expected: "$TBL1"\n        increase dimensions if resizing or try another image file\033[0m"
else 
echo "      - read: \033[1m"$TBL0"\033[0m of \033[1m"$TBL1"\033[0m pixels"
fi
unset ROW
unset DTA
unset RAW

###################
# cleanup
###################
rm -f $TMP0 > /dev/null 2>&1
rm -f $TMP1 > /dev/null 2>&1
rm -f $TMP2 > /dev/null 2>&1

echo "      done..."

###################
# stats
###################
echo "\n    Output: \033[31m"$FO"\033[0m\n"

exit 0