param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$assetDir = Join-Path $ProjectRoot "store-assets\android"
New-Item -ItemType Directory -Path $assetDir -Force | Out-Null

function Save-Jpeg {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [string]$Path,
        [long]$Quality = 94
    )

    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
        Where-Object { $_.MimeType -eq "image/jpeg" }
    $parameters = New-Object System.Drawing.Imaging.EncoderParameters 1
    $parameters.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
        [System.Drawing.Imaging.Encoder]::Quality,
        $Quality
    )
    $Bitmap.Save($Path, $codec, $parameters)
    $parameters.Dispose()
}

function Copy-Strip {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Image]$Source,
        [System.Drawing.Rectangle]$SourceRect,
        [System.Drawing.Rectangle]$TargetRect
    )

    $Graphics.DrawImage(
        $Source,
        $TargetRect,
        $SourceRect.X,
        $SourceRect.Y,
        $SourceRect.Width,
        $SourceRect.Height,
        [System.Drawing.GraphicsUnit]::Pixel
    )
}

# Phone screenshot 1: preserve the important home controls and bottom navigation,
# while removing only the large empty middle section.
$homeSourcePath = Join-Path $ProjectRoot "store-assets\ios\01-home-1242x2688.png"
$homeSource = [System.Drawing.Image]::FromFile($homeSourcePath)
$homeCanvas = New-Object System.Drawing.Bitmap 1080, 1920
$homeGraphics = [System.Drawing.Graphics]::FromImage($homeCanvas)
$homeGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$homeGraphics.Clear([System.Drawing.Color]::FromArgb(247, 249, 255))
Copy-Strip $homeGraphics $homeSource ([System.Drawing.Rectangle]::new(0, 0, 1242, 1530)) ([System.Drawing.Rectangle]::new(0, 0, 1080, 1330))
Copy-Strip $homeGraphics $homeSource ([System.Drawing.Rectangle]::new(0, 2098, 1242, 590)) ([System.Drawing.Rectangle]::new(0, 1330, 1080, 590))
Save-Jpeg $homeCanvas (Join-Path $assetDir "01-home-1080x1920.jpg")
$homeGraphics.Dispose()
$homeCanvas.Dispose()
$homeSource.Dispose()

# Phone screenshot 2: keep the complete onboarding message and actions while
# removing unused vertical whitespace.
$onboardingSourcePath = Join-Path $ProjectRoot "outputs\briefai-iap-wrapper-2.png"
$onboardingSource = [System.Drawing.Image]::FromFile($onboardingSourcePath)
$onboardingCanvas = New-Object System.Drawing.Bitmap 1080, 1920
$onboardingGraphics = [System.Drawing.Graphics]::FromImage($onboardingCanvas)
$onboardingGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$onboardingGraphics.Clear([System.Drawing.Color]::FromArgb(247, 249, 255))
Copy-Strip $onboardingGraphics $onboardingSource ([System.Drawing.Rectangle]::new(0, 0, 1080, 1500)) ([System.Drawing.Rectangle]::new(0, 0, 1080, 1500))
Copy-Strip $onboardingGraphics $onboardingSource ([System.Drawing.Rectangle]::new(0, 1980, 1080, 420)) ([System.Drawing.Rectangle]::new(0, 1500, 1080, 420))
Save-Jpeg $onboardingCanvas (Join-Path $assetDir "02-onboarding-1080x1920.jpg")
$onboardingGraphics.Dispose()
$onboardingCanvas.Dispose()
$onboardingSource.Dispose()

# Play icon follows the product's dark-blue and AI-gradient identity.
$playIcon = New-Object System.Drawing.Bitmap 512, 512
$iconGraphics = [System.Drawing.Graphics]::FromImage($playIcon)
$iconGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$iconGraphics.Clear([System.Drawing.Color]::FromArgb(8, 23, 55))
$circleRect = [System.Drawing.Rectangle]::new(70, 70, 372, 372)
$circleGradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $circleRect,
    [System.Drawing.Color]::FromArgb(45, 91, 255),
    [System.Drawing.Color]::FromArgb(145, 92, 255),
    25
)
$iconGraphics.FillEllipse($circleGradient, $circleRect)

$markPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 22
$markPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$markPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$docRect = [System.Drawing.Rectangle]::new(196, 164, 120, 178)
$iconGraphics.DrawRectangle($markPen, $docRect)
$iconGraphics.DrawLine($markPen, 222, 217, 290, 217)
$iconGraphics.DrawLine($markPen, 222, 260, 290, 260)
$iconGraphics.DrawLine($markPen, 222, 303, 275, 303)
$cornerPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 18
$cornerPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Square
$cornerPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Square
$iconGraphics.DrawLine($cornerPen, 156, 202, 156, 146)
$iconGraphics.DrawLine($cornerPen, 156, 146, 212, 146)
$iconGraphics.DrawLine($cornerPen, 356, 202, 356, 146)
$iconGraphics.DrawLine($cornerPen, 356, 146, 300, 146)
$iconGraphics.DrawLine($cornerPen, 156, 310, 156, 366)
$iconGraphics.DrawLine($cornerPen, 156, 366, 212, 366)
$iconGraphics.DrawLine($cornerPen, 356, 310, 356, 366)
$iconGraphics.DrawLine($cornerPen, 356, 366, 300, 366)
$playIcon.Save((Join-Path $assetDir "icon-512.png"), [System.Drawing.Imaging.ImageFormat]::Png)

$cornerPen.Dispose()
$markPen.Dispose()
$circleGradient.Dispose()
$iconGraphics.Dispose()
$playIcon.Dispose()

# Feature graphic uses the existing brand palette and icon.
$feature = New-Object System.Drawing.Bitmap 1024, 500
$featureGraphics = [System.Drawing.Graphics]::FromImage($feature)
$featureGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$featureGraphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$featureRect = [System.Drawing.Rectangle]::new(0, 0, 1024, 500)
$gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $featureRect,
    [System.Drawing.Color]::FromArgb(8, 23, 55),
    [System.Drawing.Color]::FromArgb(41, 67, 145),
    12
)
$featureGraphics.FillRectangle($gradient, $featureRect)

$glow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(38, 123, 113, 255))
$featureGraphics.FillEllipse($glow, 685, -95, 430, 430)
$featureGraphics.FillEllipse($glow, 790, 270, 290, 290)

$white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
$softWhite = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, 235, 242, 255))
$brandFont = New-Object System.Drawing.Font "Segoe UI", 46, ([System.Drawing.FontStyle]::Bold)
$headlineFont = New-Object System.Drawing.Font "Segoe UI", 31, ([System.Drawing.FontStyle]::Bold)
$bodyFont = New-Object System.Drawing.Font "Segoe UI", 20, ([System.Drawing.FontStyle]::Regular)

$featureGraphics.DrawString("BriefAI Germany", $brandFont, $white, 60, 70)
$featureGraphics.DrawString("Deutsche Briefe verstehen.", $headlineFont, $white, 60, 178)
$featureGraphics.DrawString("Fristen erkennen. Sicher antworten.", $bodyFont, $softWhite, 64, 250)

$pillBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(48, 111, 133, 255))
$featureGraphics.FillRectangle($pillBrush, 60, 326, 455, 72)
$pillFont = New-Object System.Drawing.Font "Segoe UI", 18, ([System.Drawing.FontStyle]::Bold)
$featureGraphics.DrawString("KI-Erklärung in Ihrer Sprache", $pillFont, $white, 82, 344)

$iconPath = Join-Path $assetDir "icon-512.png"
$icon = [System.Drawing.Image]::FromFile($iconPath)
$featureGraphics.DrawImage($icon, 706, 88, 330, 330)

Save-Jpeg $feature (Join-Path $assetDir "feature-1024x500.jpg") 95

$icon.Dispose()
$pillFont.Dispose()
$pillBrush.Dispose()
$bodyFont.Dispose()
$headlineFont.Dispose()
$brandFont.Dispose()
$softWhite.Dispose()
$white.Dispose()
$glow.Dispose()
$gradient.Dispose()
$featureGraphics.Dispose()
$feature.Dispose()

Get-ChildItem -LiteralPath $assetDir | Select-Object Name, Length
