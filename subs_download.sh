#!/bin/bash

# SET LOG FILE PATHS
mkdir -p "/home/${USER}/logs"
touch "/home/${USER}/logs/logs_detail_subs_download.log"
touch "/home/${USER}/logs/logs_subs_download.log"
LOG_FILE_DETAIL="/home/${USER}/logs/logs_detail_subs_download.log"
LOG_FILE="/home/${USER}/logs/logs_subs_download.log"

# ASK USER FOR MOVIE OR SHOW
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Selecting Movie Or Show" >> "${LOG_FILE_DETAIL}"
while true; do
    echo ""
    echo "Chosose Movie Or Show:"
    echo "1) Movie"
    echo "2) Show"
    read -p "Select (1 or 2): " MEDIA_CHOICE

    # SET LANGUAGE_CODE BASED ON LANGUAGE_CHOICE
    case ${MEDIA_CHOICE} in
        1)
            MEDIA_TYPE="movie"
            break
            ;;
        2)
            MEDIA_TYPE="tvshow"
            break
            ;;
        *)
            echo ""
            echo "Invalid Movie Or Show Selection Please Choose 1 Or 2"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N') Error Invalid Movie or Show Selection (${LANGUAGE_CHOICE})" >> "${LOG_FILE_DETAIL}"
            echo "========================================" >> "${LOG_FILE_DETAIL}"
            ;;
    esac
done

echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Movie Or Show Selected Is ${MEDIA_TYPE}" >> "${LOG_FILE_DETAIL}"


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
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Selecting Subtitle Language" >> "${LOG_FILE_DETAIL}"
while true; do
    echo ""
    echo "Which Subtitle Language To Download:"
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

# ASK FOR CREDENTIALS AND IF VALID GET BEARER_TOKEN
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Validating OpenSubtitles Credentials" >> "${LOG_FILE_DETAIL}"
while true; do
    echo ""
    read -rp "Enter OpenSubtitles API KEY: " API_KEY

    echo ""
    read -rp "Enter OpenSubtitles Username: " OPENSUBTITLES_USERNAME
    read -rsp "Enter OpenSubtitles Password: " OPENSUBTITLES_PASSWORD

    echo ""
    echo ""
    echo "Validating OpenSubtitles Credentials..."

    # VALIDATE CREDENTIALS BY ATTEMPTING LOGIN
    TEMP_ERROR=$(mktemp)
    TEMP_RESPONSE=$(mktemp)
    curl -sf --request POST \
        --url "https://api.opensubtitles.com/api/v1/login" \
        --header "Accept: application/json" \
        --header "Api-Key: ${API_KEY}" \
        --header "Content-Type: application/json" \
        --header "User-Agent: subs_download v0.1" \
        --data "{\"username\": \"${OPENSUBTITLES_USERNAME}\", \"password\": \"${OPENSUBTITLES_PASSWORD}\"}" \
        -o "${TEMP_RESPONSE}" 2>"${TEMP_ERROR}"

    LOGIN_RESPONSE_STATUS=$?
    LOGIN_RESPONSE=$(cat "${TEMP_RESPONSE}")
    LOGIN_RESPONSE_ERROR=$(cat "${TEMP_ERROR}")

    rm "${TEMP_RESPONSE}" "${TEMP_ERROR}"

    if [ "${LOGIN_RESPONSE_STATUS}" != "0" ]; then
        if LOGIN_RESPONSE_MESSAGE=$(echo "${LOGIN_RESPONSE}" | jq -re '.message' 2>/dev/null); then
            echo ""
            echo "Invalid Or Missing Credentials"
            echo ""
            echo "Please Try Again."
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Invalid Or Missing Credentials For ${OPENSUBTITLES_USERNAME}" >> "${LOG_FILE_DETAIL}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Status Is ${LOGIN_RESPONSE_STATUS} - ${LOGIN_RESPONSE_MESSAGE}" >> "${LOG_FILE_DETAIL}"
            echo "========================================" >> "${LOG_FILE_DETAIL}"
        else
            echo ""
            echo "Error"
            echo ""
            echo "Please Try Again."
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error In Sending Request To API To Validate Credentials For ${OPENSUBTITLES_USERNAME}" >> "${LOG_FILE_DETAIL}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): ${LOGIN_RESPONSE_ERROR}" >> "${LOG_FILE_DETAIL}"
            echo "========================================" >> "${LOG_FILE_DETAIL}"
        fi
    else
        ALLOWED_DOWNLOADS=$(echo "${LOGIN_RESPONSE}" | jq -r '.user.allowed_downloads')
        BEARER_TOKEN=$(echo "${LOGIN_RESPONSE}" | jq -r '.token')

        echo "Credentials Validated"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Credentials Validated For ${OPENSUBTITLES_USERNAME}" >> "${LOG_FILE_DETAIL}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Allowed Downloads Are ${ALLOWED_DOWNLOADS}" >> "${LOG_FILE_DETAIL}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Bearer Token Is ${BEARER_TOKEN}" >> "${LOG_FILE_DETAIL}"
        break
    fi
