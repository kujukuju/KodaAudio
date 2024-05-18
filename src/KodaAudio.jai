
koda_audio_init :: () {
    result := FMOD_Studio_System_Create(*fmod_system, FMOD_VERSION);
    if result {
        print("FMOD create error. %\n", result);
        return;
    }

    result = FMOD_Studio_System_Initialize(fmod_system, 128, FMOD_STUDIO_INIT_NORMAL, FMOD_INIT_NORMAL | FMOD_INIT_3D_RIGHTHANDED, null);

    if result {
        print("FMOD init error. %\n", result);
        return;
    }

    // FMOD_System_SetDSPBufferSize(fmod_system, 4096, 2);
}

koda_audio_load_bank :: (path: string) {
    assert(path.count < 512, "Your path is too long!");
    // assert(!fmod_bank, "You cannot already have loaded a bank.");

    fixed: [512] u8;
    memcpy(fixed.data, path.data, path.count);

    error := FMOD_Studio_System_LoadBankFile(fmod_system, fixed.data, FMOD_STUDIO_LOAD_BANK_NORMAL, *fmod_bank);
    assert(!error);

    state: FMOD_STUDIO_LOADING_STATE;
    FMOD_Studio_Bank_GetLoadingState(fmod_bank, *state);
    assert(state == .LOADED);

    FMOD_Studio_Bank_LoadSampleData(fmod_bank);

    FMOD_Studio_Bank_GetLoadingState(fmod_bank, *state);
    assert(state == .LOADED);
}

koda_audio_destroy :: () {
    // FMOD_Studio_System_Close(fmod_system);
    error := FMOD_Studio_System_Release(fmod_system);
    assert(!error);
    fmod_system = null;
}

koda_audio_update :: () {
    result := FMOD_Studio_System_Update(fmod_system);
    if result {
        print("FMOD update error. %\n", result);
    }
}

koda_audio_update_camera :: (camera: Camera3, velocity: Vector3 = .{}) {
    forward := get_forward_vector(camera);
    up := get_up_vector(camera);

    koda_audio_update_camera(camera.position, forward, up, velocity);
}

koda_audio_update_camera :: (position: Vector3, forward: Vector3, up: Vector3, velocity: Vector3 = .{}) {
    attributes: FMOD_3D_ATTRIBUTES;
    attributes.position = position;
    attributes.velocity = velocity;
    attributes.forward = forward;
    attributes.up = up;

    error := FMOD_Studio_System_SetListenerAttributes(fmod_system, 0, *attributes, null);
    assert(!error);
}

koda_audio_get_muted :: () -> bool {
    master_bus: *FMOD_STUDIO_BUS;
    error := FMOD_Studio_System_GetBus(fmod_system, "bus:/", *master_bus);
    assert(!error);

    muted: FMOD_BOOL;
    error = FMOD_Studio_Bus_GetMuted(master_bus, *muted);
    assert(!error);
    
    return !!muted;
}

koda_audio_set_muted :: (muted: bool) {
    master_bus: *FMOD_STUDIO_BUS;
    error := FMOD_Studio_System_GetBus(fmod_system, "bus:/", *master_bus);
    assert(!error);

    if muted {
        error = FMOD_Studio_Bus_SetMute(master_bus, 1);
        assert(!error);
    } else {
        error = FMOD_Studio_Bus_SetMute(master_bus, 0);
        assert(!error);
    }
}

koda_audio_get_banks :: () -> [] *FMOD_STUDIO_BANK {
    count: s32;
    error := FMOD_Studio_System_GetBankCount(fmod_system, *count);
    assert(!error);

    real_count: s32;
    banks := NewArray(count, *FMOD_STUDIO_BANK,, allocator = temp);
    error = FMOD_Studio_System_GetBankList(fmod_system, banks.data, count, *real_count);
    assert(!error);

    banks.count = real_count;
    return banks;
}

