
SoundInstance :: struct {
    event_instance: *FMOD_STUDIO_EVENTINSTANCE;
}

is_valid :: (instance: SoundInstance) -> bool {
    return instance.event_instance && FMOD_Studio_EventInstance_IsValid(instance.event_instance);
} @thread

get_sound :: (instance: SoundInstance) -> *Sound {
    if !is_valid(instance) {
        return null;
    }

    description: *FMOD_STUDIO_EVENTDESCRIPTION;
    error := FMOD_Studio_EventInstance_GetDescription(instance.event_instance, *description);
    assert(!error, "Could not get description. %\n", error);
    if !description {
        return null;
    }

    sound: *Sound;
    error = FMOD_Studio_EventDescription_GetUserData(description, cast(*void) *sound);
    assert(!error, "Could not get user data. %\n", error);
    assert(!!sound, "Could not get sound.\n");

    return sound;
} @thread

release_sound :: (instance: SoundInstance) {
    if !is_valid(instance) {
        return;
    }

    error := FMOD_Studio_EventInstance_Release(instance.event_instance);
    assert(!error, "Could not release instance. %\n", error);
}

get_position :: (instance: SoundInstance) -> Vector3 {
    if !is_valid(instance) {
        return .{};
    }

    attributes: FMOD_3D_ATTRIBUTES;
    error := FMOD_Studio_EventInstance_Get3DAttributes(instance.event_instance, *attributes);
    assert(!error);

    return attributes.position;
} @thread

set_position :: (instance: SoundInstance, position: Vector3) {
    set_position_velocity(instance, position, .{});
} @thread

set_position_velocity :: (instance: SoundInstance, position: Vector3, velocity: Vector3) {
    if !is_valid(instance) {
        return;
    }

    attributes: FMOD_3D_ATTRIBUTES;
    attributes.position = position;
    attributes.velocity = velocity;
    attributes.forward = .{0, 0, -1};
    attributes.up = .{0, 1, 0};

    error := FMOD_Studio_EventInstance_Set3DAttributes(instance.event_instance, *attributes);
    assert(!error, "Set 3d error %.\n", error);
} @thread

is_playing :: (instance: SoundInstance) -> bool {
    if !is_valid(instance) {
        return false;
    }

    playback_state: FMOD_STUDIO_PLAYBACK_STATE;
    error := FMOD_Studio_EventInstance_GetPlaybackState(instance.event_instance, *playback_state);
    assert(!error, "Get playback state error. %\n", error);

    return playback_state != .STOPPED && playback_state != .STOPPING;
} @thread

is_starting :: (instance: SoundInstance) -> bool {
    if !is_valid(instance) {
        return false;
    }

    playback_state: FMOD_STUDIO_PLAYBACK_STATE;
    error := FMOD_Studio_EventInstance_GetPlaybackState(instance.event_instance, *playback_state);
    assert(!error, "Get playback state error. %\n", error);

    return playback_state == .STARTING;
} @thread

get_hardware_latency :: (instance: SoundInstance) -> int {
    if !is_playing(instance) || is_starting(instance) {
        return 0;
    }

    channel_group := get_channel_group(instance);
    if !channel_group {
        return 0;
    }

    child_clock: u64;
    parent_clock: u64;
    error := FMOD_ChannelGroup_GetDSPClock(channel_group, *child_clock, *parent_clock);
    assert(!error, "Channel group get dsp clock error. %\n", error);

    sample_rate := koda_audio_get_sample_rate();
    return (cast(s64) parent_clock - cast(s64) child_clock) * 1000 / sample_rate;
}

get_channel_group :: (instance: SoundInstance) -> *FMOD_CHANNELGROUP {
    if !is_playing(instance) || is_starting(instance) {
        return null;
    }

    channel_group: *FMOD_CHANNELGROUP;
    error := FMOD_Studio_EventInstance_GetChannelGroup(instance.event_instance, *channel_group);
    assert(!error, "Get channel group error. %\n", error);

    return channel_group;
}

get_time :: (instance: SoundInstance) -> int {
    if !is_valid(instance) {
        return 0;
    }

    position: s32;
    error := FMOD_Studio_EventInstance_GetTimelinePosition(instance.event_instance, *position);
    assert(!error, "Get timeline position error. %\n", error);

    return position;
} @thread