done

search_subtitles() {
    local media="$1"
    local media_type="$2"

    if [ "${media_type}" = "tvshow" ]; then
        local media_title="${media% - S[0-9][0-9]E[0-9][0-9]*}"

        local season_episode="${media##* - }"

        local season_number="${season_episode:1:2}"
        season_number="${season_number#0}"

        local episode_number="${season_episode##*E}"
        episode_number="${episode_number#0}"
    else
        local media_title="${media% (*}"
        local media_year="${media##*(}"
        media_year="${media_year%)}"
    fi

    echo "Searching Subtitles: ${media}" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Searching Subtitles For ${media}" >> "${LOG_FILE_DETAIL}"

    # ENCODE MEDIA TO MAKE IT SAFE FOR URL
    local encoded_media_title=$(echo "${media_title}" | jq -Rr @uri)

    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Encoded Media Title Is ${encoded_media_title}" >> "${LOG_FILE_DETAIL}"
    if [ "${media_type}" = "tvshow" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Season Number Is ${season_number}" >> "${LOG_FILE_DETAIL}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Episode Number Is ${episode_number}" >> "${LOG_FILE_DETAIL}"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Media Year Is ${media_year}" >> "${LOG_FILE_DETAIL}"
    fi

    # TRY AND GET MEDIA DETAILS
    TEMP_ERROR=$(mktemp)
    TEMP_RESPONSE=$(mktemp)

    if [ "${MEDIA_TYPE}" = "movie" ]; then
        curl -sf --location --request GET \
            --url "https://api.opensubtitles.com/api/v1/features?query=${encoded_media_title}&year=${media_year}&type=${MEDIA_TYPE}" \
            --header "Accept: application/json" \
            --header "Api-Key: ${API_KEY}" \
            --header "User-Agent: subs_download v0.1" \
            -o "${TEMP_RESPONSE}" 2>"${TEMP_ERROR}"   
    else
        curl -sf --location --request GET \
            --url "https://api.opensubtitles.com/api/v1/features?query=${encoded_media_title}&type=${MEDIA_TYPE}" \
            --header "Accept: application/json" \
            --header "Api-Key: ${API_KEY}" \
            --header "User-Agent: subs_download v0.1" \
            -o "${TEMP_RESPONSE}" 2>"${TEMP_ERROR}" 
    fi

    local media_search_response_status=$?
    local media_search_response=$(cat "${TEMP_RESPONSE}")
    local media_search_error=$(cat "${TEMP_ERROR}")

    rm "${TEMP_RESPONSE}" "${TEMP_ERROR}"

    if [ "${media_search_response_status}" != "0" ]; then
        local media_search_response_message

        if media_search_response_message=$(echo "${media_search_response}" | jq -re '.message' 2>/dev/null); then
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error In Api Request - https://api.opensubtitles.com/api/v1/features?query=${encoded_media_title}&year=${media_year}&type=media" >> "${LOG_FILE_DETAIL}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Status Is ${media_search_response_status} - ${media_search_response_message}" >> "${LOG_FILE_DETAIL}"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error In API To Search For Media Details" >> "${LOG_FILE_DETAIL}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): ${media_search_error}" >> "${LOG_FILE_DETAIL}"
        fi

        return 1
    fi

    # EXTRACT FROM FIRST RESULT THAT HAS BOTH IMDB_ID AND SUBTITLES (OR FEATURE_ID IF NO IMDB)
    local subtitle_count=$(echo "${media_search_response}" | jq -r "[.data[] | select(.attributes.subtitles_counts.${LANGUAGE_CODE} > 0)] | .[0].attributes.subtitles_counts.${LANGUAGE_CODE} // 0")

    if [ "${MEDIA_TYPE}" = "tvshow" ]; then
        local imdb_id=$(echo "${media_search_response}" | jq -r "
            [.data[] | select(.attributes.subtitles_counts.${LANGUAGE_CODE} > 0 and .attributes.imdb_id != null)]
            | .[0].attributes.seasons[]
            | select(.season_number == ${season_number})
            | .episodes[]
            | select(.episode_number == ${episode_number})
            | .feature_imdb_id
            // empty" | head -1)

        local feature_id=$(echo "${media_search_response}" | jq -r "
            [.data[] | select(.attributes.subtitles_counts.${LANGUAGE_CODE} > 0)]
            | .[0].attributes.seasons[]
            | select(.season_number == ${season_number})
            | .episodes[]
            | select(.episode_number == ${episode_number})
            | .feature_id
            // empty" | head -1)
    else
        local imdb_id=$(echo "${media_search_response}" | jq -r "[.data[] | select(.attributes.subtitles_counts.${LANGUAGE_CODE} > 0 and .attributes.imdb_id != null)] | .[0].attributes.imdb_id // empty")
        local feature_id=$(echo "${media_search_response}" | jq -r "[.data[] | select(.attributes.subtitles_counts.${LANGUAGE_CODE} > 0)] | .[0].attributes.feature_id // empty")
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): IMDB ID Is ${imdb_id}" >> "${LOG_FILE_DETAIL}"
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Feature ID Is ${feature_id}" >> "${LOG_FILE_DETAIL}"
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): ${LANGUAGE_NAME} Subtitle Count For Media Is ${subtitle_count}" >> "${LOG_FILE_DETAIL}"

    # DETERMINE WHICH ID TO USE (PREFER IMDB_ID, FALLBACK TO FEATURE_ID AND THEN ID)
    local search_param=""
    local search_value=""

    if [ -n "${imdb_id}" ] && [ "${imdb_id}" != "null" ]; then
        search_param="imdb_id"
        search_value="${imdb_id}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Using IMDB ID For Search" >> "${LOG_FILE_DETAIL}"
    elif [ -n "${feature_id}" ] && [ "${feature_id}" != "null" ]; then
        search_param="id"
        search_value="${feature_id}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): IMDB ID Not Found, Using Feature ID For Search" >> "${LOG_FILE_DETAIL}"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error No IMDB ID Or Feature ID Found For ${media}" >> "${LOG_FILE_DETAIL}"
        return 1
    fi

    # CHECK IF SUBTITLE COUNT WAS FOUND
    if [ -z "${subtitle_count}" ] || [ "${subtitle_count}" == "null" ] || [ "${subtitle_count}" -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error No ${LANGUAGE_NAME} Subtitles Available For ${media}" >> "${LOG_FILE_DETAIL}"
        return 1
    fi

    # TRY AND GET SUBTITLE DETAILS
    TEMP_ERROR=$(mktemp)
    TEMP_RESPONSE=$(mktemp)

    curl -sf --location --request GET \
        --url "https://api.opensubtitles.com/api/v1/subtitles?${search_param}=${search_value}&languages=${LANGUAGE_CODE}" \
        --header "Accept: application/json" \
        --header "Api-Key: ${API_KEY}" \
        --header "User-Agent: subs_download v0.1" \
        -o "${TEMP_RESPONSE}" 2>"${TEMP_ERROR}"

    local subtitle_search_response_status=$?
    local subtitle_search_response=$(cat "${TEMP_RESPONSE}")
    local subtitle_search_error=$(cat "${TEMP_ERROR}")

    rm "${TEMP_RESPONSE}" "${TEMP_ERROR}"

    if [ "${subtitle_search_response_status}" != "0" ]; then
        local subtitle_search_response_message

        if subtitle_search_response_message=$(echo "${subtitle_search_response}" | jq -re '.message' 2>/dev/null); then
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error In Api Request - https://api.opensubtitles.com/api/v1/subtitles?${search_param}=${search_value}&languages=${LANGUAGE_CODE}" >> "${LOG_FILE_DETAIL}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Status Is ${subtitle_search_response_status} - ${subtitle_search_response_message}" >> "${LOG_FILE_DETAIL}"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error In API To Get Subtitle Details" >> "${LOG_FILE_DETAIL}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): ${subtitle_search_error}" >> "${LOG_FILE_DETAIL}"
        fi

        return 1
    else
        echo "${subtitle_search_response}"
        return 0
    fi
}

download_subtitle() {
    local file_id="$1"
    local output_file="$2"
    local bearer_token="$3"

    echo "Downloading Subtitle With ID: ${file_id}" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Downloading Subtitle With ID ${file_id}" >> "${LOG_FILE_DETAIL}"

    # TRY AND DOWNLOAD SUBTITLE
    TEMP_ERROR=$(mktemp)
    TEMP_RESPONSE=$(mktemp)
    curl -sf --location --request POST \
        --url "https://api.opensubtitles.com/api/v1/download" \
        --header "Accept: application/json" \
        --header "Api-Key: ${API_KEY}" \
        --header "Authorization: Bearer ${bearer_token}" \
        --header "Content-Type: application/json" \
        --header "User-Agent: subs_download v0.1" \
        --data '{"file_id": '"${file_id}"'}' \
        -o "${TEMP_RESPONSE}" 2>"${TEMP_ERROR}"

    local subtitle_download_response_status=$?
    local subtitle_download_response=$(cat "${TEMP_RESPONSE}")
    local subtitle_download_error=$(cat "${TEMP_ERROR}")

    rm "${TEMP_RESPONSE}" "${TEMP_ERROR}"

    if [ "${subtitle_download_response_status}" != 0 ]; then
        local subtitle_download_response_message

        if subtitle_download_response_message=$(echo "${subtitle_download_response}" | jq -re '.message' 2>/dev/null); then
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error In Api Request - https://api.opensubtitles.com/api/v1/download" >> "${LOG_FILE_DETAIL}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Status Is ${subtitle_download_response_status} - ${subtitle_download_response_message}" >> "${LOG_FILE_DETAIL}"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error In API To Download Subtitle" >> "${LOG_FILE_DETAIL}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): ${subtitle_download_error}" >> "${LOG_FILE_DETAIL}"
        fi

        return 1
    else
        local download_link=$(echo "${subtitle_download_response}" | jq -r '.link')
        local remaining_downloads=$(echo "${subtitle_download_response}" | jq -r '.remaining')

        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Download Link Is ${download_link}" >> "${LOG_FILE_DETAIL}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Remaining Downloads Are ${remaining_downloads}" >> "${LOG_FILE_DETAIL}"

        # DOWNLOAD SUBTITLE FROM DOWNLOAD LINK
        TEMP_ERROR=$(mktemp)
        curl -sf -o "${output_file}" "${download_link}" 2>"${TEMP_ERROR}"

        local download_link_response_status=$?
        local download_link_error=$(cat "${TEMP_ERROR}")

        rm "${TEMP_ERROR}"

        if [ "${download_link_response_status}" != 0 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Downloading Subtitle From Download Link ${download_link}" >> "${LOG_FILE_DETAIL}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Status Is ${download_link_response_status}" >> "${LOG_FILE_DETAIL}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): ${download_link_error}" >> "${LOG_FILE_DETAIL}"
            return 1
        else
            return 0
        fi
    fi
}

echo ""

# LOOP THROUGH ALL VIDEO FILES (MKV, MP4, AVI)
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Looping Through Video Files" >> "${LOG_FILE_DETAIL}"
echo "========================================" >> "${LOG_FILE_DETAIL}"
while IFS= read -r -d '' VIDEO_PATH; do
    DIR="$(dirname "${VIDEO_PATH}")"
    VIDEO="$(basename "${VIDEO_PATH}")"
    cd "${DIR}"

    # EXTRACT THE FILENAME WITHOUT EXTENSION
    BASE="${VIDEO%.*}"

    if [ -f "${BASE}.${LANGUAGE_CODE}.srt" ]; then
        echo "Skipping (Already Downloaded): ${VIDEO}" | tee -a "${LOG_FILE}"
        echo "========================================" | tee -a "${LOG_FILE}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Skipping (Already Downloaded) For ${VIDEO}" >> "${LOG_FILE_DETAIL}"
        echo "========================================" >> "${LOG_FILE_DETAIL}"
        continue
    fi

    if SUBTITLE_SEARCH_RESPONSE=$(search_subtitles "${BASE}" "${MEDIA_TYPE}"); then
        # CHECK IF THE RESULT IS VALID JSON
        if echo "${SUBTITLE_SEARCH_RESPONSE}" | jq empty 2>/dev/null; then
            # ORDER BY DOWNLOAD_COUNT DESCENDING AND GRAB THE THE FIRST FILE (FILE WITH MOST DOWNLOADS)
            FILE_ID=$(echo "${SUBTITLE_SEARCH_RESPONSE}" | jq -r '[.data[] | select(.attributes.download_count != null)] | sort_by(-.attributes.download_count) | .[0].attributes.files[0].file_id // empty')

            if [ -z "${FILE_ID}" ] || [ "${FILE_ID}" == "null" ]; then
                echo "Error: No File ID Found: ${VIDEO}"
                echo "========================================"
                echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error No File ID Found For ${VIDEO}" >> "${LOG_FILE_DETAIL}"
                echo "========================================" >> "${LOG_FILE_DETAIL}"
                continue
            fi
        else
            echo "Error"
            echo "========================================"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Invalid JSON Response For SUBTITLE_SEARCH_RESULT For ${VIDEO}" >> "${LOG_FILE_DETAIL}"
            echo "========================================" >> "${LOG_FILE_DETAIL}"
            continue
        fi
    else
        echo "Error Searching For Subtitles: ${VIDEO}" | tee -a "${LOG_FILE}"
        echo "========================================" | tee -a "${LOG_FILE}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Searching For Subtitles For ${VIDEO}" >> "${LOG_FILE_DETAIL}"
        echo "========================================" >> "${LOG_FILE_DETAIL}"
        continue
    fi

    download_subtitle "${FILE_ID}" "${BASE}.${LANGUAGE_CODE}.srt" "${BEARER_TOKEN}";

    # CHECK IF SUBTITLE FILE WAS CREATED
    if [ ! -f "${BASE}.${LANGUAGE_CODE}.srt" ]; then
        echo "Error Subtitle Not Downloaded: ${VIDEO}" | tee -a "${LOG_FILE}"
        echo "========================================" | tee -a "${LOG_FILE}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Error Subtitle Not Downloaded For ${VIDEO}" >> "${LOG_FILE_DETAIL}"
        echo "========================================" >> "${LOG_FILE_DETAIL}"
    else
        echo "Success: ${VIDEO}" | tee -a "${LOG_FILE}"
        echo "========================================" | tee -a "${LOG_FILE}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Success For ${VIDEO}" >> "${LOG_FILE_DETAIL}"
        echo "========================================" >> "${LOG_FILE_DETAIL}"
    fi
done < <(find "${MEDIA_FOLDER_PATH}" -type f \( -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" \) -print0)

echo "================================================================================" >> "${LOG_FILE_DETAIL}"