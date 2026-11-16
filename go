#!/bin/bash
#
# Asks whether to rebuild or release the app in this repo, then runs the script that does it.
# Releasing asks for a confirmation first. The menus are drawn by gum, which the workshop setup
# installs.

set -euo pipefail

cd "$(dirname "$0")"

fail() {
    echo "error: $1" >&2
    exit 1
}

command -v gum > /dev/null || fail "gum is missing. Run setup.sh in the workshop repo."

APP=$(sed -n 's/^name: //p' project.yml)

case $(gum choose --header "What do you want to do?" Rebuild Release) in
    Rebuild)
        exec scripts/rebuild.sh
        ;;
    Release)
        gum confirm "Release $APP?" || exit 0
        exec scripts/release.sh
        ;;
esac
