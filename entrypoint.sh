#!/bin/bash

[ "${DEBUG:-false}" = true ] && set -x
set -euo pipefail

# Vars
# ----

# Script environments
: "${ARCHI_PROJECT_PATH:=${GITHUB_WORKSPACE:-${CI_PROJECT_DIR:-/archi/project}}}"
: "${ARCHI_REPORT_PATH:=/archi/report}"
: "${ARCHI_HTML_REPORT_ENABLED:=true}"
: "${ARCHI_JASPER_REPORT_ENABLED:=false}"
: "${ARCHI_JASPER_REPORT_FORMATS:=PDF,DOCX}"
: "${ARCHI_CSV_REPORT_ENABLED:=false}"
: "${ARCHI_EXPORT_MODEL_ENABLED:=true}"
: "${ARCHI_APP:=com.archimatetool.commandline.app}"

: "${GITHUB_SERVER_URL:=https://github.com}"
: "${GITHUB_PAGES_BRANCH:=gh-pages}"
: "${GIT_SUBTREE_PREFIX:=.archi_report}"

# Tools environments
declare -a _ssh_args=(
  -o BatchMode=yes
  -o UserKnownHostsFile=/dev/null
  -o StrictHostKeyChecking=no
)
GIT_SSH_COMMAND="ssh ${_ssh_args[*]}"
GIT_TERMINAL_PROMPT=0
DISPLAY=:1
export GIT_SSH_COMMAND GIT_TERMINAL_PROMPT DISPLAY

# Regex
_re_url='([\w.@\:/~\-]+)(\.git)(\/)?'
_re_proto_http='(http(s)?(:(\/){0,3}))?'
_re_proto_ssh='((((git|user)@[\w.-]+)|(git|ssh))(:(\/){0,3}))'


# Functions
# ---------

# Run Archi
archi_run() {
  local -a _args=()

  # Html report
  [ "${ARCHI_HTML_REPORT_ENABLED,,}" == true ] &&
    _args+=(
      --html.createReport
        "${ARCHI_HTML_REPORT_PATH:=$ARCHI_REPORT_PATH/html}"
    )

  # CSV report
  [ "${ARCHI_CSV_REPORT_ENABLED,,}" == true ] &&
    _args+=(
      --csv.export
        "${ARCHI_CSV_REPORT_PATH:=$ARCHI_REPORT_PATH/csv}"
    )

  # Export model
  [ "${ARCHI_EXPORT_MODEL_ENABLED,,}" == true ] &&
    _args+=(
      --saveModel
        "${ARCHI_EXPORT_MODEL_PATH:=$ARCHI_REPORT_PATH}/$_project.archimate"
    )

  # Jasper report
  [ "${ARCHI_JASPER_REPORT_ENABLED,,}" == true ] &&
    _args+=(
      --jasper.createReport
        "${ARCHI_JASPER_REPORT_PATH:=$ARCHI_REPORT_PATH/jasper}"
      --jasper.format
        "$ARCHI_JASPER_REPORT_FORMATS"
      --jasper.filename
        "$_project"
      --jasper.title
        "${ARCHI_JASPER_REPORT_TITLE:=$_project}"
    )

  # Run Archi
  xvfb-run \
    /opt/Archi/Archi -application "$ARCHI_APP" -consoleLog -nosplash \
      --modelrepository.loadModel "$ARCHI_PROJECT_PATH" "${_args[@]}" &&
  printf '\n%s\n\n' "Done. Reports saved to $ARCHI_REPORT_PATH"
}

# Check first argument match regex present in second argument
re_match() {
  local value="${1:-}" regex="${2:-.*}"
  [ -n "$value" ] && grep -Pq "$regex" <<<"$value" && return 0
  return 1
}

# Encode url symbols
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

