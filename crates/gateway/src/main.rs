use std::{env, net::SocketAddr};

use axum::{
    Json, Router,
    extract::{Path, State, rejection::JsonRejection},
    http::{HeaderMap, HeaderValue, StatusCode, header},
    response::{IntoResponse, Response},
    routing::{get, post},
};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use tonic::{Code, Status, transport::Channel};
use tower_http::trace::TraceLayer;
use tracing::info;
use uuid::Uuid;

use proto::{
    Booking as ProtoBooking, CreateBookingRequest, GetSlotRequest, Slot as ProtoSlot,
    booking_service_client::BookingServiceClient,
};

mod proto {
    tonic::include_proto!("lastslot.booking.v1");
}

#[derive(Clone)]
struct AppState {
    booking: BookingServiceClient<Channel>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct CreateBookingBody {
    customer_name: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct BookingDto {
    id: String,
    customer_name: String,
    created_at: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct SlotDto {
    id: String,
    title: String,
    starts_at: String,
    status: String,
    booking: Option<BookingDto>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct BookingResultDto {
    booking: BookingDto,
    slot: SlotDto,
    replayed: bool,
}

#[derive(Debug, Serialize)]
struct HealthDto {
    status: &'static str,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ErrorEnvelope {
    error: ErrorBody,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ErrorBody {
    code: String,
    message: String,
    details: Value,
    request_id: Uuid,
}

struct ApiError {
    status: StatusCode,
    code: &'static str,
    message: &'static str,
    details: Value,
}

impl ApiError {
    fn new(status: StatusCode, code: &'static str, message: &'static str, details: Value) -> Self {
        Self {
            status,
            code,
            message,
            details,
        }
    }

    fn from_grpc(status: Status, slot_id: &str) -> Self {
        match (status.code(), status.message()) {
            (Code::NotFound, _) => Self::new(
                StatusCode::NOT_FOUND,
                "slot_not_found",
                "No slot exists with this identifier.",
                json!({ "slotId": slot_id }),
            ),
            (Code::AlreadyExists, "slot_taken") => Self::new(
                StatusCode::CONFLICT,
                "slot_taken",
                "Another visitor booked this slot first.",
                json!({ "slotId": slot_id }),
            ),
            (Code::InvalidArgument, "invalid_customer_name") => Self::new(
                StatusCode::UNPROCESSABLE_ENTITY,
                "invalid_customer_name",
                "Enter a name between 2 and 80 characters.",
                json!({ "field": "customerName" }),
            ),
            (Code::InvalidArgument, "idempotency_key_reused") => Self::new(
                StatusCode::UNPROCESSABLE_ENTITY,
                "idempotency_key_reused",
                "This idempotency key belongs to a different booking intent.",
                json!({}),
            ),
            (Code::InvalidArgument, _) => Self::new(
                StatusCode::UNPROCESSABLE_ENTITY,
                "invalid_request",
                "The request could not be validated.",
                json!({}),
            ),
            (Code::Unavailable, _) => Self::new(
                StatusCode::SERVICE_UNAVAILABLE,
                "booking_service_unavailable",
                "Booking is temporarily unavailable. Retry shortly.",
                json!({ "retryAfterSeconds": 1 }),
            ),
            _ => {
                tracing::error!(code = ?status.code(), message = status.message(), "gRPC request failed");
                Self::new(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "internal_error",
                    "The request could not be completed.",
                    json!({}),
                )
            }
        }
    }

    fn from_json_rejection(rejection: JsonRejection) -> Self {
        match rejection.status() {
            StatusCode::UNSUPPORTED_MEDIA_TYPE => Self::new(
                StatusCode::UNSUPPORTED_MEDIA_TYPE,
                "unsupported_media_type",
                "Send the request body as application/json.",
                json!({ "contentType": "application/json" }),
            ),
            StatusCode::UNPROCESSABLE_ENTITY => Self::new(
                StatusCode::UNPROCESSABLE_ENTITY,
                "invalid_request",
                "The JSON body does not match the booking contract.",
                json!({}),
            ),
            _ => Self::new(
                StatusCode::BAD_REQUEST,
                "invalid_json",
                "The request body is not valid JSON.",
                json!({}),
            ),
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let mut headers = HeaderMap::new();
        if self.status == StatusCode::SERVICE_UNAVAILABLE {
            headers.insert(header::RETRY_AFTER, HeaderValue::from_static("1"));
        }
        (
            self.status,
            headers,
            Json(ErrorEnvelope {
                error: ErrorBody {
                    code: self.code.to_owned(),
                    message: self.message.to_owned(),
                    details: self.details,
                    request_id: Uuid::new_v4(),
                },
            }),
        )
            .into_response()
    }
}

async fn health() -> Json<HealthDto> {
    Json(HealthDto { status: "ok" })
}

async fn get_slot(
    State(state): State<AppState>,
    Path(slot_id): Path<String>,
) -> Result<Response, ApiError> {
    let mut client = state.booking;
    let response = client
        .get_slot(GetSlotRequest {
            slot_id: slot_id.clone(),
        })
        .await
        .map_err(|status| ApiError::from_grpc(status, &slot_id))?
        .into_inner();
    let mut headers = HeaderMap::new();
    headers.insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store"));
    Ok((StatusCode::OK, headers, Json(slot_dto(response))).into_response())
}

async fn create_booking(
    State(state): State<AppState>,
    Path(slot_id): Path<String>,
    headers: HeaderMap,
    body: Result<Json<CreateBookingBody>, JsonRejection>,
) -> Result<Response, ApiError> {
    let Json(body) = body.map_err(ApiError::from_json_rejection)?;
    let idempotency_key = headers
        .get("Idempotency-Key")
        .and_then(|value| value.to_str().ok())
        .filter(|value| Uuid::parse_str(value).is_ok())
        .ok_or_else(|| {
            ApiError::new(
                StatusCode::UNPROCESSABLE_ENTITY,
                "invalid_idempotency_key",
                "Idempotency-Key must contain a UUID.",
                json!({ "header": "Idempotency-Key" }),
            )
        })?;

    let mut client = state.booking;
    let response = client
        .create_booking(CreateBookingRequest {
            slot_id: slot_id.clone(),
            customer_name: body.customer_name,
            idempotency_key: idempotency_key.to_owned(),
        })
        .await
        .map_err(|status| ApiError::from_grpc(status, &slot_id))?
        .into_inner();

    let booking = response.booking.ok_or_else(|| {
        ApiError::new(
            StatusCode::INTERNAL_SERVER_ERROR,
            "invalid_service_response",
            "The booking service returned an incomplete response.",
            json!({}),
        )
    })?;
    let slot = response.slot.ok_or_else(|| {
        ApiError::new(
            StatusCode::INTERNAL_SERVER_ERROR,
            "invalid_service_response",
            "The booking service returned an incomplete response.",
            json!({}),
        )
    })?;
    let status = if response.replayed {
        StatusCode::OK
    } else {
        StatusCode::CREATED
    };
    let mut response_headers = HeaderMap::new();
    response_headers.insert(
        header::LOCATION,
        HeaderValue::from_str(&format!("/v1/bookings/{}", booking.id)).map_err(|_| {
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "invalid_service_response",
                "The booking service returned an invalid identifier.",
                json!({}),
            )
        })?,
    );
    Ok((
        status,
        response_headers,
        Json(BookingResultDto {
            booking: booking_dto(booking),
            slot: slot_dto(slot),
            replayed: response.replayed,
        }),
    )
        .into_response())
}

fn booking_dto(booking: ProtoBooking) -> BookingDto {
    BookingDto {
        id: booking.id,
        customer_name: booking.customer_name,
        created_at: booking.created_at,
    }
}

fn slot_dto(slot: ProtoSlot) -> SlotDto {
    SlotDto {
        id: slot.id,
        title: slot.title,
        starts_at: slot.starts_at,
        status: slot.status,
        booking: slot.booking.map(booking_dto),
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .json()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "gateway=info,tower_http=info".into()),
        )
        .init();

    let booking_service_url =
        env::var("BOOKING_SERVICE_URL").unwrap_or_else(|_| "http://127.0.0.1:50051".to_owned());
    let bind_address: SocketAddr = env::var("GATEWAY_ADDRESS")
        .unwrap_or_else(|_| "127.0.0.1:8080".to_owned())
        .parse()?;
    let booking = BookingServiceClient::connect(booking_service_url).await?;
    let state = AppState { booking };

    let app = Router::new()
        .route("/healthz", get(health))
        .route("/v1/slots/{slot_id}", get(get_slot))
        .route("/v1/slots/{slot_id}/bookings", post(create_booking))
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    info!(%bind_address, "gateway ready");
    let listener = tokio::net::TcpListener::bind(bind_address).await?;
    axum::serve(listener, app).await?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use axum::{
        body::Body,
        http::{StatusCode, header},
        response::IntoResponse,
    };
    use tonic::Status;

    use super::ApiError;

    #[test]
    fn slot_conflict_has_the_public_http_semantics() {
        let error = ApiError::from_grpc(Status::already_exists("slot_taken"), "slot-1");
        assert_eq!(error.status, StatusCode::CONFLICT);
        assert_eq!(error.code, "slot_taken");
    }

    #[test]
    fn unavailable_service_includes_retry_after() {
        let response =
            ApiError::from_grpc(Status::unavailable("offline"), "slot-1").into_response();
        assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(
            response.headers().get(header::RETRY_AFTER),
            Some(&"1".parse().expect("valid header value"))
        );
        let _: Body = response.into_body();
    }
}
