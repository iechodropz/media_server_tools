#!/bin/bash

# SET LOG FILE PATHS
mkdir -p "/home/${USER}/logs"
touch "/home/${USER}/logs/logs_detail_sync_subs.log"
touch "/home/${USER}/logs/logs_sync_subs.log"
LOG_FILE_DETAIL="/home/${USER}/logs/logs_detail_sync_subs.log"
LOG_FILE="/home/${USER}/logs/logs_sync_subs.log"

# ASK USER FOR MEDIA FOLDER PATH
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Inputing Path To Media Folder" >> "${LOG_FILE_DETAIL}"
while true; do
    echo ""
    read -ep "Input Path To Media Folder: " MEDIA_FOLDER_PATH

    # CHECK IF PATH IS VALID
    if [ -d "${MEDIA_FOLDER_PATH}" ] && [ -x "${MEDIA_FOLDER_PATH}" ]; then
        break
    else
        echo ""
        echo "Directory Does Not Exist Or Not Authorized To Access Directory: ${MEDIA_FOLDER_PATH}"
        echo ""
        echo "Please Try Again."
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Directory Does Not Exist Or Not Authorized To Access Directory For ${MEDIA_FOLDER_PATH}" >> "${LOG_FILE_DETAIL}"
        echo "========================================" >> "${LOG_FILE_DETAIL}"
    fi
done

echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Path To Media Folder Is ${MEDIA_FOLDER_PATH}" >> "${LOG_FILE_DETAIL}"

# ASK USER FOR SUBTITLE LANGUAGE
while true; do
    echo ""
    echo "Which Subtitle Language To Sync:"
    echo "1) English"
    echo "2) Spanish"
    read -p "Select (1 or 2): " LANGUAGE_CHOICE

    # SET LANGUAGE_CODE BASED ON LANGUAGE_CHOICE
    case ${LANGUAGE_CHOICE} in
        1)
            LANGUAGE_CODE="en"
            LANGUAGE_NAME="English"
            break
            ;;
        2)
            LANGUAGE_CODE="es"
            LANGUAGE_NAME="Spanish"
            break
            ;;
        *)
            echo ""
            echo "Invalid Language Selection Please Choose 1 Or 2"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N') Error Invalid Language Selection (${LANGUAGE_CHOICE})" >> "${LOG_FILE_DETAIL}"
            echo "========================================" >> "${LOG_FILE_DETAIL}"
            ;;
    esac
done

echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Subtitle Language And Code Selected Are ${LANGUAGE_NAME} ${LANGUAGE_CODE}" >> "${LOG_FILE_DETAIL}"

echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Selecting Subtitle Offset" >> "${LOG_FILE_DETAIL}"
while true; do
    echo ""
    echo "Offset Subtitle:"
    echo "1) Yes"
    echo "2) No"
    read -p "Select (1 or 2): " USING_OFFSET

    case ${USING_OFFSET} in
        1)
            while true; do
                echo ""
                read -p "Enter Offset In Seconds (-20 to 20): " OFFSET_SECONDS
                if [[ "${OFFSET_SECONDS}" =~ ^-?[0-9]+([.][0-9]+)?$ ]] && (( $(echo "${OFFSET_SECONDS} >= -20 && ${OFFSET_SECONDS} <= 20" | bc -l) )); then
                    break
                else
                    echo ""
                    echo "Invalid Offset Please Enter A Number Between -20 And 20"
                    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Invalid Offset Value (${OFFSET_SECONDS})" >> "${LOG_FILE_DETAIL}"
                    echo "========================================" >> "${LOG_FILE_DETAIL}"
                fi
            done
            break
            ;;
        2)
            OFFSET_SECONDS=0
            break
            ;;
        *)
            echo ""
            echo "Invalid Selection Please Choose 1 Or 2"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Invalid Offset Selection (${USING_OFFSET})" >> "${LOG_FILE_DETAIL}"
            echo "========================================" >> "${LOG_FILE_DETAIL}"
            ;;
    esac
done

echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Offset Selected ${USING_OFFSET} Offset Seconds ${OFFSET_SECONDS}" >> "${LOG_FILE_DETAIL}"

