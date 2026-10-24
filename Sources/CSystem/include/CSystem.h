#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <mach/mach.h>
#include <sys/types.h>

#include "ITMHelperProtocol.h"

#pragma clang assume_nonnull begin

/// Energy consumed since the previous read, in joules.
typedef struct {
    double cpu;
    double ecpu;
    double pcpu;
    double gpu;
    double ane;
    double dram;
    bool hasClusterSplit;
} ITMEnergy;

typedef struct ITMPowerReader ITMPowerReader;

/// Subscribes to the IOReport "Energy Model" group. Returns NULL when unavailable.
ITMPowerReader *_Nullable itm_power_create(void);
/// Fills `out` with energy used since the previous call and `elapsed` with the seconds between them.
bool itm_power_read(ITMPowerReader *reader, ITMEnergy *out, double *elapsed);
void itm_power_destroy(ITMPowerReader *_Nullable reader);

typedef struct ITMCLPCReader ITMCLPCReader;

/// Subscribes to the CPU performance controller's energy totals, which keep updating on macOS 27
/// where the "Energy Model" CPU, memory and Neural Engine counters don't. NULL on other macOS
/// versions and on chips without known report IDs.
ITMCLPCReader *_Nullable itm_clpc_create(void);
/// Joules used since the previous read, and the seconds that covers.
typedef struct {
    double cpu, gpu, ane;
    /// Negative on chips whose memory record isn't known.
    double dram;
    double elapsed;
} ITMControllerEnergy;

bool itm_clpc_read(ITMCLPCReader *reader, ITMControllerEnergy *out);
void itm_clpc_destroy(ITMCLPCReader *_Nullable reader);

typedef struct ITMClusterReader ITMClusterReader;

/// Subscribes to the power management processor's per-cluster power histograms.
ITMClusterReader *_Nullable itm_cluster_create(void);
/// Relative energy of the efficiency and performance clusters since the previous call: weights
/// for dividing a CPU total, not joules. False when neither cluster reported anything.
bool itm_cluster_read(ITMClusterReader *reader, double *efficiency, double *performance);
void itm_cluster_destroy(ITMClusterReader *_Nullable reader);

/// GPU activity since the previous read, from its performance-state residency.
typedef struct {
    /// Share of the GPU's full-clock capacity used: busy time weighted by clock / max clock.
    double utilization;
    /// Share of time the GPU was busy at any clock.
    double activeResidency;
    /// Average clock while busy, and the highest clock, in MHz.
    double averageFrequency;
    double maxFrequency;
} ITMGPUActivity;

typedef struct ITMGPUReader ITMGPUReader;

/// Subscribes to the IOReport "GPU Performance States" channel. Returns NULL when unavailable.
ITMGPUReader *_Nullable itm_gpu_create(void);
bool itm_gpu_read(ITMGPUReader *reader, ITMGPUActivity *out);
void itm_gpu_destroy(ITMGPUReader *_Nullable reader);

/// One CPU core's activity since the previous read, from its performance-state residency.
typedef struct {
    bool performance;
    /// Position among cores of the same kind, in IOReport order.
    int index;
    /// Share of time the core was running at any clock.
    double busy;
    /// Load against flat out: busy time weighted by the clock asked of the core / its top clock.
    double utilization;
    /// The clock its cluster actually ran at while active, in MHz.
    double averageFrequency;
    /// The clock asked of the core while active, and its top clock, in MHz.
    double requestedFrequency;
    double maxFrequency;
} ITMCoreActivity;

typedef struct ITMCPUReader ITMCPUReader;

/// Subscribes to the IOReport "CPU Core Performance States" channels. NULL when unavailable.
ITMCPUReader *_Nullable itm_cpu_create(void);
/// Fills up to `capacity` cores; returns how many were written (0 on failure).
int itm_cpu_read(ITMCPUReader *reader, ITMCoreActivity *out, int capacity);
void itm_cpu_destroy(ITMCPUReader *_Nullable reader);
/// The highest clock of each core kind, in MHz.
bool itm_cpu_max_frequencies(double *efficiency, double *performance);

/// Opens a connection to AppleSMC. Returns 0 on failure.
uint32_t itm_smc_open(void);
void itm_smc_close(uint32_t conn);
/// How many keys the SMC has, and the name of the one at `index` (4 characters + NUL).
uint32_t itm_smc_key_count(uint32_t conn);
bool itm_smc_key_at(uint32_t conn, uint32_t index, char out[_Nonnull 5]);
/// Reads a 4-character SMC key of type `flt `.
bool itm_smc_read_float(uint32_t conn, const char *key, float *out);
/// The four-character key as the SMC numbers it.
uint32_t itm_smc_key_code(const char *key);
/// Reads a key already known to hold a 4-byte float (checked once with itm_smc_read_float):
/// one call to the SMC instead of two.
bool itm_smc_read_known_float(uint32_t conn, uint32_t key, float *out);

/// Asks the privileged helper at Mach service `service` for every process's counters. Returns how many were written,
/// -1 when the helper isn't installed, approved or reachable, or ITM_HELPER_TIMED_OUT when
/// it is registered but didn't answer within two seconds.
#define ITM_HELPER_TIMED_OUT (-2)
int itm_helper_snapshot(const char *service, ITMProcessCounters *out, int capacity);

mach_port_t itm_task_self(void);
mach_port_t itm_host_self(void);

#pragma clang assume_nonnull end

/// Private libsystem API: the process that macOS attributes a helper/XPC process to
/// (e.g. a Chrome renderer -> Google Chrome). Activity Monitor uses the same mechanism.
extern pid_t responsibility_get_pid_responsible_for_pid(pid_t pid);
