# Stand-in voices for the people on the 380 until ElevenLabs has quota again:
# Windows' own Czech voice (Microsoft Jakub, OneCore), each person a pitch and a pace.
#
#   powershell -ExecutionPolicy Bypass -File tools/audiogen/bus_talk_local.ps1
#
# Reads tools/audiogen/bus_talk.tsv, writes godot/assets/sfx/bus/talk/<scene>_<n>.wav.
# The game takes <id>.mp3 (ElevenLabs, tools/audiogen/bus_talk.py) over <id>.wav, so
# these are replaced just by generating the real ones. Nothing leaves the machine.

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path $here "..\..\godot\assets\sfx\bus\talk"
New-Item -ItemType Directory -Force $out | Out-Null

Add-Type -AssemblyName System.Runtime.WindowsRuntime
[void][Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]
[void][Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime]
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
	$_.Name -eq "AsTask" -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq "IAsyncOperation``1" })[0]

function Await($op, [Type]$type) {
	$task = $asTask.MakeGenericMethod($type).Invoke($null, @($op))
	$task.Wait(-1) | Out-Null
	return $task.Result
}

$synth = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
$cz = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices | Where-Object { $_.Language -eq "cs-CZ" } | Select-Object -First 1
if ($null -eq $cz) { throw "No Czech voice installed (Settings > Time & language > Speech)." }
$synth.Voice = $cz

# Who sounds how: pitch and rate for the SSML prosody.
$people = @{
	"babka" = @{ pitch = "+18%"; rate = "0.86" }
	"deda"  = @{ pitch = "-12%"; rate = "0.84" }
	"zena"  = @{ pitch = "+30%"; rate = "1.0" }
	"muz"   = @{ pitch = "+2%";  rate = "1.0" }
	"ridic" = @{ pitch = "-6%";  rate = "1.08" }
}

foreach ($line in Get-Content (Join-Path $here "bus_talk.tsv") -Encoding UTF8) {
	if ($line.Trim() -eq "" -or $line.StartsWith("#")) { continue }
	$f = $line.Split("`t")
	$file = Join-Path $out ("{0}_{1}.wav" -f $f[0], $f[1])
	$p = $people[$f[3]]
	$text = [System.Security.SecurityElement]::Escape($f[4])
	$ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='cs-CZ'><voice name='$($cz.DisplayName)'><prosody pitch='$($p.pitch)' rate='$($p.rate)'>$text</prosody></voice></speak>"
	$stream = Await ($synth.SynthesizeSsmlToStreamAsync($ssml)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
	$reader = New-Object Windows.Storage.Streams.DataReader($stream.GetInputStreamAt(0))
	$n = [uint32]$stream.Size
	Await ($reader.LoadAsync($n)) ([uint32]) | Out-Null
	$bytes = New-Object byte[] $n
	$reader.ReadBytes($bytes)
	[System.IO.File]::WriteAllBytes($file, $bytes)
	Write-Output ("{0} {1} KB" -f (Split-Path -Leaf $file), [int]($n / 1024))
}
