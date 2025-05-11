@{
    InvokeBuild                    = 'latest'
    PSScriptAnalyzer               = 'latest'
    ConvertToSARIF                 = 'latest' # cSpell: disable-line

    <#
        If preview release of Pester prevents release we should temporary shift
        back to stable.
    #>
    Pester                         = @{
        Version    = 'latest'
        Parameters = @{
            AllowPrerelease = $true
        }
    }

    Plaster                        = 'latest'
    ModuleBuilder                  = 'latest'
    ChangelogManagement            = 'latest'
    Sampler                        = 'latest'
    'Sampler.GitHubTasks'          = 'latest'
    MarkdownLinkCheck              = 'latest'
    'DscResource.Test'             = 'latest'
    xDscResourceDesigner           = 'latest'

    # Build dependencies needed for using the module
    'DscResource.Common'           = 'latest'

    # Analyzer rules
    'DscResource.AnalyzerRules'    = 'latest'
    'Indented.ScriptAnalyzerRules' = 'latest'

    # Prerequisite modules for documentation.
    'DscResource.DocGenerator'     = 'latest'
    PlatyPS                        = 'latest'

    'Viscalyx.Assert'              = @{
        Version    = 'latest'
        Parameters = @{
            AllowPrerelease = $true
        }
    }
}