set_time :: (instance: SoundInstance, time: int) {
    if !is_valid(instance) {
        return;
    }

    position := cast(s32) time;
    error := FMOD_Studio_EventInstance_SetTimelinePosition(instance.event_instance, position);
    assert(!error);
} @thread

get_type :: (instance: SoundInstance) -> SoundType {
    if !is_valid(instance) {
        return .Invalid;
    }

    event_description: *FMOD_STUDIO_EVENTDESCRIPTION;
    error := FMOD_Studio_EventInstance_GetDescription(instance.event_instance, *event_description);
    assert(!error);

    is_3d: FMOD_BOOL;
    error = FMOD_Studio_EventDescription_Is3D(event_description, *is_3d);
    assert(!error);

    if is_3d {
        return .Sound3;
    }

    return .Sound2;
} @thread

get_volume :: (instance: SoundInstance) -> float, float {
    if !is_valid(instance) {
        return 0, 0;
    }

    userdata: *SoundInstanceUserData;
    error := FMOD_Studio_EventInstance_GetUserData(instance.event_instance, cast(**void) *userdata);
    assert(!error, "Event instance get user data failed. %\n", error);
    if error {
        return 0, 0;
    }

    return userdata.volume, userdata.rolloff_volume;
} @thread

set_volume :: (instance: SoundInstance, volume: float, rolloff_volume: float, resolve: bool = true) {
    if !is_valid(instance) {
        return;
    }

    userdata: *SoundInstanceUserData;
    error := FMOD_Studio_EventInstance_GetUserData(instance.event_instance, cast(**void) *userdata);
    assert(!error);

    userdata.volume = volume;
    userdata.rolloff_volume = rolloff_volume;

    if resolve {
        resolve_volume(instance, userdata.volume, userdata.rolloff_volume);
    }
}

set_volume :: (instance: SoundInstance, volume: float, resolve: bool = true) {
    if !is_valid(instance) {
        return;
    }

    userdata: *SoundInstanceUserData;
    error := FMOD_Studio_EventInstance_GetUserData(instance.event_instance, cast(**void) *userdata);
    assert(!error);

    userdata.volume, userdata.rolloff_volume = get_volume(instance);
    userdata.volume = volume;

    if resolve {
        resolve_volume(instance, userdata.volume, userdata.rolloff_volume);
    }
} @thread

set_rolloff_volume :: (instance: SoundInstance, rolloff_volume: float) {
    if !is_valid(instance) {
        return;
    }

    userdata: *SoundInstanceUserData;
    error := FMOD_Studio_EventInstance_GetUserData(instance.event_instance, cast(**void) *userdata);
    assert(!error);

    userdata.volume, userdata.rolloff_volume = get_volume(instance);
    userdata.rolloff_volume = rolloff_volume;

    resolve_volume(instance, userdata.volume, userdata.rolloff_volume);
} @thread

resolve_volume :: (instance: SoundInstance) {
    if !is_valid(instance) {
        return;
    }

    volume, rolloff_volume := get_volume(instance);
    resolve_volume(instance, volume, rolloff_volume);
} @thread

resolve_volume :: (instance: SoundInstance, volume: float, rolloff_volume: float) {
    if !is_valid(instance) {
        return;
    }

    error := FMOD_Studio_EventInstance_SetVolume(instance.event_instance, volume * rolloff_volume);
    assert(!error, "Resolve volume error. %\n", error);
} @thread

force_volume :: (instance: SoundInstance, volume: float) {
    if !is_valid(instance) {
        return;
    }

    error := FMOD_Studio_EventInstance_SetVolume(instance.event_instance, volume);
    assert(!error);
    assert(!error, "Force volume error. %\n", error);
} @thread

get_duration :: (instance: SoundInstance) -> int {
    if !is_valid(instance) {
        return 0;
    }

    event_description: *FMOD_STUDIO_EVENTDESCRIPTION;
    error := FMOD_Studio_EventInstance_GetDescription(instance.event_instance, *event_description);
    assert(!error);

    length: s32;
    error = FMOD_Studio_EventDescription_GetLength(event_description, *length);
    assert(!error);

    return length;
} @thread

stop :: (instance: SoundInstance) {
    if !is_valid(instance) {
        return;
    }

    error := FMOD_Studio_EventInstance_Stop(instance.event_instance, .ALLOWFADEOUT);
    assert(!error);
} @thread

