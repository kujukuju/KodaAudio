
koda_audio_init :: () {
    result := FMOD_System_Create(*fmod_system, FMOD_VERSION);
    if result {
        print("FMOD create error. %\n", result);
        return;
    }

    version: u32;
    result = FMOD_System_GetVersion(fmod_system, *version);
    if result {
        print("FMOD version error. %\n", result);
        return;
    }

    result = FMOD_System_Init(fmod_system, 256, FMOD_INIT_NORMAL | FMOD_INIT_3D_RIGHTHANDED, null);
    if result {
        print("FMOD init error. %\n", result);
        return;
    }
}

koda_audio_destroy :: () {
    FMOD_System_Close(fmod_system);
    FMOD_System_Release(fmod_system);
    fmod_system = null;
}

koda_audio_update :: () {
    result := FMOD_System_Update(fmod_system);
    if result {
        print("FMOD update error. %\n", result);
    }
}

koda_audio_update_camera :: (camera: Camera3, velocity: Vector3 = .{}) {
    forward := get_forward_vector(camera);
    up := get_up_vector(camera);

    position := camera.position;
    FMOD_System_Set3DListenerAttributes(fmod_system, 0, *position, *velocity, *forward, *up);
}

koda_audio_update_camera :: (position: Vector3, forward: Vector3, up: Vector3, velocity: Vector3 = .{}) {
    FMOD_System_Set3DListenerAttributes(fmod_system, 0, *position, *velocity, *forward, *up);
}

koda_audio_set_muted :: (muted: bool) {
    channel_group: *FMOD_CHANNELGROUP;
    FMOD_System_GetMasterChannelGroup(fmod_system, *channel_group);

    if muted {
        FMOD_ChannelGroup_SetVolume(channel_group, 0);
    } else {
        FMOD_ChannelGroup_SetVolume(channel_group, 1);
    }
}

koda_audio_get_active_sound_count :: () -> int {
    channel_group: *FMOD_CHANNELGROUP;
    FMOD_System_GetMasterChannelGroup(fmod_system, *channel_group);

    channel_count: s32;
    FMOD_ChannelGroup_GetNumChannels(channel_group, *channel_count);

    return channel_count;
}

koda_audio_get_active_sound :: (index: int) -> SoundInstance {
    channel_group: *FMOD_CHANNELGROUP;
    FMOD_System_GetMasterChannelGroup(fmod_system, *channel_group);

    instance: SoundInstance;
    FMOD_ChannelGroup_GetChannel(channel_group, cast(s32) index, *instance.fmod_channel);

    return instance;
}

koda_audio_get_active_sounds :: () -> [] SoundInstance {
    channel_group: *FMOD_CHANNELGROUP;
    FMOD_System_GetMasterChannelGroup(fmod_system, *channel_group);

    channel_count: s32;
    FMOD_ChannelGroup_GetNumChannels(channel_group, *channel_count);

    sounds := NewArray(channel_count, SoundInstance, allocator = temp);
    for i: 0..channel_count - 1 {
        FMOD_ChannelGroup_GetChannel(channel_group, i, *sounds[i].fmod_channel);
    }

    return sounds;
}

koda_audio_get_directional_strength :: () -> float {
    return global_directional_strength;
}

koda_audio_set_directional_strength :: (strength: float) {
    global_directional_strength = strength;
}

koda_audio_set_custom_rolloff :: (points: [] Vector2) {
    array_reserve(*custom_rolloff, points.count);
    array_reserve(*custom_rolloff_scaled, points.count);

    custom_rolloff.count = points.count;
    custom_rolloff_scaled.count = points.count;

    custom_rolloff_distance = points[points.count - 1].x;

    for point, index: points {
        custom_rolloff[index] = Vector3.{point.x / custom_rolloff_distance, point.y, 0.0};
        custom_rolloff_scaled[index] = Vector3.{};
    }
}

koda_audio_set_custom_rolloff_distance :: (distance: float) {
    assert(custom_rolloff.count > 0, "You can only set a custom rolloff distance once a rolloff function has been defined.");

    custom_rolloff_distance = distance;
}

koda_audio_get_sample_rate :: () -> int {
    sample_rate: s32;
    FMOD_System_GetSoftwareFormat(fmod_system, *sample_rate, null, null);

    return sample_rate;
}

fmod_system: *FMOD_SYSTEM;

#scope_module

get_custom_rolloff_for_distance :: (distance: float) -> [] Vector3 {
    for i: 0..custom_rolloff.count - 1 {
        custom_rolloff_scaled[i] = custom_rolloff[i] * distance;
    }

    return custom_rolloff_scaled;
}

custom_rolloff: [..] Vector3;
custom_rolloff_distance: float;

custom_rolloff_scaled: [..] Vector3;

global_directional_strength: float = 1.0;
