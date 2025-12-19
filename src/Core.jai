
Device :: struct {
    name: FixedString(256);
    id: s32;
    guid: DeviceGUID;
}

DeviceGUID :: struct {
    data1: u32;
    data2: u16;
    data3: u16;
    data4: [8] u8;
}

#assert size_of(DeviceGUID) == size_of(FMOD_GUID) "DeviceGUID and FMOD_GUID sizes don't match.";

koda_audio_get_output_devices :: () -> [] Device {
    count: s32;
    error := FMOD_System_GetNumDrivers(fmod_system, *count);
    assert(!error, "Could not get num output drivers.\n");

    devices := NewArray(count, Device,, temp);

    for i: 0..count - 1 {
        guid: FMOD_GUID;
        systemrate: s32;
        speakermode: FMOD_SPEAKERMODE;
        speakermodechannels: s32;

        devices[i] = cast(s32) i;

        error = FMOD_System_GetDriverInfo(
            fmod_system,
            cast(s32) i,
            devices[i].name.buffer.data,
            devices[i].name.buffer.count,
            *guid,
            *systemrate,
            *speakermode,
            *speakermodechannels);
        assert(!error, "Could not get output device info.\n");

        memcpy(*devices[i].guid, *guid, size_of(type_of(guid)));
    }

    return devices;
}

koda_audio_get_input_devices :: () -> [] Device {
    count: s32;
    connected: s32;
    error := FMOD_System_GetRecordNumDrivers(fmod_system, *count, *connected);
    assert(!error, "Could not get num input drivers.\n");

    devices := NewArray(count, Device,, temp);

    for i: 0..count - 1 {
        guid: FMOD_GUID;
        systemrate: s32;
        speakermode: FMOD_SPEAKERMODE;
        speakermodechannels: s32;
        state: FMOD_DRIVER_STATE;

        devices[i] = cast(s32) i;

        error = FMOD_System_GetRecordDriverInfo(
            fmod_system,
            cast(s32) i,
            devices[i].name.buffer.data,
            devices[i].name.buffer.count,
            *guid,
            *systemrate,
            *speakermode,
            *speakermodechannels,
            *state);
        assert(!error, "Could not get output device info.\n");

        memcpy(*devices[i].guid, *guid, size_of(type_of(guid)));
    }

    return devices;
}

get_recording_driver_info :: (driver: int) -> FixedString(512), sample_rate: s32, channels: s32, speaker_mode: s32 {
    name: FixedString(512);
    sample_rate: s32;
    speaker_mode: FMOD_SPEAKERMODE;
    channels: s32;
    state: FMOD_DRIVER_STATE;

    error := FMOD_System_GetRecordDriverInfo(
        fmod_core_system,
        cast(s32) driver,
        name.buffer.data,
        cast(s32) name.buffer.count,
        null,
        *sample_rate,
        *speaker_mode,
        *channels,
        *state);
    // assert(!error, "Could not get recording driver info.\n");

    // position: u32;
    // error = FMOD_System_GetRecordPosition(
    //     fmod_core_system,
    //     cast(s32) driver,
    //     *position);
    // assert(!error, "Could not get the position of the device driver.\n");

    // print("Device position: %\n", position);

    return name, cast(s32) sample_rate, cast(s32) channels, cast(s32) speaker_mode;
}

load_core_sound :: (data: string) -> *FMOD_SOUND {
    info: FMOD_CREATESOUNDEXINFO;
    info.cbsize = size_of(FMOD_CREATESOUNDEXINFO);
    info.length = cast(u32) data.count;

    sound: *FMOD_SOUND;
    error := FMOD_System_CreateSound(fmod_core_system, data.data, FMOD_OPENMEMORY | FMOD_CREATESAMPLE | FMOD_OPENONLY, *info, *sound);
    assert(!error, "Could not create core sound. %\n", error);

    return sound;
}