koda_audio_get_event_descriptions :: (banks: [] *FMOD_STUDIO_BANK) -> [] *FMOD_STUDIO_EVENTDESCRIPTION {
    total_count: s32;
    for bank: banks {
        count: s32;
        error := FMOD_Studio_Bank_GetEventCount(bank, *count);
        assert(!error);

        total_count += count;
    }

    events := NewArray(total_count, *FMOD_STUDIO_EVENTDESCRIPTION,, allocator = temp);
    events.count = 0;

    if total_count == 0 {
        return .[];
    }

    for bank: banks {
        real_count: s32;
        result := FMOD_Studio_Bank_GetEventList(bank, events.data + events.count, total_count - cast(s32) events.count, *real_count);
        events.count += real_count;

        if result {
            print("FMOD get event error. %\n", result);
            assert(false);
        }
    }

    return events;
}

koda_audio_get_event_instances :: (events: [] *FMOD_STUDIO_EVENTDESCRIPTION) -> [] *FMOD_STUDIO_EVENTINSTANCE {
    total_count: s32;
    for event: events {
        count: s32;
        error := FMOD_Studio_EventDescription_GetInstanceCount(event, *count);
        assert(!error);

        total_count += count;
    }

    instances := NewArray(total_count, *FMOD_STUDIO_EVENTINSTANCE,, allocator = temp);
    instances.count = 0;

    if total_count == 0 {
        return .[];
    }

    for event: events {
        real_count: s32;
        error := FMOD_Studio_EventDescription_GetInstanceList(event, instances.data + instances.count, total_count - cast(s32) instances.count, *real_count);
        if error {
            print("FMOD get instance list error. %\n", error);
            assert(false);
        }

        instances.count += real_count;
    }

    return instances;
}

// koda_audio_get_active_sound_count :: () -> int {
//     master_bus: *FMOD_STUDIO_BUS;
//     FMOD_Studio_System_GetBus(fmod_system, "bus:/", *master_bus);

//     channel_group: *FMOD_CHANNELGROUP;
//     FMOD_Studio_Bus_GetChannelGroup(master_bus, *channel_group);

//     channel_count: s32;
//     FMOD_ChannelGroup_GetNumChannels(channel_group, *channel_count);

//     return channel_count;
// }

// koda_audio_get_active_sound :: (index: int) -> SoundInstance {
//     master_bus: *FMOD_STUDIO_BUS;
//     FMOD_Studio_System_GetBus(fmod_system, "bus:/", *master_bus);

//     channel_group: *FMOD_CHANNELGROUP;
//     FMOD_Studio_Bus_GetChannelGroup(master_bus, *channel_group);

//     instance: SoundInstance;
//     FMOD_ChannelGroup_GetChannel(channel_group, cast(s32) index, *instance.fmod_channel);

//     return instance;
// }

koda_audio_set_preupdate_callback :: (callback: #type ()) {
    preupdate_callback = callback;
    callback_type := ifx preupdate_callback then FMOD_STUDIO_SYSTEM_CALLBACK_PREUPDATE else 0;
    callback_type |= ifx postupdate_callback then FMOD_STUDIO_SYSTEM_CALLBACK_POSTUPDATE else 0;
    FMOD_Studio_System_SetCallback(fmod_system, fmod_callback, cast(u32) callback_type);
}

koda_audio_set_postupdate_callback :: (callback: #type ()) {
    postupdate_callback = callback;
    callback_type := ifx preupdate_callback then FMOD_STUDIO_SYSTEM_CALLBACK_PREUPDATE else 0;
    callback_type |= ifx postupdate_callback then FMOD_STUDIO_SYSTEM_CALLBACK_POSTUPDATE else 0;
    FMOD_Studio_System_SetCallback(fmod_system, fmod_callback, cast(u32) callback_type);
}

koda_audio_set_event_start_callback :: (callback: #type (instance: SoundInstance)) {
    event_start_callback = callback;
}

