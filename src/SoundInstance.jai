
SoundInstance :: struct {
    fmod_channel: *FMOD_CHANNEL;
}

play :: (instance: SoundInstance) {
    if !instance.fmod_channel {
        return;
    }

    FMOD_Channel_SetPaused(instance.fmod_channel, 0);
}

pause :: (instance: SoundInstance) {
    if !instance.fmod_channel {
        return;
    }

    FMOD_Channel_SetPaused(instance.fmod_channel, 1);
}

stop :: (instance: SoundInstance) {
    if !instance.fmod_channel {
        return;
    }

    FMOD_Channel_Stop(instance.fmod_channel);
}

// seek_to_current_system_time :: (instance: SoundInstance) {
//     if !instance.fmod_channel {
//         return;
//     }

//     sample_rate := koda_audio_get_sample_rate();
//     dsp_start_offset := cast(u64) sample_rate / 10;

//     dspclock: u64;
//     FMOD_Channel_GetDSPClock(instance.fmod_channel, *dspclock, null);

//     offset := (dspclock + dsp_start_offset) % cast(u64) get_duration_pcm(instance);

//     FMOD_Channel_SetDelay(instance.fmod_channel, dspclock + dsp_start_offset, 0, 1);
//     FMOD_Channel_SetPosition(instance.fmod_channel, cast(u32) offset, FMOD_TIMEUNIT_PCM);
// }

set_position :: (instance: SoundInstance, position: Vector3) {
    if !instance.fmod_channel {
        return;
    }

    result := FMOD_Channel_Set3DAttributes(instance.fmod_channel, *position, null);
    if result {
        print("FMOD error. %\n", result);
    }
}

set_position_velocity :: (instance: SoundInstance, position: Vector3, velocity: Vector3) {
    if !instance.fmod_channel {
        return;
    }

    result := FMOD_Channel_Set3DAttributes(instance.fmod_channel, *position, *velocity);
    if result {
        print("FMOD error. %\n", result);
    }
}

is_playing :: (instance: SoundInstance) -> bool {
    if !instance.fmod_channel {
        return false;
    }

    playing: s32;
    result := FMOD_Channel_IsPlaying(instance.fmod_channel, *playing);
    if result {
        return false;
    }

    return !!playing;
}

#run assert(size_of(*void) == 8, "Have to have 64 bit pointers.");
get_volume :: (instance: SoundInstance) -> float {
    if !instance.fmod_channel {
        return 0;
    }

    volume_scale := get_volume_scale(instance);
    if volume_scale == 0 {
        return 0;
    }

    volume: float;
    FMOD_Channel_GetVolume(instance.fmod_channel, *volume);

    return volume / volume_scale;
}

set_volume :: (instance: SoundInstance, volume: float) {
    if !instance.fmod_channel {
        return;
    }

    volume_scale := get_volume_scale(instance);
    FMOD_Channel_SetVolume(instance.fmod_channel, volume * volume_scale);
}

// get_raw_volume :: (instance: SoundInstance) -> float {
//     if !instance.fmod_channel {
//         return 0;
//     }

//     volume: float;
//     FMOD_Channel_GetVolume(instance.fmod_channel, *volume);

//     denom := get_default_volume(instance) * get_volume(instance);
//     if denom == 0 {
//         return 0;
//     }

//     return volume / denom;
// }

// set_raw_volume :: (instance: SoundInstance, volume: float) {
//     if !instance.fmod_channel {
//         return;
//     }

//     if volume * get_default_volume(instance) * get_volume(instance) > 1 {
//         print("volume % | % % %\n", volume * get_default_volume(instance) * get_volume(instance), volume, get_default_volume(instance), get_volume(instance));
//     }
//     FMOD_Channel_SetVolume(instance.fmod_channel, volume * get_default_volume(instance) * get_volume(instance));
// }

get_raw_volume :: (instance: SoundInstance) -> float {
    if !instance.fmod_channel {
        return 0;
    }

    volume: float;
    FMOD_Channel_GetVolume(instance.fmod_channel, *volume);

    return volume;
}

get_volume_scale :: (instance: SoundInstance) -> float {
    if !instance.fmod_channel {
        return 0;
    }

    volume_scale: float64;
    FMOD_Channel_GetUserData(instance.fmod_channel, cast(**void) *volume_scale);

    return cast(float) volume_scale;
}

