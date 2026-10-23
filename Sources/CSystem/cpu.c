#include "CSystem.h"
#include "ioreport.h"

#include <stdlib.h>
#include <string.h>

enum { MAX_STATES = 32 };

typedef struct {
    double mhz[MAX_STATES];  // lowest first
    int count;
} FrequencyTable;

struct ITMCPUReader {
    ITMReportStream stream;
    FrequencyTable efficiency;
    FrequencyTable performance;
};

static bool load_tables(FrequencyTable *e, FrequencyTable *p) {
    // The CPU tables are in kHz: voltage-states1 for the efficiency cluster, 5 for performance.
    e->count = itm_dvfs_table("voltage-states1-sram", 1e3, e->mhz, MAX_STATES);
    p->count = itm_dvfs_table("voltage-states5-sram", 1e3, p->mhz, MAX_STATES);
    return e->count > 0 && p->count > 0;
}

bool itm_cpu_max_frequencies(double *efficiency, double *performance) {
    FrequencyTable e, p;
    if (!load_tables(&e, &p)) return false;
    *efficiency = e.mhz[e.count - 1];
    *performance = p.mhz[p.count - 1];
    return true;
}

ITMCPUReader *itm_cpu_create(void) {
    ITMCPUReader *r = calloc(1, sizeof(ITMCPUReader));
    if (!load_tables(&r->efficiency, &r->performance) ||
        !itm_stream_open(&r->stream, CFSTR("CPU Stats"), CFSTR("CPU Core Performance States"))) {
        free(r);
        return NULL;
    }
    return r;
}

int itm_cpu_read(ITMCPUReader *r, ITMCoreActivity *out, int capacity) {
    CFDictionaryRef delta = itm_stream_delta(&r->stream);
    if (!delta) return 0;

    int count = 0, eSeen = 0, pSeen = 0;
    CFArrayRef items = CFDictionaryGetValue(delta, CFSTR("IOReportChannels"));
    for (CFIndex i = 0; items && i < CFArrayGetCount(items) && count < capacity; i++) {
        CFDictionaryRef item = CFArrayGetValueAtIndex(items, i);
        CFStringRef name = IOReportChannelGetChannelName(item);
        // One channel per core: ECPU0, ECPU1, … and PCPU0, PCPU1, …
        bool performance;
        if (name && CFStringHasPrefix(name, CFSTR("PCPU"))) performance = true;
        else if (name && CFStringHasPrefix(name, CFSTR("ECPU"))) performance = false;
        else continue;
        const FrequencyTable *table = performance ? &r->performance : &r->efficiency;

        double total = 0, active = 0, cycles = 0;
        for (int32_t s = 0; s < IOReportStateGetCount(item); s++) {
            double residency = (double)IOReportStateGetResidency(item, s);
            total += residency;
            // CPU states count down from the highest clock: V7P0 is the top, V0P7 the bottom.
            int level = itm_state_level(IOReportStateGetNameForIndex(item, s));
            if (level < 0) continue;
            int index = table->count - 1 - level;
            if (index < 0) index = 0;
            active += residency;
            cycles += residency * table->mhz[index];
        }
        double maxFrequency = table->mhz[table->count - 1];
        out[count++] = (ITMCoreActivity){
            .performance = performance,
            .index = performance ? pSeen++ : eSeen++,
            .busy = total > 0 ? active / total : 0,
            .utilization = total > 0 ? cycles / (total * maxFrequency) : 0,
            .averageFrequency = active > 0 ? cycles / active : 0,
            .maxFrequency = maxFrequency,
        };
    }
    CFRelease(delta);
    return count;
}

void itm_cpu_destroy(ITMCPUReader *r) {
    if (!r) return;
    itm_stream_close(&r->stream);
    free(r);
}
