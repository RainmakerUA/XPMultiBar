# Generate locale files from the source

$projName = 'XPMultiBar'
$localeSources = @("$projName.lua", 'utils.lua')
$locales = @('enUS', 'ruRU')
$baseLocale = 'enUS'
$localeDir = 'Locales'

$headerFmt = "-- This file is generated with $($MyInvocation.MyCommand.Name)
local L = LibStub(`"AceLocale-3.0`"):NewLocale(`"$projName`", `"{0}`"{1})
if not L then return end
---------- Total: {2} ----------"
$trueParam = ', true'
$loc_re = '(?<=L\[")([^"]+?)(?="\])'
$ext_re = '^[A-Z.]+$'
$old_re = '(?m)^L\["([^"]+?)"\]\s*=\s*"([^"]+?)"'

$localeSources | %{$strings = @()} {$strings += (Get-Content $_ -Raw | Select-String $loc_re -AllMatches | %{ $_.matches.Value } | Select-Object -Unique)} {$strings} | Out-Null

$total = $strings.Length
$ext_strings = $strings | ?{ $_ -cmatch $ext_re }
$strings = $strings | ?{ $_ -cnotmatch $ext_re }

$locales | %{
	$locale = $_
	$oldFile = ".\$localeDir\locale-$locale.lua"
    $file = "$oldFile.new"

    Select-String -Path $oldFile -Encoding utf8 -Pattern $old_re | %{$oldStrings = @{}} { $_.Matches | %{$oldStrings.Add($_.Groups[1].Value, $_.Groups[2].Value)} } {$oldStrings} | Out-Null

	Set-Content $file ([string]::Format($headerFmt, $locale, $(if($locale -eq $baseLocale){ $trueParam } else { "" }), $total))

	@($strings, $ext_strings) | %{
		Add-Content $file ($_ | %{ if($locale -eq "enUS"){ "L[`"$_`"] = true" } else { "L[`"{0}`"] = `"{1}`"" -f $_, $oldStrings[$_] } })
	}
}
