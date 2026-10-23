#include "CSystem.h"
#include "ioreport.h"

#include <stdlib.h>
#include <string.h>

enum { MAX_STATES = 32 };

struct ITMGPUReader {
    ITMReportStream stream;
    /// MHz of performance states P1, P2, … (lowest first).
    double frequencies[MAX_STATES];
    int frequencyCount;
};

ITMGPUReader *itm_gpu_create(void) {
    ITMGPUReader *r = calloc(1, sizeof(ITMGPUReader));
    r->frequencyCount = itm_dvfs_table("voltage-states9", 1e6, r->frequencies, MAX_STATES);
    if (r->frequencyCount == 0 || !itm_stream_open(&r->stream, CFSTR("GPU Stats"), CFSTR("GPU Performance States"))) {
        free(r);
        return NULL;
    }
    return r;
}

bool itm_gpu_read(ITMGPUReader *r, ITMGPUActivity *out) {
    memset(out, 0, sizeof(*out));
    CFDictionaryRef delta = itm_stream_delta(&r->stream);
    if (!delta) return false;

    double total = 0, active = 0, cycles = 0;
    CFArrayRef items = CFDictionaryGetValue(delta, CFSTR("IOReportChannels"));
    for (CFIndex i = 0; items && i < CFArrayGetCount(items); i++) {
        CFDictionaryRef item = CFArrayGetValueAtIndex(items, i);
        CFStringRef name = IOReportChannelGetChannelName(item);
        if (!name || CFStringCompare(name, CFSTR("GPUPH"), 0) != kCFCompareEqualTo) continue;
        for (int32_t s = 0; s < IOReportStateGetCount(item); s++) {
            double residency = (double)IOReportStateGetResidency(item, s);
            total += residency;
            // GPU states count up from the lowest clock: P1, P2, …; OFF/IDLE are idle time.
            int level = itm_state_level(IOReportStateGetNameForIndex(item, s));
            if (level < 1) continue;
            int index = level <= r->frequencyCount ? level - 1 : r->frequencyCount - 1;
            active += residency;
            cycles += residency * r->frequencies[index];
        }
    }
    CFRelease(delta);
    if (total <= 0) return false;

    double maxFrequency = r->frequencies[r->frequencyCount - 1];
    out->activeResidency = active / total;
    out->utilization = cycles / (total * maxFrequency);
    out->averageFrequency = active > 0 ? cycles / active : 0;
    out->maxFrequency = maxFrequency;
    return true;
}

void itm_gpu_destroy(ITMGPUReader *r) {
    if (!r) return;
    itm_stream_close(&r->stream);
    free(r);
}
