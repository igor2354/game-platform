# Внешние ресурсы

| Ресурс | Автор | Источник | Лицензия | Где используется | В репозитории |
|---|---|---|---|---|---|
| Animated Pixel Adventurer v1.5 (кадры idle, run, smrslt, ladder-climb) | rvros | [rvros.itch.io/animated-pixel-hero](https://rvros.itch.io/animated-pixel-hero) | Бесплатно, коммерческое использование и изменение разрешены, указание автора необязательно; перепродавать и распространять сам набор нельзя | Третий режим тела по F4, для сравнения анимаций | Нет: `assets/thirdparty/` в `.gitignore` |

Чтобы третий режим появился у вас локально, скачайте `Adventurer-1.5.zip` со страницы автора, распакуйте и выполните:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tools/import_adventurer.gd -- "<папка Individual Sprites>"
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

Без набора игра работает, просто F4 переключает только два режима.
