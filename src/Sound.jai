
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

get_sound :: (name: string) -> *Sound {
    found, sound := table_find_new(*loaded_sounds, create_fixed_string(name, 128));
    assert(found, "Could not find sound to play. %\n", name);

    return sound;
}

play_sound :: (name: string, volume: float = 1.0) -> SoundInstance {
    sound := get_sound(name);
    if !sound {
        return .{};
    }

    instance := play_sound(sound, volume);
    return instance;
}

play_sound :: (sound: string, position: Vector3, volume: float = 1.0) -> SoundInstance {
    instance := play_sound(get_sound(sound), position, volume);
    return instance;
} @thread

play_sound :: (sound: *Sound, position: Vector3, volume: float = 1.0) -> SoundInstance {
    instance := play_sound(sound, volume);
    set_position(instance, position);

    return instance;
} @thread

play_sound :: (sound: string, position: Vector3, velocity: Vector3, volume: float = 1.0) -> SoundInstance {
    instance := play_sound(get_sound(sound), position, velocity, volume);
    return instance;
} @thread

play_sound :: (sound: *Sound, position: Vector3, velocity: Vector3, volume: float = 1.0) -> SoundInstance {
    instance := play_sound(sound, volume);
    set_position_velocity(instance, position, velocity);

    return instance;
} @thread

play_sound :: (sound: *Sound, volume: float = 1.0) -> SoundInstance {
    if !sound || !sound.event_description {
        return .{};
    }

    instance: SoundInstance;

    error := FMOD_Studio_EventDescription_CreateInstance(sound.event_description, *instance.event_instance);
    assert(!error);

    error = FMOD_Studio_EventInstance_SetVolume(instance.event_instance, 0);
    assert(!error);

    userdata := New(SoundInstanceUserData);
    error = FMOD_Studio_EventInstance_SetUserData(instance.event_instance, userdata);
    assert(!error);

    error = FMOD_Studio_EventInstance_SetCallback(instance.event_instance, sound_instance_lifecycle_callback, FMOD_STUDIO_EVENT_CALLBACK_DESTROYED);
    assert(!error);

    error = FMOD_Studio_EventInstance_Start(instance.event_instance);
    assert(!error);

    set_volume(instance, volume, resolve = false);

    if event_start_callback {
        thread_safe_event_start_callback :: inline (instance: SoundInstance) {
            event_start_callback(instance);
        } @thread_safe

        thread_safe_event_start_callback(instance);
    }

    return instance;
} @thread

play_programmer_sound :: (sound: string, core_sound: *FMOD_SOUND, $destroyed_callback: #type (params: *FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES) #c_call = null, $event_created_callback: #type (event: *FMOD_STUDIO_EVENTINSTANCE) #c_call = null) -> SoundInstance {
    return play_programmer_sound(get_sound(sound), core_sound, destroyed_callback, event_created_callback);
} @thread

play_programmer_sound :: (sound: *Sound, core_sound: *FMOD_SOUND, $destroyed_callback: #type (params: *FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES) #c_call = null, $event_created_callback: #type (event: *FMOD_STUDIO_EVENTINSTANCE) #c_call = null) -> SoundInstance {
    if !sound || !sound.event_description || !core_sound {
        return .{};
    }

    instance: SoundInstance;

    error := FMOD_Studio_EventDescription_CreateInstance(sound.event_description, *instance.event_instance);
    assert(!error);

    // error = FMOD_Studio_EventInstance_SetVolume(instance.event_instance, 0);
    error = FMOD_Studio_EventInstance_SetVolume(instance.event_instance, 1);
    assert(!error);

    userdata := New(SoundInstanceUserData);
    userdata.core_sound = core_sound;
    userdata.volume = 1.0; // TODO DELETE ONCE ITS A SOUND3
    userdata.rolloff_volume = 1.0; // TODO DELETE ONCE ITS A SOUND3
    error = FMOD_Studio_EventInstance_SetUserData(instance.event_instance, userdata);
    assert(!error);

    programmer_sound_callback :: (type: FMOD_STUDIO_EVENT_CALLBACK_TYPE, event: *FMOD_STUDIO_EVENTINSTANCE, parameters: *void) -> FMOD_RESULT #c_call {
        if type == FMOD_STUDIO_EVENT_CALLBACK_CREATE_PROGRAMMER_SOUND {
            params := cast(*FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES) parameters;
            userdata: *SoundInstanceUserData;
            FMOD_Studio_EventInstance_GetUserData(event, cast(**void) *userdata);

            core_sound := userdata.core_sound;

            if core_sound {
                params.sound = core_sound;
                params.subsoundIndex = -1;
            }
        }

        #if destroyed_callback {
            if type == FMOD_STUDIO_EVENT_CALLBACK_DESTROY_PROGRAMMER_SOUND {
                params := cast(*FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES) parameters;
                destroyed_callback(params);
            }
        }

        #if event_created_callback {
            if type == FMOD_STUDIO_EVENT_CALLBACK_CREATED {
                event_created_callback(event);
            }
        }

        // TODO delete sound?

        return sound_instance_lifecycle_callback(type, event, parameters);
    }

    callback_events: FMOD_STUDIO_EVENT_CALLBACK_TYPE;
    callback_events = FMOD_STUDIO_EVENT_CALLBACK_CREATE_PROGRAMMER_SOUND | FMOD_STUDIO_EVENT_CALLBACK_DESTROYED;

    #if destroyed_callback {
        callback_events |= FMOD_STUDIO_EVENT_CALLBACK_DESTROY_PROGRAMMER_SOUND;
    }

    #if event_created_callback {
        callback_events |= FMOD_STUDIO_EVENT_CALLBACK_CREATED;
    }

    error = FMOD_Studio_EventInstance_SetCallback(
        instance.event_instance,
        programmer_sound_callback,
        callback_events);
    assert(!error);

    error = FMOD_Studio_EventInstance_Start(instance.event_instance);
    assert(!error);

    if event_start_callback {
        thread_safe_event_start_callback :: inline (instance: SoundInstance) {
            event_start_callback(instance);
        } @thread_safe

        thread_safe_event_start_callback(instance);
    }

    return instance;
} @thread

get_path :: (sound: *Sound) -> FixedString(512) {
    path: FixedString(512);

    used_count: s32;
    error := FMOD_Studio_EventDescription_GetPath(sound.event_description, path.buffer.data, cast(s32) path.buffer.count, *used_count);
    assert(!error, "Could not get path.\n");

    assert(used_count <= path.buffer.count, "Path buffer not large enough for sound path. %\n", to_string(*path));

    return path;
}

get_core_sound :: (sound: *Sound) -> *FMOD_SOUND {
    path := get_path(sound);

    sound_info: FMOD_STUDIO_SOUND_INFO;
    print("sound path %\n", to_string(guid));
    error := FMOD_Studio_System_GetSoundInfo(fmod_system, guid, *sound_info);
    assert(!error, "Could not get sound info. %\n", error);

    soundgroup := sound_info.exinfo.initialsoundgroup;
    subindex := sound_info.subsoundindex;

    core_sound: *FMOD_SOUND;
    error = FMOD_SoundGroup_GetSound(soundgroup, subindex, *core_sound);
    assert(!error, "Could not get the sound from the sound group. %\n", error);

    return core_sound;
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
