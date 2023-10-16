
Sound :: struct {
    type: SoundType;
    fmod_sounds: [20] *FMOD_SOUND;
    count: int;
    names: [20] string;
    default_volume: float;
    default_size: float;
    default_directional_strength: float;
    fmod_size_dsp: *FMOD_DSP;
    volume_ramp: bool;
}

SoundType :: enum {
    Invalid;
    Sound2;
    Sound3;
}

// TODO each sound type should have its own file with the base type passing it to the correct function

// TODO I need to have a way to load and serialize every sound in the game and then retrieve them by byte array to create sound files
// TODO I can request load all files, it'll auto hash and serialize/deserialize, and then load from memory will read from this internal block instead by file name
// TODO file name just points to start byte and length

load_sound3 :: (paths: ..string, loop: bool = false, volume: float = 1.0, size: float = 0.0, directional_strength: float = 1.0, volume_ramp: bool = false) -> *Sound {
    sound := New(Sound);
    sound.type = .Sound3;
    sound.count = paths.count;
    sound.default_volume = volume;
    sound.default_size = size;
    sound.default_directional_strength = directional_strength;
    sound.volume_ramp = volume_ramp;

    assert(paths.count <= sound.fmod_sounds.count, "More than 10 or 20 or something sounds not currently supported for simplicity.");
    for path: paths {
        assert(path.count < 512, "Audio path is too long.");
    }

    sound_type := FMOD_3D;
    if loop {
        sound_type |= FMOD_LOOP_NORMAL;
    }

    for path, index: paths {
        fixed_path: [512] u8;
        memcpy(fixed_path.data, path.data, path.count);

        sound.names[index] = path;

        result := FMOD_System_CreateSound(fmod_system, fixed_path.data, sound_type, null, *sound.fmod_sounds[index]);
        if result {
            print("FMOD load sound error. % %\n", result, path);
            assert(false, "FMOD load sound error.");
            return null;
        }

        FMOD_Sound_SetUserData(sound.fmod_sounds[index], sound);
    }

    if sound.default_size > 0 {
        FMOD_System_CreateDSPByType(fmod_system, .FMOD_DSP_TYPE_PAN, *sound.fmod_size_dsp);
        FMOD_DSP_SetParameterFloat(sound.fmod_size_dsp, cast(s32) FMOD_DSP_PAN.FMOD_DSP_PAN_3D_SOUND_SIZE, sound.default_size);
    }

    return sound;
}

load_sound2 :: (paths: ..string, loop: bool = false, volume: float = 1.0, size: float = 0.0, volume_ramp: bool = false) -> *Sound {
    sound := New(Sound);
    sound.type = .Sound2;
    sound.count = paths.count;
    sound.default_volume = volume;
    sound.default_size = size;
    sound.volume_ramp = volume_ramp;

    assert(paths.count <= sound.fmod_sounds.count, "More than 10 or 20 or something sounds not currently supported for simplicity.");
    for path: paths {
        assert(path.count < 512, "Audio path is too long.");
    }

    sound_type := FMOD_DEFAULT;
    if loop {
        sound_type |= FMOD_LOOP_NORMAL;
    }

    for path, index: paths {
        fixed_path: [512] u8;
        memcpy(fixed_path.data, path.data, path.count);

        sound.names[index] = path;

        result := FMOD_System_CreateSound(fmod_system, fixed_path.data, sound_type, null, *sound.fmod_sounds[index]);
        if result {
            print("FMOD load sound error. % %\n", result, path);
            assert(false, "FMOD load sound error.");
            return null;
        }

        FMOD_Sound_SetUserData(sound.fmod_sounds[index], sound);
    }

    return sound;
}

destroy_sound :: (sound: *Sound) {
    for i: 0..sound.count - 1 {
        result := FMOD_Sound_Release(sound.fmod_sounds[i]);
        if result {
            print("FMOD error destroying sound. %\n", result);
        }
    }

    free(sound);
}

play_sound :: (sound: Sound, volume: float = 1.0, index: int = -1) -> SoundInstance, int {
    sound_instance: SoundInstance;

    if index == -1 {
        index = 0;
        if sound.count > 1 {
            index = cast(int) (random_get() % cast(u64) sound.count);
        }
    }

    assert(index >= 0 && index < sound.count, "Invalid index for audio source.");

    print("% playing %\n", get_time(), sound.names[index]);

    FMOD_System_PlaySound(fmod_system, sound.fmod_sounds[index], null, 0, *sound_instance.fmod_channel);

    if sound.volume_ramp {
        set_volume_ramp(sound_instance, true);
    }

    if sound.fmod_size_dsp {
        FMOD_Channel_AddDSP(sound_instance.fmod_channel, 0, sound.fmod_size_dsp);
    } else {
        numdsps: s32;
        FMOD_Channel_GetNumDSPs(sound_instance.fmod_channel, *numdsps);
        // dsp: *FMOD_DSP;
        // FMOD_Channel_GetDSP(sound_instance.fmod_channel, 0, *dsp);
        // print("dsp %\n", numdsps);
        assert(numdsps == 1, "DSP cannot exist here. I want to be sure it's not reused.");
    }

    final_volume := sound.default_volume * volume;
    set_volume(sound_instance, final_volume);
    set_raw_volume(sound_instance, final_volume);

    if sound.type == .Sound3 {
        final_directional_strength := global_directional_strength * sound.default_directional_strength;
        if final_directional_strength != 1 {
            // set_spread(sound_instance, 180 - 90);
            set_directional_strength(sound_instance, final_directional_strength);
        }
    }

    return sound_instance, index;
}

play_sound :: (sound: Sound, position: Vector3, volume: float = 1.0, index: int = -1) -> SoundInstance, int {
    sound_instance, played_index := play_sound(sound, volume, index);

    set_position(sound_instance, position);

    return sound_instance, played_index;
}

play_sound :: (sound: Sound, position: Vector3, velocity: Vector3, volume: float = 1.0, index: int = -1) -> SoundInstance, int {
    sound_instance, played_index := play_sound(sound, volume, index);

    set_position_velocity(sound_instance, position, velocity);

    return sound_instance, played_index;
}

pause_sound :: (sound: Sound) {
    
}
