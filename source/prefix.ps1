$script:dscResourceCommonModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'Modules/DscResource.Common'
Import-Module -Name $script:dscResourceCommonModulePath

$script:viscalyxCommonModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'Modules/Viscalyx.Common'
Import-Module -Name $script:viscalyxCommonModulePath

$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'