update_html() {
  if [ "${ARCHI_CSV_REPORT_ENABLED,,}" == true ]; then
    for item in {elements,properties,relations}; do
      _li="<li><a href=\"${item}.csv\" class=\"go\">${item^}</a></li>"
      sed "/modal.*i18n-about/i $_li" -i "$ARCHI_REPORT_PATH/index.html"
    done
  fi

  if [ "${ARCHI_JASPER_REPORT_ENABLED,,}" == true ]; then
    for item in ${ARCHI_JASPER_REPORT_FORMATS//,/ }; do
      _li="<li><a href=\"$_project.${item,,}\" class=\"go\">${item^^}</a></li>"
      sed "/modal.*i18n-about/i $_li" -i "$ARCHI_REPORT_PATH/index.html"
    done
  fi

  if [ "${ARCHI_EXPORT_MODEL_ENABLED,,}" == true ]; then
    _li="<li><a href=\"$_project.archimate\" class=\"go\">Model</a></li>"
    sed "/modal.*i18n-about/i $_li" -i "$ARCHI_REPORT_PATH/index.html"
  fi
}

# Git clone wrap
git_clone() { git clone "${1:?Repo url not set}" "$ARCHI_PROJECT_PATH"; }

# GitLab log separator
section_start () {
  printf '\e[0Ksection_start:%s:%s[collapsed=true]\r\e[0K\e[1;36m%s\e[0m\n' \
    "$(date +%s)" "$1" "${*:2}"
}
section_end () {
  printf '\e[0Ksection_end:%s:%s\r\e[0K\n' "$(date +%s)" "$*"
}

# Fail message to stder and exit 1
fail() { printf >&2 '%s\n' "$*"; exit 1; }


# Main
# ----

# Run custom archi command
if [ "$#" -ge 1 ]; then
  echo "Execute Archi with _args: $*"
  xvfb-run \
    /opt/Archi/Archi -application "$ARCHI_APP" -consoleLog -nosplash "$@"
  exit 0
fi


# Get project title
if [ -f "$ARCHI_PROJECT_PATH/model/folder.xml" ]; then
  _project="$(
    grep -Pom1 'name="\K([^"]*)' \
      "$ARCHI_PROJECT_PATH/model/folder.xml" | \
      head -1
  )"
elif [ -n "${GIT_REPOSITORY:-}" ]; then
  _project="$(basename -s .git "$GIT_REPOSITORY")"
else
  _project='Model'
fi


# Run in GitHub actions
if [ "${GITHUB_ACTIONS:-}" == true ]; then
  echo "Run Archi report generation in GitHub actions"

  # Prepare vars
  : "${GITHUB_REPOSITORY:?Repository name not set}"
  GITHUB_TOKEN="$(urlencode "${GITHUB_TOKEN:?Token not specified}")"

  # Create repository url with token
  _gh_repo="${GITHUB_SERVER_URL//:\/\/*}://"                       # Protocol
  _gh_repo+="x-access-token:$GITHUB_TOKEN@"                        # Auth
  _gh_repo+="${GITHUB_SERVER_URL//*\/\/}/$GITHUB_REPOSITORY.git"   # URL

  # Set actions specified paths
  ARCHI_REPORT_PATH="$ARCHI_PROJECT_PATH/$GIT_SUBTREE_PREFIX"
  ARCHI_HTML_REPORT_PATH="$ARCHI_REPORT_PATH"
  ARCHI_CSV_REPORT_PATH="$ARCHI_REPORT_PATH"
  ARCHI_JASPER_REPORT_PATH="$ARCHI_REPORT_PATH"
  ARCHI_EXPORT_MODEL_PATH="$ARCHI_REPORT_PATH"
  cd "$ARCHI_PROJECT_PATH" && mkdir -p "$ARCHI_REPORT_PATH"

  # Create CNAME for custon domain
  [ -n "${GITHUB_PAGES_DOMAIN:-}" ] &&
    echo "$GITHUB_PAGES_DOMAIN" > "$ARCHI_REPORT_PATH/CNAME"

  # Disable Jekyll
  touch "$ARCHI_REPORT_PATH/.nojekyll"

  # Create report
  archi_run

  [ "${ARCHI_HTML_REPORT_ENABLED,,}" == true ] && update_html

  exit 0

