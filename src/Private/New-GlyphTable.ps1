function New-GlyphTable {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory table only.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseLiteralInitializerForHashtable', '', Justification = 'The tables need an explicit OrdinalIgnoreCase comparer, which a literal initializer cannot provide.')]
    [OutputType([hashtable])]
    [CmdletBinding()]
    param()

    $comparer = [System.StringComparer]::OrdinalIgnoreCase
    @{
        files       = @{
            names      = [hashtable]::new($comparer)
            extensions = [hashtable]::new($comparer)
            links      = [hashtable]::new($comparer)
            default    = $null
        }
        directories = @{
            names   = [hashtable]::new($comparer)
            links   = [hashtable]::new($comparer)
            default = $null
        }
    }
}
