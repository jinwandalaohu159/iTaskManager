// CPU, GPU and Neural Engine energy from the CPU performance controller (AppleCLPC).
//
// On macOS 27 the power manager's "Energy Model" counters for the CPU, memory and Neural
// Engine stop updating for anyone but Apple's own tools. AppleCLPC keeps its own running
// totals; they aren't listed by IOReport, so each channel is described here by hand with the
// report ID found in that macOS release's driver.
//
// Report IDs from macmon (https://github.com/vladkens/macmon, src/clpc.rs), extracted from
// macOS 27.0 (26A428) and 27.0.1 (26A434):
//
//   MIT License — Copyright (c) 2024 vladkens
//   Permission is hereby granted, free of charge, to any person obtaining a copy of this
//   software and associated documentation files (the "Software"), to deal in the Software
//   without restriction, including without limitation the rights to use, copy, modify, merge,
//   publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
//   to whom the Software is furnished to do so, subject to the following conditions: The above
//   copyright notice and this permission notice shall be included in all copies or substantial
//   portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.

#include "CSystem.h"
#include "ioreport.h"

#include <IOKit/IOKitLib.h>
#include <mach/mach_time.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>

typedef struct {
    const char *bundle;
    uint32_t cpu, gpu, ane;
    /// Memory, where known (0 otherwise).
    uint32_t dram;
} CLPCKeys;

// Table indices are the same for every driver in macOS 27.
enum { kIndexCPU = 16, kIndexGPU = 25, kIndexANE = 24, kIndexDRAM = 26 };

static const CLPCKeys kKeys[] = {
    {"com.apple.driver.AppleT6000CLPCv3", 0x47479059, 0x4519bf1e, 0x9aaa17f8},
    {"com.apple.driver.AppleT6002CLPC", 0xb501816b, 0x9e2c3e8b, 0x14d5a574},
    {"com.apple.driver.AppleT6020CLPC", 0xe301cd75, 0x8f34cc7a, 0x7415fb0f},
    {"com.apple.driver.AppleT6022CLPC", 0x76f5fd21, 0x90624499, 0x3c097307},
    {"com.apple.driver.AppleT6030CLPC", 0xbe03a01a, 0x472d6c9c, 0xb8990c38},
    {"com.apple.driver.AppleT6031CLPC", 0xd81e0084, 0x1085f98b, 0x313a3be1},
    {"com.apple.driver.AppleT6032CLPC", 0xf4a21308, 0x85e80513, 0x63dc8e25},
    {"com.apple.driver.AppleT6041CLPC", 0x263cf1f0, 0x22e4cf59, 0x7849fb5c},
    {"com.apple.driver.AppleT6050CLPC", 0xd3ab60bb, 0x27cd4ce5, 0x8c0f1c59},
    {"com.apple.driver.AppleT6050dCLPC", 0x18b3010e, 0xedeca11a, 0x188bd883},
    {"com.apple.driver.AppleT8103CLPCv3", 0x2cdd31f2, 0x21becf42, 0x0667fb81},
    {"com.apple.driver.AppleT8112CLPC", 0xb5435137, 0x638d9d52, 0xea089c36},
    {"com.apple.driver.AppleT8122CLPC", 0x54b51c99, 0xce2dd9dc, 0x960afe2f},
    {"com.apple.driver.AppleT8132CLPC", 0x4a854d94, 0x3b3e3b79, 0x1ff4a9ec},
    {"com.apple.driver.AppleT8140CLPC", 0x9bf54436, 0xef70589c, 0x569d941b},
    // The memory record was found in the M5 driver of macOS 27.0.1 (26A434): its report
    // table lists each record's key, at the index the report uses. Record 26 matched the
    // Energy Model's DRAM counter over its batch windows (0.027 W idle, 0.205 vs 0.204 W
    // under memory load).
    {"com.apple.driver.AppleT8142CLPC", 0x43708744, 0x6a010933, 0xbc5efdf0, 0xe13633aa},
    {"com.apple.driver.AppleT8152CLPC", 0x485d4bfc, 0x11784654, 0x9380c6bb},
};

struct ITMCLPCReader {
    ITMReportStream stream;
    bool hasDRAM;
    uint64_t previousTime;
};

static bool is_macos_27(void) {
    char version[32] = {0};
    size_t size = sizeof(version);
    if (sysctlbyname("kern.osproductversion", version, &size, NULL, 0) != 0) return false;
    return strncmp(version, "27.", 3) == 0 || strcmp(version, "27") == 0;
}

static CFNumberRef number(int64_t value) {
    return CFNumberCreate(NULL, kCFNumberSInt64Type, &value);
}

