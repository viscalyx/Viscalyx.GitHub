@{
    # Script module or binary module file associated with this manifest.
    RootModule           = 'Viscalyx.GitHub.psm1'

    # Version number of this module.
    ModuleVersion        = '0.0.1'

    # ID used to uniquely identify this module
    GUID                 = 'aba638ad-a584-4234-8eaa-48691b21be2f'

    # Author of this module
    Author               = 'Viscalyx' # cSpell: ignore Viscalyx

    # Company or vendor of this module
    CompanyName          = 'Viscalyx'

    # Copyright statement for this module
    Copyright            = 'Copyright the Viscalyx.GitHub contributors. All rights reserved.'

    # Description of the functionality provided by this module
    Description          = 'Common commands that adds or improves functionality in various scenarios.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion    = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules      = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport    = @()

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport      = @()

    # Variables to export from this module
    VariablesToExport    = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport      = @()

    # DSC resources to export from this module
    DscResourcesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('Common', 'Utility', 'Pester', 'PSReadLine', 'Sampler')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/viscalyx/Viscalyx.GitHub/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/viscalyx/Viscalyx.GitHub'

            # A URL to an icon representing this module.
            IconUri      = 'https://avatars.githubusercontent.com/u/53994072'

            # ReleaseNotes of this module
            ReleaseNotes = ''

            # Prerelease string of this module
            Prerelease   = ''
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}
