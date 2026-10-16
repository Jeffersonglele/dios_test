@echo off
rem Lance l'app avec les clés de dart_defines.json (fond de carte CARTO).
rem Usage : run.bat            (appareil par défaut)
rem         run.bat -d <id>    (appareil précis, voir `flutter devices`)
flutter run --dart-define-from-file=dart_defines.json %*
