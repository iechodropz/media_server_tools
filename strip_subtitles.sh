#!/usr/bin/env bash

set -euo pipefail

#
# strip_subtitles.sh
#
# WHAT THIS DOES
#   1. Recursively scans a directory (and all subdirectories) for media files.
#   2. For each media file, creates a copy with ALL subtitle streams removed.
#   3. By default, cleaned files go into a new "<source>_no_subs" folder,
#      mirroring the original folder structure, so your originals are safe.
#
# REQUIREMENTS
#   - ffmpeg must be installed.
#       Ubuntu:  sudo apt install ffmpeg
#
# USAGE
#   ./strip_subtitles.sh <source_directory> [options]
#
# OPTIONS
#   -o, --output <dir>       Where to put cleaned files (default: "<source>_no_subs").
#   --overwrite-original     Overwrite original files instead of copying to a new folder.
#   --delete-external-subs   Also delete standalone subtitle files sitting next to media files (e.g. movie.srt).
#   --force                  Re-process files even if they're already marked as done.
#   -h, --help               Show this help text
#
# ALREADY-STRIPPED FILES
#   Every file that finishes successfully gets its relative path written to:
#       ~/logs/strip_subtitles_done.list
#   On the next run, any file whose relative path is already in that list is
#   skipped automatically, so you can re-run this script on the same folder
#   over and over without re-stripping movies you already handled.
#   Use --force to ignore this list and process everything again.
#
# EXAMPLES
#   ./strip_subtitles.sh ~/Videos
#   ./strip_subtitles.sh ~/Videos -o ~/Videos_clean
#   ./strip_subtitles.sh ~/Videos --overwrite-original --delete-external-subs

cleanup() {
    if [[ -n "${SRC_DIR:-}" && -d "${SRC_DIR}" ]]; then
        find "${SRC_DIR}" -type f -name "*.tmp_nosubs.*" -delete 2>/dev/null
    fi

    echo "================================================================================" >> "${LOG_FILE}"
    echo "================================================================================" >> "${LOG_FILE_DETAIL}"
}

trap cleanup EXIT
trap 'echo "Interrupted by user."; exit 130' INT
trap 'echo "Terminated."; exit 143' TERM

SCRIPT_NAME="$(basename "$0")"

# SET LOG FILE PATHS
LOG_DIR="${HOME}/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE_DETAIL="${LOG_DIR}/logs_detail_strip_subtitles.log"
LOG_FILE="${LOG_DIR}/logs_strip_subtitles.log"
DONE_FILE="${LOG_DIR}/strip_subtitles_done.list"
touch "${LOG_FILE_DETAIL}"
touch "${LOG_FILE}"
touch "${DONE_FILE}"

echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Running ${SCRIPT_NAME}..." >> "${LOG_FILE_DETAIL}"

SRC_DIR=""
OUT_DIR=""
OVERWRITE_ORIGINAL=false
DELETE_EXTERNAL_SUBS=false
FORCE=false

# PRINT ONLY THE HELP SECTION FROM ABOVE.
print_help() {
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Printing Help" >> "${LOG_FILE_DETAIL}"
    awk '
        /^#!/ { next }
        /^# strip_subtitles.sh/ { found=1 }
        found && /^#/ { print }
        found && !/^#/ { exit }
    ' "$0" | sed 's/^#//; s/^ //'
    exit 0
}

# CHECK WHETHER THE USER RAN THE SCRIPT WITHOUT ANY COMMAND-LINE ARGUMENTS OR PASSED (-h) OR (--help) flags, ($#) IS A SPECIAL BASH VARIABLE THAT CONTAINS THE NUMBER OF COMMAND-LINE ARGUMENTS PASSED TO THE SCRIPT.
if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
    print_help
fi