has_channel_group :: (instance: SoundInstance) -> bool {
    channel_group: *FMOD_CHANNELGROUP;
    error := FMOD_Studio_EventInstance_GetChannelGroup(instance.event_instance, *channel_group);

    return channel_group && !error;
} @thread

attach_dsp :: (instance: SoundInstance, dsp: *FMOD_DSP) {
    channel_group: *FMOD_CHANNELGROUP;
    error := FMOD_Studio_EventInstance_GetChannelGroup(instance.event_instance, *channel_group);
    assert(!error, "Could not get the channel group to attach dsp. %\n", error);

    error = FMOD_ChannelGroup_AddDSP(channel_group, cast(s32) FMOD_CHANNELCONTROL_DSP_INDEX.TAIL, dsp);
    assert(!error, "Could not attach dsp to event instance channel group. %\n", error);
} @thread

detach_dsp :: (instance: SoundInstance, dsp: *FMOD_DSP) {
    channel_group: *FMOD_CHANNELGROUP;
    error := FMOD_Studio_EventInstance_GetChannelGroup(instance.event_instance, *channel_group);
    assert(!error, "Could not get the channel group to detach dsp. %\n", error);

    error = FMOD_ChannelGroup_RemoveDSP(channel_group, dsp);
    assert(!error, "Could not detach dsp from event instance channel group. %\n", error);
} @thread

set_pitch_and_speed_semitones :: (instance: SoundInstance, semitones: float) {
    factor := pow(2.0, semitones / 12.0);
    set_pitch_and_speed(instance, factor);
}

set_pitch_and_speed :: (instance: SoundInstance, pitch: float) {
    if !is_valid(instance) {
        return;
    }

    error := FMOD_Studio_EventInstance_SetPitch(instance.event_instance, pitch);
    assert(!error, "Could not set pitch. %\n", error);
}

#scope_module

SoundInstanceUserData :: struct {
    volume: float;
    rolloff_volume: float;
    core_sound: *FMOD_SOUND;
}

sound_instance_lifecycle_callback :: (type: FMOD_STUDIO_EVENT_CALLBACK_TYPE, event: *FMOD_STUDIO_EVENTINSTANCE, parameters: *void) -> FMOD_RESULT #c_call {
    if type == FMOD_STUDIO_EVENT_CALLBACK_DESTROYED {
        userdata: *SoundInstanceUserData;
        FMOD_Studio_EventInstance_GetUserData(event, cast(**void) *userdata);

        if userdata {
            empty: #Context;
            push_context empty {
                free(userdata);
            }
        }
    }

    return .FMOD_OK;
}


// get_volume :: (instance: SoundInstance) -> float {

// }



// SoundInstance :: struct {
//     fmod_channel: *FMOD_CHANNEL;
// }

// play :: (instance: SoundInstance) {
//     if !instance.fmod_channel {
//         return;
//     }

//     FMOD_Channel_SetPaused(instance.fmod_channel, 0);
// }

// pause :: (instance: SoundInstance) {
//     if !instance.fmod_channel {
//         return;
//     }

//     FMOD_Channel_SetPaused(instance.fmod_channel, 1);
// }

// stop :: (instance: SoundInstance) {
//     if !instance.fmod_channel {
//         return;
//     }

//     FMOD_Channel_Stop(instance.fmod_channel);
// }

// // seek_to_current_system_time :: (instance: SoundInstance) {
// //     if !instance.fmod_channel {
// //         return;
// //     }

// //     sample_rate := koda_audio_get_sample_rate();
// //     dsp_start_offset := cast(u64) sample_rate / 10;

// //     dspclock: u64;
// //     FMOD_Channel_GetDSPClock(instance.fmod_channel, *dspclock, null);

// //     offset := (dspclock + dsp_start_offset) % cast(u64) get_duration_pcm(instance);

// //     FMOD_Channel_SetDelay(instance.fmod_channel, dspclock + dsp_start_offset, 0, 1);
// //     FMOD_Channel_SetPosition(instance.fmod_channel, cast(u32) offset, FMOD_TIMEUNIT_PCM);
// // }

// set_position :: (instance: SoundInstance, position: Vector3) {
//     if !instance.fmod_channel {
//         return;
//     }

