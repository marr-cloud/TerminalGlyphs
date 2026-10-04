BeforeDiscovery {
    $rows = @(
        @{ Glyph = 'nf-dev-go'; Color = '00ADD8'; Files = 'main.go', 'go.mod', 'go.sum', 'go.work', 'go.work.sum' }
        @{ Glyph = 'nf-dev-rust'; Color = 'DEA584'; Files = 'main.rs', 'Cargo.toml', 'Cargo.lock', 'rust-toolchain', 'rust-toolchain.toml', 'rustfmt.toml', '.rustfmt.toml', 'clippy.toml' }
        @{ Glyph = 'nf-dev-cloudflareworkers'; Color = 'F38020'; Files = 'wrangler.toml', 'wrangler.json', 'wrangler.jsonc' }
        @{ Glyph = 'nf-dev-cloudflare'; Color = 'F38020'; Directories = '.wrangler' }
        @{ Glyph = 'nf-md-file_key'; Color = 'F38020'; Files = '.dev.vars' }
        @{ Glyph = 'nf-dev-terraform'; Color = '844FBA'; Files = 'main.tf', 'prod.tfvars', 'terraform.tfstate', 'config.hcl', '.terraform.lock.hcl'; Directories = '.terraform' }
        @{ Glyph = 'nf-dev-aws'; Color = 'FF9900'; Files = 'stack.cfn.yaml', 'stack.cfn.yml', 'stack.cfn.json', 'samconfig.toml', 'cdk.json'; Directories = '.aws-sam', 'cdk.out' }
        @{ Glyph = 'nf-md-chef_hat'; Files = 'mise.toml', '.mise.toml', 'mise.local.toml', '.tool-versions' }
        @{ Glyph = 'nf-dev-python'; Color = '3776AB'; Files = 'uv.lock', '.python-version', 'pyproject.toml'; Directories = '.venv' }
        @{ Glyph = 'nf-dev-pnpm'; Color = 'F69220'; Files = 'pnpm-lock.yaml', 'pnpm-workspace.yaml', '.pnpmfile.cjs' }
        @{ Glyph = 'nf-dev-bun'; Color = 'FBF0DF'; Files = 'bun.lock', 'bun.lockb', 'bunfig.toml' }
        @{ Glyph = 'nf-dev-astro'; Color = 'FF5D01'; Files = 'index.astro', 'astro.config.mjs', 'astro.config.ts', 'astro.config.js', 'astro.config.mts'; Directories = '.astro' }
        @{ Glyph = 'nf-dev-vite'; Color = '646CFF'; Files = 'vite.config.ts', 'vite.config.js', 'vite.config.mjs', 'vite.config.mts'; Directories = '.vitepress' }
        @{ Glyph = 'nf-dev-vitest'; Color = '729B1B'; Files = 'vitest.config.ts', 'vitest.config.js', 'vitest.config.mjs', 'vitest.config.mts' }
        @{ Glyph = 'nf-dev-docker'; Color = '2496ED'; Files = 'Dockerfile', 'docker-compose.yml', 'app.dockerfile', 'Containerfile', '.dockerignore', 'compose.yaml', 'compose.yml', 'docker-compose.yaml' }
        @{ Glyph = 'nf-cod-claude'; Color = 'D97757'; Files = 'CLAUDE.md', 'CLAUDE.local.md'; Directories = '.claude' }
        @{ Glyph = 'nf-md-ghost'; Directories = '.kiro' }
        @{ Glyph = 'nf-cod-sparkle'; Files = 'AGENTS.md', 'GEMINI.md', 'llms.txt', '.mcp.json', '.cursorrules', 'copilot-instructions.md'; Directories = '.gemini', '.cursor', '.codex' }
        @{ Glyph = 'nf-dev-biome'; Files = 'biome.json', 'biome.jsonc' }
        @{ Glyph = 'nf-dev-denojs'; Files = 'deno.json', 'deno.jsonc' }
        @{ Glyph = 'nf-custom-toml'; Files = 'config.toml' }
        @{ Glyph = 'nf-md-format_list_checks'; Files = 'justfile', 'Justfile', '.justfile' }
    )
    $cases = foreach ($row in $rows) {
        foreach ($name in @($row.Files)) { if ($name) { @{ Name = $name; Directory = $false; Glyph = $row.Glyph; Color = $row.Color } } }
        foreach ($name in @($row.Directories)) { if ($name) { @{ Name = $name; Directory = $true; Glyph = $row.Glyph; Color = $row.Color } } }
    }
    $colorCases = @($cases | Where-Object { $_.Color })
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $savedConfig = $env:TERMINALGLYPHS_CONFIG
    Import-Module (Get-BuiltManifestPath) -Force

    function Resolve-ForTest([string]$Name, [bool]$Directory, [string]$ColorTheme = 'default') {
        $config = Join-Path $TestDrive "$ColorTheme.jsonc"
        [System.IO.File]::WriteAllText($config, "{ `"colorTheme`": `"$ColorTheme`" }")
        $env:TERMINALGLYPHS_CONFIG = $config
        InModuleScope TerminalGlyphs -Parameters @{ N = $Name; D = $Directory; T = $ColorTheme } {
            param($N, $D, $T)
            if ($null -eq $script:TGState -or $script:TGState.ColorTheme -ne $T) { Initialize-TerminalGlyph -Force }
            Resolve-TerminalGlyph -Name $N -Directory:$D
        }
    }
}

AfterAll {
    $env:TERMINALGLYPHS_CONFIG = $savedConfig
    Remove-Module TerminalGlyphs -ErrorAction SilentlyContinue
}

Describe 'stack icons (spec section 6)' {
    It '<Name> uses <Glyph>' -ForEach $cases {
        (Resolve-ForTest -Name $Name -Directory $Directory).IconName | Should -BeExactly $Glyph
    }

    It '<Name> uses brand color <Color> in the default theme' -ForEach $colorCases {
        (Resolve-ForTest -Name $Name -Directory $Directory).ColorName | Should -BeExactly $Color
    }

    It '<Name> has a color in the light theme' -ForEach $colorCases {
        (Resolve-ForTest -Name $Name -Directory $Directory -ColorTheme 'light').ColorName | Should -Not -BeNullOrEmpty
    }

    It '<Name> has a color in the dracula theme' -ForEach $colorCases {
        (Resolve-ForTest -Name $Name -Directory $Directory -ColorTheme 'dracula').ColorName | Should -Not -BeNullOrEmpty
    }

    It 'darkens Bun and AWS in the light theme' {
        (Resolve-ForTest -Name 'bun.lock' -Directory $false -ColorTheme 'light').ColorName | Should -BeExactly '8A6D3B'
        (Resolve-ForTest -Name 'cdk.json' -Directory $false -ColorTheme 'light').ColorName | Should -BeExactly 'B26B00'
    }

    It 'keeps brand colors in the dracula theme' {
        (Resolve-ForTest -Name 'go.mod' -Directory $false -ColorTheme 'dracula').ColorName | Should -BeExactly '00ADD8'
    }
}