set_volume_scale_internal :: (instance: SoundInstance, volume: float) {
    if !instance.fmod_channel {
        return;
    }

    fmod_sound: *FMOD_SOUND;
    FMOD_Channel_GetCurrentSound(instance.fmod_channel, *fmod_sound);

    user_data: *Sound;
    FMOD_Sound_GetUserData(fmod_sound, cast(*void) *user_data);

    sound_volume := user_data.default_volume;

    volume64 := cast(float64) (volume * sound_volume);
    FMOD_Channel_SetUserData(instance.fmod_channel, (cast(**void) *volume64).*);
}

get_muted :: (instance: SoundInstance) -> bool {
    if !instance.fmod_channel {
        return false;
    }

    muted: s32;
    FMOD_Channel_GetMute(instance.fmod_channel, *muted);

    return !!muted;
}

set_muted :: (instance: SoundInstance, muted: bool) {
    if !instance.fmod_channel {
        return;
    }

    FMOD_Channel_SetMute(instance.fmod_channel, ifx muted then cast(s32) 1 else cast(s32) 0);
}

get_type :: (instance: SoundInstance) -> SoundType {
    if !instance.fmod_channel {
        return .Invalid;
    }

    mode: FMOD_MODE;
    FMOD_Channel_GetMode(instance.fmod_channel, *mode);

    if mode & FMOD_3D {
        return .Sound3;
    }

    return .Sound2;
}

get_position :: (instance: SoundInstance) -> Vector3 {
    if !instance.fmod_channel {
        return .{};
    }

    position: Vector3;
    velocity: Vector3;
    FMOD_Channel_Get3DAttributes(instance.fmod_channel, *position, *velocity);

    return position;
}

set_pan :: (instance: SoundInstance, pan: float) {
    if !instance.fmod_channel {
        return;
    }

    FMOD_Channel_SetPan(instance.fmod_channel, pan);
}

get_directional_strength :: (instance: SoundInstance) -> float {
    if !instance.fmod_channel {
        return 0;
    }
    
    strength: float;
    FMOD_Channel_Get3DLevel(instance.fmod_channel, *strength);
    return strength;
}

set_directional_strength :: (instance: SoundInstance, strength: float) {
    if !instance.fmod_channel {
        return;
    }

    FMOD_Channel_Set3DLevel(instance.fmod_channel, strength);
}

get_spread :: (instance: SoundInstance) -> float {
    if !instance.fmod_channel {
        return 0;
    }

    angle: float;
    FMOD_Channel_Get3DSpread(instance.fmod_channel, *angle);
    return angle;
}

set_spread :: (instance: SoundInstance, angle: float) {
    if !instance.fmod_channel {
        return;
    }

    FMOD_Channel_Set3DSpread(instance.fmod_channel, angle);
}

set_custom_rolloff :: (instance: SoundInstance, rolloff: [] Vector3) {
    if !instance.fmod_channel {
        return;
    }

    FMOD_Channel_Set3DCustomRolloff(instance.fmod_channel, rolloff.data, cast(s32) rolloff.count);
}

is_fading_out :: (instance: SoundInstance) -> bool {
    if !instance.fmod_channel {
        return false;
    }

    numpoints: u32;
    FMOD_Channel_GetFadePoints(instance.fmod_channel, *numpoints, null, null);

    if numpoints == 0 {
        return false;
    }

    points := NewArray(numpoints, u64, allocator = temp);
    volumes := NewArray(numpoints, float, allocator = temp);
    FMOD_Channel_GetFadePoints(instance.fmod_channel, *numpoints, points.data, volumes.data);

    dspclock: u64;
    FMOD_Channel_GetDSPClock(instance.fmod_channel, *dspclock, null);

    for i: 0..numpoints - 1 {
        if dspclock < points[i] && volumes[i] == 0 {
            return true;
        }
    }

    return false;
}

is_done_fading_out :: (instance: SoundInstance) -> bool {
    numpoints: u32;
    FMOD_Channel_GetFadePoints(instance.fmod_channel, *numpoints, null, null);
    
    points := NewArray(numpoints, u64, allocator = temp);
    volumes := NewArray(numpoints, float, allocator = temp);
    FMOD_Channel_GetFadePoints(instance.fmod_channel, *numpoints, points.data, volumes.data);

    dspclock: u64;
    FMOD_Channel_GetDSPClock(instance.fmod_channel, *dspclock, null);

    for i: 0..numpoints - 1 {
        if dspclock >= points[i] && volumes[i] == 0 {
            return true;
        }
    }

    return false;
}

