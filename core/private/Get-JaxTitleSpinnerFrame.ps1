function Get-JaxTitleSpinnerFrame {
    <#
    .SYNOPSIS
        Return the next braille spinner frame and advance the module-scoped index.
    .DESCRIPTION
        Jax updates the tab title at task boundaries (the outer task + every inner
        psake TaskSetup), not on a timer, so we "animate" by advancing one frame per
        title update. Over a multi-step run the spinner visibly cycles. State lives in
        $script:JaxTitleSpinnerIndex (seeded by Initialize-JaxTerminalTitleState).
    #>
    [CmdletBinding()]
    param()

    $frames = $script:JaxTitleSpinnerFrames
    if (-not $frames -or $frames.Count -eq 0) { return '⠿' }

    $i = $script:JaxTitleSpinnerIndex % $frames.Count
    $script:JaxTitleSpinnerIndex = ($script:JaxTitleSpinnerIndex + 1) % $frames.Count
    return $frames[$i]
}
