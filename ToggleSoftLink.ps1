$pathAddons = "C:\Users\Owner\Documents\Elder Scrolls Online\live\AddOns"
$addonName = "LibScrollableMenu"
$develFolder = "C:\Users\Owner\Documents\Git\eso-LibScrollableMenu"

if (Test-Path $pathAddons\$addonName) {
  $file = Get-Item "$pathAddons\$addonName"
  if($file.Attributes -band [IO.FileAttributes]::ReparsePoint){
    echo "Removing Softlink"
    (Get-Item "$pathAddons\$addonName").Delete()
    if (Test-Path $pathAddons\$addonName_minion) {
      echo "Move Directory"
      echo "$pathAddons\${addonName}_minion"
      Move-Item -Path "$pathAddons\${addonName}_minion" -Destination "$pathAddons\$addonName"
    }
  } else {
    #move folder to _minion
    Move-Item "$pathAddons\$addonName" "$pathAddons\${addonName}_minion"
    echo "Creating Softlink"
    New-Item -ItemType SymbolicLink -Path $pathAddons -Name $addonName -Value $develFolder

  }
} else {
  echo "Creating Softlink"
  New-Item -ItemType SymbolicLink -Path $pathAddons -Name $addonName -Value $develFolder
}