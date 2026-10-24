#pragma once
// Private to CSystem: the IOReport API (libIOReport.dylib) and helpers shared by the readers.

#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>

typedef struct IOReportSubscription *IOReportSubscriptionRef;
extern CFDictionaryRef IOReportCopyChannelsInGroup(CFStringRef, CFStringRef, uint64_t, uint64_t, uint64_t);
extern IOReportSubscriptionRef IOReportCreateSubscription(void *, CFMutableDictionaryRef, CFMutableDictionaryRef *, uint64_t, CFTypeRef);
extern CFDictionaryRef IOReportCreateSamples(IOReportSubscriptionRef, CFMutableDictionaryRef, CFTypeRef);
extern CFDictionaryRef IOReportCreateSamplesDelta(CFDictionaryRef, CFDictionaryRef, CFTypeRef);
extern CFStringRef IOReportChannelGetChannelName(CFDictionaryRef);
extern CFStringRef IOReportChannelGetUnitLabel(CFDictionaryRef);
extern int64_t IOReportSimpleGetIntegerValue(CFDictionaryRef, int32_t);
extern int32_t IOReportStateGetCount(CFDictionaryRef);
extern CFStringRef IOReportStateGetNameForIndex(CFDictionaryRef, int32_t);
extern int64_t IOReportStateGetResidency(CFDictionaryRef, int32_t);

/// A subscription that hands back the change since the previous call.
typedef struct {
    IOReportSubscriptionRef subscription;
    CFMutableDictionaryRef channels;
    CFDictionaryRef previous;
} ITMReportStream;

/// Subscribes to a group (and optionally one subgroup) and takes the first sample.
bool itm_stream_open(ITMReportStream *stream, CFStringRef group, CFStringRef subgroup);
/// Like itm_stream_open, keeping only the channels with these names.
bool itm_stream_open_named(ITMReportStream *stream, CFStringRef group, CFStringRef subgroup,
                           const CFStringRef *names, int count);
/// Subscribes to channels described by hand: a dictionary with an "IOReportChannels" array.
bool itm_stream_open_channels(ITMReportStream *stream, CFMutableDictionaryRef channels);
/// The delta since the previous call, or NULL. The caller releases it.
CFDictionaryRef itm_stream_delta(ITMReportStream *stream);
void itm_stream_close(ITMReportStream *stream);

/// Reads a DVFS table from the power manager (`pmgr`): pairs of (frequency, voltage), lowest
/// first. Zero-frequency placeholders are skipped; `divisor` converts entries to MHz.
/// Returns the number of frequencies written to `out`.
int itm_dvfs_table(const char *key, double divisor, double *out, int capacity);

/// How a performance-state channel's levels map onto a DVFS table (lowest clock first).
typedef enum {
    /// CPU: level 0 is the top clock ("V7P0"), counting down.
    ITMLevelsFromTop,
    /// GPU: level 1 is the bottom clock ("P1"), counting up; level 0 isn't a clock.
    ITMLevelsFromBottom,
} ITMLevelOrder;

/// Residency of one performance-state channel: all of it, the part at some clock, and that part
/// weighted by its clock in MHz (so `cycles / active` is the average running clock).
typedef struct {
    double total, active, cycles;
} ITMClockResidency;

ITMClockResidency itm_clock_residency(CFDictionaryRef channel, const double *mhz, int count, ITMLevelOrder order);
