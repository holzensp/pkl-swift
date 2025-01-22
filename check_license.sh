#!/bin/bash
#####################################################################################
# Copyright © 2024-2025 Apple Inc. and the Pkl project authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#####################################################################################
set -e

# Environment
current_year=$(date +%Y)

# Constants
header_start="(.*Copyright © ([0-9]{4}-)?)([0-9]{4})( Apple Inc. and the Pkl project authors. All rights reserved.)"
header_end="limitations under the License."
backup_extension=".version_header_fix"
default_ignore_pattern="\\(^\\.gitignore\\|\\.\\(adoc\\|ya\\?ml\\|txt\\)\\)$"

# State
status=0
arity="*"
extensions=""

while (($#))
do
  case "$1" in
    --extension|-e)
      arity=""
      shift
      extensions+="\\|$1"
      shift
      ;;
    *)
      echo "Unknown argument $1"
      exit -1
      ;;
  esac
done

files=$(git diff --name-only -r main | grep -v "${default_ignore_pattern}" | grep "\(\.\(${extensions##??}\)\)${arity}\$")


for FILE in $files
do
  latest_year=$(head -n 10 "${FILE}" | sed -nEe "/${header_start}/ {s/${header_start}/\3/; p;}")
  line_count=$(sed -nEe "/${header_start}/,/${header_end}/ {p;}" "${FILE}" | wc -l)

  if [[ ${line_count} -ne 13 ]]; then
    echo "Non-compliant (or missing) header detected in ${FILE}."
    ((status+=1))
  elif [[ "${latest_year}" -lt ${current_year} ]]; then
    echo "Amending copyright years in ${FILE}."
    sed -i "${backup_extension}" -Ee "/${header_start}/ {
      s/(© [0-9]{4}-)[0-9]{4}( Apple)/\1${current_year}\2/
      t print
      s/(© [0-9]{4})( Apple)/\1-${current_year}\2/
      :print
    }" "${FILE}"
    rm "${FILE}${backup_extension}"
  fi
  shift
done

if [[ $status -gt 0 ]]; then
  echo "Some files had non-compliant license headers."
  exit $status
fi

exec git diff --exit-code > /dev/null
