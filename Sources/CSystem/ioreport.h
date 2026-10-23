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
/// The delta since the previous call, or NULL. The caller releases it.
CFDictionaryRef itm_stream_delta(ITMReportStream *stream);
void itm_stream_close(ITMReportStream *stream);

/// Reads a DVFS table from the power manager (`pmgr`): pairs of (frequency, voltage), lowest
/// first. Zero-frequency placeholders are skipped; `divisor` converts entries to MHz.
/// Returns the number of frequencies written to `out`.
int itm_dvfs_table(const char *key, double divisor, double *out, int capacity);

/// Performance level parsed from a state name: "P3" or "V4P3" -> 3. -1 for idle/off states.
int itm_state_level(CFStringRef name);