fi

# Run in GitLab CI
if [ "${GITLAB_CI:-}" == true ]; then
  echo "Run Archi report generation in GitLab CI"
  section_start 'archi_report' 'Render ArchiMate report'

  # Set actions specified paths
  ARCHI_REPORT_PATH="$CI_PROJECT_DIR/public"
  ARCHI_HTML_REPORT_PATH="$CI_PROJECT_DIR/public"
  ARCHI_CSV_REPORT_PATH="$CI_PROJECT_DIR/public"
  ARCHI_JASPER_REPORT_PATH="$CI_PROJECT_DIR/public"
  ARCHI_EXPORT_MODEL_PATH="$CI_PROJECT_DIR/public"
  cd "$ARCHI_PROJECT_PATH" && mkdir -p "$ARCHI_REPORT_PATH"

  # Create report
  archi_run
  [ "${ARCHI_HTML_REPORT_ENABLED,,}" == true ] && update_html

  section_end 'Render ArchiMate report complete'
  exit 0
fi

# Check and use exist or mounted model
if [ -f "$ARCHI_PROJECT_PATH/model/folder.xml" ]; then
  echo "Work with exist model in $ARCHI_PROJECT_PATH directory"
  # Try update exist model
  {
    git -C "$ARCHI_PROJECT_PATH" pull &>/dev/null &&
    echo "Use actual state of model $_project."
  } || :


# Work with remote git repository model
elif [ -n "${GIT_REPOSITORY:-}" ]; then

  # Chek URL is SSH and clone
  if re_match "${GIT_REPOSITORY:-}" "^$_re_proto_ssh$_re_url$"; then
    echo "Clone model from $GIT_REPOSITORY to $ARCHI_PROJECT_PATH dir with ssh"
    git_clone "$GIT_REPOSITORY"

  # Check URL is HTTP
  elif re_match "${GIT_REPOSITORY:-}" "^$_re_proto_http$_re_url$"; then
    _proto="${GIT_REPOSITORY%://*}"

    # Use token if set
    if [ -n "${GIT_TOKEN:-}" ]; then
      # Encode symbols
      GIT_TOKEN="$(urlencode "$GIT_TOKEN")"

      if re_match "${GIT_REPOSITORY:-}" '^https://github.com/'; then
        _auth="x-access-token:$GIT_TOKEN"
      else
        _auth="oauth2:$GIT_TOKEN"
      fi

      echo \
        "Clone model from $GIT_REPOSITORY to $ARCHI_PROJECT_PATH dir use token"
      git_clone "$_proto://$_auth@${GIT_REPOSITORY#*://}"

    # Use login and password
    elif [ -n "${GIT_USERNAME:-}" ] && [ -n "${GIT_PASSWORD:-}" ]; then
      # Encode symbols
      _auth="$(urlencode "$GIT_USERNAME"):$(urlencode "$GIT_PASSWORD")"

      echo \
        "Clone model from $GIT_REPOSITORY to $ARCHI_PROJECT_PATH dir use token"
      git_clone "$_proto://$_auth@${GIT_REPOSITORY#*://}"

    # Use public repository access
    else
      echo \
        "Clone model from repository $GIT_REPOSITORY to $ARCHI_PROJECT_PATH dir"
      git_clone "$GIT_REPOSITORY"

    fi

  # Git URL not valid
  else
    fail 'Git repository URL not valid. Plese use http or ssh url'
  fi

# Exit. Model not exist
else
  fail \
    "Plese set http or ssh url to git repositorty in \$GIT_REPOSITORY" \
    "variable or mount model to \$ARCHI_PROJECT_PATH ($ARCHI_PROJECT_PATH)" \
    'directory.'
fi


# Make report
archi_run

exit 0