# ASK USER IF THEY WANT TO USE SUBTITLE REFERENCE
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Selecting To Use Subtitle Reference" >> "${LOG_FILE_DETAIL}"
while true; do
   echo ""
   echo "Use Another Subtitle As Reference:"
   echo "1) Yes"
   echo "2) No"
   read -p "Select (1 or 2): " USING_SUBTITLE_REFERENCE
   echo ""

   case ${USING_SUBTITLE_REFERENCE} in
       1)
           while true; do
               echo "Which Subtitle Language To Use As Reference:"
               echo "1) English"
               echo "2) Spanish"
               read -p "Select (1 or 2): " SUBTITLE_LANGUAGE_REFERENCE
               echo ""

               case ${SUBTITLE_LANGUAGE_REFERENCE} in
                   1)
                       REFERENCE_LANGUAGE_CODE="en"
                       REFERENCE_LANGUAGE_NAME="English"
                       break
                       ;;
                   2)
                       REFERENCE_LANGUAGE_CODE="es"
                       REFERENCE_LANGUAGE_NAME="Spanish"
                       break
                       ;;
                   *)
                       echo ""
                       echo "Invalid Selection Please Choose 1 Or 2"
                       echo "$(date '+%Y-%m-%d %H:%M:%S.%3N') Error Invalid Subtitle Language Reference Selection (${SUBTITLE_LANGUAGE_REFERENCE})" >> "${LOG_FILE_DETAIL}"
                       echo "========================================" >> "${LOG_FILE_DETAIL}"
                       ;;
               esac
           done
           break
           ;;
       2)
           break
           ;;
       *)
           echo ""
           echo "Invalid Selection Please Choose 1 Or 2"
           echo "$(date '+%Y-%m-%d %H:%M:%S.%3N') Error Invalid Using Subtitle Reference Selection (${USING_SUBTITLE_REFERENCE})" >> "${LOG_FILE_DETAIL}"
           echo "========================================" >> "${LOG_FILE_DETAIL}"
           ;;
   esac
done

echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Using Subtitle Reference ${SUBTITLE_LANGUAGE_REFERENCE} And Subtitle Language Reference And Code Selected Are ${REFERENCE_LANGUAGE_NAME} ${REFERENCE_LANGUAGE_CODE}" >> "${LOG_FILE_DETAIL}"

