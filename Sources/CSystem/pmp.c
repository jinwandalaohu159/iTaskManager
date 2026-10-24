// How CPU power splits between the efficiency and performance clusters, from the power
// management processor (PMP).
//
// PMP keeps a histogram per cluster ("EACC0", "PACC0", with "… SRAM" alongside): each state is
// a power band named by its upper edge ("0.250W", "1W", ...), and its residency counts the
// samples taken in that band. Samples come at a fixed rate while the cluster is powered and
// stop while it's off, so the sum of residency × band midpoint is proportional to the energy
// the cluster used. The bands are coarse at low power, so these are only used as weights to
// divide a measured CPU total, not as wattages of their own.

#include "CSystem.h"
#include "ioreport.h"

#include <stdlib.h>

struct ITMClusterReader {
    ITMReportStream stream;
};

ITMClusterReader *itm_cluster_create(void) {
    ITMClusterReader *r = calloc(1, sizeof(ITMClusterReader));
    if (!itm_stream_open(&r->stream, CFSTR("PMP"), CFSTR("Energy"))) {
        free(r);
        return NULL;
    }
    return r;
}

/// Σ residency × band midpoint over one histogram.
static double weighted_energy(CFDictionaryRef item) {
    double total = 0, lower = 0;
    int32_t count = IOReportStateGetCount(item);
    for (int32_t i = 0; i < count; i++) {
        CFStringRef name = IOReportStateGetNameForIndex(item, i);
        double upper = name ? CFStringGetDoubleValue(name) : 0;
        total += (double)IOReportStateGetResidency(item, i) * (lower + upper) / 2;
        lower = upper;
    }
    return total;
}

bool itm_cluster_read(ITMClusterReader *r, double *efficiency, double *performance) {
    *efficiency = *performance = 0;
    CFDictionaryRef delta = itm_stream_delta(&r->stream);
    if (!delta) return false;

    CFArrayRef items = CFDictionaryGetValue(delta, CFSTR("IOReportChannels"));
    for (CFIndex i = 0; items && i < CFArrayGetCount(items); i++) {
        CFDictionaryRef item = CFArrayGetValueAtIndex(items, i);
        CFStringRef name = IOReportChannelGetChannelName(item);
        if (!name) continue;
        // Every cluster counts, with its SRAM: EACC0, PACC0, PACC1 SRAM, ...
        if (CFStringHasPrefix(name, CFSTR("EACC"))) *efficiency += weighted_energy(item);
        else if (CFStringHasPrefix(name, CFSTR("PACC"))) *performance += weighted_energy(item);
    }
    CFRelease(delta);
    return *efficiency + *performance > 0;
}

void itm_cluster_destroy(ITMClusterReader *r) {
    if (!r) return;
    itm_stream_close(&r->stream);
    free(r);
}
