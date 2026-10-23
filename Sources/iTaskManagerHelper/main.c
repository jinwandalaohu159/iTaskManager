// iTaskManager's privileged helper. launchd starts it as root when the app connects; it
// answers one question — the usage counters of every process — and exits after a quiet
// spell. It accepts no other input and changes nothing, and it only talks to the app.
// The same figures are what /usr/bin/top, a setuid tool, already shows to any user.

#include "ITMHelperProtocol.h"

#include <dispatch/dispatch.h>
#include <libproc.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <xpc/xpc.h>

enum { MAX_PROCESSES = 8192, IDLE_SECONDS = 30 };

static dispatch_source_t idle_timer;

static void postpone_exit(void) {
    dispatch_source_set_timer(idle_timer, dispatch_time(DISPATCH_TIME_NOW, IDLE_SECONDS * NSEC_PER_SEC),
                              DISPATCH_TIME_FOREVER, NSEC_PER_SEC);
}

static xpc_object_t snapshot(void) {
    static pid_t pids[MAX_PROCESSES];
    static ITMProcessCounters counters[MAX_PROCESSES];
    int bytes = proc_listallpids(pids, sizeof pids);
    int count = bytes > 0 ? bytes : 0;
    if (count > MAX_PROCESSES) count = MAX_PROCESSES;

    int filled = 0;
    for (int i = 0; i < count; i++) {
        struct rusage_info_v6 r;
        if (pids[i] <= 0 || proc_pid_rusage(pids[i], RUSAGE_INFO_V6, (rusage_info_t *)&r) != 0) continue;
        counters[filled++] = (ITMProcessCounters){
            .pid = pids[i],
            .startTime = r.ri_proc_start_abstime,
            .userTime = r.ri_user_time,
            .systemTime = r.ri_system_time,
            .userPTime = r.ri_user_ptime,
            .systemPTime = r.ri_system_ptime,
            .cycles = r.ri_cycles,
            .pCycles = r.ri_pcycles,
            .energy = r.ri_energy_nj,
            .footprint = r.ri_phys_footprint,
            .diskRead = r.ri_diskio_bytesread,
            .diskWritten = r.ri_diskio_byteswritten,
        };
    }
    return xpc_data_create(counters, (size_t)filled * sizeof(ITMProcessCounters));
}

static void handle(xpc_connection_t peer, xpc_object_t message) {
    if (xpc_get_type(message) != XPC_TYPE_DICTIONARY) return;
    postpone_exit();
    xpc_object_t reply = xpc_dictionary_create_reply(message);
    if (!reply) return;
    xpc_dictionary_set_int64(reply, ITM_HELPER_KEY_VERSION, ITM_HELPER_PROTOCOL_VERSION);
    if (xpc_dictionary_get_int64(message, ITM_HELPER_KEY_VERSION) == ITM_HELPER_PROTOCOL_VERSION) {
        xpc_object_t data = snapshot();
        xpc_dictionary_set_value(reply, ITM_HELPER_KEY_COUNTERS, data);
        xpc_release(data);
    }
    xpc_connection_send_message(peer, reply);
    xpc_release(reply);
}

int main(void) {
    idle_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(idle_timer, ^{ exit(0); });
    postpone_exit();
    dispatch_resume(idle_timer);

    xpc_connection_t listener = xpc_connection_create_mach_service(
        ITM_HELPER_SERVICE, dispatch_get_main_queue(), XPC_CONNECTION_MACH_SERVICE_LISTENER);
    xpc_connection_set_event_handler(listener, ^(xpc_object_t peer) {
        if (xpc_get_type(peer) != XPC_TYPE_CONNECTION) return;
        // Messages from anything but the app fail before they reach the handler. If the
        // requirement can't be set, refuse the connection rather than serve it unchecked.
        if (xpc_connection_set_peer_code_signing_requirement(peer, ITM_HELPER_CLIENT_REQUIREMENT) != 0) {
            xpc_connection_cancel(peer);
            return;
        }
        xpc_connection_set_event_handler(peer, ^(xpc_object_t message) { handle(peer, message); });
        xpc_connection_resume(peer);
    });
    xpc_connection_resume(listener);
    dispatch_main();
}
