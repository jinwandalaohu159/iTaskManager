#pragma once
// The message format between the app and its privileged helper. Shared by both sides.

#include <stdint.h>

// The helper's launchd label, which is also its Mach service name, is chosen per build from
// the helper's own code hash (see scripts/build-app.sh): the app finds it under ITMHelperLabel
// in its Info.plist, the helper in XPC_SERVICE_NAME.

/// Only this code-signing identity may talk to the helper.
#define ITM_HELPER_CLIENT_REQUIREMENT "identifier \"com.rhysmao.iTaskManager\""
/// Bumped whenever `ITMProcessCounters` changes, so a stale helper is never misread.
#define ITM_HELPER_PROTOCOL_VERSION 1

#define ITM_HELPER_KEY_VERSION "version"
#define ITM_HELPER_KEY_COUNTERS "counters"

/// Cumulative counters for one process, straight from proc_pid_rusage (RUSAGE_INFO_V6).
/// The app turns two snapshots into rates, exactly as it does for processes it can read itself.
typedef struct {
    int32_t pid;
    uint32_t reserved;
    uint64_t startTime;       // ri_proc_start_abstime: tells a reused pid apart
    uint64_t userTime;        // mach time units
    uint64_t systemTime;
    uint64_t userPTime;       // the part of the above on performance cores
    uint64_t systemPTime;
    uint64_t cycles;
    uint64_t pCycles;
    uint64_t energy;          // nJ
    uint64_t footprint;       // bytes
    uint64_t diskRead;        // bytes
    uint64_t diskWritten;
} ITMProcessCounters;
