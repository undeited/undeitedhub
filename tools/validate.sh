#!/usr/bin/env bash
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

required_files="main.lua games.lua shared/config.lua shared/settings.lua shared/utils.lua shared/windui.lua"
for path in $required_files; do
    test -f "$path"
done

while IFS= read -r initializer; do
    test -f "$initializer"
done < <(find games -mindepth 2 -maxdepth 2 -type f -name init.lua | sort)

while IFS= read -r registered_path; do
    test -f "$registered_path"
done < <(sed -n 's/.*= "\(games\/[^"[:space:]]*\)".*/\1/p' games.lua)

printf 'Hub structure validation passed.\n'
