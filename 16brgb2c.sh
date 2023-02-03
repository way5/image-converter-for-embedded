#!/usr/bin/env sh
#
# ###################################################################################
# File: 16bin2rgb565.sh
# Project: image2c - 16bit color encoded image binary to RGB565 C/C++ array (see $VERS)
# File Created: Sunday, 21st June 2020 8:18:16 pm
# Author: sk
# Last Modified: Wednesday, 1st February 2023 9:47:59 pm
# Modified By: Sergey Ko
# License: CC-BY-NC-4.0 (https://creativecommons.org/licenses/by-nc/4.0/legalcode)
# ###################################################################################
# CHANGELOG:
# Jun 23, 2020 - Fixes + improvements
# ###################################################################################
#
ARGS=$@
ALPHA=0
TYPDFS=0
ALPHABYTE="0x8080"
ALPHAC=""
DR=$(pwd)
DO="/out"
DI="/in"
DRO=$DR$DO
DRI=$DR$DI
RAW=""
# MAGIC0=0
# MAGIC1=0
CE=0
VERS="2.1"
GDT=$(date +"%d.%m.%Y %H:%m:%S")
# functions
function help {
    echo "\033[32mUSAGE:\033[0m "$0" [-options] [filemame]\n"
    echo "- Options:"
    echo "  ------------------------------------------------"
    echo "   \033[1m-w\033[0m <value>      image width (obligatory)"
    echo "   \033[1m-h\033[0m <value>      image height (obligatory)"
    echo "   \033[1m-a\033[0m              input image has an alpha byte"
    echo "   \033[1m-c\033[0m              use byte-compression algorithm"
    echo "   \033[1m-ac\033[0m <value>     value is a 16-bit HEX color code that"
    echo "                   is meant to be transparent"
    echo "   \033[1m-td\033[0m             include typedefs in output file"
    echo "  ------------------------------------------------"
    echo "   \033[1m-ls\033[0m             list all files from input dir,"
    echo "                   suitable for convertion"
    echo "   \033[1m-clean\033[0m          to clean only \033[4moutput\033[0m directory"
    echo "   \033[1m-purge\033[0m          to clean \033[4mALL\033[0m project directories"
    echo "  ------------------------------------------------"
    echo "\n\033[33mDESCRIPTION:\033[0m The script converts RGB565 encoded bin files into 16-bit C/C++ RAW pixel arrays.\n\
             Only ."$DI"/[RGB565].bin files can be used\n"
    exit 0
}
function error {
    echo "\n    \033[41m Error: \033[0m "$1"\n"
}
function lsinp {
    if find $DRI -mindepth 1 -type f -name '*.bin' | read; then
        echo "    *.bin files found:"
        for l in $(find $DRI -type f -name '*.bin'); do
            echo "      "$(basename "$l" | sed 's/\.bin//')
        done
    else
        echo "    No suitable files detected in \033[100m ."$DI" \033[0m"
    fi
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
    if [ "$np" = "-w" ]; then
        W=$n
    elif [ "$np" = "-h" ]; then
        H=$n
    elif [ "$np" = "-a" ]; then
        ALPHA=1
    elif [ "$np" = "-c" ]; then
        CE=1
    elif [ "$np" = "-td" ]; then
        TYPDFS=1
    elif [ "$np" = "-ac" ]; then
        if ! [[ "$n" =~ ^[0-9]+x([0-9]|[A|B|C|F|F])+$ ]]; then
            error "alpha color is not a \033[27m16-bit HEX\033[0m value."
            exit 0
        fi
        ALPHAC=$(printf "%04X" $n)
        if [ -z "$ALPHAC" ]; then
            help
        fi
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
    elif [ "$n" = "-ls" ]; then
        echo ""
        lsinp
        echo ""
        exit 0
    fi
    np=$n
done
unset np

# paths & names
SC="${@: -1}"
FI=$DRI"/"$SC".bin"
FO=$DRO"/"$SC"_"
CEST=""
NM=$(basename "$FI" | sed 's/\.bin//')"_"
if [ $ALPHA -eq 1 ]; then
    NM=$NM"a"
    FO=$FO"a"
elif [ -n "$ALPHAC" ]; then
    NM=$NM"ac"
    FO=$FO"ac"
fi
if [ $CE -eq 1 ]; then
    SC=$SC"-compr"
    NM=$NM"zc"
    FO=$FO"zc"
    CEST="(compressed)"
fi
FO=$FO".h"

# check arguments
if [ -z "$W" ] || [ -z "$H" ]; then
    error "image Width or Height is not specified. Check arguments."
    help
fi

# check the file size
FSBSRC=$(wc -c < $FI | sed 's: ::g')
FSBGN=$(((W*H*2)+5))
if [ $FSBSRC -ne $FSBGN ]; then
    if [ $FSBSRC -gt $FSBGN ]; then
        FSBSTAT=$((FSBSRC-FSBGN))" byte(s) \033[1mbigger\033[0m"
    else
        FSBSTAT=$((FSBGN-FSBSRC))" byte(s) \033[1msmaller\033[0m"
    fi
    error "seems that image has different dimensions: ${FSBSTAT}"
    exit 0
fi

if [ -n "$ALPHAC" ] && [ $ALPHA -eq 1 ]; then
    error "image with alpha channel can not use an alpha color. Use \033[100m-a\033[0m or \033[100m-ac\033[0m"
    help
fi

# check input file
if ! test -f "$FI"; then
    error "no such file: "$(basename "$FI")" :("
    lsinp
    echo ""
    help
fi

# check output file
if test -f "$FO"; then
    rm $FO
fi
touch $FO
###################
# typedefs
###################
if [ $TYPDFS -eq 1 ]; then
    echo "typedef uint16_t color_t;\n" >> $FO
    echo "typedef struct {\n\
    const uint16_t  *bitmap;\n\
    uint8_t         compressed;\n\
    uint8_t         width;\n\
    uint8_t         height;\n\
    uint8_t         alpha;\n\
    color_t         alpha_color;\n} rgb565_t;\n" >> $FO
fi

###################
# begin output file
###################
HDR="/**\n * fmt: 16-bit/pixl, RGB565"
if [ $ALPHA -eq 0 ]; then
    if [ -n "$ALPHAC" ]; then
        HDR=$HDR" with alpha color (0x"$ALPHAC"=0.0)"
    fi
else
    HDR=$HDR" with alpha channel ("$ALPHABYTE"=0.0)"
fi
HDR=$HDR"\n * img: "$NM"\n * bmp: "$NM"_bmp "$CEST"\n * gen: \
"${0/\.\/}" (v."$VERS") at "$GDT"\n*/\nconst uint16_t \
"$NM"_bmp[] PROGMEM = {"
echo "$HDR" >> $FO
BF=""
CNTR0=0
CNTR1=0
# compression
FSIZECMP=0
CEPH=""
if [ $CE -eq 1 ]; then
    CFB=""
    CEC=0
    CEPH=", \033[1mcompressed\033[0m"
fi
FSIZE=0
############################
# image without alpha channel
############################
if [ $ALPHA -eq 0 ]; then
    #### TRUE COLOR, BINARY RGB565, NO_SWAP
    #### STRUCTURE (NO COMPRESSION): [0xCOLOR],[0xCOLOR],...
    #### STRUCTURE (COMPRESSED): [0xCOLOR],[0xCOUNT],[0xCOLOR],[0xCOUNT]...
    BMAX=$(((W*H)+2))
    RAW=$(cat $FI | hexdump -v -e '/2 "%04X "' 2>&1)

    for c in $RAW; do
        CNTR0=$((CNTR0+1))
        if [ $CNTR0 -lt 3 ]; then
            continue
        elif [ $CNTR0 -gt $BMAX ]; then
            break
        fi
        CNTR1=$((CNTR1+1))
        # compression enabled
        if [ $CE -eq 1 ]; then
            # (CNTR0*5) - 4 digits and one space for each loop
            if [ "$CFB" != "$c" ] || [ $(((CNTR0*5)+5)) -ge ${#RAW} ]; then
                # the very first word
                if [ "$CFB" = "" ]; then
                    CFB=$c
                    CEC=$((CEC+1))
                else
                    # the very last word
                    if [ $(((CNTR0*5)+5)) -ge ${#RAW} ] && [ "$CFB" == "$c" ]; then
                        CEC=$((CEC+1))
                    fi
                    BF=$BF"0x"$CFB","$(echo "0x"$(printf "%04X" $CEC))","
                    CFB=$c
                    CEC=1
                    FSIZECMP=$((FSIZECMP+4))
                    if [ $FSIZECMP -gt 0 ] && [ $((FSIZECMP%16)) -eq 0 ]; then
                        echo $BF >> $FO
                        BF=""
                    fi
                fi
            else
                CEC=$((CEC+1))
            fi
        else
            BF=$BF"0x"$c","
            # append if length is equal to the width
            if [ $((CNTR1%W)) -eq 0 ]; then
                echo $BF >> $FO
                BF=""
            fi
        fi
        if [ -n "$ALPHAC" ] && [ "$c" = "0x${ALPHAC}," ]; then
            ACLR=1
        else
            ACLR=0
        fi
        FSIZE=$((FSIZE+2))
    done
    # take care about the abnormalities
    if [ -n "$BF" ]; then
        echo $BF >> $FO
        BF=""
    fi
    # for a stats sake...
    BMAX=$((BMAX*2+1))
    # if image doesn't contain alpha color, abort
    if [ -n "$ALPHAC" ] && [ $ACLR -eq 0 ]; then
        error "image doesn't contain \033[100m0x"$ALPHAC"\033[0m color. Mission failed..\033[5m.\033[0m"
        rm $FO
        exit 0
    fi
    # info
    if [ -n "$ALPHAC" ]; then
        ACLR=0
        echo "\n- Input ."$DI"/"$NM".bin \033[1m=>\033[0m RGB565 format \033[1mwith alpha color\033[0m"$CEPH
    else
        echo "\n- Input ."$DI"/"$NM".bin \033[1m=>\033[0m RGB565 format"$CEPH
    fi
##########################
# image with alpha channel
##########################
else
    #### TRUE COLOR WITH ALPHA, BINARY RGB565, NO_SWAP (8 bits for alpha after every pixel)
    #### STRUCTURE (NO COMPRESSION): [0xCOLOR],[0xCOLOR],...
    #### STRUCTURE (COMPRESSED): [0xCOLOR],[0xCOUNT],[0xCOLOR],[0xCOUNT]...
    BMAX=$((((W*H)*3)+5))
    RAW=$(cat $FI | hexdump -v -e '/1 "%02X "' 2>&1)
    acntr=0
    b1=""
    b2=""
    alpha2="" # previous alpha value
    for c in $RAW; do
        CNTR0=$((CNTR0+1))
        if [ $CNTR0 -lt 5 ]; then
            continue
        elif [ $CNTR0 -gt $BMAX ]; then
            break
        fi
        if [ -z "$b1" ]; then
            b1=$c
        elif [ -z "$b2" ]; then
            b2=$c
        else
            CNTR1=$((CNTR1+1))
            # compression enabled
            if [ $CE -eq 1 ]; then
                # very first byte
                if [ "$CFB" = "" ]; then
                    CFB=$b2$b1
                    alpha2=$c
                fi
                # 1.11
                if [[ ( "$CFB" != "$b2$b1" || "$alpha2" != "$c" ) ]]; then
                    if [ "$alpha2" = "00" ]; then
                        # 100% transparent
                        BF=$BF$ALPHABYTE","
                    else
                        BF=$BF"0x"$CFB","
                    fi
                    BF=$BF$(echo "0x"$(printf "%04X" $CEC))","
                    CFB=$b2$b1
                    CEC=1
                    alpha2=$c
                    FSIZECMP=$((FSIZECMP+4))
                    if [ $FSIZECMP -gt 0 ] && [ $((FSIZECMP%16)) -eq 0 ]; then
                        echo $BF >> $FO
                        BF=""
                    fi
                else
                    CEC=$((CEC+1))
                fi
            else
                # third byte is always alpha, so skip this
                if [ "$c" = "00" ]; then
                    # 100% transparent
                    BF=$BF$ALPHABYTE","
                else
                    BF=$BF"0x"$b2$b1","
                fi
                if [ $((CNTR1%W)) -eq 0 ]; then
                    echo $BF >> $FO
                    BF=""
                fi
            fi
            acntr=$((acntr+1))
            b1=""
            b2=""
        fi
        FSIZE=$((FSIZE+1))
    done
    # issue with missing bytes at the end of
    # compressed image with alpha (see statement 1.11)
    if [ $CEC -gt 0 ] && [ -n "$CFB" ]; then
        BF=$BF"0x"$CFB","$(echo "0x"$(printf "%04X" $CEC))","
    fi
    # take care about an abnormalities
    if [ -n "$BF" ]; then
        echo $BF >> $FO
        BF=""
    fi
    FSIZE=$((FSIZE-acntr-1))
    # info
    echo "\n- Input: ."$DI"/"$NM".bin \033[1m=>\033[0m RGB565 format \033[1mwith alpha channel\033[0m"$CEPH
fi

echo "};\n" >> $FO

# MAGIC0=$(cat $FI | head -c2 | hexdump -v -e '"0x" 1/2 "%04X"' 2>&1)
# MAGIC1=$(cat $FI | head -c4 | tail -c -2 | hexdump -v -e '"0x" 1/2 "%04X"' 2>&1)
if [ $CE -eq 1 ]; then
    CELV=$((100-((FSIZECMP*100)/FSIZE)))
fi

echo "const rgb565_t "$NM" PROGMEM = {\n\
    "$NM"_bmp, "$CE",\n\
    "$W", "$H >> $FO

PS=""
# if image has alpha channel
if [ $ALPHA -eq 1 ]; then
    PS=", 1"
elif [ -n "$ALPHAC" ]; then
    PS=", 0, 0x${ALPHAC}"
fi

echo $PS"};\n" >> $FO
if [ $CE -eq 1 ]; then
    echo "// image size (compr.: "$CELV"%) "$FSIZECMP" bytes.\n" >> $FO # MAGIC0="$MAGIC0" MAGIC1="$MAGIC1"\n" >> $FO
else
    echo "// image size "$FSIZE" bytes.\n" >> $FO # MAGIC0="$MAGIC0" MAGIC1="$MAGIC1"\n" >> $FO
fi
#################
# output file end
#################

# stats
echo "    \033[33m"$BMAX"\033[0m bytes total"
[ $ALPHA -eq 1 ] && echo "    \033[33m"$acntr"\033[0m alpha bytes found"
if [ $CE -eq 1 ]; then
    echo "    \033[32m"$FSIZECMP"\033[0m bytes image created"
    echo "    \033[35m"$CELV"%\033[0m compression level"
else
    echo "    \033[32m"$FSIZE"\033[0m bytes image created"
fi
echo "- Output: \033[90m"$FO"\033[0m\n"

exit 0