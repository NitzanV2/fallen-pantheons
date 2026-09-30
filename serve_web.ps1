# Serves build\web on http://localhost:8060 to try an exported build before pushing it.
#   .\deploy.ps1 -NoPush; .\serve_web.ps1        (Ctrl+C to stop)

param([int]$Port = 8060)

$dir = Join-Path $PSScriptRoot "build\web"
$types = @{
	".html" = "text/html"; ".js" = "application/javascript"; ".wasm" = "application/wasm"
	".pck" = "application/octet-stream"; ".png" = "image/png"; ".json" = "application/json"
}
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $dir on http://localhost:$Port/ (Ctrl+C to stop)"
try {
	while ($listener.IsListening) {
		$ctx = $listener.GetContext()
		$name = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart("/"))
		if (-not $name) { $name = "index.html" }
		$path = Join-Path $dir $name
		if ((Test-Path $path -PathType Leaf) -and ([IO.Path]::GetFullPath($path).StartsWith($dir))) {
			$bytes = [IO.File]::ReadAllBytes($path)
			$type = $types[[IO.Path]::GetExtension($path)]
			$ctx.Response.ContentType = if ($type) { $type } else { "application/octet-stream" }
			$ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
		} else {
			$ctx.Response.StatusCode = 404
		}
		$ctx.Response.Close()
	}
} finally {
	$listener.Stop()
}
