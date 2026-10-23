#include "ioreport.h"

#include <IOKit/IOKitLib.h>
#include <stdlib.h>
#include <string.h>

bool itm_stream_open(ITMReportStream *s, CFStringRef group, CFStringRef subgroup) {
    memset(s, 0, sizeof(*s));
    CFDictionaryRef found = IOReportCopyChannelsInGroup(group, subgroup, 0, 0, 0);
    if (!found) return false;
    CFMutableDictionaryRef wanted = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, found);
    CFRelease(found);
    s->subscription = IOReportCreateSubscription(NULL, wanted, &s->channels, 0, NULL);
    CFRelease(wanted);
    if (s->subscription && s->channels) s->previous = IOReportCreateSamples(s->subscription, s->channels, NULL);
    if (!s->previous) {
        itm_stream_close(s);
        return false;
    }
    return true;
}

CFDictionaryRef itm_stream_delta(ITMReportStream *s) {
    CFDictionaryRef current = IOReportCreateSamples(s->subscription, s->channels, NULL);
    if (!current) return NULL;
    CFDictionaryRef delta = IOReportCreateSamplesDelta(s->previous, current, NULL);
    CFRelease(s->previous);
    s->previous = current;
    return delta;
}

void itm_stream_close(ITMReportStream *s) {
    if (s->previous) CFRelease(s->previous);
    if (s->channels) CFRelease(s->channels);
    if (s->subscription) CFRelease((CFTypeRef)s->subscription);
    memset(s, 0, sizeof(*s));
}

int itm_dvfs_table(const char *key, double divisor, double *out, int capacity) {
    io_iterator_t it;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleARMIODevice"), &it) != KERN_SUCCESS) return 0;
    CFStringRef property = CFStringCreateWithCString(kCFAllocatorDefault, key, kCFStringEncodingUTF8);
    int count = 0;
    io_object_t entry;
    while ((entry = IOIteratorNext(it))) {
        io_name_t name;
        if (count == 0 && IORegistryEntryGetName(entry, name) == KERN_SUCCESS && strcmp(name, "pmgr") == 0) {
            CFTypeRef data = IORegistryEntryCreateCFProperty(entry, property, kCFAllocatorDefault, 0);
            if (data && CFGetTypeID(data) == CFDataGetTypeID()) {
                const uint32_t *pairs = (const uint32_t *)CFDataGetBytePtr(data);
                CFIndex n = CFDataGetLength(data) / 8;
                for (CFIndex i = 0; i < n && count < capacity; i++) {
                    if (pairs[i * 2] > 0) out[count++] = pairs[i * 2] / divisor;
                }
            }
            if (data) CFRelease(data);
        }
        IOObjectRelease(entry);
    }
    CFRelease(property);
    IOObjectRelease(it);
    return count;
}

int itm_state_level(CFStringRef name) {
    char state[32] = "";
    if (!name || !CFStringGetCString(name, state, sizeof state, kCFStringEncodingUTF8)) return -1;
    char *p = strrchr(state, 'P');
    if (!p || p[1] < '0' || p[1] > '9') return -1;
    return atoi(p + 1);
}
