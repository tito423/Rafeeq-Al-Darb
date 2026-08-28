param([Parameter(Mandatory=$true)][string]$Phase)
$ProgressPreference = 'SilentlyContinue'
if ($Phase -eq 'adhan') {
    $adDir = 'e:\My Projects\Rafiq-Al-Darb\rafeeq_app\assets\audio\adhan'
    New-Item -ItemType Directory -Force $adDir | Out-Null
    foreach ($i in 1..10) {
        $out = Join-Path $adDir ("azan{0}.mp3" -f $i)
        if (Test-Path $out) { continue }
        Invoke-WebRequest ("https://www.islamcan.com/audio/adhan/azan{0}.mp3" -f $i) -OutFile $out -TimeoutSec 60
    }
    Write-Output 'ADHAN DONE'
    exit 0
}
$map = @{ 'bukhari'='bukhari'; 'muslim'='muslim'; 'ahmed'='ahmed'; 'abudawud'='abudawud'; 'tirmidhi'='tirmidhi'; 'nasai'='nasai'; 'ibnmajah'='ibnmajah'; 'malik'='malik'; 'darimi'='darimi' }
$book = $map[$Phase]
if (-not $book) { throw "unknown phase $Phase" }
$hDir = 'e:\My Projects\Rafiq-Al-Darb\scripts\temp_phase1\hadith9'
New-Item -ItemType Directory -Force $hDir | Out-Null
$out = Join-Path $hDir ($book + '.json')
if (-not (Test-Path $out)) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest ("https://raw.githubusercontent.com/A7med3bdulBaset/hadith-json/main/db/by_book/the_9_books/{0}.json" -f $book) -OutFile $out -TimeoutSec 120
}
Write-Output "$book DONE $((Get-Item $out).Length)"
