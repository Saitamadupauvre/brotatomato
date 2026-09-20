extends Node
## Central SFX player. Every sound plays through play(name), pooled across
## a handful of AudioStreamPlayers so overlapping calls don't cut each
## other off.
##
## To tune a sound that's too loud/quiet: find its entry in SOUNDS below
## and edit the volume_db number (negative = quieter, 0 = clip's native
## volume, positive = louder — rarely needed). That's the only place
## volume lives; nothing else in the codebase sets it.
##
## To add a sound that doesn't exist yet: drop the file under
## assets/audio/sfx/<category>/, add an entry here. See NEEDED.md for
## names still missing a file.
##
## Every play() randomizes pitch (and a little volume) within the
## entry's pitch_variation/volume_variation so a sound retriggered fast
## (footsteps, hits) doesn't sound like a machine gun of identical
## samples. Set either to 0.0 on an entry to disable for that sound
## (e.g. a one-shot stinger where pitch drift would sound wrong).

class SfxEntry:
	var stream: AudioStream
	var volume_db: float
	var pitch_variation: float
	var volume_variation: float
	func _init(p_stream: AudioStream, p_volume_db: float = 0.0, p_pitch_variation: float = 0.06, p_volume_variation: float = 1.5) -> void:
		stream = p_stream
		volume_db = p_volume_db
		pitch_variation = p_pitch_variation
		volume_variation = p_volume_variation

var SOUNDS: Dictionary[StringName, SfxEntry] = {
	&"hit_impact": SfxEntry.new(preload("res://assets/audio/sfx/combat/hit_impact.wav"), -8.0),
	&"melee_swing": SfxEntry.new(preload("res://assets/audio/sfx/combat/melee_swing.wav"), -10.0),
	&"ranged_fire": SfxEntry.new(preload("res://assets/audio/sfx/combat/ranged_fire.wav"), -10.0),
	&"reload": SfxEntry.new(preload("res://assets/audio/sfx/combat/reload.wav"), -6.0),
	## Reused for both dash flavors and the camp<->dungeon transition —
	## same "quick burst" read fits all three.
	&"dash_attack": SfxEntry.new(preload("res://assets/audio/sfx/combat/whoosh.mp3"), -30.0),
	&"player_dash": SfxEntry.new(preload("res://assets/audio/sfx/combat/whoosh.mp3"), -30.0),
	&"scene_transition": SfxEntry.new(preload("res://assets/audio/sfx/combat/whoosh.mp3"), -30.0),

	&"plant_seed": SfxEntry.new(preload("res://assets/audio/sfx/camp/plant_seed.wav"), -6.0),
	&"water_plot": SfxEntry.new(preload("res://assets/audio/sfx/camp/water_plot.wav"), -12.0),
	&"harvest": SfxEntry.new(preload("res://assets/audio/sfx/camp/harvest.wav"), -6.0),

	## Footsteps retrigger constantly while running — widen pitch drift
	## well past the default so consecutive steps don't blur together.
	&"footsteps_grass": SfxEntry.new(preload("res://assets/audio/sfx/movement/footsteps_grass.wav"), -20.0, 0.12, 2.0),
	&"footsteps_dirt": SfxEntry.new(preload("res://assets/audio/sfx/movement/footsteps_dirt.ogg"), -25.0, 0.12, 2.0),
}

const POOL_SIZE: int = 8

## Looping background ambiance. Plays continuously across both Camp and
## Dungeon since this is an autoload that survives scene changes.
const AMBIANCE_STREAM: AudioStream = preload("res://assets/audio/ambiance/forest_ambiance.wav")
const AMBIANCE_VOLUME_DB: float = -16.0

## Per-scene looping music, keyed by the name scenes pass to play_music().
## Base volume is the "not fighting" resting level; combat swells up to
## base + COMBAT_VOLUME_SWELL_DB on top of it (see _process below).
const MUSIC: Dictionary[StringName, AudioStream] = {
	&"camp": preload("res://assets/audio/music/tiny_movement.mp3"),
	&"dungeon": preload("res://assets/audio/music/call_of_the_brave.mp3"),
	&"menu": preload("res://assets/audio/music/sleeping_tree.mp3"),
}
const MUSIC_BASE_VOLUME_DB: float = -18.0
## How much louder the music gets at full combat heat.
const COMBAT_VOLUME_SWELL_DB: float = 8.0
## Heat added per landed hit (see notify_combat_hit) and how fast it
## decays back to 0 (full quiet) per second once hits stop landing.
const COMBAT_HEAT_PER_HIT: float = 0.5
const COMBAT_HEAT_DECAY_PER_SEC: float = 0.35

var _pool: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _ambiance_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _current_music: StringName = &""
var _combat_heat: float = 0.0


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_pool.append(player)

	_ambiance_player = AudioStreamPlayer.new()
	_ambiance_player.bus = "Master"
	_ambiance_player.stream = AMBIANCE_STREAM
	_ambiance_player.volume_db = AMBIANCE_VOLUME_DB
	# Loop by hand instead of the stream's built-in loop_mode: mutating
	# loop_mode on the imported resource at runtime (with the default
	# loop_end=-1) silently breaks playback on some WAV imports.
	_ambiance_player.finished.connect(_ambiance_player.play)
	add_child(_ambiance_player)
	_ambiance_player.play()

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = MUSIC_BASE_VOLUME_DB
	_music_player.finished.connect(_music_player.play)
	add_child(_music_player)


func _process(delta: float) -> void:
	_combat_heat = max(_combat_heat - COMBAT_HEAT_DECAY_PER_SEC * delta, 0.0)
	if _music_player.stream:
		_music_player.volume_db = MUSIC_BASE_VOLUME_DB + _combat_heat * COMBAT_VOLUME_SWELL_DB


## Switches the looping music track. No-ops if track_name is already
## playing (so scenes can call this every _ready without restarting the
## track), and silently no-ops for an unknown name.
func play_music(track_name: StringName) -> void:
	if track_name == _current_music:
		return
	var stream: AudioStream = MUSIC.get(track_name)
	if stream == null:
		return
	_current_music = track_name
	_music_player.stream = stream
	_music_player.play()


## Bumps combat music intensity — call whenever a hit lands (either
## direction). Heat decays on its own each frame, so the music eases back
## to resting volume once hits stop landing instead of snapping quiet.
func notify_combat_hit() -> void:
	_combat_heat = min(_combat_heat + COMBAT_HEAT_PER_HIT, 1.0)


## Silently no-ops for any sound_name not in SOUNDS — lets call sites for
## not-yet-sourced sounds stay in code without erroring.
func play(sound_name: StringName, volume_db_offset: float = 0.0) -> void:
	var entry: SfxEntry = SOUNDS.get(sound_name)
	if entry == null:
		return
	var player := _pool[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = entry.stream
	player.volume_db = entry.volume_db + volume_db_offset + randf_range(-entry.volume_variation, entry.volume_variation)
	player.pitch_scale = 1.0 + randf_range(-entry.pitch_variation, entry.pitch_variation)
	player.play()
