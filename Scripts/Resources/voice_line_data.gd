## One spoken line of an NPC: what it is for (a category such as a greeting
## or a cry of pain), the words (shown as a subtitle) and the recording.
## Generated with the rest of a voice by Tools/generate_voices.ps1 from
## Tools/Voices/lines.tsv.
##
## Dependencies: none
class_name VoiceLineData
extends Resource

## Customers at the window.
const GREET: StringName = &"greet"
const ORDER: StringName = &"order"
const HAPPY: StringName = &"happy"
const ANGRY: StringName = &"angry"
const HAGGLE: StringName = &"haggle"
const IMPATIENT: StringName = &"impatient"
const SENT_AWAY: StringName = &"sent_away"
## People in the street (the dialogue and passing remarks).
const HELLO: StringName = &"hello"
const SMALLTALK: StringName = &"smalltalk"
const PITCH_YES: StringName = &"pitch_yes"
const PITCH_NO: StringName = &"pitch_no"
const BYE: StringName = &"bye"
const AMBIENT: StringName = &"ambient"
## The police during a raid.
const RAID: StringName = &"raid"
const ADVANCE: StringName = &"advance"
const COVER: StringName = &"cover"
const HIT: StringName = &"hit"
const DOWN: StringName = &"down"
const RAM: StringName = &"ram"

## What the line is for (one of the constants above).
@export var category: StringName = &""
## The words, shown as a subtitle while the line plays. Spoken German on
## purpose (the jokes are German internet slang), so it is not translated.
@export_multiline var text: String = ""
@export var stream: AudioStream
