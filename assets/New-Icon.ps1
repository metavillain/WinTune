# Generates assets\wintune.ico - a "W" fused with a musical note - and a preview PNG.
# Re-run this if you want to tweak the look; Build-Exe.ps1 picks up wintune.ico automatically.
Add-Type -AssemblyName System.Drawing

$BgTop = [Drawing.Color]::FromArgb(0x16, 0x6F, 0xD6)   # bright blue
$BgBot = [Drawing.Color]::FromArgb(0x08, 0x3A, 0x8C)   # deep blue
$White = [Drawing.Color]::White
$Note  = [Drawing.Color]::FromArgb(0xFF, 0xC4, 0x00)   # amber note

function New-Bitmap {
    param([int]$S)
    $bmp = New-Object Drawing.Bitmap($S, $S, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear([Drawing.Color]::Transparent)

    # rounded-rectangle background with a vertical blue gradient
    $pad = [math]::Max(1, [int]($S * 0.04))
    $rect = New-Object Drawing.Rectangle($pad, $pad, ($S - 2 * $pad), ($S - 2 * $pad))
    $radius = [int]($S * 0.22)
    $path = New-Object Drawing.Drawing2D.GraphicsPath
    $d = $radius * 2
    $path.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
    $path.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
    $path.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $brush = New-Object Drawing.Drawing2D.LinearGradientBrush($rect, $BgTop, $BgBot, 90)
    $g.FillPath($brush, $path)

    # the "W": draw as four thick strokes so it stays crisp and leaves room for the note
    $lw = [math]::Max(2.0, $S * 0.11)
    $pen = New-Object Drawing.Pen($White, $lw)
    $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
    $topY = $S * 0.30; $botY = $S * 0.70
    $x0 = $S * 0.20; $x1 = $S * 0.345; $x2 = $S * 0.49; $x3 = $S * 0.635; $x4 = $S * 0.78
    $midY = $S * 0.52
    $pts = @(
        (New-Object Drawing.PointF($x0, $topY)),
        (New-Object Drawing.PointF($x1, $botY)),
        (New-Object Drawing.PointF($x2, $midY)),
        (New-Object Drawing.PointF($x3, $botY)),
        (New-Object Drawing.PointF($x4, $topY))
    )
    for ($i = 0; $i -lt $pts.Count - 1; $i++) { $g.DrawLine($pen, $pts[$i], $pts[$i + 1]) }

    # musical eighth note at upper-right: stem rises from the last W peak, amber notehead + flag
    $noteBrush = New-Object Drawing.SolidBrush($Note)
    $stemX = [single]$x4
    $peakY = [single]$topY
    $stemTopY = [single]($S * 0.15)
    $stemPen = New-Object Drawing.Pen($Note, ([single][math]::Max(1.8, $S * 0.05)))
    $stemPen.StartCap = 'Round'; $stemPen.EndCap = 'Round'
    $g.DrawLine($stemPen, $stemX, $peakY, $stemX, $stemTopY)
    # filled flag curving off the top of the stem
    $flag = New-Object Drawing.Drawing2D.GraphicsPath
    $p0 = New-Object Drawing.PointF($stemX, $stemTopY)
    $c1 = New-Object Drawing.PointF([single]($stemX + $S * 0.20), [single]($stemTopY + $S * 0.06))
    $c2 = New-Object Drawing.PointF([single]($stemX + $S * 0.17), [single]($stemTopY + $S * 0.20))
    $p1 = New-Object Drawing.PointF([single]($stemX + $S * 0.03), [single]($stemTopY + $S * 0.26))
    $p2 = New-Object Drawing.PointF($stemX, [single]($stemTopY + $S * 0.14))
    $flag.AddBezier($p0, $c1, $c2, $p1)
    $flag.AddLine($p1, $p2)
    $flag.CloseFigure()
    $g.FillPath($noteBrush, $flag)
    # notehead (filled ellipse, slightly tilted) at the bottom of the stem
    $hd = [single]($S * 0.21)
    $state = $g.Save()
    $g.TranslateTransform($stemX, $peakY)
    $g.RotateTransform(-20)
    $g.FillEllipse($noteBrush, [single](- $hd), [single](- $hd * 0.45), $hd, [single]($hd * 0.72))
    $g.Restore($state)

    $g.Dispose()
    $bmp
}

function Save-Ico {
    param([int[]]$Sizes, [string]$OutFile)
    $pngs = foreach ($s in $Sizes) {
        $bmp = New-Bitmap $s
        $ms = New-Object IO.MemoryStream
        $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        [pscustomobject]@{ Size = $s; Bytes = $ms.ToArray() }
    }
    $out = New-Object IO.MemoryStream
    $bw = New-Object IO.BinaryWriter($out)
    $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$pngs.Count)
    $offset = 6 + 16 * $pngs.Count
    foreach ($p in $pngs) {
        $wh = if ($p.Size -ge 256) { 0 } else { $p.Size }
        $bw.Write([byte]$wh); $bw.Write([byte]$wh); $bw.Write([byte]0); $bw.Write([byte]0)
        $bw.Write([uint16]1); $bw.Write([uint16]32)
        $bw.Write([uint32]$p.Bytes.Length); $bw.Write([uint32]$offset)
        $offset += $p.Bytes.Length
    }
    foreach ($p in $pngs) { $bw.Write($p.Bytes) }
    $bw.Flush()
    [IO.File]::WriteAllBytes($OutFile, $out.ToArray())
    $bw.Dispose(); $out.Dispose()
}

$here = $PSScriptRoot
Save-Ico -Sizes 16, 24, 32, 48, 64, 128, 256 -OutFile (Join-Path $here 'wintune.ico')
# preview
$big = New-Bitmap 256
$big.Save((Join-Path $here 'wintune-preview.png'), [Drawing.Imaging.ImageFormat]::Png)
$big.Dispose()
Write-Host "Wrote wintune.ico ($((Get-Item (Join-Path $here 'wintune.ico')).Length) bytes) and wintune-preview.png"
