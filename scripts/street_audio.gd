extends Node

const RATE := 16000
var effects := {}
var engine: AudioStreamPlayer
var ambience: AudioStreamPlayer

func _ready() -> void:
    var random := RandomNumberGenerator.new()
    random.seed = 3729
    effects["step"] = _sound(random, 0.10, 83, 0.42, 25)
    effects["strike"] = _sound(random, 0.19, 58, 0.65, 18)
    effects["pulse"] = _sound(random, 0.28, 122, 0.84, 15)
    effects["horn"] = _sound(random, 0.42, 318, 0.05, 3)
    effects["reload"] = _sound(random, 0.12, 360, 0.40, 18)
    engine = _loop(_sound(random, 0.5, 48, 0, 0), -55)
    ambience = _loop(_sound(random, 1.0, 45, 0.08, 0), -34)

func play_effect(effect: String, volume: float = -14) -> void:
    var player := AudioStreamPlayer.new()
    player.stream = effects[effect]
    player.volume_db = volume
    add_child(player)
    player.finished.connect(player.queue_free)
    player.play()

func set_engine(speed: float, driving: bool) -> void:
    engine.pitch_scale = 0.75 + absf(speed) * 0.066
    engine.volume_db = -25 + minf(absf(speed), 18) * 0.6 if driving else -55

func _loop(stream: AudioStreamWAV, volume: float) -> AudioStreamPlayer:
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_end = stream.data.size() / 2
    var player := AudioStreamPlayer.new()
    player.stream = stream
    player.volume_db = volume
    add_child(player)
    player.play()
    return player

func _sound(random: RandomNumberGenerator, duration: float, frequency: float, noise: float, decay: float) -> AudioStreamWAV:
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = RATE
    var samples := PackedByteArray()
    samples.resize(roundi(duration * RATE) * 2)
    for index in range(samples.size() / 2):
        var time := float(index) / RATE
        var wave := sin(time * frequency * TAU) * 0.65 + sin(time * frequency * 2.0 * TAU) * 0.24
        var value := lerpf(wave, random.randf_range(-1.0, 1.0), noise) * exp(-decay * time)
        samples.encode_s16(index * 2, roundi(value * 12500))
    stream.data = samples
    return stream
