#!/bin/bash

#ToolScript
#
#This script is used to optimize JPEG pictures.
#

export tmpDir=$(mktemp -d)
export threshold=${threshold:=15} # accepted size difference
export factor=${factor:=85}       # init factor
export WHITELISTED=${WHITELISTED:="$HOME/.optimisedMediaWhitelist.log"}
export MSGLOG="$PWD/.optimisedMediaWhitelist_$(date +%Y%m%d).why"

function checkDependecies {
  touch "${WHITELISTED}" "${MSGLOG}"
	which jpegoptim &> /dev/null
	[[ $? -gt 0 ]] && sudo aptitude install jpegoptim
}

checkDependecies;

if [[ "${1}" = "info" ]]
then
  echo threshold=$threshold
  echo factor=$factor
  echo MSGLOG=$MSGLOG
  echo WHITELISTED=$WHITELISTED
  exit 1;
fi

if [[ "${1}" = "--dryrun" ]]
then
  export PROXY="echo"
  shift
else
  #exec &> /dev/null
  export PROXY="eval"
fi

export saved_space=0  
export largestJpegFile="$(find . -type f \( -name '*.jpg' -o -name '*.JPG' -o -name '*.jpeg' \) -printf '%s %p\n' | LC_ALL=C fgrep -vf "${WHITELISTED}" | sort -nr | head -1 | cut -d' ' -f2-)"
while [[ -n "$largestJpegFile" ]]
do
  tmpFileName=$(basename "$largestJpegFile")
  rm -f "$tmpDir/$tmpFileName" &> /dev/null
  jpegoptim --all-progressive -npvm$factor -d$tmpDir -T$threshold "$largestJpegFile" | grep "skipped.$" &> /dev/null
  if [[ $? -eq $((0)) ]]
  then
    factor=$((factor-1))
  else
    break
  fi
done

function optimizeJpeg {
  export media="${@}"
  [[ -n "${media}" ]] || return
  export media_size=$(du -sb "$media" | awk '{ print $1 }')
  export tmpFile=$(mktemp)
  echo -n "Optimizing ${media}"$'\r'
  $PROXY jpegoptim --all-progressive -opvm${factor} -T${threshold} \"${media}\" 2> /dev/null | tee >(cut -d',' -f2 > ${tmpFile})
  export verb=$(cat ${tmpFile} | sed 's/[^a-zA-Z]//g')
  export new_media_size=$(du -sb "$media" | awk '{ print $1 }')
  export media_save=$((media_size-new_media_size))
  export saved_space=$((saved_space+media_save))
  [[ "${PROXY}" = "echo" ]] || (
    echo "${1:${#PWD}}" >> $WHITELISTED       #Media tagged as optimized
    echo "${1:${#PWD}};${verb}" >> $MSGLOG    #Media added to daily journal
  )
  rm $tmpFile
}
export -f optimizeJpeg

export IFS=$'\n'
export _ficVConv=($(find "${PWD}" -type f \( -name '*.jpg' -o -name '*.JPG' -o -name '*.jpeg' \) -print | LC_ALL=C fgrep -vf "${WHITELISTED}"))
export _totalFicVConv=${#_ficVConv[*]}
# processing all images
for file in ${_ficVConv[@]}
do
  [[ $((_totalFicVConv)) -eq 0 ]] && break;
	nbConVids=${nbConVids:=0}
	echo "Avancement du procedé: $((++nbConVids*100/_totalFicVConv))% [ $nbConVids sur $_totalFicVConv ]"
	[[ -e "$file" ]] || continue;
	# Doing the optimization
  optimizeJpeg "${file}"
done

echo "Espace recuperé par le traitement: "$((saved_space/1024))" Kb"

