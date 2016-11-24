#!/bin/bash

#ToolScript
#
#This script is used to optimize ${_MEDIAIN} Medias.
#

# Configuration de la shell
set -o nounset  # Quitte l'exécution pour tout variable utilisée sans valeur d'initialisation
set -o errexit  # Quitte l'exécution pour tout erreur non gére
set -o errtrace # Les backtrace des fonctions sont disponibles

# Configuration generale du script
export _CFGTRM='#' # Separateur des configurations
export _MSGLOG="$PWD/.optimisedMediaWhitelist_$(date +%Y%m%d).why"
export _OPSLOG=$(basename "$0" ".sh").log
export _STDERR=$(mktemp)

# Mise en place d'une fonction de nettoyage des fichiers temporaires'
trap 'echo "Fermeture en cours, veuillez patienter.."; rm "${_STDERR}";' EXIT

# Parametrables
export _CONFIG=${_CONFIG:="$HOME/.optimisedMedia.cfg"}
export _WHITELISTED=${_WHITELISTED:="$HOME/.optimisedMediaWhitelist.log"}
export _ENCODER=${_ENCODER:="--x264-preset veryslow --h264-profile high10 --x264-tune film --h264-level auto -E av_aac"}
export _PROXY=${_PROXY:="nice"}
export _QUALITY=${_QUALITY:=23}
export _FACTOR=${_FACTOR:=1536}
export _MEDIA_THRESHOULD=${_MEDIA_THRESHOULD:=1536}
export _MEDIAIN=${_MEDIAIN:="mp4"}
export _MEDIAEXT=${_MEDIAEXT:="mkv"}
export _OPTIONS=${_OPTIONS:="-e x264 -2 -T -P -U"}
export _EXIFDATA=${_EXIFDATA:="../exifdata"}
export _FACTOR_AUDIO=${_FACTOR_AUDIO:=true}
export _FACTOR_VIDEO=${_FACTOR_VIDEO:=true}

# Mise en place d'une fonction de debug
trap '__printDebugInfos "${$?}" "$BASH_COMMAND" "$LINENO" "$BASH_LINENO" "$BASH_SUBSHELL" "${FUNCNAME[@]}"' ERR
function __printDebugInfos {
    local __scriptExitCode="${1}"
    local __scriptStatement="${2}"
    local __scriptLine="${3}"
    local __scriptLineFunc="${4}"
    local __scriptSubShell="${5}"
    local __scriptStack="${6}"
    echo "##########################################################################################"
    echo $"# Analyse de la commande en erreur"
    echo $"'${__scriptStatement}' (ligne ${__scriptLine}) avec code erreur '${__scriptExitCode}'"
    if [[ -n "${__scriptStack}" ]]
    then
      echo $"# Analyse du stack de fonction"
      echo $"'${FUNCNAME}::${__scriptStack}' (ligne ${__scriptLineFunc})"
    fi
    echo $"# Analyse des variables locales"
    for x in ${!_*}
    do 
      echo $x=$(eval "echo \$$x")
    done
    if [[ -e "${_STDERR}" ]]
    then
      echo $"# Analyse du STDERR"
      cat "${_STDERR}"
    fi
    # Affiche les infos du debug pour l'utilisateur'
    read -t 10 -p "Appuyer sur la touche ENTREE pour continuer..."
    echo && echo "##########################################################################################" 
} >> /dev/stderr

