#!/bin/bash

# SET LOG FILE PATHS
mkdir -p "/home/${USER}/logs"
touch "/home/${USER}/logs/logs_detail_sanity_check.log"
touch "/home/${USER}/logs/logs_sanity_check.log"
LOG_FILE_DETAIL="/home/${USER}/logs/logs_detail_sanity_check.log"
LOG_FILE="/home/${USER}/logs/logs_sanity_check.log"

# ASK USER FOR MEDIA FOLDER PATH
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Inputing Path To Media Folder" >> "${LOG_FILE_DETAIL}"
while true; do
    echo ""
    read -ep "Input Path To Media Folder: " MEDIA_FOLDER_PATH
    echo ""

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

# LOOP THROUGH ALL VIDEO FILES (MKV, MP4, AVI)
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Looping Through Video Files" >> "${LOG_FILE_DETAIL}"
echo "========================================" >> "${LOG_FILE_DETAIL}"
while IFS= read -r -d '' VIDEO_PATH; do
    DIR="$(dirname "${VIDEO_PATH}")"
    VIDEO="$(basename "${VIDEO_PATH}")"
    cd "${DIR}"

    # CHECK IF FILE IS IN LOG_FILE
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Checking LOG_FILE For ${VIDEO}" >> "${LOG_FILE_DETAIL}"
    if grep -q "^${VIDEO} - " "${LOG_FILE}" 2>/dev/null; then
        STATUS=$(grep "^${VIDEO} - " "${LOG_FILE}" | sed 's/.*- //')

        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Status In Log File Is ${STATUS}" >> "${LOG_FILE_DETAIL}"

        # SKIP FILE IF STATUS OF FILE IS OK
        if [ "${STATUS}" = "OK" ]; then
            echo "Skipping (Previously OK): ${VIDEO}"
            echo "========================================"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Skipping (Previously OK) For ${VIDEO}" >> "${LOG_FILE_DETAIL}"
            echo "========================================" >> "${LOG_FILE_DETAIL}"
            continue
        fi

        # IF FILE IS CORRUPTED RECHECK IT
        echo "Re-Checking (Previously Corrupted): ${VIDEO}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Re-Checking (Previously Corrupted) For ${VIDEO}" >> "${LOG_FILE_DETAIL}"
    else
        echo "Checking (New): ${VIDEO}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Checking (New) For ${VIDEO}" >> "${LOG_FILE_DETAIL}"
    fi

    # GET OUTPUT OF FFMPEG TO CHECK FOR CORRUPTION
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Running FFMPEG" >> "${LOG_FILE_DETAIL}"
    TEMP_ERROR=$(mktemp)
    ffmpeg -nostdin -v warning -xerror -err_detect aggressive -i "${VIDEO}" -f null - 2>"${TEMP_ERROR}"

    FFMPEG_RESPONSE_STATUS=$?
    FFMPEG_ERROR=$(cat "${TEMP_ERROR}")

    rm "${TEMP_ERROR}"

    CORRUPT_PATTERN="error|invalid|corrupt|missing|partial|drop|decode|fail"
    CORRUPT_PATTERN+="|non-monoton|discontinu|reference|conceal|overread|overflow"
    CORRUPT_PATTERN+="|damaged|broken|illegal|mismatch"

    # REMOVE OLD ENTRY OF MEDIA IN LOG_FILE
    if grep -q "^${VIDEO} - " "${LOG_FILE}" 2>/dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Removing Old Entry In LOG_FILE For ${VIDEO}" >> "${LOG_FILE_DETAIL}"
        sed -i "/^${VIDEO} - /d" "${LOG_FILE}"
    fi

    # HANDLE IF CORRUPTION WAS FOUND
    if grep -qiE "${CORRUPT_PATTERN}" <<< "${FFMPEG_ERROR}"; then
        echo "CORRUPTED: ${VIDEO}"
        echo "${VIDEO} - CORRUPTED" >> "${LOG_FILE}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): CORRUPTED For ${VIDEO}" >> "${LOG_FILE_DETAIL}"
        echo "${FFMPEG_ERROR}" >> "${LOG_FILE_DETAIL}"
    elif [ ${FFMPEG_RESPONSE_STATUS} -ne 0 ]; then
        echo "ERROR: ${VIDEO}"
        echo "${VIDEO} - ERROR" >> "${LOG_FILE}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): ERROR For ${VIDEO} - ${FFMPEG_ERROR}" >> "${LOG_FILE_DETAIL}"
    else
        echo "OK: ${VIDEO}"
        echo "${VIDEO} - OK" >> "${LOG_FILE}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): OK For ${VIDEO}" >> "${LOG_FILE_DETAIL}"
    fi
    echo "========================================"
    echo "========================================" >> "${LOG_FILE_DETAIL}"
done < <(find "${MEDIA_FOLDER_PATH}" -type f \( -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" \) -print0)

echo "================================================================================" >> "${LOG_FILE_DETAIL}"

# CLEAN UP REPETITIVE ERROR MESSAGES TO NOT CLOG LOG_FILE_DETAIL
echo "Cleaning Up ${LOG_FILE_DETAIL}" | tee -a "${LOG_FILE_DETAIL}"
TEMP_LOG=$(mktemp)
awk '
BEGIN {
    seen_dts = 0
    seen_codec = 0
    seen_analyze = 0
}

/Application provided invalid, non monotonically increasing dts to muxer/ {
    if (!seen_dts) {
        print "[] Application provided invalid, non monotonically increasing dts to muxer"
        seen_dts = 1
    }
    next
}

/Could not find codec parameters for stream/ {
    if (!seen_codec) {
        print "[] Could not find codec parameters for stream (Subtitle)"
        seen_codec = 1
    }
    next
}

/Consider increasing the value for the analyzeduration/ {
    if (!seen_analyze) {
        print "[] Consider increasing the value for the analyzeduration (0) and probesize (5000000) options"
        seen_analyze = 1
    }
    next
}

/========================================/ {
    seen_dts = 0
    seen_codec = 0
    seen_analyze = 0
}

{ print }
' "${LOG_FILE_DETAIL}" > "${TEMP_LOG}"

mv "${TEMP_LOG}" "${LOG_FILE_DETAIL}"