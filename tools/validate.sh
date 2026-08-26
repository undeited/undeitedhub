#!/usr/bin/env bash
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

required_files="main.lua games.lua shared/config.lua shared/settings.lua shared/utils.lua shared/windui.lua shared/hydroxide.lua"
for path in $required_files; do
    test -f "$path"
done

while IFS= read -r initializer; do
    test -f "$initializer"
done < <(find games -mindepth 2 -maxdepth 2 -type f -name init.lua | sort)

while IFS= read -r registered_path; do
    test -f "$registered_path"
done < <(sed -n 's/.*= "\(games\/[^"[:space:]]*\)".*/\1/p' games.lua)

while IFS= read -r loaded_path; do
    test -f "$loaded_path"
done < <(find games shared -type f -name '*.lua' -print0 | xargs -0 grep -hoE 'LoadScript\("[^"]+"\)' | sed 's/LoadScript("//; s/")$//' | sort -u)

test "$(find . -path './.git' -prune -o -type d -empty -print | wc -l)" -eq 0
