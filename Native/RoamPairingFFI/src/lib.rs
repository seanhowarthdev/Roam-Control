use std::ffi::{CStr, CString, c_char, c_void};
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::ptr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use idevice::dvt::{
    location_simulation::LocationSimulationClient, remote_server::RemoteServerClient,
};
use idevice::remote_pairing::{
    PairableHost, PairableHostInfo, PeerDevice, RemotePairingClient, RpPairingFile,
    RpPairingSocket, connect_tls_psk_tunnel_native,
};
use idevice::rsd::RsdHandshake;
use idevice::{RsdService, tcp};
use tokio::net::{TcpListener, TcpStream};
use tokio::time::{Instant, sleep, timeout};

const DEFAULT_HOST_NAME: &str = "Roam Control";
const DEFAULT_HOST_MODEL: &str = "Mac17,7";
const CANCELLED_ERROR: &str = "Pairing was cancelled.";
const LOCATION_CANCELLED_ERROR: &str = "The location session was stopped.";
const SESSION_TIMEOUT: Duration = Duration::from_secs(15);

pub type ReadyCallback = Option<
    extern "C" fn(
        context: *mut c_void,
        service_identifier: *const c_char,
        port: u16,
        txt_keys: *const *const c_char,
        txt_values: *const *const c_char,
        txt_count: usize,
    ),
>;

pub type PinCallback = Option<extern "C" fn(context: *mut c_void, pin: *const c_char)>;

#[repr(C)]
pub struct RemotePairingSession {
    cancelled: Arc<AtomicBool>,
}

#[repr(C)]
pub struct LocationSession {
    cancelled: Arc<AtomicBool>,
    coordinates: Arc<Mutex<LocationCoordinates>>,
}

#[derive(Clone, Copy, PartialEq)]
struct LocationCoordinates {
    latitude: f64,
    longitude: f64,
}

impl LocationCoordinates {
    fn validated(latitude: f64, longitude: f64) -> Result<Self, String> {
        if latitude.is_finite()
            && longitude.is_finite()
            && (-90.0..=90.0).contains(&latitude)
            && (-180.0..=180.0).contains(&longitude)
        {
            Ok(Self {
                latitude,
                longitude,
            })
        } else {
            Err("That location is outside the valid coordinate range.".to_string())
        }
    }
}

#[repr(C)]
pub struct RemotePairingResult {
    pub error_message: *mut c_char,
    pub device_name: *mut c_char,
    pub device_model: *mut c_char,
    pub device_udid: *mut c_char,
    pub pairing_record: *mut u8,
    pub pairing_record_length: usize,
    pub host_alt_irk: *mut u8,
    pub host_alt_irk_length: usize,
}

#[repr(C)]
pub struct LocationResult {
    pub error_message: *mut c_char,
}

pub type LocationStartedCallback = Option<extern "C" fn(context: *mut c_void)>;

impl RemotePairingResult {
    fn empty() -> Self {
        Self {
            error_message: ptr::null_mut(),
            device_name: ptr::null_mut(),
            device_model: ptr::null_mut(),
            device_udid: ptr::null_mut(),
            pairing_record: ptr::null_mut(),
            pairing_record_length: 0,
            host_alt_irk: ptr::null_mut(),
            host_alt_irk_length: 0,
        }
    }
}

struct CallbackSet {
    ready: ReadyCallback,
    pin: PinCallback,
    context: *mut c_void,
}

unsafe impl Send for CallbackSet {}

struct CompletedPairing {
    device_name: String,
    device_model: String,
    device_udid: String,
    pairing_record: Vec<u8>,
    host_alt_irk: Vec<u8>,
}

