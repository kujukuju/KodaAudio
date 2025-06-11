
DSP :: struct {
    dsp: *FMOD_DSP;
}

koda_audio_init :: () {
    result := FMOD_Studio_System_Create(*fmod_system, FMOD_VERSION);
    if result {
        print("FMOD create error. %\n", result);
        return;
    }

    #if LIVE_UPDATE {
        INIT_FLAGS :: FMOD_STUDIO_INIT_LIVEUPDATE;
    } else {
        INIT_FLAGS :: FMOD_STUDIO_INIT_NORMAL;
    }

    result = FMOD_Studio_System_Initialize(fmod_system, 128, INIT_FLAGS, FMOD_INIT_NORMAL | FMOD_INIT_3D_RIGHTHANDED, null);

    if result {
        print("FMOD init error. %\n", result);
        return;
    }

    result = FMOD_Studio_System_GetCoreSystem(fmod_system, *fmod_core_system);
    assert(!result, "Could not get core system.\n");

    no_temporary_storage.overflow_allocator = no_temporary_allocator;
    no_temporary_context.temporary_storage = *no_temporary_storage;

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

koda_audio_load_sounds :: () {
    bank_count: s32;
    error := FMOD_Studio_System_GetBankCount(fmod_system, *bank_count);
    assert(!error, "Could not load banks.\n");

    banks := NewArray(bank_count, *FMOD_STUDIO_BANK,, temp);
    banks_loaded_count: s32;

    error = FMOD_Studio_System_GetBankList(fmod_system, banks.data, bank_count, *banks_loaded_count);
    banks.count = banks_loaded_count;

    event_count: s32;
    for bank: banks {
        current_event_count: s32;
        error = FMOD_Studio_Bank_GetEventCount(bank, *current_event_count);
        assert(!error, "Could not load bank events.\n");

        event_count += current_event_count;
    }

    print("Loaded % events.\n", event_count);
    if event_count == 0 return;

    events := NewArray(event_count, *FMOD_STUDIO_EVENTDESCRIPTION,, temp);
    events.count = 0;

    for bank: banks {
        event_offset := cast(s32) events.count;
        remaining_events := event_count - event_offset;

        loaded_event_count: s32;
        error = FMOD_Studio_Bank_GetEventList(bank, events.data + event_offset, remaining_events, *loaded_event_count);
        assert(!error, "Could not load bank events.\n");

        events.count += loaded_event_count;
    }

    for event: events {
        name: FixedString(128);

        name_count: s32;
        FMOD_Studio_EventDescription_GetPath(event, name.buffer.data, 128, *name_count);
        assert(name_count < 128, "Loaded a sound file that had more than 128 path characters. %\n", to_string(*name));

        sound := load_sound(to_string(*name));
        assert(!!sound, "Could not load sound file. %\n", to_string(*name));

        table_set(*loaded_sounds, name, sound);
    }
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
    if !fmod_system {
        return;
    }

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

koda_audio_set_volume :: (volume: float) {
    if !fmod_system {
        return;
    }

    master_bus: *FMOD_STUDIO_BUS;
    error := FMOD_Studio_System_GetBus(fmod_system, "bus:/", *master_bus);
    assert(!error);

    error = FMOD_Studio_Bus_SetVolume(master_bus, volume);
    assert(!error);
}

// BanksIterator :: struct {
//     system: *FMOD_STUDIO_SYSTEM;
// }

// koda_audio_get_banks :: () -> BanksIterator {
//     return BanksIterator.{fmod_system};
// }

// for_expansion :: (iterator: BanksIterator, body: Code, flags: For_Flags) #expand {
//     #assert(!(flags & .REVERSE));
//     #assert !(flags & .POINTER) "Banks iterator is always a pointer.\n";

//     count: s32;
//     error := FMOD_Studio_System_GetBankCount(fmod_system, *count);
//     assert(!error);

//     // TODO allocations
//     banks := NewArray(count, *FMOD_STUDIO_BANK);
//     defer array_free(banks);

//     bank_count: s32;
//     error = FMOD_Studio_System_GetBankList(iterator.system, banks.data, cast(s32) banks.count, *bank_count);
//     assert(!error);

//     for i: 0..bank_count - 1 {
//         `it := banks[i];
//         `it_index := i;

//         #insert body;
//     }
// }

koda_audio_get_banks :: () -> [] *FMOD_STUDIO_BANK {
    count: s32;
    error := FMOD_Studio_System_GetBankCount(fmod_system, *count);
    assert(!error);

    banks := NewArray(count, *FMOD_STUDIO_BANK,, temp);

    bank_count: s32;
    error = FMOD_Studio_System_GetBankList(fmod_system, banks.data, cast(s32) banks.count, *bank_count);
    assert(!error);
    banks.count = bank_count;

    return banks;
}

// EventDescriptionsIterator :: struct {
//     bank: *FMOD_STUDIO_BANK;
// }

// koda_audio_get_event_descriptions :: (bank: *FMOD_STUDIO_BANK) -> EventDescriptionsIterator {
//     return EventDescriptionsIterator.{bank};
// }

// for_expansion :: (iterator: EventDescriptionsIterator, body: Code, flags: For_Flags) #expand {
//     #assert(!(flags & .REVERSE));
//     #assert !(flags & .POINTER) "Event descriptions iterator is always a pointer.\n";

//     count: s32;
//     error := FMOD_Studio_Bank_GetEventCount(iterator.bank, *count);
//     assert(!error);

//     // TODO allocations
//     events := NewArray(count, *FMOD_STUDIO_EVENTDESCRIPTION);
//     defer array_free(events);

//     event_count: s32;
//     error = FMOD_Studio_Bank_GetEventList(iterator.bank, events.data, cast(s32) events.count, *event_count);
//     assert(!error);

//     for i: 0..event_count - 1 {
//         `it := events[i];
//         `it_index := i;

//         #insert body;
//     }
// }

// cached_event_descriptions: [..] *FMOD_STUDIO_EVENTDESCRIPTION;

koda_audio_get_event_descriptions :: (banks: [] *FMOD_STUDIO_BANK) -> [] *FMOD_STUDIO_EVENTDESCRIPTION {
    total_count: s32;
    for bank: banks {
        count: s32;
        error := FMOD_Studio_Bank_GetEventCount(bank, *count);
        assert(!error, "Cannot get event count. %\n", error);

        total_count += count;
    }

    // // TODO just iterate.....
    // array_free(cached_event_descriptions);
    // empty: [..] *FMOD_STUDIO_EVENTDESCRIPTION;
    // cached_event_descriptions = empty;

    // cached_event_descriptions.count = 0;
    // array_resize(*cached_event_descriptions, total_count);

    // events: [] *FMOD_STUDIO_EVENTDESCRIPTION = cached_event_descriptions;
    // events.count = 0;

    if total_count == 0 {
        return .[];
    }

    events := NewArray(total_count, *FMOD_STUDIO_EVENTDESCRIPTION,, temp);
    events.count = 0;

    for bank: banks {
        real_count: s32;
        error := FMOD_Studio_Bank_GetEventList(bank, events.data + events.count, total_count - cast(s32) events.count, *real_count);
        assert(!error, "Cannot get event list. %\n", error);
        events.count += real_count;
    }

    // for event_description: events {
    //     path: FixedString(512);

    //     used_count: s32;
    //     error := FMOD_Studio_EventDescription_GetPath(event_description, path.buffer.data, cast(s32) path.buffer.count, *used_count);
    //     assert(!error, "Could not get path.\n");
    //     print("Event description: %\n", to_string(*path));
    // }

    return events;
}

// EventInstancesIterator :: struct {
//     event: *FMOD_STUDIO_EVENTDESCRIPTION;
// }

// koda_audio_get_event_instances :: (event: *FMOD_STUDIO_EVENTDESCRIPTION) -> EventInstancesIterator {
//     return EventInstancesIterator.{event};
// }

// for_expansion :: (iterator: EventInstancesIterator, body: Code, flags: For_Flags) #expand {
//     #assert(!(flags & .REVERSE));
//     #assert !(flags & .POINTER) "Event instances iterator is always a pointer.\n";

//     count: s32;
//     error := FMOD_Studio_EventDescription_GetInstanceCount(iterator.event, *count);
//     assert(!error);

//     // TODO allocations
//     instances := NewArray(count, *FMOD_STUDIO_EVENTINSTANCE);
//     defer array_free(instances);

//     instance_count: s32;
//     error = FMOD_Studio_EventDescription_GetInstanceList(iterator.event, instances.data, cast(s32) instances.count, *instance_count);
//     empty: #Context;
//     push_context empty {
//         print("%\n", iterator.event);
//         assert(!error, "%", error);
//     }

//     for i: 0..instance_count - 1 {
//         `it := instances[i];
//         `it_index := i;

//         #insert body;
//     }
// }

// cached_event_instances: [..] *FMOD_STUDIO_EVENTINSTANCE;

koda_audio_get_event_instances :: (events: [] *FMOD_STUDIO_EVENTDESCRIPTION) -> [] *FMOD_STUDIO_EVENTINSTANCE {
    total_count: s32;
    for event: events {
        count: s32;
        error := FMOD_Studio_EventDescription_GetInstanceCount(event, *count);
        assert(!error, "Cannot get instance count. %\n", error);

        total_count += count;
    }

    // // TODO just iterate.....
    // array_free(cached_event_instances);
    // empty: [..] *FMOD_STUDIO_EVENTINSTANCE;
    // cached_event_instances = empty;

    // cached_event_instances.count = 0;
    // array_resize(*cached_event_instances, total_count);

    // instances: [] *FMOD_STUDIO_EVENTINSTANCE = cached_event_instances;
    // instances.count = 0;

    if total_count == 0 {
        return .[];
    }

    instances := NewArray(total_count, *FMOD_STUDIO_EVENTINSTANCE,, temp);
    instances.count = 0;

    for event: events {
        real_count: s32;
        error := FMOD_Studio_EventDescription_GetInstanceList(event, instances.data + instances.count, total_count - cast(s32) instances.count, *real_count);
        assert(!error, "Cannot get instance list. %\n", error);

        path: FixedString(512);
        used_count: s32;
        error = FMOD_Studio_EventDescription_GetPath(event, path.buffer.data, cast(s32) path.buffer.count, *used_count);
        assert(!error, "Could not get path.\n");

        instances.count += real_count;
    }

    return instances;
}

koda_audio_stop_all_event_instances :: () {
    master_bus: *FMOD_STUDIO_BUS;
    error := FMOD_Studio_System_GetBus(fmod_system, "bus:/", *master_bus);
    assert(!error, "Get bus error %.\n", error);

    error = FMOD_Studio_Bus_StopAllEvents(master_bus, .ALLOWFADEOUT);
    assert(!error, "Stop all events error %.\n", error);
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

koda_audio_set_callback_userdata :: (userdata: *void) {
    FMOD_Studio_System_SetUserData(fmod_system, userdata);
}

koda_audio_get_callback_userdata :: () -> *void {
    userdata: *void;
    FMOD_Studio_System_GetUserData(fmod_system, *userdata);
    return userdata;
}

koda_audio_set_preupdate_callback :: (callback: #type (userdata: *void)) {
    preupdate_callback = callback;
    callback_type := ifx preupdate_callback then FMOD_STUDIO_SYSTEM_CALLBACK_PREUPDATE else 0;
    callback_type |= ifx postupdate_callback then FMOD_STUDIO_SYSTEM_CALLBACK_POSTUPDATE else 0;
    FMOD_Studio_System_SetCallback(fmod_system, fmod_callback, cast(u32) callback_type);
}

koda_audio_set_postupdate_callback :: (callback: #type (userdata: *void)) {
    postupdate_callback = callback;
    callback_type := ifx preupdate_callback then FMOD_STUDIO_SYSTEM_CALLBACK_PREUPDATE else 0;
    callback_type |= ifx postupdate_callback then FMOD_STUDIO_SYSTEM_CALLBACK_POSTUPDATE else 0;
    FMOD_Studio_System_SetCallback(fmod_system, fmod_callback, cast(u32) callback_type);
}

koda_audio_set_event_start_callback :: (callback: #type (instance: SoundInstance)) {
    event_start_callback = callback;
}

// SoundInstanceIterator :: struct {

// }

// koda_audio_get_active_sounds :: () -> SoundInstanceIterator {
//     return SoundInstanceIterator.{};
// }

// for_expansion :: (iterator: SoundInstanceIterator, body: Code, flags: For_Flags) #expand {
//     #assert(!(flags & .REVERSE));
//     #assert !(flags & .POINTER) "Sound instance iterator cannot be a pointer.\n";

//     index := 0;
//     for bank: koda_audio_get_banks() {
//         for event: koda_audio_get_event_descriptions(bank) {
//             for instance: koda_audio_get_event_instances(event) {
//                 defer index += 1;

//                 `it := SoundInstance.{instance};
//                 `it_index := index;

//                 #insert body;
//             }
//         }
//     }
// }

// cached_sound_instances: [..] SoundInstance;

koda_audio_get_active_sounds :: () -> [] SoundInstance {
    event_instances := koda_audio_get_event_instances(koda_audio_get_event_descriptions(koda_audio_get_banks()));

    // TODO just iterate.....
    // array_free(cached_sound_instances);
    // empty: [..] SoundInstance;
    // cached_sound_instances = empty;

    // cached_sound_instances.count = 0;
    // array_resize(*cached_sound_instances, event_instances.count);

    instances := NewArray(event_instances.count, SoundInstance,, temp);

    for event_instance, index: event_instances {
        instances[index] = SoundInstance.{event_instance};
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

koda_audio_get_master_channel_group :: () -> *FMOD_CHANNELGROUP {
    core_system: *FMOD_SYSTEM;
    error := FMOD_Studio_System_GetCoreSystem(fmod_system, *core_system);
    assert(!error);

    channel_group: *FMOD_CHANNELGROUP;
    error = FMOD_System_GetMasterChannelGroup(core_system, *channel_group);
    assert(!error);

    return channel_group;
} @thread

DspIterator :: struct {
    channel_group: *FMOD_CHANNELGROUP;
    channel_count: s32;
}

koda_audio_get_channel_group_dsps :: (channel_group: *FMOD_CHANNELGROUP) -> DspIterator {
    channel_count: s32;
    error := FMOD_ChannelGroup_GetNumDSPs(channel_group, *channel_count);
    assert(!error);

    return DspIterator.{
        channel_group,
        channel_count,
    };
}

for_expansion :: (iterator: DspIterator, body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .REVERSE));
    #assert(!(flags & .POINTER));

    for i: 0..iterator.channel_count - 1 {
        dsp: *FMOD_DSP;

        error := FMOD_ChannelGroup_GetDSP(iterator.channel_group, i, *dsp);
        assert(!error);

        if !dsp {
            continue;
        }

        `it := dsp;
        `it_index := i;

        #insert body;
    }
}

koda_audio_create_dsp :: ($callback: (samples: [] float, channels: int) #c_call) -> DSP {
    core_system: *FMOD_SYSTEM;
    error := FMOD_Studio_System_GetCoreSystem(fmod_system, *core_system);
    assert(!error);

    description: FMOD_DSP_DESCRIPTION;
    description.version = FMOD_VERSION;
    description.numinputbuffers = 1;
    description.numoutputbuffers = 1;

    read_callback :: (dsp_state: *FMOD_DSP_STATE, inbuffer: *float, outbuffer: *float, length: u32, inchannels: s32, outchannels: *s32) -> FMOD_RESULT #c_call {
        memcpy(outbuffer, inbuffer, cast(s64) length * inchannels * size_of(float));
        view: [] float;
        view.data = inbuffer;
        view.count = cast(s64) length * inchannels;

        callback(view, cast(int) inchannels);

        return .FMOD_OK;
    } @thread_unlocked

    description.read = read_callback;

    dsp: *FMOD_DSP;
    error = FMOD_System_CreateDSP(core_system, *description, *dsp);

    return DSP.{dsp};
}

koda_audio_attach_dsp :: (dsp: DSP) {
    channel_group := koda_audio_get_master_channel_group();

    error := FMOD_ChannelGroup_AddDSP(channel_group, 0, dsp.dsp);
    assert(!error, "Failed to attach DSP.\n");
    assert(!error, "Failed to attach DSP.\n");
}

koda_audio_detach_dsp :: (dsp: DSP) {
    channel_group := koda_audio_get_master_channel_group();

    error := FMOD_ChannelGroup_RemoveDSP(channel_group, dsp.dsp);
    assert(!error, "Failed to remove DSP.\n");
}

koda_audio_is_dsp_attached :: (dsp: DSP) -> bool {
    channel_group := koda_audio_get_master_channel_group();

    dsp_count: s32;
    error := FMOD_ChannelGroup_GetNumDSPs(channel_group, *dsp_count);
    assert(!error);

    for i: 0..dsp_count - 1 {
        current: *FMOD_DSP;
        error = FMOD_ChannelGroup_GetDSP(channel_group, i, *current);
        assert(!error);

        if current == dsp.dsp {
            return true;
        }
    }

    return false;
}

get_guid :: (guid: *u8) -> FMOD_GUID {
    value: FMOD_GUID;
    FMOD_Studio_ParseID(guid, *value);

    return value;
}

fmod_bank: *FMOD_STUDIO_BANK;
fmod_system: *FMOD_STUDIO_SYSTEM;
fmod_core_system: *FMOD_SYSTEM;

#scope_module

fmod_callback_context: #Context;

fmod_callback :: (system: *FMOD_STUDIO_SYSTEM, type: FMOD_STUDIO_SYSTEM_CALLBACK_TYPE, commanddata: *void, userdata: *void) -> FMOD_RESULT #c_call {
    push_context fmod_callback_context {
        if preupdate_callback && (type & FMOD_STUDIO_SYSTEM_CALLBACK_PREUPDATE) {
            preupdate_callback(userdata);
        }

        if postupdate_callback && (type & FMOD_STUDIO_SYSTEM_CALLBACK_POSTUPDATE) {
            postupdate_callback(userdata);
        }

        reset_temporary_storage();
    }

    return .FMOD_OK;
} @thread_unlocked

no_temporary_context: #Context;
no_temporary_storage: Temporary_Storage;
no_temporary_callback :: (mode: Allocator_Mode, size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
    print("Can not use the temporary allocator from this thread.\n");
    print_stack_trace();
    assert(false, "Can not use the temporary allocator from this thread.\n");
    return null;
}
no_temporary_allocator := Allocator.{no_temporary_callback, null};

loaded_sounds: Table(FixedString(128), *Sound, given_hash_function = fixed_string_hash, given_compare_function = fixed_string_equals);

custom_rolloff: [..] Vector2;
custom_rolloff_distance: float;

global_directional_strength: float = 1.0;

preupdate_callback: #type (userdata: *void);
postupdate_callback: #type (userdata: *void);
event_start_callback: #type (instance: SoundInstance);