/// A channel description in the shape IOReport's legend would give: a simple integer in
/// the power category, one element, counting nanojoules.
static CFDictionaryRef channel(uint64_t driver, uint64_t reportID, CFStringRef name) {
    CFNumberRef idNumber = number((int64_t)reportID);
    CFNumberRef type = number(1 | (2 << 16) | (1LL << 32));
    const void *legendValues[] = {idNumber, type, name};
    CFArrayRef legend = CFArrayCreate(NULL, legendValues, 3, &kCFTypeArrayCallBacks);

    CFNumberRef unit = number((3LL << 56) | (118LL << 32));
    const void *infoKeys[] = {CFSTR("IOReportChannelUnit")};
    const void *infoValues[] = {unit};
    CFDictionaryRef info = CFDictionaryCreate(NULL, infoKeys, infoValues, 1,
                                              &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    CFNumberRef driverNumber = number((int64_t)driver);
    const void *keys[] = {CFSTR("DriverID"), CFSTR("DriverName"), CFSTR("IOReportGroupName"),
                          CFSTR("IOReportSubGroupName"), CFSTR("IOReportChannelInfo"), CFSTR("LegendChannel")};
    const void *values[] = {driverNumber, CFSTR("AppleCLPC"), CFSTR("CLPC"), CFSTR("Energy Counters"), info, legend};
    CFDictionaryRef fixed = CFDictionaryCreate(NULL, keys, values, 6,
                                               &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    // IOReport caches derived fields in the channel, so it has to be mutable.
    CFMutableDictionaryRef result = CFDictionaryCreateMutableCopy(NULL, 0, fixed);

    CFRelease(fixed);
    CFRelease(driverNumber);
    CFRelease(info);
    CFRelease(unit);
    CFRelease(legend);
    CFRelease(type);
    CFRelease(idNumber);
    return result;
}

/// The running CLPC driver's registry ID and its report IDs, if this macOS and chip are known.
static const CLPCKeys *driver_keys(uint64_t *driver) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleCLPC"));
    if (!service) return NULL;
    const CLPCKeys *found = NULL;
    CFTypeRef bundle = IORegistryEntryCreateCFProperty(service, CFSTR("CFBundleIdentifier"), NULL, 0);
    if (bundle && CFGetTypeID(bundle) == CFStringGetTypeID() &&
        IORegistryEntryGetRegistryEntryID(service, driver) == KERN_SUCCESS) {
        char name[128] = {0};
        CFStringGetCString(bundle, name, sizeof(name), kCFStringEncodingUTF8);
        for (size_t i = 0; i < sizeof(kKeys) / sizeof(kKeys[0]); i++) {
            if (strcmp(kKeys[i].bundle, name) == 0) found = &kKeys[i];
        }
    }
    if (bundle) CFRelease(bundle);
    IOObjectRelease(service);
    return found;
}

ITMCLPCReader *itm_clpc_create(void) {
    if (!is_macos_27()) return NULL;
    uint64_t driver = 0;
    const CLPCKeys *keys = driver_keys(&driver);
    if (!keys) return NULL;

    CFDictionaryRef channels[] = {
        channel(driver, ((uint64_t)kIndexCPU << 32) | keys->cpu, CFSTR("CPU")),
        channel(driver, ((uint64_t)kIndexGPU << 32) | keys->gpu, CFSTR("GPU")),
        channel(driver, ((uint64_t)kIndexANE << 32) | keys->ane, CFSTR("ANE")),
        keys->dram ? channel(driver, ((uint64_t)kIndexDRAM << 32) | keys->dram, CFSTR("DRAM")) : NULL,
    };
    int count = keys->dram ? 4 : 3;
    CFArrayRef list = CFArrayCreate(NULL, (const void **)channels, count, &kCFTypeArrayCallBacks);
    for (int i = 0; i < count; i++) CFRelease(channels[i]);
    const void *wantedKeys[] = {CFSTR("IOReportChannels")};
    const void *wantedValues[] = {list};
    CFDictionaryRef fixed = CFDictionaryCreate(NULL, wantedKeys, wantedValues, 1,
                                               &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFMutableDictionaryRef wanted = CFDictionaryCreateMutableCopy(NULL, 0, fixed);
    CFRelease(fixed);
    CFRelease(list);

    ITMCLPCReader *r = calloc(1, sizeof(ITMCLPCReader));
    r->hasDRAM = keys->dram != 0;
    r->previousTime = mach_absolute_time();
    bool ok = itm_stream_open_channels(&r->stream, wanted);
    CFRelease(wanted);
    if (!ok) {
        free(r);
        return NULL;
    }
    return r;
}

bool itm_clpc_read(ITMCLPCReader *r, ITMControllerEnergy *out) {
    *out = (ITMControllerEnergy){.dram = r->hasDRAM ? 0 : -1};
    CFDictionaryRef delta = itm_stream_delta(&r->stream);
    if (!delta) return false;
    static mach_timebase_info_data_t tb;
    if (tb.denom == 0) mach_timebase_info(&tb);
    uint64_t now = mach_absolute_time();
    out->elapsed = (double)(now - r->previousTime) * tb.numer / tb.denom / 1e9;
    r->previousTime = now;

    CFArrayRef items = CFDictionaryGetValue(delta, CFSTR("IOReportChannels"));
    for (CFIndex i = 0; items && i < CFArrayGetCount(items); i++) {
        CFDictionaryRef item = CFArrayGetValueAtIndex(items, i);
        CFStringRef name = IOReportChannelGetChannelName(item);
        double joules = (double)IOReportSimpleGetIntegerValue(item, 0) * 1e-9;
        if (!name) continue;
        if (CFEqual(name, CFSTR("CPU"))) out->cpu = joules;
        else if (CFEqual(name, CFSTR("GPU"))) out->gpu = joules;
        else if (CFEqual(name, CFSTR("ANE"))) out->ane = joules;
        else if (CFEqual(name, CFSTR("DRAM"))) out->dram = joules;
    }
    CFRelease(delta);
    return true;
}

void itm_clpc_destroy(ITMCLPCReader *r) {
    if (!r) return;
    itm_stream_close(&r->stream);
    free(r);
}
