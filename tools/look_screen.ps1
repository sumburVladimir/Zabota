Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class ScreenCap {
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    public static void Init() { SetProcessDPIAware(); }
}
"@
[ScreenCap]::Init()
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$outDir = "C:\Users\Владимир Капов\AppData\Local\Temp\opencode"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$i = 0
foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
    $i++
    $b = $s.Bounds
    $bmp = New-Object System.Drawing.Bitmap($b.Width, $b.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.X, $b.Y, 0, 0, $b.Size)
    $g.Dispose()
    $out = Join-Path $outDir "screen_$i.png"
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "screen_$i.png ($($b.Width)x$($b.Height), Primary=$($s.Primary))"
}