#[unsafe(no_mangle)]
pub extern "C" fn rc_remote_pairing_session_create() -> *mut RemotePairingSession {
    Box::into_raw(Box::new(RemotePairingSession {
        cancelled: Arc::new(AtomicBool::new(false)),
    }))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn rc_remote_pairing_session_cancel(session: *mut RemotePairingSession) {
    if let Some(session) = unsafe { session.as_ref() } {
        session.cancelled.store(true, Ordering::Release);
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn rc_remote_pairing_session_run(
    session: *mut RemotePairingSession,
    host_name: *const c_char,
    host_model: *const c_char,
    ready_callback: ReadyCallback,
    pin_callback: PinCallback,
    context: *mut c_void,
    result: *mut RemotePairingResult,
) -> i32 {
    if session.is_null() || result.is_null() {
        return 2;
    }

    unsafe { *result = RemotePairingResult::empty() };

    let session = unsafe { &*session };
    session.cancelled.store(false, Ordering::Release);

    let host_name = unsafe { optional_c_string(host_name, DEFAULT_HOST_NAME) };
    let host_model = unsafe { optional_c_string(host_model, DEFAULT_HOST_MODEL) };
    let callbacks = CallbackSet {
        ready: ready_callback,
        pin: pin_callback,
        context,
    };
    let cancellation = Arc::clone(&session.cancelled);

    let execution = catch_unwind(AssertUnwindSafe(|| {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
            .map_err(|_| "Roam Control could not start its pairing engine.".to_string())?;

        runtime.block_on(run_pairing(host_name, host_model, callbacks, cancellation))
    }));

    match execution {
        Ok(Ok(completed)) => {
            unsafe { write_success(&mut *result, completed) };
            0
        }
        Ok(Err(message)) => {
            unsafe { (*result).error_message = owned_c_string(message) };
            1
        }
        Err(_) => {
            unsafe {
                (*result).error_message =
                    owned_c_string("The pairing engine stopped unexpectedly.");
            }
            1
        }
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn rc_remote_pairing_result_destroy(result: *mut RemotePairingResult) {
    let Some(result) = (unsafe { result.as_mut() }) else {
        return;
    };

    for value in [
        result.error_message,
        result.device_name,
        result.device_model,
        result.device_udid,
    ] {
        if !value.is_null() {
            unsafe { drop(CString::from_raw(value)) };
        }
    }

    unsafe {
        destroy_byte_buffer(result.pairing_record, result.pairing_record_length);
        destroy_byte_buffer(result.host_alt_irk, result.host_alt_irk_length);
    }
    *result = RemotePairingResult::empty();
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn rc_remote_pairing_session_destroy(session: *mut RemotePairingSession) {
    if !session.is_null() {
        unsafe { drop(Box::from_raw(session)) };
    }
}

/// Returns 1 when an mDNS remote-pairing announcement belongs to the device
/// represented by this pairing record, and 0 for a non-match or malformed data.
/// The full pair-verify handshake remains the final identity check.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rc_pairing_record_matches_service(
    pairing_record: *const u8,
    pairing_record_length: usize,
    service_identifier: *const c_char,
    auth_tag: *const c_char,
) -> i32 {
    if pairing_record.is_null()
        || pairing_record_length == 0
        || service_identifier.is_null()
        || auth_tag.is_null()
    {
        return 0;
    }

    let execution = catch_unwind(AssertUnwindSafe(|| {
        let pairing_record =
            unsafe { std::slice::from_raw_parts(pairing_record, pairing_record_length) };
        let Ok(pairing_file) = RpPairingFile::from_bytes(pairing_record) else {
            return false;
        };
        let Some(alt_irk) = pairing_file.alt_irk() else {
            return false;
        };
        let Ok(service_identifier) = (unsafe { CStr::from_ptr(service_identifier) }).to_str()
        else {
            return false;
        };
        let Ok(auth_tag) = (unsafe { CStr::from_ptr(auth_tag) }).to_str() else {
            return false;
        };

        PeerDevice::validate_auth_tag(alt_irk, service_identifier.trim(), auth_tag.trim())
    }));

    matches!(execution, Ok(true)) as i32
}

#[unsafe(no_mangle)]
pub extern "C" fn rc_location_session_create() -> *mut LocationSession {
    Box::into_raw(Box::new(LocationSession {
        cancelled: Arc::new(AtomicBool::new(false)),
        coordinates: Arc::new(Mutex::new(LocationCoordinates {
            latitude: 0.0,
            longitude: 0.0,
        })),
    }))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn rc_location_session_cancel(session: *mut LocationSession) {
    if let Some(session) = unsafe { session.as_ref() } {
        session.cancelled.store(true, Ordering::Release);
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn rc_location_session_update(
    session: *mut LocationSession,
    latitude: f64,
    longitude: f64,
) -> i32 {
    let Some(session) = (unsafe { session.as_ref() }) else {
        return 2;
    };
    let Ok(coordinates) = LocationCoordinates::validated(latitude, longitude) else {
        return 1;
    };
    let Ok(mut current) = session.coordinates.lock() else {
        return 2;
    };
    *current = coordinates;
    0
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn rc_location_session_run(
    session: *mut LocationSession,
    pairing_record: *const u8,
    pairing_record_length: usize,
    peer_address: *const c_char,
    remote_pairing_port: u16,
    service_identifier: *const c_char,
    auth_tag: *const c_char,
    latitude: f64,
    longitude: f64,
    started_callback: LocationStartedCallback,
    context: *mut c_void,
    result: *mut LocationResult,
) -> i32 {
    if session.is_null()
        || result.is_null()
        || pairing_record.is_null()
        || pairing_record_length == 0
    {
        return 2;
    }

    unsafe {
        (*result).error_message = ptr::null_mut();
    }

    let session = unsafe { &*session };
    session.cancelled.store(false, Ordering::Release);
    let pairing_record =
        unsafe { std::slice::from_raw_parts(pairing_record, pairing_record_length).to_vec() };
    let peer_address = unsafe { optional_c_string(peer_address, "10.7.0.1") };
    let service_identifier = unsafe { optional_c_string(service_identifier, "") };
    let auth_tag = unsafe { optional_c_string(auth_tag, "") };
    let cancellation = Arc::clone(&session.cancelled);
    let coordinates = Arc::clone(&session.coordinates);
    if let Ok(mut current) = coordinates.lock() {
        *current = LocationCoordinates {
            latitude,
            longitude,
        };
    }
    let callback_context = context as usize;

    let execution = catch_unwind(AssertUnwindSafe(|| {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .worker_threads(3)
            .enable_all()
            .build()
            .map_err(|_| "Roam Control could not start its device session.".to_string())?;

        runtime.block_on(run_location_session(
            pairing_record,
            peer_address,
            remote_pairing_port,
            service_identifier,
            auth_tag,
            coordinates,
            started_callback,
            callback_context,
            cancellation,
        ))
    }));

    match execution {
        Ok(Ok(())) => 0,
        Ok(Err(message)) => {
            unsafe { (*result).error_message = owned_c_string(message) };
            1
        }
        Err(_) => {
            unsafe {
                (*result).error_message =
                    owned_c_string("The location session stopped unexpectedly.");
            }
            1
        }
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn rc_location_result_destroy(result: *mut LocationResult) {
    let Some(result) = (unsafe { result.as_mut() }) else {
        return;
    };
    if !result.error_message.is_null() {
        unsafe { drop(CString::from_raw(result.error_message)) };
    }
    result.error_message = ptr::null_mut();
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn rc_location_session_destroy(session: *mut LocationSession) {
    if !session.is_null() {
        unsafe { drop(Box::from_raw(session)) };
    }
}

async fn run_pairing(
    host_name: String,
    host_model: String,
    callbacks: CallbackSet,
    cancellation: Arc<AtomicBool>,
) -> Result<CompletedPairing, String> {
    if cancellation.load(Ordering::Acquire) {
        return Err(CANCELLED_ERROR.to_string());
    }

    let listener = TcpListener::bind(SocketAddr::new(Ipv4Addr::UNSPECIFIED.into(), 0))
        .await
        .map_err(|_| "Roam Control could not open a local pairing connection.".to_string())?;
    let port = listener
        .local_addr()
        .map_err(|_| "Roam Control could not determine its pairing port.".to_string())?
        .port();

    let mut pairing_record = RpPairingFile::generate(&host_name);
    let host_info = PairableHostInfo::generate(&host_name, &host_model);
    let host_alt_irk = host_info.alt_irk.to_vec();
    let service_identifier = pairing_record.identifier.clone();

    publish_ready_callback(&callbacks, &service_identifier, port, &host_info);

    let (stream, _) = tokio::select! {
        accepted = listener.accept() => {
            accepted.map_err(|_| "The iPhone could not connect to Roam Control.".to_string())?
        }
        _ = wait_for_cancellation(Arc::clone(&cancellation)) => {
            return Err(CANCELLED_ERROR.to_string());
        }
    };

    let pin_callback = callbacks.pin;
    let callback_context = callbacks.context as usize;
    let socket = RpPairingSocket::new_device(stream);
    let mut pairable_host = PairableHost::new(socket, host_info);

    let peer = tokio::select! {
        outcome = pairable_host.accept(&mut pairing_record, move |pin| async move {
            if let Some(callback) = pin_callback
                && let Ok(pin) = CString::new(pin)
            {
                callback(callback_context as *mut c_void, pin.as_ptr());
            }
        }) => {
            outcome.map_err(|error| friendly_pairing_error(&error.to_string()))?
        }
        _ = wait_for_cancellation(Arc::clone(&cancellation)) => {
            return Err(CANCELLED_ERROR.to_string());
        }
    };

    Ok(CompletedPairing {
        device_name: peer.name,
        device_model: peer.model,
        device_udid: peer.remotepairing_udid,
        pairing_record: pairing_record.to_bytes(),
        host_alt_irk,
    })
}

#[allow(clippy::too_many_arguments)]
async fn run_location_session(
    pairing_record_bytes: Vec<u8>,
    peer_address: String,
    remote_pairing_port: u16,
    service_identifier: String,
    auth_tag: String,
    coordinates: Arc<Mutex<LocationCoordinates>>,
    started_callback: LocationStartedCallback,
    callback_context: usize,
    cancellation: Arc<AtomicBool>,
) -> Result<(), String> {
    let mut applied_coordinates = current_coordinates(&coordinates)?;
    if remote_pairing_port == 0 || service_identifier.is_empty() || auth_tag.is_empty() {
        return Err("Roam Control could not identify this iPhone's pairing service.".to_string());
    }

    let mut pairing_file = RpPairingFile::from_bytes(&pairing_record_bytes)
        .map_err(|_| "The saved pairing record could not be read.".to_string())?;
    let alt_irk = pairing_file
        .alt_irk()
        .ok_or_else(|| "The saved pairing record is missing its device identity.".to_string())?;
    if !PeerDevice::validate_auth_tag(alt_irk, &service_identifier, &auth_tag) {
        return Err("The discovered device did not match the paired iPhone.".to_string());
    }
    check_location_cancellation(&cancellation)?;

    let peer_ip: IpAddr = peer_address
        .parse()
        .map_err(|_| "LocalDevVPN returned an invalid device address.".to_string())?;
    let pairing_address = SocketAddr::new(peer_ip, remote_pairing_port);
    let stream = timeout(SESSION_TIMEOUT, TcpStream::connect(pairing_address))
        .await
        .map_err(|_| {
            "LocalDevVPN did not make the iPhone connection available in time.".to_string()
        })?
        .map_err(|_| "Roam Control could not reach the iPhone through LocalDevVPN.".to_string())?;

    let socket = RpPairingSocket::new(stream);
    let mut remote_pairing = RemotePairingClient::new(socket, DEFAULT_HOST_NAME);
    timeout(SESSION_TIMEOUT, remote_pairing.attempt_pair_verify())
        .await
        .map_err(|_| "The paired iPhone did not respond in time.".to_string())?
        .map_err(|_| "The iPhone rejected the saved pairing session.".to_string())?;
    timeout(
        SESSION_TIMEOUT,
        remote_pairing.validate_pairing(&mut pairing_file),
    )
    .await
    .map_err(|_| "Pairing verification took too long.".to_string())?
    .map_err(|_| {
        "The saved pairing is no longer valid. Reset Device Setup and pair again.".to_string()
    })?;
    check_location_cancellation(&cancellation)?;

    let tunnel_port = timeout(SESSION_TIMEOUT, remote_pairing.create_tcp_listener())
        .await
        .map_err(|_| "The iPhone did not create its secure tunnel in time.".to_string())?
        .map_err(|_| "The iPhone could not create its secure tunnel.".to_string())?;
    let tunnel_stream = timeout(
        SESSION_TIMEOUT,
        TcpStream::connect(SocketAddr::new(peer_ip, tunnel_port)),
    )
    .await
    .map_err(|_| "LocalDevVPN did not open the secure tunnel in time.".to_string())?
    .map_err(|_| "Roam Control could not open the secure device tunnel.".to_string())?;
    let tunnel = timeout(
        SESSION_TIMEOUT,
        connect_tls_psk_tunnel_native(tunnel_stream, remote_pairing.encryption_key()),
    )
    .await
    .map_err(|_| "The encrypted device tunnel took too long to start.".to_string())?
    .map_err(|_| "Roam Control could not secure the device tunnel.".to_string())?;

    let client_ip: IpAddr = tunnel
        .info
        .client_address
        .parse()
        .map_err(|_| "The iPhone returned an invalid tunnel address.".to_string())?;
    let server_ip: IpAddr = tunnel
        .info
        .server_address
        .parse()
        .map_err(|_| "The iPhone returned an invalid service address.".to_string())?;
    let rsd_port = tunnel.info.server_rsd_port;
    let adapter = tcp::adapter::Adapter::new(Box::new(tunnel.into_inner()), client_ip, server_ip);
    let mut handle = adapter.to_async_handle();

    let rsd_stream = timeout(SESSION_TIMEOUT, handle.connect(rsd_port))
        .await
        .map_err(|_| "The iPhone's service directory took too long to respond.".to_string())?
        .map_err(|_| "Roam Control could not open the iPhone's service directory.".to_string())?;
    let mut handshake = timeout(SESSION_TIMEOUT, RsdHandshake::new(rsd_stream))
        .await
        .map_err(|_| "The iPhone's service handshake took too long.".to_string())?
        .map_err(|_| "Roam Control could not complete the iPhone service handshake.".to_string())?;
    let mut dvt = timeout(
        SESSION_TIMEOUT,
        RemoteServerClient::connect_rsd(&mut handle, &mut handshake),
    )
    .await
    .map_err(|_| "The location service took too long to open.".to_string())?
    .map_err(|_| "The iPhone did not make its location service available.".to_string())?;
    timeout(SESSION_TIMEOUT, dvt.read_message(0))
        .await
        .map_err(|_| "The location service did not become ready in time.".to_string())?
        .map_err(|_| "The iPhone's location service did not become ready.".to_string())?;
    let mut location = timeout(SESSION_TIMEOUT, LocationSimulationClient::new(&mut dvt))
        .await
        .map_err(|_| "The location controls took too long to open.".to_string())?
        .map_err(|_| "Roam Control could not open the iPhone's location controls.".to_string())?;

    location
        .set(applied_coordinates.latitude, applied_coordinates.longitude)
        .await
        .map_err(|_| "The iPhone did not accept the selected location.".to_string())?;
    if let Some(callback) = started_callback {
        callback(callback_context as *mut c_void);
    }

    let mut last_refresh = Instant::now();
    while !cancellation.load(Ordering::Acquire) {
        sleep(Duration::from_millis(200)).await;
        if cancellation.load(Ordering::Acquire) {
            break;
        }
        let latest_coordinates = current_coordinates(&coordinates)?;
        if latest_coordinates != applied_coordinates
            || last_refresh.elapsed() >= Duration::from_secs(4)
        {
            location
                .set(latest_coordinates.latitude, latest_coordinates.longitude)
                .await
                .map_err(|_| "The iPhone ended the active location session.".to_string())?;
            applied_coordinates = latest_coordinates;
            last_refresh = Instant::now();
        }
    }

    let _ = location.clear().await;
    Ok(())
}

fn current_coordinates(
    coordinates: &Arc<Mutex<LocationCoordinates>>,
) -> Result<LocationCoordinates, String> {
    let current = coordinates
        .lock()
        .map_err(|_| "Roam Control could not update the active location.".to_string())?;
    LocationCoordinates::validated(current.latitude, current.longitude)
}

fn check_location_cancellation(cancelled: &Arc<AtomicBool>) -> Result<(), String> {
    if cancelled.load(Ordering::Acquire) {
        Err(LOCATION_CANCELLED_ERROR.to_string())
    } else {
        Ok(())
    }
}

async fn wait_for_cancellation(cancelled: Arc<AtomicBool>) {
    while !cancelled.load(Ordering::Acquire) {
        sleep(Duration::from_millis(150)).await;
    }
}

fn publish_ready_callback(
    callbacks: &CallbackSet,
    service_identifier: &str,
    port: u16,
    host_info: &PairableHostInfo,
) {
    let Some(callback) = callbacks.ready else {
        return;
    };
    let Ok(service_identifier) = CString::new(service_identifier) else {
        return;
    };

    let records = host_info.mdns_txt_records(service_identifier.to_str().unwrap_or_default());
    let keys: Vec<CString> = records
        .iter()
        .filter_map(|(key, _)| CString::new(key.as_str()).ok())
        .collect();
    let values: Vec<CString> = records
        .iter()
        .filter_map(|(_, value)| CString::new(value.as_str()).ok())
        .collect();

    if keys.len() != records.len() || values.len() != records.len() {
        return;
    }

    let key_pointers: Vec<*const c_char> = keys.iter().map(|value| value.as_ptr()).collect();
    let value_pointers: Vec<*const c_char> = values.iter().map(|value| value.as_ptr()).collect();

    callback(
        callbacks.context,
        service_identifier.as_ptr(),
        port,
        key_pointers.as_ptr(),
        value_pointers.as_ptr(),
        records.len(),
    );
}

fn friendly_pairing_error(raw: &str) -> String {
    let lowercased = raw.to_lowercase();
    if lowercased.contains("srp") || lowercased.contains("auth") {
        "The code was not accepted. Start pairing again and enter the new code.".to_string()
    } else if lowercased.contains("connection")
        || lowercased.contains("broken pipe")
        || lowercased.contains("unexpected eof")
    {
        "The iPhone ended the pairing connection. Start pairing again when you are ready."
            .to_string()
    } else {
        "The iPhone could not finish pairing. Please try again.".to_string()
    }
}

unsafe fn optional_c_string(value: *const c_char, fallback: &str) -> String {
    if value.is_null() {
        return fallback.to_string();
    }

    unsafe { CStr::from_ptr(value) }
        .to_str()
        .ok()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or(fallback)
        .to_string()
}

unsafe fn write_success(result: &mut RemotePairingResult, completed: CompletedPairing) {
    result.device_name = owned_c_string(completed.device_name);
    result.device_model = owned_c_string(completed.device_model);
    result.device_udid = owned_c_string(completed.device_udid);

    let (pairing_record, pairing_record_length) = owned_byte_buffer(completed.pairing_record);
    result.pairing_record = pairing_record;
    result.pairing_record_length = pairing_record_length;

    let (host_alt_irk, host_alt_irk_length) = owned_byte_buffer(completed.host_alt_irk);
    result.host_alt_irk = host_alt_irk;
    result.host_alt_irk_length = host_alt_irk_length;
}

fn owned_c_string(value: impl Into<Vec<u8>>) -> *mut c_char {
    CString::new(value).unwrap_or_default().into_raw()
}

fn owned_byte_buffer(value: Vec<u8>) -> (*mut u8, usize) {
    let mut value = value.into_boxed_slice();
    let length = value.len();
    let pointer = value.as_mut_ptr();
    std::mem::forget(value);
    (pointer, length)
}

unsafe fn destroy_byte_buffer(pointer: *mut u8, length: usize) {
    if !pointer.is_null() && length > 0 {
        unsafe { ptr::write_bytes(pointer, 0, length) };
        let slice = ptr::slice_from_raw_parts_mut(pointer, length);
        unsafe { drop(Box::from_raw(slice)) };
    }
}
