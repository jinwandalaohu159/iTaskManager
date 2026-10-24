#include "CSystem.h"

#include <dispatch/dispatch.h>
#include <os/lock.h>
#include <string.h>
#include <xpc/xpc.h>

static xpc_connection_t connection;
static dispatch_queue_t replies;
static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;

/// A registered helper that launchd can't start leaves messages unanswered rather than
/// failing them, so the sampler never waits longer than this.
static const int64_t kReplyTimeout = 2 * NSEC_PER_SEC;

static xpc_connection_t current_connection(const char *service) {
    if (!connection) {
        connection = xpc_connection_create_mach_service(service, NULL, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
        xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {});
        xpc_connection_resume(connection);
    }
    return connection;
}

static void reset_connection(void) {
    xpc_connection_cancel(connection);
    xpc_release(connection);
    connection = NULL;
}

/// The helper's reply, or NULL if none came in time.
static xpc_object_t send_with_timeout(const char *service, xpc_object_t request) {
    if (!replies) replies = dispatch_queue_create("com.rhysmao.iTaskManager.helper-replies", DISPATCH_QUEUE_SERIAL);
    __block xpc_object_t reply = NULL;
    __block bool abandoned = false;
    dispatch_semaphore_t answered = dispatch_semaphore_create(0);
    xpc_connection_send_message_with_reply(current_connection(service), request, replies, ^(xpc_object_t r) {
        if (abandoned) return;
        reply = xpc_retain(r);
        dispatch_semaphore_signal(answered);
    });
    if (dispatch_semaphore_wait(answered, dispatch_time(DISPATCH_TIME_NOW, kReplyTimeout)) != 0) {
        // Handlers run on `replies`, so once this has run a late reply can't touch anything;
        // one that slipped in just before is still used.
        dispatch_sync(replies, ^{ abandoned = true; });
    }
    dispatch_release(answered);
    return reply;
}

int itm_helper_snapshot(const char *service, ITMProcessCounters *out, int capacity) {
    os_unfair_lock_lock(&lock);
    xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_int64(request, ITM_HELPER_KEY_VERSION, ITM_HELPER_PROTOCOL_VERSION);
    xpc_object_t reply = send_with_timeout(service, request);
    xpc_release(request);

    int count = -1;
    if (!reply) {
        // No answer: start over on the next call.
        reset_connection();
        count = ITM_HELPER_TIMED_OUT;
    } else if (xpc_get_type(reply) == XPC_TYPE_DICTIONARY &&
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
        reset_connection();
    }
    // XPC_ERROR_CONNECTION_INTERRUPTED (the helper quit when idle) needs nothing: the next
    // message relaunches it.
    if (reply) xpc_release(reply);
    os_unfair_lock_unlock(&lock);
    return count;
}
