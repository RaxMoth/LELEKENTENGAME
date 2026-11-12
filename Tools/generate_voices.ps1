# Generates the NPC voices: every line of Tools/Voices/lines.tsv spoken by
# the voices of Tools/Voices/voices.tsv with Windows' built-in German speech
# synthesis (Microsoft Stefan / Katja / Hedda, no download needed), written to
#   Assets/Audio/Voices/<voice>/<category>_<nn>.wav   (16 kHz mono)
#   Ressources/Voices/<voice>.tres                    (VoiceData)
#
# Usage (Windows PowerShell 5.1, from the project root):
#   powershell -ExecutionPolicy Bypass -File Tools/generate_voices.ps1
#
# lines.tsv: voices <TAB> category <TAB> text. "voices" is a comma list of
# voice ids or a group: @kunden (customers) or @leute (people in the street).
# Rerun after editing either table; Godot reimports the files on the next
# start. These are placeholder voices: replace a .wav with a real recording
# of the same line and the game uses it as is.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$groups = @{
	'@kunden' = @('kumpel', 'brocken', 'schnaeppchen', 'kennerin', 'influencerin')
	'@leute' = @('kumpel', 'brocken', 'influencerin', 'oma')
}

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime]
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
	$_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]

function Await($operation, [Type]$resultType) {
	$task = $asTask.MakeGenericMethod($resultType).Invoke($null, @($operation))
	$task.Wait(-1) | Out-Null
	return $task.Result
}

function Escape-Xml([string]$text) {
	return [System.Security.SecurityElement]::Escape($text)
}

