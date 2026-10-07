param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$assetDirectory = Join-Path $ProjectRoot 'assets\Tiles\FarmLand'
$sourcePath = Join-Path $assetDirectory 'FarmLand_Tile_Squared.png'
$sourceImage = [System.Drawing.Bitmap]::new($sourcePath)

try {
    if ($sourceImage.Width -ne 32 -or $sourceImage.Height -ne 16) {
        throw "Expected a 32 x 16 source image, got $($sourceImage.Width) x $($sourceImage.Height)."
    }

    for ($tileIndex = 0; $tileIndex -lt 2; $tileIndex++) {
        $region = [System.Drawing.Rectangle]::new($tileIndex * 16, 0, 16, 16)
        $tileImage = $sourceImage.Clone($region, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $outputPath = Join-Path $assetDirectory ('FarmLand_Tile_Squared_{0:00}.png' -f ($tileIndex + 1))
        try {
            $tileImage.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $tileImage.Dispose()
        }

        $savedImage = [System.Drawing.Bitmap]::new($outputPath)
        try {
            if ($savedImage.Width -ne 16 -or $savedImage.Height -ne 16) {
                throw "Unexpected output dimensions: $outputPath"
            }
            for ($pixelY = 0; $pixelY -lt 16; $pixelY++) {
                for ($pixelX = 0; $pixelX -lt 16; $pixelX++) {
                    $expected = $sourceImage.GetPixel($tileIndex * 16 + $pixelX, $pixelY).ToArgb()
                    if ($savedImage.GetPixel($pixelX, $pixelY).ToArgb() -ne $expected) {
                        throw "Pixel mismatch at ($pixelX, $pixelY): $outputPath"
                    }
                }
            }
            Write-Output "Verified 16 x 16 PNG (RGBA pixels preserved): $outputPath"
        }
        finally {
            $savedImage.Dispose()
        }
    }
}
finally {
    $sourceImage.Dispose()
}