# REMOVE THE FIRST COMMAND-LINE ARGUMENT AND SHIFT ALL THE OTHERS DOWN BY ONE POSITION.
SRC_DIR="$1"
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Source Directory Is ${SRC_DIR}" >> "${LOG_FILE_DETAIL}"
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Removing The First Command-Line Argument And Shifting All The Others Down By One Position..." >> "${LOG_FILE_DETAIL}"
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) ${@}" >> "${LOG_FILE_DETAIL}"
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) |" >> "${LOG_FILE_DETAIL}"
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) V" >> "${LOG_FILE_DETAIL}"
shift
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) ${@}" >> "${LOG_FILE_DETAIL}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            if [[ $# -lt 2 ]]; then
                echo "Error: $1 requires a directory" | tee -a "${LOG_FILE}"
                echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (Error) $1 requires a directory" >> "${LOG_FILE_DETAIL}"
                exit 1
            fi

            OUT_DIR="$2"
            shift 2
            ;;
        --overwrite-original)
            OVERWRITE_ORIGINAL=true
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): OVERWRITE_ORIGINAL Is true" >> "${LOG_FILE_DETAIL}"
            shift
            ;;
        --delete-external-subs)
            DELETE_EXTERNAL_SUBS=true
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): DELETE_EXTERNAL_SUBS Is true" >> "${LOG_FILE_DETAIL}"
            shift
            ;;
        --force)
            FORCE=true
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): FORCE Is true" >> "${LOG_FILE_DETAIL}"
            shift
            ;;
        -h|--help)
            print_help
            ;;
        *)
            echo Error: "Unknown option: ${1}" | tee -a "${LOG_FILE}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (ERROR) Unknown option: ${1}" >> "${LOG_FILE_DETAIL}"
            exit 1
            ;;
    esac
done

while [[ ! -d "$SRC_DIR" ]]; do
    echo "Warning: '${SRC_DIR}' is not a valid directory." | tee -a "${LOG_FILE}"
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (WARNING) '${SRC_DIR}' is not a valid directory." >> "${LOG_FILE_DETAIL}"

    read -r -p "Enter a valid source directory: " SRC_DIR
done

if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Install it first (e.g. sudo apt install ffmpeg)"| tee -a "${LOG_FILE}"
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (ERROR) ffmpeg is not installed." >> "${LOG_FILE_DETAIL}"
    exit 1
fi

# REMOVE TRAILING SLASH (/).
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Removing Trailing Slash..." >> "${LOG_FILE_DETAIL}"
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) ${SRC_DIR}" >> "${LOG_FILE_DETAIL}"
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) |" >> "${LOG_FILE_DETAIL}"
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) V" >> "${LOG_FILE_DETAIL}"
SRC_DIR="${SRC_DIR%/}"
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) ${SRC_DIR}" >> "${LOG_FILE_DETAIL}"

if [[ "${OVERWRITE_ORIGINAL}" == false && -z "${OUT_DIR}" ]]; then
    OUT_DIR="${SRC_DIR}_no_subs"
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Output Directory Is ${OUT_DIR}" >> "${LOG_FILE_DETAIL}"
fi

