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
    /// Per core: which state each core asked for, and when it was idle.
    ITMReportStream cores;
    /// Per cluster: "ECPM" and "PCPM" are the clocks the power manager actually ran each
    /// cluster at — what powermetrics reports as "HW active frequency". (The "ECPU"/"PCPU"
    /// channels beside them, like the per-core ones, are the clocks requested; on macOS 27 an
    /// M5's busy performance cores asked for 4608 MHz while the cluster ran at 4248 MHz.)
    ITMReportStream clusters;
    bool hasClusters;
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
        !itm_stream_open(&r->cores, CFSTR("CPU Stats"), CFSTR("CPU Core Performance States"))) {
        free(r);
        return NULL;
    }
    // Not listed among the channels, but there to subscribe to.
    const CFStringRef actual[] = {CFSTR("ECPM"), CFSTR("PCPM")};
    r->hasClusters = itm_stream_open_named(&r->clusters, CFSTR("CPU Stats"), CFSTR("CPU Complex Performance States"), actual, 2);
    return r;
}

/// Average clock while active over one performance-state channel; 0 if it was never active.
static double active_frequency(CFDictionaryRef item, const FrequencyTable *table) {
    ITMClockResidency r = itm_clock_residency(item, table->mhz, table->count, ITMLevelsFromTop);
    return r.active > 0 ? r.cycles / r.active : 0;
}

/// Each cluster's actual clock since the last read, from the power manager's channels.
static void read_clusters(ITMCPUReader *r, double *efficiency, double *performance) {
    *efficiency = *performance = 0;
    if (!r->hasClusters) return;
    CFDictionaryRef delta = itm_stream_delta(&r->clusters);
    if (!delta) return;
    CFArrayRef items = CFDictionaryGetValue(delta, CFSTR("IOReportChannels"));
    for (CFIndex i = 0; items && i < CFArrayGetCount(items); i++) {
        CFDictionaryRef item = CFArrayGetValueAtIndex(items, i);
        CFStringRef name = IOReportChannelGetChannelName(item);
        if (name && CFEqual(name, CFSTR("ECPM"))) *efficiency = active_frequency(item, &r->efficiency);
        else if (name && CFEqual(name, CFSTR("PCPM"))) *performance = active_frequency(item, &r->performance);
    }
    CFRelease(delta);
}

int itm_cpu_read(ITMCPUReader *r, ITMCoreActivity *out, int capacity) {
    double eCluster, pCluster;
    read_clusters(r, &eCluster, &pCluster);
    CFDictionaryRef delta = itm_stream_delta(&r->cores);
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

        // The core's own states: busy share (every state but IDLE), and the clock asked of it.
        // With every core flat out that's the top clock, whatever the power limiter then lets
        // the cluster run at. Load is measured against it, so a core flat out reads 100%. The
        // clock shown is the cluster's actual one.
        ITMClockResidency own = itm_clock_residency(item, table->mhz, table->count, ITMLevelsFromTop);
        double total = own.total, active = own.active;
        double requested = active > 0 ? own.cycles / active : 0;
        double cluster = performance ? pCluster : eCluster;
        double maxFrequency = table->mhz[table->count - 1];
        double busy = total > 0 ? active / total : 0;
        out[count++] = (ITMCoreActivity){
            .performance = performance,
            .index = performance ? pSeen++ : eSeen++,
            .busy = busy,
            .utilization = busy * requested / maxFrequency,
            .averageFrequency = cluster > 0 ? cluster : requested,
            .requestedFrequency = requested,
            .maxFrequency = maxFrequency,
        };
    }
    CFRelease(delta);
    return count;
}

void itm_cpu_destroy(ITMCPUReader *r) {
    if (!r) return;
    itm_stream_close(&r->cores);
    if (r->hasClusters) itm_stream_close(&r->clusters);
    free(r);
}
