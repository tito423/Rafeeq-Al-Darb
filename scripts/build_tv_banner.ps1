Add-Type -AssemblyName System.Drawing
$root = 'E:\My Projects\Rafiq-Al-Darb\rafeeq_app'
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile("$root\assets\fonts\google_fonts\Alexandria-Bold.ttf")
$family = $pfc.Families[0]

# Drawn at 4x, then scaled to 320x180 for clean edges.
$W = 1280; $H = 720
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.InterpolationMode = 'HighQualityBicubic'
$g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([System.Drawing.ColorTranslator]::FromHtml('#9BC4B3'))

# The owner's icon, unchanged, on the right (Arabic reads from the right).
$icon = [System.Drawing.Image]::FromFile("$root\assets\icon\app_icon.png")
$s = 600
$g.DrawImage($icon, $W - $s - 60, [int](($H - $s) / 2), $s, $s)

$fmt = New-Object System.Drawing.StringFormat
$fmt.FormatFlags = [System.Drawing.StringFormatFlags]::DirectionRightToLeft
$fmt.Alignment = 'Center'
$fmt.LineAlignment = 'Center'
$font = New-Object System.Drawing.Font($family, 120, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#173A30'))
$name = -join ([char[]](0x0631,0x0641,0x064A,0x0642,0x0020,0x0627,0x0644,0x062F,0x0631,0x0628))
$rect = New-Object System.Drawing.RectangleF(40, 0, ($W - $s - 140), $H)
$g.DrawString($name, $font, $brush, $rect, $fmt)

$out = New-Object System.Drawing.Bitmap 320, 180
$g2 = [System.Drawing.Graphics]::FromImage($out)
$g2.InterpolationMode = 'HighQualityBicubic'
$g2.DrawImage($bmp, 0, 0, 320, 180)
$out.Save("$root\android\app\src\main\res\drawable-xhdpi\tv_banner.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Save("C:\Users\Asus\AppData\Local\Temp\claude\e--My-Projects-Rafiq-Al-Darb\84b11bb0-21c1-4486-b778-a726e5ef9b73\scratchpad\tv_banner_big.png", [System.Drawing.Imaging.ImageFormat]::Png)
'ok'
