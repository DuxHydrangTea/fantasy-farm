Add-Type -AssemblyName System.Drawing
$d='C:\projects\fantasy-farm\docs\building_polish_comparison_2026-11-08'
$font=[System.Drawing.Font]::new('Arial',16)
$brush=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
foreach($n in @('seed_storage','produce_warehouse','cattle_barn','chicken_coop')) {
 $paths=@("$d\inputs\$n.png","$d\$($n)_correct.png","$d\$($n)_pixen.png")
 if(-not (Test-Path -LiteralPath $paths[2])){continue}
 $canvas=[System.Drawing.Bitmap]::new(1560,460)
 $g=[System.Drawing.Graphics]::FromImage($canvas)
 $g.Clear([System.Drawing.Color]::FromArgb(70,86,76))
 $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
 $g.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::Half
 $labels=@('Original','Correct Pixel Art - 0.1','Pixen edit - 1')
 for($i=0;$i -lt 3;$i++) {
  $im=[System.Drawing.Bitmap]::FromFile($paths[$i])
  $g.DrawString($labels[$i],$font,$brush,[single]($i*520+12),[single]10)
  $g.DrawImage($im,[System.Drawing.Rectangle]::new($i*520+12,48,$im.Width*2,$im.Height*2),0,0,$im.Width,$im.Height,[System.Drawing.GraphicsUnit]::Pixel)
  $im.Dispose()
 }
 $canvas.Save("$d\compare_$n.png")
 $g.Dispose();$canvas.Dispose()
}
$font.Dispose();$brush.Dispose()