if [[ "${OVERWRITE_ORIGINAL}" == false ]]; then
    if [[ -d "${OUT_DIR}" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Output Directory Already Exists (${OUT_DIR})" >> "${LOG_FILE_DETAIL}"
    else
        mkdir -p "${OUT_DIR}"
        echo "Created output directory: ${OUT_DIR}" | tee -a "${LOG_FILE}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): Created Output Directory (${OUT_DIR})" >> "${LOG_FILE_DETAIL}"
    fi
fi


if [[ "${OVERWRITE_ORIGINAL}" == true ]]; then
    echo "Warning: --overwrite-original will overwrite your original files"| tee -a "${LOG_FILE}"
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (WARNING): --overwrite-original will overwrite your original files" >> "${LOG_FILE_DETAIL}"
    read -r -p "Type 'yes' to continue: " CONFIRM
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) ${CONFIRM}" >> "${LOG_FILE_DETAIL}"
    if [[ "${CONFIRM}" != "yes" ]]; then
        echo "Aborted" | tee -a "${LOG_FILE}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Aborted" >> "${LOG_FILE_DETAIL}"
        exit 1
    fi
fi

MEDIA_EXTENSIONS=(mp4 mkv avi mov wmv flv webm m4v mpg mpeg ts m2ts 3gp)
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Media Extensions Are ${MEDIA_EXTENSIONS[*]}" >> "${LOG_FILE_DETAIL}"
SUBTITLE_EXTENSIONS=(srt ass ssa vtt sub idx)

# expr=("mkv" "mp4" "avi") ---> expr=(-iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" -o)
build_find_expr() {
    # CREATES A LOCAL REFERENCE TO THE ARRAY NAME PASSED AS THE FIRST ARGUMENT.
    local -n extensions=$1
    local expr=()
    for ext in "${extensions[@]}"; do
        expr+=(-iname "*.${ext}" -o)
    done

    # DELETE THE FINAL (-o) FROM expr.
    unset 'expr[${#expr[@]}-1]'   # drop the trailing -o
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Looping Through Find Expression (${expr[@]})" >> "${LOG_FILE_DETAIL}"
    echo "${expr[@]}"
}

FILE_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

read -r -a MEDIA_FIND_ARGS <<< "$(build_find_expr MEDIA_EXTENSIONS)"

FIND_EXCLUDE=(-not -name "._*" -not -name ".DS_Store")

if [[ -n "${OUT_DIR}" ]]; then
    FIND_EXCLUDE+=(-not -path "${OUT_DIR}/*")
fi

echo "========================================" | tee -a "${LOG_FILE}"
echo "========================================" >> "${LOG_FILE_DETAIL}"

# READ UNTIL YOU ENCOUNTER A NULL CHARACTER INSTEAD OF A NEWLINE.
while IFS= read -r -d '' file; do
    # SRC_DIR="/Videos" ---> file="/Videos/Movies/Avatar.mkv" ---> rel_path="Movies/Avatar.mkv"
    rel_path="${file#$SRC_DIR/}"

    # CHECK IF THIS FILE'S RELATIVE PATH IS ALREADY RECORDED IN THE DONE FILE.
    # -F = TREAT THE SEARCH TERM AS A PLAIN STRING, NOT A REGEX.
    # -x = MATCH THE WHOLE LINE EXACTLY, NOT JUST A PART OF IT.
    # -q = STAY QUIET, WE ONLY CARE ABOUT THE EXIT CODE (FOUND OR NOT).
    if [[ "${FORCE}" == false ]] && grep -Fxq "${rel_path}" "${DONE_FILE}" 2>/dev/null; then
        SKIP_COUNT=$((SKIP_COUNT + 1))
        echo "Skipping (already stripped): $rel_path" | tee -a "${LOG_FILE}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Skipping (Already Stripped): $rel_path" >> "${LOG_FILE_DETAIL}"
        echo "========================================" | tee -a "${LOG_FILE}"
		echo "========================================" >> "${LOG_FILE_DETAIL}"
        continue
    fi

    FILE_COUNT=$((FILE_COUNT + 1))

    echo "Processing... ($FILE_COUNT): $rel_path" | tee -a "${LOG_FILE}"
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Processing... ($FILE_COUNT): $rel_path" >> "${LOG_FILE_DETAIL}"

    if [[ "${OVERWRITE_ORIGINAL}" == true ]]; then
        tmp_file="${file}.tmp_nosubs.${file##*.}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Creating Temp File (${tmp_file})" >> "${LOG_FILE_DETAIL}"
        if ffmpeg -y -nostdin -loglevel warning -i "$file" -map 0 -sn -c copy "${tmp_file}" 2>>"${LOG_FILE_DETAIL}" && mv -f "${tmp_file}" "${file}"; then
            echo "Subtitles removed (overwritten original)." | tee -a "${LOG_FILE}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Subtitles removed (overwritten original)" >> "${LOG_FILE_DETAIL}"
            echo "${rel_path}" >> "${DONE_FILE}"
        else
            echo "Error: Failed to process ${file}" | tee -a "${LOG_FILE}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (ERROR) Failed To Process ${file}" >> "${LOG_FILE_DETAIL}"
            rm -f "${tmp_file}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Deleted Temp File (${tmp_file})" >> "${LOG_FILE_DETAIL}"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        out_file="${OUT_DIR}/${rel_path}"
        mkdir -p "$(dirname "${out_file}")"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Created Output File (${out_file})" >> "${LOG_FILE_DETAIL}"

        if ffmpeg -y -nostdin -loglevel warning -i "$file" -map 0 -sn -c copy "${out_file}" 2>>"${LOG_FILE_DETAIL}"; then
            chmod --reference="$file" "${out_file}"
            chown --reference="$file" "${out_file}"

            echo "Saved clean copy to: ${out_file}" | tee -a "${LOG_FILE}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Saved Clean Copy To ${out_file}" >> "${LOG_FILE_DETAIL}"
            echo "${rel_path}" >> "${DONE_FILE}"
        else
            echo "Error: Failed to process ${file}"
            echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (ERROR) Failed To Process ${file}" >> "${LOG_FILE_DETAIL}"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    fi

    echo "========================================" | tee -a "${LOG_FILE}"
    echo "========================================" >> "${LOG_FILE_DETAIL}"

done < <(find "${SRC_DIR}" -type f "${FIND_EXCLUDE[@]}" \( "${MEDIA_FIND_ARGS[@]}" \) -print0)

# DELETE EXTERNAL SUBTITLE FILES
if [[ "${DELETE_EXTERNAL_SUBS}" == true ]]; then
    echo "========================================"
    echo "Deleting external subtitle files..." | tee -a "${LOG_FILE}"
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Deleting External Subtitle Files..." >> "${LOG_FILE_DETAIL}"
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Subtitle Extensions Are ${SUBTITLE_EXTENSIONS}" >> "${LOG_FILE_DETAIL}"

    read -r -a SUB_FIND_ARGS <<< "$(build_find_expr SUBTITLE_EXTENSIONS)"

    SUB_COUNT=0
    while IFS= read -r -d '' subfile; do
        rm -f "${subfile}"
        echo "Deleted: ${subfile}" | tee -a "${LOG_FILE}"
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Deleted (${subfile})" >> "${LOG_FILE_DETAIL}"
        SUB_COUNT=$((SUB_COUNT + 1))
    done < <(find "${SRC_DIR}" -type f "${FIND_EXCLUDE[@]}" \( "${SUB_FIND_ARGS[@]}" \) -print0)

    echo "Deleted ${SUB_COUNT} external subtitle file(s)" | tee -a "${LOG_FILE}"
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Deleted ${SUB_COUNT} external subtitle file(s)" >> "${LOG_FILE_DETAIL}"
fi

echo "Done" | tee -a "${LOG_FILE}"
echo "Media files processed: ${FILE_COUNT}" | tee -a "${LOG_FILE}"
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Media Files Processed Is ${FILE_COUNT}" >> "${LOG_FILE_DETAIL}"
echo "Media files skipped (already stripped): ${SKIP_COUNT}" | tee -a "${LOG_FILE}"
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Media Files Skipped Is ${SKIP_COUNT}" >> "${LOG_FILE_DETAIL}"
echo "Media files failures: ${FAIL_COUNT}" | tee -a "${LOG_FILE}"
echo "$(date '+%Y-%m-%d %H:%M:%S.%3N'): (INFO) Media Files Failures Is ${FAIL_COUNT}" >> "${LOG_FILE_DETAIL}"