# Affichage d'un manuel de l'utilisateur
if [[ ${#} -eq 0 ]] || [[ ! "$1" =~ ^(run|why|info|--dryrun)$ ]]
then
  echo $"
    $(which bash) ${0} [run|why|info|--dryrun]
    
    run
      Le script de conversion est exécutée
    
    why
      Affiche un report des operations exécutées dans le dossier courant
      
    info
      Affiche toutes les variables utilisées par le script.
      Vous pouvez les modifier en exportant dans l'environnement d'exécution avec une valeur de votre préférence
      
    --dryrun
      Pretends l'exécution du script et affiche les commandes d'optimisation générées au lieu de les performer.
  "
  exit 1
fi

if [[ "$1" == "why" ]]
then
  echo $"En cours de developpement.."
  exit 1
fi

if [[ "$1" == "info" ]]
then
  echo $"# Options générales de l'encodeur"
  echo _ENCODER=\"$_ENCODER\"
  echo _OPTIONS=\"$_OPTIONS\"
  echo $"# Le proxy des commandes"
  echo _PROXY=\"$_PROXY\"
  echo $"# Paramètres de qualité de conversion"
  echo _QUALITY=$_QUALITY
  echo $"# Réduction souhaitée de l'espace dans un facteur de conversion de 1: 1 = _FACTOR: 1024"
  echo _FACTOR=$_FACTOR
  echo $"# Fichiers vidéo d'entrée et conteneur de sortie souhaité"
  echo _MEDIAIN=$_MEDIAIN
  echo _MEDIAEXT=$_MEDIAEXT
  echo $"# Où les journaux d'exploitation actuels seront enregistrés"
  echo _MSGLOG=\"$_MSGLOG\"
  echo $"# Lorsque les données seront sauvegardées après la conversion (les chemins seront conservés)"
  echo _EXIFDATA=\"$_EXIFDATA\"
  echo $"# Registre céntral des média optimisé pour rechercher des médias déjà optimisés"
  echo _WHITELISTED=\"$_WHITELISTED\"
  echo $"# Si les données vidéo et/ou audio doivent être rétrécies en fonction du débit binaire"
  echo _FACTOR_VIDEO=$_FACTOR_VIDEO
  echo _FACTOR_AUDIO=$_FACTOR_AUDIO
  echo -n "##########################################################################################"
  echo $"
    Concernant le fichier de config, il faut écrire un fichier pouvant surcharger les options de conversion basé sur le dossier en conversion.
    Les options sont hierarchisées: les sousdossiers s'appliquent sur les dossiers parents.
    Les deux parametres sont optionnels autrement le paramètre par défaut sera pris en lieu et en place: _encoderConfig=${_ENCODER}, _optionConfig=${_OPTIONS}
    
    Exemple de fichier de configuration entre «» exclus:
    «
    ${PWD}${_CFGTRM}_encoderConfig=\"${_ENCODER}\"
    ${PWD}${_CFGTRM}_optionConfig=\"${_OPTIONS}\"
    »
  "
  echo _CONFIG=\"$_CONFIG\"
  exit 1
fi

if [[ "$1" = "--dryrun" ]]
then
  export _PROXY="echo"
  shift
fi

function checkDependecies {
  local exitCode=0

  # Fichiers nécéssaire pour l'avancement du script'
  touch "${_WHITELISTED}" "${_MSGLOG}" "${_CONFIG}"

  # Check des binaires externes nécéssaire á l'usage du script
  
  echo $"Récherche du binaire de HandBrake.."
  if ! command -v HandBrakeCLI
  then
    sudo aptitude install handbrake-cli
  fi
  exitCode=$?
  
  echo $"Récherche du binaire de tovid.."
  if command -v tovid
  then
    sudo aptitude install tovid
  fi
  exitCode=$?
  
  echo $"Récherche du binaire de exiftool.."
  if command -v exiftool
  then
    sudo aptitude install exiftool
  fi
  exitCode=$?
  
  exit $exitCode;
}

function getVideoBitRate {
  # TODO: Trouver une alternative a tovid!
  tovid id "${@}" | grep 'Video bitrate' | tr -d " " | tr -s "[:alpha:]:" "~" | cut -d "~" -f2
}

function getAudioBitRate {
  # TODO: Trouver une alternative a tovid!
  tovid id "${@}" | grep 'Bitrate' | tr -d " " | tr -s "[:alpha:]:" "~" | cut -d "~" -f2
}

function logError {
  [[ "${_PROXY}" = "echo" ]] || (
    printf "${_media:${#PWD}}" >> $_WHITELISTED
    printf "${_media:${#PWD}};$_adjectif" >> $_MSGLOG
  )
}

function getMediaConfig {
  # Est-ce qu'une config specifique pour ce media existe?
  local customConfig=$(grep "${_media:${#PWD}}${_CFGTRM}" "${_CONFIG}" | cut -d'#' -f2-)
  if [[ ${#customConfig} -eq 0 ]]
  then
    folders=($(printf "${_media:${#PWD}}" | grep -aob '/' | cut -d':' -f1 | sort -n)) # Liste ordonnées du hierarchie des dossier de ce media
    for idx in $( seq 1 $((${#folders[*]}-1)) | sort -nr) #du filtre plus restraint (/folder1/folder2/...) jusqu'a la racine (/folder1)
    do
      customConfig=($(grep "${_media:${#PWD}:$((${folders[$idx]}+1))}${_CFGTRM}" "${_CONFIG}" | cut -d'#' -f2-))
      # Est-ce qu'une config specifique pour ce dossier (l'un de sa hierarchie) de ce media existe?
      [[ ${#customConfig[*]} -eq 0 ]] && continue || break
    done
  fi
  # Si une config a été trouvée alors on l'exécute
  if [[ ${#customConfig[*]} -gt 0 ]]
  then
    eval "${customConfig[*]}"
  fi
  # Defaults
  export _encoderConfig=${_encoderConfig:="$_ENCODER"}
  export _optionConfig=${_optionConfig:="$_OPTIONS"}
}

function encodeMedia {
  unset _media_estimated_encode_gain _adjectif _encoderConfig _optionConfig _encodeFactorConfig
  export _media_estimated_encode_gain=$(( (_media_size-(_media_size*1024/_encodeFactor))/1024 ))
  if [[ $((_media_estimated_encode_gain)) -lt $((_MEDIA_THRESHOULD)) ]]
  # Ca ne vaut pas la peine de recuper de l'espace depuis ce fichier
  then
    export _adjectif=${_adjectif:="inutile"}
    echo $"L'éstimation de recuperation d'espace de ${_media_estimated_encode_gain} Kb a été jugée insuffisante pour justifier un encodage" | eval "$_LOGGER"
    export _encodeRetry=0
  else
    echo $"L'éstimation de recuperation d'espace est de ${_media_estimated_encode_gain} Kb" | eval "$_LOGGER"
    [[ -e  "${_media_path}/${_encoded}" ]] && eval $_PROXY rm -f \"${_media_path}/${_encoded}\"
    # Installation TRAP en cas d'interruption
    trap '
      echo "Fermeture en cours, veuillez patienter.."
      echo $"Suppression fichier en cours de conversion: ${_media_path}/${_encoded}";
      [[ -e "${_media_path}/$_encoded" ]] && [[ -s "${_media_path}/$_encoded" ]] && eval $_PROXY rm \"${_media_path}/$_encoded\"
      export _exitNow="true";
      export _adjectif="interrompue"
      if [[ -e "${_STDERR}" ]]
      then
        echo $"# Analyse du STDERR"
        cat "${_STDERR}"
      fi
      exit 0;
    ' INT TERM;
    # Recupere une configuration personalisee, si ca existe, pour cet encodage
    getMediaConfig;
    # Genère le facteur de conversion selon configuration
    if ( [[ "${_FACTOR_VIDEO}" == "true" ]] && [[ $((_vbt)) -gt 0 ]] ) && ( [[ "${_FACTOR_AUDIO}" == "true" ]] && [[ $((_abt)) -gt 0 ]] )
    then
      export _encodeFactorConfig="--vb $((_vbt/_encodeFactor)) --ab $((_abt/_encodeFactor))"
    elif ( [[ "${_FACTOR_VIDEO}" == "true" ]] && [[ $((_vbt)) -gt 0 ]] ) && ( [[ "${_FACTOR_AUDIO}" == "false" ]] || [[ $((_abt)) -eq 0 ]] )
    then
      export _encodeFactorConfig="--vb $((_vbt/_encodeFactor))"
    elif ( [[ "${_FACTOR_VIDEO}" == "false" ]] || [[ $((_vbt)) -eq 0 ]] ) && ( [[ "${_FACTOR_AUDIO}" == "true" ]] && [[ $((_abt)) -gt 0 ]] )
    then
      export _encodeFactorConfig="--ab $((_abt/_encodeFactor))"
    else
      unset _encodeFactorConfig
    fi
    # Affichage des infos de conversion
    echo $"Conversion en cours de $_media"
    echo $"Options-> $_optionConfig"
    echo $"Encoder-> $_encoderConfig $_encodeFactorConfig -q $_encodeQuality"
    echo $"Destination: "${_media_path}/${_encoded}
    # Execution de l'optimisation
    eval $_PROXY HandBrakeCLI $_optionConfig -i \"$_media\" $_encoderConfig $_encodeFactorConfig -q $_encodeQuality -o \"${_media_path}/${_encoded}\" 2> "${_STDERR}" < /dev/null
  fi
}

#main
checkDependecies;

#Calcul du nombre des fichiers à convertir
printf $'\r'"Veillez patienter, préparation en cours."$'\r'
export IFS=$'\n'
if [[ $(find "$PWD" -iname "*.${_MEDIAIN}" -print | wc -l) -gt 0 ]]
then
  export _ficVConv=($(find "$PWD" -iname "*.${_MEDIAIN}" -print | fgrep -vf "${_WHITELISTED}"))
  export _totalFicVConv=${#_ficVConv[*]}
else
  export _totalFicVConv=0
fi
echo $"Nombre total de fichiers à convertir: ${_totalFicVConv}"

export _global_saved_space=0
export _startTS=$(date +%s)
if [[ ${#_ficVConv[*]} -gt 0 ]]
then
  for _media in ${_ficVConv[*]}
  do
    [[ $((_totalFicVConv)) -eq 0 ]] && break;
    nbConVids=${nbConVids:=0}
    echo $"Avancement du procedé: $((++nbConVids*100/_totalFicVConv))% [ $nbConVids sur $_totalFicVConv ]"
    export _epoch=$(($(date +%s)-_startTS)) #secondes depuis le demarrage
    export _avgtt=$((_epoch/nbConVids))     #temps moyen en secondes par encodage
    export _eta=$((_avgtt * (_totalFicVConv - nbConVids))) #temps en secondes prevu pour les fichiers restants
    export _ETA_DYS=$((${_eta} / 86400))
    export _ETA_HMS=$(date -d@$((${_eta} % 86400)) -u +"%H heures, %M minutes et %S secondes")
    [[ -e "${_media}" ]] || (echo $"${_media} n'a pas été trouvé sur le filesystem, skipped"; continue);

    export _media
    export _encoded=$(basename "$_media" ".${_MEDIAIN}").$_MEDIAEXT
    export _media_path=$(dirname "${_media}")
    export _encodeRetry=3
    export _exitNow="false"
    
    #Creating _LOGGER destination
    export _LOGGER="tee -a \"${_media_path}/${_OPSLOG}\""
    #Création des fichiers de configuration
    touch "${_media_path}/${_OPSLOG}"
    
    # Affichage du temps total d'optimisation restant
    echo $"Temps estimé de l'optimisation : "${_ETA_DYS}" jours, "${_ETA_HMS}
    
    echo "################################################################################" | eval "$_LOGGER"
    echo $"Conversion video: "$(basename "${_media}")" (${_media_path})" | eval "$_LOGGER"
    # Calcul de dimensions du fichiers à encoder
    export _media_size=$(du -sb "$_media" | awk '{ print $1 }')
    
    if [[ -e "${_media_path}/$_encoded" ]] && [[ -s "${_media_path}/$_encoded" ]]
    # Il existe déjà un fichier portant ce nom!
    then
      echo $"Le fichier ${_media_path}/$_encoded existe déjà." | eval "$_LOGGER"
    # Le fichier n'a pas été déjà optimisé
    else
      export _vbt=$(getVideoBitRate "${_media}")
      export _abt=$(getAudioBitRate "${_media}")
      export _encodeFactor=${_FACTOR}
      export _encodeQuality=${_QUALITY}
      # Exécution!
      encodeMedia;
    fi
    # Vérification que le fichiers de sortie existe
    while true
    do
      if [[ "${_PROXY}" = "echo" ]]
      then
        read -t 5 -p $'\r'"Dryrun... les phases de controles seront sautées (appuyer sur ENTREE pour continuer)"
        break;
      else
        # Nous avons fait un CTRL+C
        if [[ "${_exitNow}" = "true" ]]
        then
          printf $'\r'"Fermeture en cours.. veuillez patienter!"
          break;
        fi
        # Calcule les dimensions du fichiers encodé
        if [[ $((_encodeRetry)) -gt 0 ]]
        then
          export _encoded_size=$(du -sb "${_media_path}/$_encoded" | awk '{ print $1 }')
          export _saved_space=$((_media_size-_encoded_size))
        else
          export _saved_space=0 #no gain, no pain
        fi
      
        if [[ $((_saved_space)) -le $((0)) ]]
        # Conversion inappropriée
        then
          export _adjectif=${_adjectif:="inappropriée"}
          echo $"Conversion "${_adjectif}" pour $_media" | eval "$_LOGGER"
          # Ok, on va essayer peut-être encore avec des paramètres plus aggressifs
          if [[ $((_encodeRetry)) -gt 0 ]]
          then
            echo $"Espace potentiellement pérdu: "$((_saved_space/1024))" Kb" | eval "$_LOGGER"
            echo $"La conversion sera exécutée avec des paramètres plus aggressifs." | eval "$_LOGGER"
            export _encodeRetry=$((_encodeRetry-1));
            # Pour chaque itération, le facteur de reduction augemente de 10% et..
            export _encodeFactor=$((_encodeFactor*11/10))
            # ..la qualité diminue d'un decibèl.
            export _encodeQuality=$((_encodeQuality+1))
            # Exécution!
            encodeMedia;
            # recalcule les métriques
            continue;
          # rien à faire, le fichier est vraiment déjà très bien encodé
          else
            if [[ -e  "${_media_path}/${_encoded}" ]]
            then
              eval $_PROXY rm "${_media_path}/$_encoded"
              echo $"Conversion "${_adjectif}" a été supprimée" | eval "$_LOGGER"
            fi
            logError;
            echo $"Ce media a été marqué pour ne pas être optimisé" | eval "$_LOGGER"
            break;
          fi
        # Conversion appropriée
        else
          if [[ -e "${_media_path}/$_encoded" ]] && [[ -s "${_media_path}/$_encoded" ]]
          then
            #Préserve les données Exif
            eval $_PROXY exiftool -tagsFromfile \"${_media}\" -r -all:all -overwrite_original \"${_media_path}/${_encoded}\" &> /dev/null
            #Préserve le timestamp
            eval $_PROXY exiftool "-TrackCreateDate>FileModifyDate" \"${_media}\" &> /dev/null
            # Suppression du fichier original
            exifDest=$(dirname "${_EXIFDATA}${_media:${#PWD}}")
            eval $_PROXY mkdir --parent \"${exifDest}\"
            eval $_PROXY mv \"${_media}\" \"${exifDest}\"
            unset exifDest
            # Log
            echo $"Conversion appropriée pour $_media" | eval "$_LOGGER"
            echo $"Espace recuperé: "$((_saved_space/1024))" Kb [ -"$((100-(_encoded_size*100/_media_size)))" %]" | eval "$_LOGGER"
            # Journalise le gain d'espace recuperé par le traitement
            _global_saved_space=$((_global_saved_space+_saved_space))
            break;
          else
            export _adjectif=${_adjectif:="erreur"}
            logError;
            echo ${_media}' a été converti mais sa version optimizée est manquante: FATAL ERROR ('${_media_path}/${_OPSLOG}')' | eval "$_LOGGER"
            exit 3;
          fi
        fi
      fi
      unset _encoded_size _saved_space _encodeFactor _encodeQuality _encodeRetry
    done
    unset _media_path _encoded _vbt _abt _media_size
  done
fi

if [[ "${_PROXY}" = "echo" ]]
then
  find "$PWD" -type f -name "${_OPSLOG}" -delete 2> "${_STDERR}" # Supprime tous les journaux d'optimisation
else
  echo $"Voici les journaux de l'optimisation:"
  find "$PWD" -type f -name "${_OPSLOG}" -print 2> "${_STDERR}" # Affiche tous les journaux d'optimisation
  echo $"Espace recuperé par le traitement: "$((_global_saved_space/1024))" Kb"
fi

exit 0;
: # Fin du script
