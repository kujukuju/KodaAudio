
Sound :: struct {
    event_description: *FMOD_STUDIO_EVENTDESCRIPTION;
}

SoundType :: enum {
    Invalid;
    Sound2;
    Sound3;
}

load_sound :: (id: FMOD_GUID) -> *Sound {
    sound := New(Sound);
    result := FMOD_Studio_System_GetEventByID(fmod_system, *id, *sound.event_description);
    if result {
        print("FMOD get event error. %\n", result);
        assert(false);
    }

    error := FMOD_Studio_EventDescription_LoadSampleData(sound.event_description);
    assert(!error);
    FMOD_Studio_EventDescription_SetUserData(sound.event_description, sound);

    return sound;
}

load_sound :: (path: string) -> *Sound {
    assert(path.count < 512, "Path too long!");
    fixed: [512] u8;
    memcpy(fixed.data, path.data, path.count);

    sound := New(Sound);
    error := FMOD_Studio_System_GetEvent(fmod_system, fixed.data, *sound.event_description);
    if error {
        print("FMOD get event error. %\n", error);
        assert(false);
    }

    error = FMOD_Studio_EventDescription_LoadSampleData(sound.event_description);
    assert(!error);
    FMOD_Studio_EventDescription_SetUserData(sound.event_description, sound);

    return sound;
}

play_sound :: (sound: *Sound, volume: float = 1.0, index: int = -1) -> SoundInstance, int {
    if !sound || !sound.event_description {
        return .{}, -1;
    }

    instance: SoundInstance;

    error := FMOD_Studio_EventDescription_CreateInstance(sound.event_description, *instance.event_instance);
    assert(!error);

    error = FMOD_Studio_EventInstance_Start(instance.event_instance);
    assert(!error);

    set_volume(instance, volume);
    // if get_type(instance) == .Sound3 {
    //     set_volume(instance, volume, 0);
    // } else {
    //     set_volume(instance, volume, 1);
    // }

    if event_start_callback {
        thread_safe_event_start_callback :: inline (instance: SoundInstance) {
            event_start_callback(instance);
        } @thread_safe

        thread_safe_event_start_callback(instance);
    }

    return instance, -1;
} @thread

play_sound :: (sound: *Sound, position: Vector3, volume: float = 1.0, index: int = -1) -> SoundInstance, int {
    instance := play_sound(sound, volume, index);
    set_position(instance, position);

    return instance, -1;
} @thread

play_sound :: (sound: *Sound, position: Vector3, velocity: Vector3, volume: float = 1.0, index: int = -1) -> SoundInstance, int {
    instance := play_sound(sound, volume, index);
    set_position_velocity(instance, position, velocity);

    return instance, -1;
} @thread

get_path :: (sound: *Sound) -> string {
    path: [..] u8;
    path.allocator = temp;
    array_reserve(*path, 256);

    used_count := cast(s32) path.allocated;
    while used_count == path.allocated {
        if FMOD_Studio_EventDescription_GetPath(sound.event_description, path.data, cast(s32) path.allocated, *used_count) {
            assert(false, "Could not get path.\n");
            return "";
        }

        path.count = used_count;
        if used_count == path.allocated {
            array_reserve(*path, path.allocated * 2);
        }
    }

    path_string: string;
    path_string.data = path.data;
    path_string.count = path.count;
    return path_string;
}



// Sound :: struct {
//     type: SoundType;
//     fmod_sounds: [20] *FMOD_SOUND;
//     count: int;
//     names: [20] string;
//     default_volume: float;
//     default_size: float;
//     default_directional_strength: float;
//     fmod_size_dsp: *FMOD_DSP;
//     volume_ramp: bool;
//     priority: int = 0;
//     // memory_buffers: [20] [] u8;
// }

// // TODO each sound type should have its own file with the base type passing it to the correct function

// // TODO I need to have a way to load and serialize every sound in the game and then retrieve them by byte array to create sound files
// // TODO I can request load all files, it'll auto hash and serialize/deserialize, and then load from memory will read from this internal block instead by file name
// // TODO file name just points to start byte and length

// load_sound3 :: (paths: ..string, loop: bool = false, volume: float = 1.0, size: float = 0.0, directional_strength: float = 1.0, volume_ramp: bool = false, priority: int = 0) -> *Sound {
//     sound := New(Sound);
//     sound.type = .Sound3;
//     sound.count = paths.count;
//     sound.default_volume = volume;
//     sound.default_size = size;
//     sound.default_directional_strength = directional_strength;
//     sound.volume_ramp = volume_ramp;
//     sound.priority = priority;

//     assert(paths.count <= sound.fmod_sounds.count, "More than 10 or 20 or something sounds not currently supported for simplicity.");
//     for path: paths {
//         assert(path.count < 512, "Audio path is too long.");
//     }

//     // for path, index: paths {
//     //     file, loaded := read_entire_file(path);
//     //     assert(loaded, "Could not load fmod sound.");

//     //     sound.memory_buffers[index].data = file.data;
//     //     sound.memory_buffers[index].count = file.count;
//     // }

//     sound_type := FMOD_3D | FMOD_CREATESAMPLE;
//     if loop {
//         sound_type |= FMOD_LOOP_NORMAL;
//     }

//     // sound_type |= FMOD_3D_LINEARROLLOFF;

//     // rolloff: [] Vector3;
//     // if custom_rolloff.count > 0 {
//     //     rolloff = get_custom_rolloff_for_distance(custom_rolloff_distance);
//     //     sound_type |= FMOD_3D_CUSTOMROLLOFF;
//     // }

