# Add a directory to the current process PATH once.
#
# Comparing whole entries instead of matching a substring keeps paths that
# contain glob characters (for example `[`) from being misdetected.
function Add-PathEntry {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not $Path) {
        return
    }
    $entries = $env:Path -split [IO.Path]::PathSeparator
    if ($entries -notcontains $Path) {
        $env:Path = "$Path$([IO.Path]::PathSeparator)$env:Path"
    }
}
