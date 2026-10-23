#include "CSystem.h"

#include <os/lock.h>
#include <string.h>
#include <xpc/xpc.h>

static xpc_connection_t connection;
static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;

static xpc_connection_t current_connection(void) {
    if (!connection) {
        connection = xpc_connection_create_mach_service(ITM_HELPER_SERVICE, NULL, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
        xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {});
        xpc_connection_resume(connection);
    }
    return connection;
}

int itm_helper_snapshot(ITMProcessCounters *out, int capacity) {
    os_unfair_lock_lock(&lock);
    xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_int64(request, ITM_HELPER_KEY_VERSION, ITM_HELPER_PROTOCOL_VERSION);
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(current_connection(), request);
    xpc_release(request);

    int count = -1;
    if (xpc_get_type(reply) == XPC_TYPE_DICTIONARY &&
        xpc_dictionary_get_int64(reply, ITM_HELPER_KEY_VERSION) == ITM_HELPER_PROTOCOL_VERSION) {
        size_t length = 0;
        const void *bytes = xpc_dictionary_get_data(reply, ITM_HELPER_KEY_COUNTERS, &length);
        if (bytes) {
            count = (int)(length / sizeof(ITMProcessCounters));
            if (count > capacity) count = capacity;
            memcpy(out, bytes, (size_t)count * sizeof(ITMProcessCounters));
        }
    } else if (reply == XPC_ERROR_CONNECTION_INVALID) {
        // Not installed, not approved, or removed: start over on the next call.
        xpc_connection_cancel(connection);
        xpc_release(connection);
        connection = NULL;
    }
    // XPC_ERROR_CONNECTION_INTERRUPTED (the helper quit when idle) needs nothing: the next
    // message relaunches it.
    xpc_release(reply);
    os_unfair_lock_unlock(&lock);
    return count;
}