validate_and_fix_subtitle() {
    local srt_file="$1"

    echo "Validating Subtitle: ${BASE}.${LANGUAGE_CODE}.srt" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Validating Subtitle For ${BASE}.${LANGUAGE_CODE}.srt" >> "${LOG_FILE_DETAIL}"

    # IF THE FILE DOES NOT EXIST OR EXISTS BUT IS EMPTY
    if [ ! -s "${srt_file}" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N') Error Subtitle File Does Not Exist Or Is Empty For ${srt_file}" >> "${LOG_FILE_DETAIL}"
        return 1
    fi

    # CHECK WHAT THE CHARSET OF THE SUBTITLE FILE IS AND CONVERT IT TO UTF-8 IF NOT ALREADY
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Checking Charset Of Subtitle File ${srt_file}" >> "${LOG_FILE_DETAIL}"
    local charset=$(file -bi "${srt_file}" | grep -o 'charset=.*' | cut -d= -f2)
    if [ "${charset}" != "utf-8" ] && [ "${charset}" != "us-ascii" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Converting From ${charset} To UTF-8 For ${srt_file}" >> "${LOG_FILE_DETAIL}"

        # CREATE BACKUP OF SRT FILE IN CASE CONVERSION FAILS
        cp "${srt_file}" "${srt_file}.backup"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Created Backup File For ${srt_file}" >> "${LOG_FILE_DETAIL}"

        # TRY CONVERTING TO UTF-8
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Converting ${srt_file} To UTF-8" >> "${LOG_FILE_DETAIL}"
        TEMP_ERROR=$(mktemp)
        iconv -f "${charset}" -t UTF-8 "${srt_file}" -o "${srt_file}.utf8" 2>"${TEMP_ERROR}"

        local iconv_response_status=$?
        local iconv_error=$(cat "${TEMP_ERROR}")

        rm "${TEMP_ERROR}"

        if [ "${iconv_response_status}" -eq 0 ]; then
            mv "${srt_file}.utf8" "${srt_file}"
            rm "${srt_file}.backup"

            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Successfully Converted To UTF-8 For ${srt_file}" >> "${LOG_FILE_DETAIL}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Deleted Backup File ${srt_file}.backup" >> "${LOG_FILE_DETAIL}"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Conversion To UTF-8 Failed For ${srt_file} - ${iconv_error}" >> "${LOG_FILE_DETAIL}"
            return 1
        fi
    fi

    # CHECK IF SUBTITLE FILE DOES NOT HAVE BASIC SRT STRUCTURE
    if ! grep -q "^[0-9]\+$" "${srt_file}" || ! grep -q " --> " "${srt_file}"; then
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Not Valid SRT Structure For ${srt_file}" >> "${LOG_FILE_DETAIL}"
        return 1
    fi

    return 0
}

# LOOP THROUGH ALL VIDEO FILES (MKV, MP4, AVI)
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Looping Through Video Files" >> "${LOG_FILE_DETAIL}"
echo "========================================" >> "${LOG_FILE_DETAIL}"
while IFS= read -r -d '' VIDEO_PATH; do
    DIR="$(dirname "${VIDEO_PATH}")"
    VIDEO="$(basename "${VIDEO_PATH}")"
    cd "${DIR}"

    # EXTRACT THE FILENAME WITHOUT EXTENSION
    BASE="${VIDEO%.*}"

    if [ -f "${BASE}.synced.${LANGUAGE_CODE}.srt" ]; then
        echo "Skipping (Already Synced): ${VIDEO}" | tee -a "${LOG_FILE}"
        echo "========================================" | tee -a "${LOG_FILE}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Skipping (Already Synced) For ${VIDEO}" >> "${LOG_FILE_DETAIL}"
        echo "========================================" >> "${LOG_FILE_DETAIL}"
        continue
    fi

    if [ -f "${BASE}.${LANGUAGE_CODE}.srt" ]; then
        validate_and_fix_subtitle "${BASE}.${LANGUAGE_CODE}.srt"
        VALIDATION_STATUS=$?

        if [ ${VALIDATION_STATUS} -ne 0 ]; then
            echo "Subtitle Validation Failed: ${BASE}.${LANGUAGE_CODE}.srt" | tee -a "${LOG_FILE}"
            echo "========================================" | tee -a "${LOG_FILE}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Subtitle Validation Failed For ${BASE}.${LANGUAGE_CODE}.srt" >> "${LOG_FILE_DETAIL}"
            echo "========================================" >> "${LOG_FILE_DETAIL}"
            continue
        else
            echo "Subtitles Validated: ${BASE}.${LANGUAGE_CODE}.srt" | tee -a "${LOG_FILE}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Subtitles Validated For ${BASE}.${LANGUAGE_CODE}.srt" >> "${LOG_FILE_DETAIL}"
        fi

        # SYNC SUBTITLES TO AUDIO AND SAVE RESULT
        TEMP_ERROR=$(mktemp)
        if [ ${USING_SUBTITLE_REFERENCE} = "1" ]; then
            # CHECK IF REFERENCE SUBTITLE EXISTS
            if [ ! -f "${BASE}.${REFERENCE_LANGUAGE_CODE}.srt" ]; then
                echo "Reference Subtitle Not Found: ${BASE}.${REFERENCE_LANGUAGE_CODE}.srt" | tee -a "${LOG_FILE}"
                echo "========================================" | tee -a "${LOG_FILE}"
                echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Reference Subtitle Not Found For ${BASE}.${REFERENCE_LANGUAGE_CODE}.srt" >> "${LOG_FILE_DETAIL}"
                echo "========================================" >> "${LOG_FILE_DETAIL}"
                rm "${TEMP_ERROR}"
                continue
            fi

            echo "Attempting To Sync Using Reference Subtitle: ${BASE}.${REFERENCE_LANGUAGE_CODE}.srt" | tee -a "${LOG_FILE}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Attempting To Sync Using Reference Subtitle ${BASE}.${REFERENCE_LANGUAGE_CODE}.srt" >> "${LOG_FILE_DETAIL}"
            ffsubsync "${BASE}.${REFERENCE_LANGUAGE_CODE}.srt" -i "${BASE}.${LANGUAGE_CODE}.srt" -o "${BASE}.synced.${LANGUAGE_CODE}.srt" $( [ "${USING_OFFSET}" = "1" ] && echo "--offset-seconds ${OFFSET_SECONDS}" ) 2>"${TEMP_ERROR}"
        else
            echo "Attempting To Sync: ${BASE}.${LANGUAGE_CODE}.srt" | tee -a "${LOG_FILE}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Attempting To Sync For ${BASE}.${LANGUAGE_CODE}.srt" >> "${LOG_FILE_DETAIL}"
            ffs "${VIDEO}" -i "${BASE}.${LANGUAGE_CODE}.srt" -o "${BASE}.synced.${LANGUAGE_CODE}.srt" $( [ "${USING_OFFSET}" = "1" ] && echo "--offset-seconds ${OFFSET_SECONDS}" ) 2>"${TEMP_ERROR}"
        fi

        FFS_RESPONSE_STATUS=$?
        FFS_ERROR=$(cat "${TEMP_ERROR}")

        rm "${TEMP_ERROR}"

        # CHECK IF SYNCED FILE WAS CREATED
        if [ "${FFS_RESPONSE_STATUS}" -ne 0 ]; then
            echo "Failed To Sync: ${VIDEO}" | tee -a "${LOG_FILE}"
            echo "========================================" | tee -a "${LOG_FILE}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Failed To Sync For ${BASE}.${LANGUAGE_CODE}.srt with ${VIDEO} - ${FFS_ERROR}" >> "${LOG_FILE_DETAIL}"
            echo "========================================" >> "${LOG_FILE_DETAIL}"
        else
            cp "${BASE}.synced.${LANGUAGE_CODE}.srt" "${BASE}.${LANGUAGE_CODE}.srt"

            echo "Success: ${VIDEO}" | tee -a "${LOG_FILE}"
            echo "========================================" | tee -a "${LOG_FILE}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Success For ${VIDEO}" >> "${LOG_FILE_DETAIL}"
            echo "========================================" >> "${LOG_FILE_DETAIL}"
        fi
    else
        echo "No Subtitles Found: ${VIDEO}" | tee -a "${LOG_FILE}"
        echo "========================================" | tee -a "${LOG_FILE}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error No Subtitles Found For ${VIDEO}" >> "${LOG_FILE_DETAIL}"
        echo "========================================" >> "${LOG_FILE_DETAIL}"
    fi
done < <(find "${MEDIA_FOLDER_PATH}" -type f \( -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" \) -print0)

echo "================================================================================" >> "${LOG_FILE_DETAIL}"