koda_audio_get_active_sounds :: () -> [] SoundInstance {
    event_instances := koda_audio_get_event_instances(koda_audio_get_event_descriptions(koda_audio_get_banks()));
    instances := NewArray(event_instances.count, SoundInstance,, allocator = temp);
    for event_instance, index: event_instances {
        instances[index].event_instance = event_instance;
    }

    return instances;
}

koda_audio_get_directional_strength :: () -> float {
    return global_directional_strength;
}

koda_audio_set_directional_strength :: (strength: float) {
    global_directional_strength = strength;
}

koda_audio_set_custom_rolloff :: (points: [] Vector2) {
    array_resize(*custom_rolloff, points.count);

    maximum_rolloff_distance := points[points.count - 1].x;
    if custom_rolloff_distance == 0 {
        custom_rolloff_distance = maximum_rolloff_distance;
    }

    for point, index: points {
        custom_rolloff[index] = Vector2.{point.x / maximum_rolloff_distance, point.y};
    }

    print("final custom rolloff %\n", custom_rolloff);
}

koda_audio_set_custom_rolloff_distance :: (distance: float) {
    custom_rolloff_distance = distance;
}

koda_audio_get_sample_rate :: () -> int {
    core_system: *FMOD_SYSTEM;
    error := FMOD_Studio_System_GetCoreSystem(fmod_system, *core_system);
    assert(!error);

    sample_rate: s32;
    error = FMOD_System_GetSoftwareFormat(core_system, *sample_rate, null, null);
    assert(!error);

    return sample_rate;
} @thread

koda_audio_get_buffer_size :: () -> int {
    core_system: *FMOD_SYSTEM;
    error := FMOD_Studio_System_GetCoreSystem(fmod_system, *core_system);
    assert(!error);

    bufferlength: u32;
    numbuffers: s32;
    error = FMOD_System_GetDSPBufferSize(core_system, *bufferlength, *numbuffers);
    assert(!error);

    return cast(int) bufferlength * numbuffers;
} @thread

koda_audio_get_estimated_delay :: () -> int {
    buffer_size := koda_audio_get_buffer_size();
    sample_rate := koda_audio_get_sample_rate();

    return buffer_size * 1000 / sample_rate;
} @thread

get_guid :: (guid: *u8) -> FMOD_GUID {
    value: FMOD_GUID;
    FMOD_Studio_ParseID(guid, *value);

    return value;
}

fmod_bank: *FMOD_STUDIO_BANK;
fmod_system: *FMOD_STUDIO_SYSTEM;

#scope_module

get_custom_rolloff_for_distance :: (distance: float) -> [] Vector3 {
    custom_rolloff_scaled: [..] Vector3;
    custom_rolloff_scaled.allocator = temp;
    array_resize(*custom_rolloff_scaled, custom_rolloff.count);
    for i: 0..custom_rolloff.count - 1 {
        custom_rolloff_scaled[i] = Vector3.{custom_rolloff[i].x * distance, custom_rolloff[i].y, 0};
    }

    return custom_rolloff_scaled;
}

fmod_callback :: (system: *FMOD_STUDIO_SYSTEM, type: FMOD_STUDIO_SYSTEM_CALLBACK_TYPE, commanddata: *void, userdata: *void) -> FMOD_RESULT #c_call {
    empty: Context;
    push_context empty {
        if preupdate_callback && (type & FMOD_STUDIO_SYSTEM_CALLBACK_PREUPDATE) {
            preupdate_callback();
        }

        if postupdate_callback && (type & FMOD_STUDIO_SYSTEM_CALLBACK_POSTUPDATE) {
            postupdate_callback();
        }
    }

    return .FMOD_OK;
} @thread_unlocked

custom_rolloff: [..] Vector2;
custom_rolloff_distance: float;

global_directional_strength: float = 1.0;

preupdate_callback: #type ();
postupdate_callback: #type ();
event_start_callback: #type (instance: SoundInstance);
