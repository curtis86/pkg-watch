# Debug echo
de() {
  local _dmsg="$( date ) - DEBUG - $@"
  echo "${_dmsg}" >&2
  set -u && echo "${_dmsg}" >> "${log_file}"
}

# Error echo
ee() {
  local _msg="$@"
  echo
  echo "Error: ${_msg}"
}

# Warning echo
we() {
  local _msg="$@"
  echo
  echo "Warning: ${_msg}"
}

# A function wrapper for better error messages handling... I think?
f() {
  local _function="$1" ; shift
  local _message_on_error="$@"

  export function_output;

  if ! function_output="$( "${_function}"  )" ; then
    echo "Error: ${_message_on_error}"
    echo "${function_output}"
    exit 1
  else
    return 0
  fi
}

# Sets up directories and files
pw::setup() {
  [ ! -d "${state_dir}" ] && mkdir "${state_dir}"
  [ ! -d "${yum_metadata_dir}" ] && mkdir "${yum_metadata_dir}"
  [ ! -d "${package_metadata_dir}" ] && mkdir "${package_metadata_dir}" 
  
  [ ! -f "${log_file}" ] && touch "${log_file}"
  [ ! -f "${contacts_file}" ] && touch "${contacts_file}"
  [ ! -f "${packages_file}" ] && touch "${packages_file}"
  [ ! -f "${yum_last_cache_expire_file}" ] && touch "${yum_last_cache_expire_file}" && set -u && echo 0 > "${yum_last_cache_expire_file}"
}

# Checks script depdencies are installed
pw::check_dependencies() {
  for dep in "${script_dependencies[@]}" ; do
    if ! which "${dep}" >/dev/null 2>&1 ; then
      echo "Error: script dependency \"${dep}\" not found. Exiting."
      exit 127
    fi
done
}

pw::usage() {
  cat << EOF

Usage: ${progname} <option>

Commands:
update             Updates yum package metadata
pkg-info           Show latest known version of a package

EOF
}

yum::clean() {
  req_args=1
  [ $# -ne ${req_args} ] && ee "Invalid args on yum::clean function" && exit 1

  case "$1" in
    all|cache) yum -q clean packages metadata expire-cache && set -u && echo $( date +%s ) > "${yum_last_cache_expire_file}" ;;
    metadata) yum -q clean packages metadata ;;
    *) ee "Invalid yum::clean option. Exiting" && exit 1
  esac
}

# Tests if a package has a bad character in it
pw::check_pkg_name() {
  local _package="$1"

  [ -z "${_package}" ] && return 1

  _package="$( echo "${_package}" | sed 's/-/DASH/g' | sed 's/\./DOT/g' | sed 's/_/UNDERSCORE/g' )"
  
  _package_filtered="$( echo "${_package}" | tr -d '[:alnum:]' )"
  
  if [ -z "${_package_filtered}" ]; then
    return 0
  else
    return 1
  fi
}

## pkg-watch functions

# List packages being watched
pw::list_packages() {
  if [ -f "${packages_file}" ]; then
    local _packages=( $( cat "${packages_file}" ) )
      if [ -z "${_packages}" ]; then
        ee "packages file found, but no packages defined. Please define a package to watch in ${packages_file} first." && exit 1
      fi
  else
    ee "unable to read packages file, ${packages_file}. Exiting." && exit 1
  fi
  echo
  echo "Currently watching ${#_packages[@]} packages:"
  for package in "${_packages[@]}" ; do
    echo "${package}"
  done
}

# List of contacts that will be notified (email)
pw::list_contacts() {
  if [ -f "${contacts_file}" ]; then
    local _contacts=( $( cat "${contacts_file}" ) )
      if [ -z "${_contacts}" ]; then
        ee "contacts file found, but no contacts defined. Please define a contact email address in ${contacts_file} first." && exit 1
      fi
  else
    ee "unable to read contacts file, ${contacts_file}. Exiting." && exit 1
  fi
  echo
  echo "Currently notifying ${#_contacts[@]} contacts:"
  for contact in "${_contacts[@]}" ; do
    echo "${contact}"
  done
}

