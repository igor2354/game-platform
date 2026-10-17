#!/bin/zsh
cd -- "${0:A:h}" || exit 1
if [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
    godot_bin=/Applications/Godot.app/Contents/MacOS/Godot
elif command -v godot >/dev/null 2>&1; then
    godot_bin=$(command -v godot)
else
    print 'Установите Godot 4.7.2 и откройте project.godot.'
    [[ -t 0 ]] && read -r
    exit 1
fi

# A pull/fresh checkout contains sources and .import metadata, not the local
# .godot cache. Import assets and register script classes before loading menus.
mkdir -p -- "$PWD/.godot" || exit 1
import_log="$PWD/.godot/startup-import.log"
print 'Подготовка ресурсов Godot…'
import_status=0
"$godot_bin" --headless --editor --import --path "$PWD" --quit >"$import_log" 2>&1 || import_status=$?
# Some Godot script/resource errors are logged even when the exit code is 0.
if (( import_status != 0 )) || grep -Eq 'SCRIPT ERROR:|ERROR:' "$import_log"; then
    cat -- "$import_log"
    print -u2 "Не удалось подготовить ресурсы. Журнал: $import_log"
    [[ -t 0 ]] && read -r '?Нажмите Enter, чтобы закрыть окно.'
    exit 1
fi
exec "$godot_bin" --path "$PWD" "$@"