//     result := FMOD_Channel_Set3DAttributes(instance.fmod_channel, *position, null);
//     if result {
//         print("FMOD error. %\n", result);
//     }
// }

// set_position_velocity :: (instance: SoundInstance, position: Vector3, velocity: Vector3) {
//     if !instance.fmod_channel {
//         return;
//     }

//     result := FMOD_Channel_Set3DAttributes(instance.fmod_channel, *position, *velocity);
//     if result {
//         print("FMOD error. %\n", result);
//     }
// }

// is_playing :: (instance: SoundInstance) -> bool {
//     if !instance.fmod_channel {
//         return false;
//     }

//     playing: s32;
//     result := FMOD_Channel_IsPlaying(instance.fmod_channel, *playing);
//     if result {
//         return false;
//     }

//     return !!playing;
// }

// #run assert(size_of(*void) == 8, "Have to have 64 bit pointers.");
// get_volume :: (instance: SoundInstance) -> float {
//     if !instance.fmod_channel {
//         return 0;
//     }

//     volume_scale := get_volume_scale(instance);
//     if volume_scale == 0 {
//         return 0;
//     }

//     volume: float;
//     FMOD_Channel_GetVolume(instance.fmod_channel, *volume);

//     return volume / volume_scale;
// }

// set_volume :: (instance: SoundInstance, volume: float) {
//     if !instance.fmod_channel {
//         return;
//     }

//     volume_scale := get_volume_scale(instance);
//     FMOD_Channel_SetVolume(instance.fmod_channel, volume * volume_scale);
// }

// // get_raw_volume :: (instance: SoundInstance) -> float {
// //     if !instance.fmod_channel {
// //         return 0;
// //     }

// //     volume: float;
// //     FMOD_Channel_GetVolume(instance.fmod_channel, *volume);

// //     denom := get_default_volume(instance) * get_volume(instance);
// //     if denom == 0 {
// //         return 0;
// //     }

// //     return volume / denom;
// // }

// // set_raw_volume :: (instance: SoundInstance, volume: float) {
// //     if !instance.fmod_channel {
// //         return;
// //     }

// //     if volume * get_default_volume(instance) * get_volume(instance) > 1 {
// //         print("volume % | % % %\n", volume * get_default_volume(instance) * get_volume(instance), volume, get_default_volume(instance), get_volume(instance));
// //     }
// //     FMOD_Channel_SetVolume(instance.fmod_channel, volume * get_default_volume(instance) * get_volume(instance));
// // }

// get_raw_volume :: (instance: SoundInstance) -> float {
//     if !instance.fmod_channel {
//         return 0;
//     }

//     volume: float;
//     FMOD_Channel_GetVolume(instance.fmod_channel, *volume);

//     return volume;
// }

// get_volume_scale :: (instance: SoundInstance) -> float {
//     if !instance.fmod_channel {
//         return 0;
//     }

//     volume_scale: float64;
//     FMOD_Channel_GetUserData(instance.fmod_channel, cast(**void) *volume_scale);

//     return cast(float) volume_scale;
// }

// set_volume_scale_internal :: (instance: SoundInstance, volume: float) {
//     if !instance.fmod_channel {
//         return;
//     }

//     fmod_sound: *FMOD_SOUND;
//     FMOD_Channel_GetCurrentSound(instance.fmod_channel, *fmod_sound);

//     user_data: *Sound;
//     FMOD_Sound_GetUserData(fmod_sound, cast(*void) *user_data);

//     sound_volume := user_data.default_volume;

//     volume64 := cast(float64) (volume * sound_volume);
//     FMOD_Channel_SetUserData(instance.fmod_channel, (cast(**void) *volume64).*);
// }

// get_muted :: (instance: SoundInstance) -> bool {
//     if !instance.fmod_channel {
//         return false;
//     }

//     muted: s32;
//     FMOD_Channel_GetMute(instance.fmod_channel, *muted);

//     return !!muted;
// }

// set_muted :: (instance: SoundInstance, muted: bool) {
//     if !instance.fmod_channel {
//         return;
//     }

//     FMOD_Channel_SetMute(instance.fmod_channel, ifx muted then cast(s32) 1 else cast(s32) 0);
// }

