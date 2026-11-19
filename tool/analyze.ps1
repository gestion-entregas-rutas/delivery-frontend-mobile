# Corre `flutter analyze` en proyectos cuya ruta tiene caracteres no ASCII
# (por ejemplo "GESTIÓN DE APLICACIONES").
#
# Por qué: flutter analyze manda la ruta real al servidor de análisis y el
# mensaje llega cortado ("FormatException: Unexpected end of input") porque el
# largo se calcula en caracteres y no en bytes UTF-8. Una unidad virtual (subst)
# evita la ruta con tilde.
#
# Uso:  powershell -File tool\analyze.ps1

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot

# Primera letra libre, de la Z hacia atrás.
$letter = 90..68 | ForEach-Object { [char]$_ } |
  Where-Object { -not (Test-Path ("{0}:\" -f $_)) } |
  Select-Object -First 1
if (-not $letter) { throw 'No hay una letra de unidad libre.' }

subst "${letter}:" $project
try {
  Push-Location "${letter}:\"
  flutter analyze
  $code = $LASTEXITCODE
} finally {
  Pop-Location
  subst "${letter}:" /d
}
exit $code
