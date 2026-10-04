function Find-GlyphEntry {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Table,

        [Parameter(Mandatory)]
        [ValidateSet('files', 'directories')]
        [string]$Kind,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [string]$LinkType
    )

    $linkKey = switch ($LinkType) {
        'SymbolicLink' { 'symlink' }
        'Junction' { 'junction' }
        default { $null }
    }
    if ($linkKey -and $Table.links.ContainsKey($linkKey)) {
        return [pscustomobject]@{ Entry = $Table.links[$linkKey]; Rule = "$Kind.links[$linkKey]" }
    }
    if ($Name -and $Table.names.ContainsKey($Name)) {
        return [pscustomobject]@{ Entry = $Table.names[$Name]; Rule = "$Kind.names[$Name]" }
    }
    if ($Name -and $Table.ContainsKey('extensions')) {
        # Longest compound suffix first: app.test.d.ts tries .test.d.ts, then .d.ts, then .ts.
        $dot = $Name.IndexOf('.')
        while ($dot -ge 0) {
            $suffix = $Name.Substring($dot)
            if ($Table.extensions.ContainsKey($suffix)) {
                return [pscustomobject]@{ Entry = $Table.extensions[$suffix]; Rule = "$Kind.extensions[$suffix]" }
            }
            $dot = $Name.IndexOf('.', $dot + 1)
        }
    }
    [pscustomobject]@{ Entry = $Table.default; Rule = "$Kind.default" }
}