// get_type :: (instance: SoundInstance) -> SoundType {
//     if !instance.fmod_channel {
//         return .Invalid;
//     }

//     mode: FMOD_MODE;
//     FMOD_Channel_GetMode(instance.fmod_channel, *mode);

//     if mode & FMOD_3D {
//         return .Sound3;
//     }

//     return .Sound2;
// }

// get_position :: (instance: SoundInstance) -> Vector3 {
//     if !instance.fmod_channel {
//         return .{};
//     }

//     position: Vector3;
//     velocity: Vector3;
//     FMOD_Channel_Get3DAttributes(instance.fmod_channel, *position, *velocity);

//     return position;
// }

// set_pan :: (instance: SoundInstance, pan: float) {
//     if !instance.fmod_channel {
//         return;
//     }

//     FMOD_Channel_SetPan(instance.fmod_channel, pan);
// }

// get_directional_strength :: (instance: SoundInstance) -> float {
//     if !instance.fmod_channel {
//         return 0;
//     }

//     strength: float;
//     FMOD_Channel_Get3DLevel(instance.fmod_channel, *strength);
//     return strength;
// }

// set_directional_strength :: (instance: SoundInstance, strength: float) {
//     if !instance.fmod_channel {
//         return;
//     }

//     FMOD_Channel_Set3DLevel(instance.fmod_channel, strength);
// }

// get_spread :: (instance: SoundInstance) -> float {
//     if !instance.fmod_channel {
//         return 0;
//     }

//     angle: float;
//     FMOD_Channel_Get3DSpread(instance.fmod_channel, *angle);
//     return angle;
// }

// set_spread :: (instance: SoundInstance, angle: float) {
//     if !instance.fmod_channel {
//         return;
//     }

//     FMOD_Channel_Set3DSpread(instance.fmod_channel, angle);
// }

// set_custom_rolloff :: (instance: SoundInstance, rolloff: [] Vector3) {
//     if !instance.fmod_channel {
//         return;
//     }

//     FMOD_Channel_Set3DCustomRolloff(instance.fmod_channel, rolloff.data, cast(s32) rolloff.count);
// }

// is_fading_out :: (instance: SoundInstance) -> bool {
//     if !instance.fmod_channel {
//         return false;
//     }

//     numpoints: u32;
//     FMOD_Channel_GetFadePoints(instance.fmod_channel, *numpoints, null, null);

//     if numpoints == 0 {
//         return false;
//     }

//     points := NewArray(numpoints, u64, allocator = temp);
//     volumes := NewArray(numpoints, float, allocator = temp);
//     FMOD_Channel_GetFadePoints(instance.fmod_channel, *numpoints, points.data, volumes.data);

//     dspclock: u64;
//     FMOD_Channel_GetDSPClock(instance.fmod_channel, *dspclock, null);

//     for i: 0..numpoints - 1 {
//         if dspclock < points[i] && volumes[i] == 0 {
//             return true;
//         }
//     }

//     return false;
// }

// is_done_fading_out :: (instance: SoundInstance) -> bool {
//     numpoints: u32;
//     FMOD_Channel_GetFadePoints(instance.fmod_channel, *numpoints, null, null);

//     points := NewArray(numpoints, u64, allocator = temp);
//     volumes := NewArray(numpoints, float, allocator = temp);
//     FMOD_Channel_GetFadePoints(instance.fmod_channel, *numpoints, points.data, volumes.data);

//     dspclock: u64;
//     FMOD_Channel_GetDSPClock(instance.fmod_channel, *dspclock, null);

//     for i: 0..numpoints - 1 {
//         if dspclock >= points[i] && volumes[i] == 0 {
//             return true;
//         }
//     }

//     return false;
// }

// fade_out :: (instance: SoundInstance, duration: float) {
//     if !instance.fmod_channel {
//         return;
//     }

//     sample_rate := koda_audio_get_sample_rate();

//     dspclock: u64;
//     FMOD_Channel_GetDSPClock(instance.fmod_channel, null, *dspclock);

//     FMOD_Channel_AddFadePoint(instance.fmod_channel, dspclock, 1.0);
//     FMOD_Channel_AddFadePoint(instance.fmod_channel, dspclock + cast(u64) (duration / 1000.0 * sample_rate), 0.0);
// }

// is_fading_in :: (instance: SoundInstance) -> bool {
//     if !instance.fmod_channel {
//         return false;
//     }

