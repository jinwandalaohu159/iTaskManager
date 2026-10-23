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
    /// Share of the core's full-clock capacity used: busy time weighted by clock / max clock.
    double utilization;
    /// Average clock while running, and the core's highest clock, in MHz.
    double averageFrequency;
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
/// Reads a 4-character SMC key of type `flt `.
bool itm_smc_read_float(uint32_t conn, const char *key, float *out);

/// Asks the privileged helper for every process's counters. Returns how many were written, or
/// -1 when the helper isn't installed, approved or reachable.
int itm_helper_snapshot(ITMProcessCounters *out, int capacity);

mach_port_t itm_task_self(void);
mach_port_t itm_host_self(void);

#pragma clang assume_nonnull end

/// Private libsystem API: the process that macOS attributes a helper/XPC process to
/// (e.g. a Chrome renderer -> Google Chrome). Activity Monitor uses the same mechanism.
extern pid_t responsibility_get_pid_responsible_for_pid(pid_t pid);
