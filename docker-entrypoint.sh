#!/bin/bash
set -euo pipefail

# Script environments
: "${MODEL_PATH:=/archi/project}"
: "${REPORT_PATH:=/archi/report}"
: "${HTML_REPORT_ENABLED:=true}"
: "${JASPER_REPORT_ENABLED:=true}"
: "${JASPER_REPORT_FORMATS:=PDF,DOCX}"
: "${CSV_REPORT_ENABLED:=true}"
: "${EXPORT_MODEL_ENABLED:=true}"

# Tools environments
: "${DISPLAY:=:1}"
: "${GIT_SSH_COMMAND:=ssh -oBatchMode=yes}"
: "${GIT_TERMINAL_PROMPT:=0}"
export DISPLAY GIT_SSH_COMMAND GIT_TERMINAL_PROMPT

declare -a args=()

urlencode() {
  local LC_COLLATE=C length="${#1}"
  for ((i = 0; i < length; i++)); do
    local c="${1:$i:1}"
    case $c in
    [a-zA-Z0-9.~_-]) printf '%s' "$c" ;;
    *) printf '%%%02X' "'$c" ;;
    esac
  done
}

if [ "$#" -ge 1 ]; then
  printf '%s\n' "Execute Archi with args: $*"
  xvfb-run /opt/Archi/Archi \
    -application com.archimatetool.commandline.app \
    -consoleLog \
    -nosplash \
    "$@"
  exit 0
fi

# Check and use exist or mounted model
if [ -f "$MODEL_PATH/model/folder.xml" ]; then
  printf '%s\n' \
    "Work with exist model in $MODEL_PATH directory"
  # Try update exist model
  git -C "$MODEL_PATH" pull || :
  TITLE="$(grep -Po 'name="\K([^"]*)' "$MODEL_PATH/model/folder.xml")"

# Work remote git repository model
elif [ -n "${GIT_REPOSITORY:-}" ]; then
  TITLE="$(basename -s .git "$GIT_REPOSITORY")"

  # Chek URL is SSH and clone
  if [ -n "${GIT_REPOSITORY:-}" ] && grep -Pq \
    '^((((git|user)@[\w.-]+)|(git|ssh))(:(\/){0,3}))([\w.@\:/~\-]+)(\.git)(\/)?$' \
    <<< "$GIT_REPOSITORY"
  then
    printf '%s\n' \
      "Clone model from $GIT_REPOSITORY to $MODEL_PATH dir with ssh"
    git clone "$GIT_REPOSITORY" "$MODEL_PATH"

  # Check URL is HTTP
  elif [ -n "${GIT_REPOSITORY:-}" ] && grep -Pq \
    '^(http(s)?(:(\/){0,3}))?([\w.@\:/~\-]+)(\.git)(\/)?$' \
    <<< "$GIT_REPOSITORY"
  then

    # Use token if set
    if [ -n "${GIT_TOKEN:-}" ]; then
      # Encode symbols
      GIT_TOKEN="$(urlencode "$GIT_TOKEN")"

      printf '%s\n' \
        "Clone model from $GIT_REPOSITORY to $MODEL_PATH dir use token"
      git clone \
      "${GIT_REPOSITORY%://*}://oauth2:$GIT_TOKEN@${GIT_REPOSITORY#*://}" \
      "$MODEL_PATH"

    # USe login and password
    elif [ -n "${GIT_USERNAME:-}" ] && [ -n "${GIT_PASSWORD:-}" ]; then
      # Encode symbols
      GIT_USERNAME="$(urlencode "$GIT_USERNAME")"
      GIT_PASSWORD="$(urlencode "$GIT_PASSWORD")"

      printf '%s\n' \
        "Clone model from $GIT_REPOSITORY to $MODEL_PATH dir use token"
      git clone \
      "${GIT_REPOSITORY%://*}://$GIT_USERNAME:$GIT_PASSWORD@${GIT_REPOSITORY#*://}" \
      "$MODEL_PATH"

    # Use public repository access
    else
      printf '%s\n' \
        "Clone model from repository $GIT_REPOSITORY to $MODEL_PATH dir"
      git clone "$GIT_REPOSITORY" "$MODEL_PATH"
    fi

  # Git URL not valid
  else
    >&2 printf '%s\n' \
      'Git repository URL not valid. Plese use http or ssh url'
    exit 1
  fi

# Exit. Model not exist
else
  >&2 printf '%s %s\n' \
    "Plese set http or ssh url to git repositorty in \$GIT_REPOSITORY" \
    "variable or mount model to \$MODEL_PATH ($MODEL_PATH) directory."
  exit 1
fi

# Manage options
[ "${HTML_REPORT_ENABLED,,}" == true ] && \
  args+=(
    '--html.createReport'    "$REPORT_PATH/html"
  )
[ "${JASPER_REPORT_ENABLED,,}" == true ] && \
  args+=(
    '--jasper.createReport'  "$REPORT_PATH/jasper"
    '--jasper.format'        "$JASPER_REPORT_FORMATS"
    '--jasper.filename'      "$TITLE"
    '--jasper.title'         "${JASPER_REPORT_TITLE:-$TITLE}"
  )
[ "${CSV_REPORT_ENABLED,,}" == true ] && \
  args+=(
    '--csv.export'           "$REPORT_PATH/csv"
  )
[ "${EXPORT_MODEL_ENABLED,,}" == true ] && \
  args+=(
    '--saveModel'            "$REPORT_PATH/$TITLE.archimate"
  )

# Make report
xvfb-run /opt/Archi/Archi \
  -application com.archimatetool.commandline.app \
  -consoleLog \
  -nosplash \
  --modelrepository.loadModel "$MODEL_PATH" \
  "${args[@]}"

printf '\n%s\n\n' \
  "Done. Reports saved to $REPORT_PATH"

exit 0
