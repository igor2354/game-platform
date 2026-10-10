#!/bin/zsh
cd -- "${0:A:h}"
if [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
    exec /Applications/Godot.app/Contents/MacOS/Godot --path "$PWD"
elif command -v godot >/dev/null 2>&1; then
    exec godot --path "$PWD"
else
    print 'Установите Godot 4.4+ и откройте project.godot.'
    read -r
fi