//     for path, index: paths {
//         fixed_path: [512] u8;
//         memcpy(fixed_path.data, path.data, path.count);

//         sound.names[index] = path;

//         result := FMOD_System_CreateSound(fmod_system, fixed_path.data, sound_type, null, *sound.fmod_sounds[index]);
//         if result {
//             print("FMOD load sound error. % %\n", result, path);
//             assert(false, "FMOD load sound error.");
//             return null;
//         }

//         FMOD_Sound_SetUserData(sound.fmod_sounds[index], sound);
//         FMOD_Sound_SetDefaults(sound.fmod_sounds[index], 48000, cast(s32) sound.priority);
//         // FMOD_Sound_Set3DMinMaxDistance(sound.fmod_sounds[index], 0.5, 10.0);
//         // if rolloff.count > 0 {
//         //     FMOD_Sound_Set3DCustomRolloff(sound.fmod_sounds[index], rolloff.data, xx rolloff.count);
//         // }
//     }

//     if sound.default_size > 0 {
//         FMOD_System_CreateDSPByType(fmod_system, .FMOD_DSP_TYPE_PAN, *sound.fmod_size_dsp);
//         FMOD_DSP_SetParameterFloat(sound.fmod_size_dsp, cast(s32) FMOD_DSP_PAN.FMOD_DSP_PAN_3D_SOUND_SIZE, sound.default_size);
//     }

//     return sound;
// }

// load_sound2 :: (paths: ..string, loop: bool = false, volume: float = 1.0, size: float = 0.0, volume_ramp: bool = false, priority: int = 0) -> *Sound {
//     sound := New(Sound);
//     sound.type = .Sound2;
//     sound.count = paths.count;
//     sound.default_volume = volume;
//     sound.default_size = size;
//     sound.volume_ramp = volume_ramp;
//     sound.priority = priority;

//     assert(paths.count <= sound.fmod_sounds.count, "More than 10 or 20 or something sounds not currently supported for simplicity.");
//     for path: paths {
//         assert(path.count < 512, "Audio path is too long.");
//     }

//     sound_type := FMOD_DEFAULT | FMOD_CREATESAMPLE;
//     if loop {
//         sound_type |= FMOD_LOOP_NORMAL;
//     }

//     for path, index: paths {
//         fixed_path: [512] u8;
//         memcpy(fixed_path.data, path.data, path.count);

//         sound.names[index] = path;

//         result := FMOD_System_CreateSound(fmod_system, fixed_path.data, sound_type, null, *sound.fmod_sounds[index]);
//         if result {
//             print("FMOD load sound error. % %\n", result, path);
//             assert(false, "FMOD load sound error.");
//             return null;
//         }

//         FMOD_Sound_SetUserData(sound.fmod_sounds[index], sound);
//         FMOD_Sound_SetDefaults(sound.fmod_sounds[index], 48000, cast(s32) sound.priority);
//     }

//     return sound;
// }

// destroy_sound :: (sound: *Sound) {
//     for i: 0..sound.count - 1 {
//         result := FMOD_Sound_Release(sound.fmod_sounds[i]);
//         if result {
//             print("FMOD error destroying sound. %\n", result);
//         }
//     }

//     free(sound);
// }

// play_sound :: (sound: Sound, volume: float = 1.0, index: int = -1) -> SoundInstance, int {
//     sound_instance: SoundInstance;

//     if index == -1 {
//         index = 0;
//         if sound.count > 1 {
//             index = cast(int) (random_get() % cast(u64) sound.count);
//         }
//     }

//     assert(index >= 0 && index < sound.count, "Invalid index for audio source.");

//     // print("% playing %\n", seconds_since_init(), sound.names[index]);

//     FMOD_System_PlaySound(fmod_system, sound.fmod_sounds[index], null, 0, *sound_instance.fmod_channel);

//     set_volume_ramp(sound_instance, sound.volume_ramp);

//     if sound.fmod_size_dsp {
//         FMOD_Channel_AddDSP(sound_instance.fmod_channel, 0, sound.fmod_size_dsp);
//     } else {
//         // ensure no size dsp carries over unintentionally
//         numdsps: s32;
//         FMOD_Channel_GetNumDSPs(sound_instance.fmod_channel, *numdsps);
//         // dsp: *FMOD_DSP;
//         // FMOD_Channel_GetDSP(sound_instance.fmod_channel, 0, *dsp);
//         // print("dsp %\n", numdsps);
//         assert(numdsps == 1, "DSP cannot exist here. I want to be sure it's not reused.");
//     }

//     volume_scale := sound.default_volume * volume;
//     set_volume_scale_internal(sound_instance, volume_scale);
//     set_volume(sound_instance, 1.0);

//     if sound.type == .Sound3 {
//         final_directional_strength := global_directional_strength * sound.default_directional_strength;
//         if final_directional_strength != 1 {
//             // set_spread(sound_instance, 180 - 90);
//             set_directional_strength(sound_instance, final_directional_strength);
//         }
//     }

//     return sound_instance, index;
// }

// play_sound :: (sound: Sound, position: Vector3, volume: float = 1.0, index: int = -1) -> SoundInstance, int {
//     sound_instance, played_index := play_sound(sound, volume, index);

//     set_position(sound_instance, position);

//     return sound_instance, played_index;
// }

// play_sound :: (sound: Sound, position: Vector3, velocity: Vector3, volume: float = 1.0, index: int = -1) -> SoundInstance, int {
//     sound_instance, played_index := play_sound(sound, volume, index);

//     set_position_velocity(sound_instance, position, velocity);

//     return sound_instance, played_index;
// }

// pause_sound :: (sound: Sound) {
    
// }
