# Windows' own OCR (Windows.Media.Ocr), Arabic, on one or more images.
# Used as a third witness when two digital copies of a book disagree: it reads
# the PRINTED page, so it is independent of both. No install - the ar-SA
# recognizer ships with Windows here (checked 2026-09-25).
#
#   powershell -File scripts\winocr.ps1 out.txt page1.png [page2.png ...]
#
# Writes UTF-8, one "=== <image>" header per page, one OCR line per line.
# With WINOCR_BOXES=1 each line is prefixed by its box "x0,y0,x1,y1<TAB>".
param([string]$Out, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Images)

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime]
$null = [Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime]

$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
function Await($op, [Type]$t) {
    $task = $asTask.MakeGenericMethod($t).Invoke($null, @($op))
    $task.Wait() | Out-Null
    $task.Result
}

$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new('ar-SA'))
if ($null -eq $engine) { throw 'no ar-SA OCR recognizer' }
$sb = New-Object System.Text.StringBuilder
foreach ($img in $Images) {
    $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync((Resolve-Path $img).Path)) ([Windows.Storage.StorageFile])
    $stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
    [void]$sb.AppendLine("=== $img")
    foreach ($line in $result.Lines) {
        if ($env:WINOCR_BOXES) {
            # x0,y0,x1,y1 of the line (union of its words), then a tab.
            $x0 = 1e9; $y0 = 1e9; $x1 = 0; $y1 = 0
            foreach ($w in $line.Words) {
                $r = $w.BoundingRect
                $x0 = [Math]::Min($x0, $r.X); $y0 = [Math]::Min($y0, $r.Y)
                $x1 = [Math]::Max($x1, $r.X + $r.Width); $y1 = [Math]::Max($y1, $r.Y + $r.Height)
            }
            [void]$sb.Append(('{0:0},{1:0},{2:0},{3:0}' -f $x0, $y0, $x1, $y1) + "`t")
        }
        [void]$sb.AppendLine($line.Text)
    }
    $stream.Dispose()
}
[System.IO.File]::WriteAllText($Out, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
