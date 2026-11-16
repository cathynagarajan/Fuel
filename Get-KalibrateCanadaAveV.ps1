[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$year = (Get-Date).Year
$url = "https://charting.kalibrate.com/WPPS/Diesel/Retail%20(Incl.%20Tax)/WEEKLY/$year/Diesel_Retail%20(Incl.%20Tax)_WEEKLY_$year.xlsx"
$outFile = "C:\Users\krithika\Documents\Fuel\Kalibrate_Diesel_Weekly_$year.xlsx"
Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($outFile)
$ssEntry = $zip.GetEntry("xl/sharedStrings.xml")
$ss = @()
$sr = New-Object System.IO.StreamReader($ssEntry.Open())
[xml]$ssXml = $sr.ReadToEnd()
$sr.Close()
foreach ($si in $ssXml.sst.si) {
    if ($si.t -is [string]) { $ss += $si.t }
    elseif ($si.t.'#text') { $ss += $si.t.'#text' }
    else { $ss += "" }
}
$shEntry = $zip.GetEntry("xl/worksheets/sheet1.xml")
$sr2 = New-Object System.IO.StreamReader($shEntry.Open())
[xml]$shXml = $sr2.ReadToEnd()
$sr2.Close()
$zip.Dispose()

$r3 = @{}
foreach ($c in $shXml.worksheet.sheetData.row[2].c) {
    $col = $c.r -replace '\d+',''
    $v = $c.v
    if ($c.t -eq 's') { $v = $ss[[int]$v] }
    $r3[$col] = $v
}

foreach ($row in $shXml.worksheet.sheetData.row) {
    if ($row.c -and $row.c[0].t -eq 's') {
        $name = $ss[[int]$row.c[0].v]
        if ($name -eq "Canada Ave(V)") {
            $nonEmpty = $row.c | Where-Object { $_.t -ne 's' -and $null -ne $_.v -and $_.v -ne '' }
            $lastCell = $nonEmpty[-1]
            $col = $lastCell.r -replace '\d+',''
            Write-Output "Metric: $name | Week: $($r3[$col]) | Value: $($lastCell.v)"
        }
    }
}
