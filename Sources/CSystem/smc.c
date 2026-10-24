#include "CSystem.h"

#include <IOKit/IOKitLib.h>
#include <string.h>

// Layout of the AppleSMC user client struct (80 bytes).
typedef struct { char major, minor, build, reserved; uint16_t release; } SMCVersion;
typedef struct { uint16_t version, length; uint32_t cpuPLimit, gpuPLimit, memPLimit; } SMCPLimitData;
typedef struct { uint32_t dataSize; uint32_t dataType; char dataAttributes; } SMCKeyInfo;
typedef struct {
    uint32_t key;
    SMCVersion vers;
    SMCPLimitData pLimitData;
    SMCKeyInfo keyInfo;
    char result;
    char status;
    char data8;
    uint32_t data32;
    unsigned char bytes[32];
} SMCParam;

enum { kSMCHandleYPCEvent = 2, kSMCReadKey = 5, kSMCGetKeyFromIndex = 8, kSMCGetKeyInfo = 9 };

uint32_t itm_smc_open(void) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return 0;
    io_connect_t conn = 0;
    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &conn);
    IOObjectRelease(service);
    return kr == KERN_SUCCESS ? conn : 0;
}

void itm_smc_close(uint32_t conn) {
    if (conn) IOServiceClose(conn);
}

static bool smc_call(uint32_t conn, SMCParam *in, SMCParam *out) {
    size_t size = sizeof(SMCParam);
    return IOConnectCallStructMethod(conn, kSMCHandleYPCEvent, in, sizeof(SMCParam), out, &size) == KERN_SUCCESS
        && out->result == 0;
}

static uint32_t four_cc(const char *key) {
    return ((uint32_t)key[0] << 24) | ((uint32_t)key[1] << 16) | ((uint32_t)key[2] << 8) | (uint32_t)key[3];
}

uint32_t itm_smc_key_count(uint32_t conn) {
    if (!conn) return 0;
    SMCParam in = {0}, res = {0};
    in.key = four_cc("#KEY");
    in.data8 = kSMCGetKeyInfo;
    if (!smc_call(conn, &in, &res)) return 0;
    in.keyInfo.dataSize = res.keyInfo.dataSize;
    in.data8 = kSMCReadKey;
    memset(&res, 0, sizeof(res));
    if (!smc_call(conn, &in, &res)) return 0;
    return ((uint32_t)res.bytes[0] << 24) | ((uint32_t)res.bytes[1] << 16) | ((uint32_t)res.bytes[2] << 8) | res.bytes[3];
}

bool itm_smc_key_at(uint32_t conn, uint32_t index, char out[5]) {
    if (!conn) return false;
    SMCParam in = {0}, res = {0};
    in.data8 = kSMCGetKeyFromIndex;
    in.data32 = index;
    if (!smc_call(conn, &in, &res)) return false;
    out[0] = (char)(res.key >> 24);
    out[1] = (char)(res.key >> 16);
    out[2] = (char)(res.key >> 8);
    out[3] = (char)res.key;
    out[4] = 0;
    return true;
}

uint32_t itm_smc_key_code(const char *key) {
    return strlen(key) == 4 ? four_cc(key) : 0;
}

bool itm_smc_read_known_float(uint32_t conn, uint32_t key, float *out) {
    if (!conn) return false;
    SMCParam in = {0}, res = {0};
    in.key = key;
    in.keyInfo.dataSize = sizeof(float);
    in.data8 = kSMCReadKey;
    if (!smc_call(conn, &in, &res)) return false;
    memcpy(out, res.bytes, sizeof(float));
    return true;
}

bool itm_smc_read_float(uint32_t conn, const char *key, float *out) {
    if (!conn || strlen(key) != 4) return false;
    SMCParam in = {0}, res = {0};
    in.key = four_cc(key);

    in.data8 = kSMCGetKeyInfo;
    if (!smc_call(conn, &in, &res)) return false;
    if (res.keyInfo.dataType != 'flt ' || res.keyInfo.dataSize != 4) return false;

    in.keyInfo.dataSize = res.keyInfo.dataSize;
    in.data8 = kSMCReadKey;
    memset(&res, 0, sizeof(res));
    if (!smc_call(conn, &in, &res)) return false;
    memcpy(out, res.bytes, sizeof(float));
    return true;
}