//     numpoints: u32;
//     FMOD_Channel_GetFadePoints(instance.fmod_channel, *numpoints, null, null);

//     if numpoints == 0 {
//         return false;
//     }

//     points := NewArray(numpoints, u64, allocator = temp);
//     volumes := NewArray(numpoints, float, allocator = temp);
//     FMOD_Channel_GetFadePoints(instance.fmod_channel, *numpoints, points.data, volumes.data);

//     dspclock: u64;
//     FMOD_Channel_GetDSPClock(instance.fmod_channel, *dspclock, null);

//     for i: 0..numpoints - 1 {
//         if dspclock < points[i] && volumes[i] == 1 {
//             return true;
//         }
//     }

//     return false;
// }

// is_done_fading_in :: (instance: SoundInstance) -> bool {
//     numpoints: u32;
//     FMOD_Channel_GetFadePoints(instance.fmod_channel, *numpoints, null, null);

//     points := NewArray(numpoints, u64, allocator = temp);
//     volumes := NewArray(numpoints, float, allocator = temp);
//     FMOD_Channel_GetFadePoints(instance.fmod_channel, *numpoints, points.data, volumes.data);

//     dspclock: u64;
//     FMOD_Channel_GetDSPClock(instance.fmod_channel, *dspclock, null);

//     for i: 0..numpoints - 1 {
//         if dspclock >= points[i] && volumes[i] == 1 {
//             return true;
//         }
//     }

//     return false;
// }

// fade_in :: (instance: SoundInstance, duration: float, delay: float = 0) {
//     if !instance.fmod_channel {
//         return;
//     }

//     sample_rate := koda_audio_get_sample_rate();

//     dspclock: u64;
//     FMOD_Channel_GetDSPClock(instance.fmod_channel, null, *dspclock);

//     delay_pcm := cast(u64) (delay / 1000.0 * sample_rate);

//     FMOD_Channel_AddFadePoint(instance.fmod_channel, dspclock, 0);
//     FMOD_Channel_AddFadePoint(instance.fmod_channel, dspclock + delay_pcm, 0);
//     FMOD_Channel_AddFadePoint(instance.fmod_channel, dspclock + delay_pcm + cast(u64) (duration / 1000.0 * sample_rate), 1.0);
// }

// // get_default_volume :: (instance: SoundInstance) -> float {
// //     if !instance.fmod_channel {
// //         return 0;
// //     }

// //     fmod_sound: *FMOD_SOUND;
// //     FMOD_Channel_GetCurrentSound(instance.fmod_channel, *fmod_sound);

// //     user_data: *Sound;
// //     FMOD_Sound_GetUserData(fmod_sound, cast(*void) *user_data);

// //     return user_data.default_volume;
// // }

// // in milliseconds
// get_duration :: (instance: SoundInstance) -> float {
//     if !instance.fmod_channel {
//         return 0;
//     }

//     fmod_sound: *FMOD_SOUND;
//     FMOD_Channel_GetCurrentSound(instance.fmod_channel, *fmod_sound);

//     length: u32;
//     FMOD_Sound_GetLength(fmod_sound, *length, FMOD_TIMEUNIT_PCM);

//     sample_rate := koda_audio_get_sample_rate();

//     return length * 1000.0 / sample_rate;
// }

// get_duration_pcm :: (instance: SoundInstance) -> int {
//     if !instance.fmod_channel {
//         return 0;
//     }

//     fmod_sound: *FMOD_SOUND;
//     FMOD_Channel_GetCurrentSound(instance.fmod_channel, *fmod_sound);

//     length: u32;
//     FMOD_Sound_GetLength(fmod_sound, *length, FMOD_TIMEUNIT_PCM);

//     return length;
// }

// get_volume_ramp :: (instance: SoundInstance) -> bool {
//     if !instance.fmod_channel {
//         return false;
//     }

//     ramp: s32;
//     FMOD_Channel_GetVolumeRamp(instance.fmod_channel, *ramp);

//     return !!ramp;
// }

// set_volume_ramp :: (instance: SoundInstance, ramp: bool) {
//     if !instance.fmod_channel {
//         return;
//     }

//     FMOD_Channel_SetVolumeRamp(instance.fmod_channel, cast(s32) ramp);
// }