function Escape-Godot([string]$text) {
	return $text.Replace('\', '\\').Replace('"', '\"')
}

# Trims leading and trailing near-silence from 16-bit mono PCM WAV bytes and
# writes a clean 44-byte-header WAV.
function Write-TrimmedWav([byte[]]$bytes, [string]$path) {
	$offset = 12
	$sampleRate = 16000
	$data = $null
	while ($offset -lt $bytes.Length - 8) {
		$chunkId = [System.Text.Encoding]::ASCII.GetString($bytes, $offset, 4)
		$chunkSize = [BitConverter]::ToInt32($bytes, $offset + 4)
		if ($chunkId -eq 'fmt ') { $sampleRate = [BitConverter]::ToInt32($bytes, $offset + 12) }
		if ($chunkId -eq 'data') {
			$length = [Math]::Min($chunkSize, $bytes.Length - $offset - 8)
			$data = New-Object byte[] $length
			[Array]::Copy($bytes, $offset + 8, $data, 0, $length)
			break
		}
		$offset += 8 + $chunkSize + ($chunkSize % 2)
	}
	if ($null -eq $data) { throw "No audio data for $path" }
	$threshold = 400
	$samples = [int]($data.Length / 2)
	$first = 0
	while ($first -lt $samples -and [Math]::Abs([BitConverter]::ToInt16($data, $first * 2)) -lt $threshold) { $first++ }
	$last = $samples - 1
	while ($last -gt $first -and [Math]::Abs([BitConverter]::ToInt16($data, $last * 2)) -lt $threshold) { $last-- }
	# Keep a short breath of silence around the words.
	$pad = [int]($sampleRate * 0.04)
	$first = [Math]::Max(0, $first - $pad)
	$last = [Math]::Min($samples - 1, $last + $pad)
	$length = ($last - $first + 1) * 2
	$stream = New-Object System.IO.MemoryStream
	$writer = New-Object System.IO.BinaryWriter($stream)
	$writer.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF'))
	$writer.Write([int](36 + $length))
	$writer.Write([System.Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
	$writer.Write([int]16)
	$writer.Write([int16]1)
	$writer.Write([int16]1)
	$writer.Write([int]$sampleRate)
	$writer.Write([int]($sampleRate * 2))
	$writer.Write([int16]2)
	$writer.Write([int16]16)
	$writer.Write([System.Text.Encoding]::ASCII.GetBytes('data'))
	$writer.Write([int]$length)
	$writer.Write($data, $first * 2, $length)
	$writer.Flush()
	[System.IO.File]::WriteAllBytes($path, $stream.ToArray())
}

$voices = Import-Csv -Delimiter "`t" -Path (Join-Path $root 'Tools/Voices/voices.tsv') -Encoding UTF8
$lines = Import-Csv -Delimiter "`t" -Path (Join-Path $root 'Tools/Voices/lines.tsv') -Encoding UTF8
$synth = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
$utf8 = New-Object System.Text.UTF8Encoding($false)

foreach ($voice in $voices) {
	$voiceDir = Join-Path $root "Assets/Audio/Voices/$($voice.id)"
	New-Item -ItemType Directory -Force $voiceDir | Out-Null
	$engineVoice = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices | Where-Object { $_.DisplayName -eq $voice.engine_voice }
	if ($null -eq $engineVoice) { throw "Speech voice '$($voice.engine_voice)' is not installed (Settings > Time & Language > Speech)." }
	$synth.Voice = $engineVoice
	$counts = @{}
	$entries = New-Object System.Collections.Generic.List[object]
	foreach ($line in $lines) {
		$speakers = @()
		foreach ($token in $line.voices.Split(',')) {
			$name = $token.Trim()
			if ($groups.ContainsKey($name)) { $speakers += $groups[$name] } else { $speakers += $name }
		}
		if ($speakers -notcontains $voice.id) { continue }
		$category = $line.category.Trim()
		$counts[$category] = 1 + [int]$counts[$category]
		$fileName = '{0}_{1:D2}.wav' -f $category, $counts[$category]
		$ssml = '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="de-DE"><voice name="{0}"><prosody pitch="{1}" rate="{2}">{3}</prosody></voice></speak>' -f $voice.engine_voice, $voice.pitch, $voice.rate, (Escape-Xml $line.text)
		$speech = Await ($synth.SynthesizeSsmlToStreamAsync($ssml)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
		$reader = New-Object Windows.Storage.Streams.DataReader($speech.GetInputStreamAt(0))
		$size = [uint32]$speech.Size
		$null = Await ($reader.LoadAsync($size)) ([uint32])
		$bytes = New-Object byte[] $size
		$reader.ReadBytes($bytes)
		Write-TrimmedWav $bytes (Join-Path $voiceDir $fileName)
		$entries.Add([pscustomobject]@{ category = $category; text = $line.text; file = $fileName })
	}
	# The VoiceData resource listing every line with its recording.
	$builder = New-Object System.Text.StringBuilder
	[void]$builder.AppendLine('[gd_resource type="Resource" script_class="VoiceData" format=3]')
	[void]$builder.AppendLine('')
	[void]$builder.AppendLine('[ext_resource type="Script" path="res://Scripts/Resources/voice_data.gd" id="voice_script"]')
	[void]$builder.AppendLine('[ext_resource type="Script" path="res://Scripts/Resources/voice_line_data.gd" id="line_script"]')
	for ($index = 0; $index -lt $entries.Count; $index++) {
		[void]$builder.AppendLine(('[ext_resource type="AudioStream" path="res://Assets/Audio/Voices/{0}/{1}" id="stream_{2}"]' -f $voice.id, $entries[$index].file, $index))
	}
	for ($index = 0; $index -lt $entries.Count; $index++) {
		[void]$builder.AppendLine('')
		[void]$builder.AppendLine(('[sub_resource type="Resource" id="line_{0}"]' -f $index))
		[void]$builder.AppendLine('script = ExtResource("line_script")')
		[void]$builder.AppendLine(('category = &"{0}"' -f $entries[$index].category))
		[void]$builder.AppendLine(('text = "{0}"' -f (Escape-Godot $entries[$index].text)))
		[void]$builder.AppendLine(('stream = ExtResource("stream_{0}")' -f $index))
	}
	$references = (0..($entries.Count - 1) | ForEach-Object { 'SubResource("line_{0}")' -f $_ }) -join ', '
	[void]$builder.AppendLine('')
	[void]$builder.AppendLine('[resource]')
	[void]$builder.AppendLine('script = ExtResource("voice_script")')
	[void]$builder.AppendLine(('id = &"{0}"' -f $voice.id))
	[void]$builder.AppendLine(('display_name = "{0}"' -f $voice.display_name))
	[void]$builder.AppendLine(('volume_db = {0}' -f $voice.volume_db))
	[void]$builder.AppendLine(('lines = Array[ExtResource("line_script")]([{0}])' -f $references))
	$resourceDir = Join-Path $root 'Ressources/Voices'
	New-Item -ItemType Directory -Force $resourceDir | Out-Null
	[System.IO.File]::WriteAllText((Join-Path $resourceDir "$($voice.id).tres"), $builder.ToString().Replace("`r`n", "`n"), $utf8)
	Write-Host ('{0}: {1} lines' -f $voice.id, $entries.Count)
}
