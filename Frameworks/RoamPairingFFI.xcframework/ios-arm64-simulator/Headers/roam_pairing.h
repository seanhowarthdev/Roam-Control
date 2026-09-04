#ifndef ROAM_PAIRING_H
#define ROAM_PAIRING_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct RCRemotePairingSession RCRemotePairingSession;
typedef struct RCLocationSession RCLocationSession;

typedef void (*RCRemotePairingReadyCallback)(
    void *context,
    const char *service_identifier,
    uint16_t port,
    const char *const *txt_keys,
    const char *const *txt_values,
    size_t txt_count
);

typedef void (*RCRemotePairingPINCallback)(
    void *context,
    const char *pin
);

typedef struct {
    char *error_message;
    char *device_name;
    char *device_model;
    char *device_udid;
    uint8_t *pairing_record;
    size_t pairing_record_length;
    uint8_t *host_alt_irk;
    size_t host_alt_irk_length;
} RCRemotePairingResult;

typedef void (*RCLocationStartedCallback)(void *context);

typedef struct {
    char *error_message;
} RCLocationResult;

RCRemotePairingSession *rc_remote_pairing_session_create(void);

void rc_remote_pairing_session_cancel(RCRemotePairingSession *session);

int32_t rc_remote_pairing_session_run(
    RCRemotePairingSession *session,
    const char *host_name,
    const char *host_model,
    RCRemotePairingReadyCallback ready_callback,
    RCRemotePairingPINCallback pin_callback,
    void *context,
    RCRemotePairingResult *result
);

void rc_remote_pairing_result_destroy(RCRemotePairingResult *result);

void rc_remote_pairing_session_destroy(RCRemotePairingSession *session);

int32_t rc_pairing_record_matches_service(
    const uint8_t *pairing_record,
    size_t pairing_record_length,
    const char *service_identifier,
    const char *auth_tag
);

RCLocationSession *rc_location_session_create(void);

void rc_location_session_cancel(RCLocationSession *session);

int32_t rc_location_session_update(
    RCLocationSession *session,
    double latitude,
    double longitude
);

int32_t rc_location_session_run(
    RCLocationSession *session,
    const uint8_t *pairing_record,
    size_t pairing_record_length,
    const char *peer_address,
    uint16_t remote_pairing_port,
    const char *service_identifier,
    const char *auth_tag,
    double latitude,
    double longitude,
    RCLocationStartedCallback started_callback,
    void *context,
    RCLocationResult *result
);

void rc_location_result_destroy(RCLocationResult *result);

void rc_location_session_destroy(RCLocationSession *session);

#ifdef __cplusplus
}
#endif

#endif
