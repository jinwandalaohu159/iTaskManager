#include "CSystem.h"
#include "ioreport.h"

#include <CoreFoundation/CoreFoundation.h>
#include <mach/mach_time.h>
#include <stdlib.h>
#include <string.h>

struct ITMPowerReader {
    ITMReportStream stream;
    uint64_t previousTime;
};

static double seconds_since(uint64_t start) {
    static mach_timebase_info_data_t tb;
    if (tb.denom == 0) mach_timebase_info(&tb);
    return (double)(mach_absolute_time() - start) * tb.numer / tb.denom / 1e9;
}

ITMPowerReader *itm_power_create(void) {
    ITMPowerReader *r = calloc(1, sizeof(ITMPowerReader));
    if (!itm_stream_open(&r->stream, CFSTR("Energy Model"), NULL)) {
        free(r);
        return NULL;
    }
    r->previousTime = mach_absolute_time();
    return r;
}

static double joules(CFStringRef unit, int64_t value) {
    if (!unit) return 0;
    if (CFStringCompare(unit, CFSTR("mJ"), 0) == kCFCompareEqualTo) return value * 1e-3;
    if (CFStringCompare(unit, CFSTR("uJ"), 0) == kCFCompareEqualTo ||
        CFStringCompare(unit, CFSTR("µJ"), 0) == kCFCompareEqualTo) return value * 1e-6;
    if (CFStringCompare(unit, CFSTR("nJ"), 0) == kCFCompareEqualTo) return value * 1e-9;
    return 0;
}

static bool name_is(CFStringRef name, CFStringRef s) {
    return CFStringCompare(name, s, 0) == kCFCompareEqualTo;
}

bool itm_power_read(ITMPowerReader *r, ITMEnergy *out, double *elapsed) {
    memset(out, 0, sizeof(*out));
    CFDictionaryRef delta = itm_stream_delta(&r->stream);
    *elapsed = seconds_since(r->previousTime);
    r->previousTime = mach_absolute_time();
    if (!delta) return false;

    CFArrayRef items = CFDictionaryGetValue(delta, CFSTR("IOReportChannels"));
    if (items) {
        for (CFIndex i = 0; i < CFArrayGetCount(items); i++) {
            CFDictionaryRef item = CFArrayGetValueAtIndex(items, i);
            CFStringRef name = IOReportChannelGetChannelName(item);
            if (!name) continue;
            double j = joules(IOReportChannelGetUnitLabel(item), IOReportSimpleGetIntegerValue(item, 0));

            if (name_is(name, CFSTR("CPU Energy"))) out->cpu += j;
            else if (name_is(name, CFSTR("GPU Energy"))) out->gpu += j;
            else if (name_is(name, CFSTR("DRAM"))) out->dram += j;
            else if (CFStringHasPrefix(name, CFSTR("ANE"))) out->ane += j;
            // Cluster totals: "ECPU"/"PCPU" on M2 and later, "EACC_CPU"/"PACCn_CPU" on M1.
            else if (name_is(name, CFSTR("ECPU")) || name_is(name, CFSTR("EACC_CPU"))) out->ecpu += j;
            else if (name_is(name, CFSTR("PCPU")) ||
                     (CFStringHasPrefix(name, CFSTR("PACC")) && CFStringHasSuffix(name, CFSTR("_CPU")))) out->pcpu += j;
        }
    }
    CFRelease(delta);

    out->hasClusterSplit = out->ecpu > 0 || out->pcpu > 0;
    if (out->cpu == 0) out->cpu = out->ecpu + out->pcpu;
    return true;
}

void itm_power_destroy(ITMPowerReader *r) {
    if (!r) return;
    itm_stream_close(&r->stream);
    free(r);
}

mach_port_t itm_task_self(void) { return mach_task_self(); }
mach_port_t itm_host_self(void) { return mach_host_self(); }