fade_out :: (instance: SoundInstance, duration: float) {
    if !instance.fmod_channel {
        return;
    }

    sample_rate := koda_audio_get_sample_rate();

    dspclock: u64;
    FMOD_Channel_GetDSPClock(instance.fmod_channel, null, *dspclock);

    FMOD_Channel_AddFadePoint(instance.fmod_channel, dspclock, 1.0);
    FMOD_Channel_AddFadePoint(instance.fmod_channel, dspclock + cast(u64) (duration / 1000.0 * sample_rate), 0.0);
}

is_fading_in :: (instance: SoundInstance) -> bool {
    if !instance.fmod_channel {
        return false;
    }

    numpoints: u32;
    FMOD_Channel_GetFadePoints(instance.fmod_channel, *numpoints, null, null);

    if numpoints == 0 {
        return false;
    }

    points := NewArray(numpoints, u64, allocator = temp);
    volumes := NewArray(numpoints, float, allocator = temp);
    FMOD_Channel_GetFadePoints(instance.fmod_channel, *numpoints, points.data, volumes.data);

    dspclock: u64;
    FMOD_Channel_GetDSPClock(instance.fmod_channel, *dspclock, null);

    for i: 0..numpoints - 1 {
        if dspclock < points[i] && volumes[i] == 1 {
            return true;
        }
    }

    return false;
}

is_done_fading_in :: (instance: SoundInstance) -> bool {
    numpoints: u32;
    FMOD_Channel_GetFadePoints(instance.fmod_channel, *numpoints, null, null);
    
    points := NewArray(numpoints, u64, allocator = temp);
    volumes := NewArray(numpoints, float, allocator = temp);
    FMOD_Channel_GetFadePoints(instance.fmod_channel, *numpoints, points.data, volumes.data);

    dspclock: u64;
    FMOD_Channel_GetDSPClock(instance.fmod_channel, *dspclock, null);

    for i: 0..numpoints - 1 {
        if dspclock >= points[i] && volumes[i] == 1 {
            return true;
        }
    }

    return false;
}

fade_in :: (instance: SoundInstance, duration: float, delay: float = 0) {
    if !instance.fmod_channel {
        return;
    }

    sample_rate := koda_audio_get_sample_rate();

    dspclock: u64;
    FMOD_Channel_GetDSPClock(instance.fmod_channel, null, *dspclock);

    delay_pcm := cast(u64) (delay / 1000.0 * sample_rate);

    FMOD_Channel_AddFadePoint(instance.fmod_channel, dspclock, 0);
    FMOD_Channel_AddFadePoint(instance.fmod_channel, dspclock + delay_pcm, 0);
    FMOD_Channel_AddFadePoint(instance.fmod_channel, dspclock + delay_pcm + cast(u64) (duration / 1000.0 * sample_rate), 1.0);
}

// get_default_volume :: (instance: SoundInstance) -> float {
//     if !instance.fmod_channel {
//         return 0;
//     }

//     fmod_sound: *FMOD_SOUND;
//     FMOD_Channel_GetCurrentSound(instance.fmod_channel, *fmod_sound);

//     user_data: *Sound;
//     FMOD_Sound_GetUserData(fmod_sound, cast(*void) *user_data);

//     return user_data.default_volume;
// }

// in milliseconds
get_duration :: (instance: SoundInstance) -> float {
    if !instance.fmod_channel {
        return 0;
    }

    fmod_sound: *FMOD_SOUND;
    FMOD_Channel_GetCurrentSound(instance.fmod_channel, *fmod_sound);

    length: u32;
    FMOD_Sound_GetLength(fmod_sound, *length, FMOD_TIMEUNIT_PCM);
    
    sample_rate := koda_audio_get_sample_rate();

    return length * 1000.0 / sample_rate;
}

get_duration_pcm :: (instance: SoundInstance) -> int {
    if !instance.fmod_channel {
        return 0;
    }

    fmod_sound: *FMOD_SOUND;
    FMOD_Channel_GetCurrentSound(instance.fmod_channel, *fmod_sound);

    length: u32;
    FMOD_Sound_GetLength(fmod_sound, *length, FMOD_TIMEUNIT_PCM);

    return length;
}

get_volume_ramp :: (instance: SoundInstance) -> bool {
    if !instance.fmod_channel {
        return false;
    }

    ramp: s32;
    FMOD_Channel_GetVolumeRamp(instance.fmod_channel, *ramp);

    return !!ramp;
}

set_volume_ramp :: (instance: SoundInstance, ramp: bool) {
    if !instance.fmod_channel {
        return;
    }

    FMOD_Channel_SetVolumeRamp(instance.fmod_channel, cast(s32) ramp);
}