# Gets the latest available version from
pw::package_info() {
  local e_args=1
  [ $# -ne ${e_args} ] && pw::usage && exit 1

  local _package="$1"
  local _package_version="$( yum list all ${_package} 2>/dev/null | sed 1d | awk '{ print $2 }' | sort -n | tail -1 )"

  if [ -n "${_package_version}" ]; then
    echo
    echo "The latest version of ${_package} is: ${_package_version}"
  else
    echo "Unable to find version info for package ${_package}." >&2
    exit 1
  fi
}

pw::update() {

 local new_updates=1

  echo "Updating package data for ${#PACKAGES[@]} packages."

  local last_cache_refresh=$( cat "${yum_last_cache_expire_file}" )

  readonly yum_expire_cache_seconds=$(( yum_expire_cache * 60 ))

  if [ ${last_cache_refresh} -eq 0 ]; then
    echo "Yum cache has not been refreshed yet. Refreshing cache..."
    yum::clean cache
  elif [ ${last_cache_refresh} -gt 0 ]; then
    local time_now=$( date +%s )
    local last_update_in_seconds=$(( time_now - last_cache_refresh ))

    if [ ${last_update_in_seconds} -ge ${yum_expire_cache_seconds} ]; then
      echo "Last yum cache refresh was $( date -d@${last_cache_refresh} ) and exceeds cache expiry of ${yum_expire_cache} minutes. Refreshing yum cache..."
      yum::clean cache
    fi
  else
    echo "Last yum cache refresh was $( date -d@${last_cache_refresh} ) and does not exceed cache expiry of ${yum_expire_cache} minutes."
  fi

  echo

  new_updates_file="$( mktemp -p "${yum_metadata_dir}" )"

  # We should do a single yum check for all packages here, but will figure out that method in future.
  
  for package in "${PACKAGES[@]}" ; do
      
    echo "[${package}]"
    local this_package_dir="${package_metadata_dir}/${package}"
    local this_package_last_version_file="${this_package_dir}/last_version"
    local this_package_current_version="$( yum list all "${package}" | sed 1d | awk '{ print $2 }' | sort -n | tail -1 )"

    if [ $? -ne 0 ] || [ -z "${this_package_current_version}" ]; then
      we "Got non-zero exit code, or empty string for package ${package}. This could mean the package is not found, misspelled or contains a bad character. This package will be skipped for the rest of this run."
      echo
      continue
    fi

    echo " * Got package version ${this_package_current_version}"

    # If last known version file doesn't exist, assume it's never been checked before
    if [ ! -d "${this_package_dir}" ] || [ ! -f "${this_package_last_version_file}" ]; then
      [ ! -d "${this_package_dir}" ] && mkdir "${this_package_dir}"
      touch "${this_package_last_version_file}"
      set -u && echo "${this_package_current_version}" > "${this_package_last_version_file}"
    else
      # File exists, so assume that version has been checked before. If current version differs from last version, assume we have a new version available.
      local this_package_last_version="$( cat "${this_package_last_version_file}" )"
      echo " * Got last checked version ${this_package_last_version}"

      if [ "${this_package_current_version}" != "${this_package_last_version}" ]; then
        new_updates=0
        echo " * Package update detected. Adding package to updates file."
        set -u && echo "${this_package_current_version}" > "${this_package_last_version_file}"
        set -u && echo "${package},${this_package_current_version}" >> "${new_updates_file}"
      else
        echo " * No package version change detected."
      fi
    fi
  done
  
  echo

  if [ ${new_updates} -eq 0 ]; then
    echo "New updates detected. Sending notifications."
    pw::send_updates_notification "${new_updates_file}"
  fi
}

pw::send_updates_notification() {
  local updates_file="$1"

  _new_update_data="$( cat "${updates_file}" | sed 's/,/ /g' | column -t )"

  if [ -f "${contacts_file}" ]; then
      _contacts=( $( cat "${contacts_file}" ) )
      if [ ${#_contacts[@]} -eq 0 ]; then
        ee "not sending notifications - contacts file found, but no contacts defined. Please define contact email address(es) in ${contacts_file} if you want to send email notifications."
      else
        local subject="[pkg-watch] Package updates available!"
        update_msg="The following package(s) have updates available: 

${_new_update_data}"

        for contact in "${_contacts[@]}" ; do
          echo "Sending notification to ${contact}"
          echo "${update_msg}" | mail -s "${subject}" "${contact}"
        done
      fi
  else
    ee "unable to read contacts file, ${contacts_file}. Not sending notification."
  fi
  echo

  # Clean up new updates file
  set -u && rm "${updates_file}"
}

# Tests packages file
pw::test_config() {

  # Test package configuration
  if [ -f "${packages_file}" ]; then
    if [ $( wc -c "${packages_file}" | awk '{ print $1 }' ) -eq 0 ]; then
      ee "packages file found, but no packages defined. Please define a package to watch in ${packages_file} first." && exit 1
    else
      PACKAGES=( $( cat "${packages_file}" ) )
    fi
  else
    ee "unable to read packages file, ${packages_file}. Exiting." && exit 1
  fi
  echo

  # Verify package names
  local package_array_index=0
  for package in "${PACKAGES[@]}" ; do

    if ! pw::check_pkg_name "${package}" ; then
      we "package name '${package}' contains illegal characters. Package will be skipped."
      unset PACKAGES[${package_array_index}]
      echo
    fi

    ((package_array_index++))

  done

  [ ${#PACKAGES[@]} -eq 0 ] && ee "no more packages left in array, exiting." && exit 1
}