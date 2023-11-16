# vars
. ".\.vscode\Global.ps1"

#intunewin
#[string]$uri = "https://github.com/microsoft/microsoft-win32-content-prep-tool/blob/master"
[string]$uri = "https://github.com/microsoft/microsoft-win32-content-prep-tool/raw/master"
[string]$exe = "IntuneWinAppUtil.exe"

# source content prep tool
if (-not(Test-Path "$env:ProgramData\$exe")){
	Invoke-WebRequest -Uri "$Uri/$exe" -OutFile "$env:ProgramData\$exe"
}
# execute content prep tool
$processOptions = @{
		FilePath = "$env:ProgramData\$exe"
		ArgumentList = "-c ""$Cache"" -s ""$Cache\Deploy-Application.exe"" -o ""$env:TEMP"" -q"
		WindowStyle = "Maximized"
		Wait = $true
}	
Start-Process @processOptions

#Rename and prepare for upload
Move-Item -Path "env:TEMP\Deploy-Application.intunewin" -Destination "$Desktop\$Application.intunewin" -Force -Verbose
explorer $Desktop