use std::{env, net::SocketAddr};

use chrono::{DateTime, Utc};
use sqlx::{FromRow, PgPool, postgres::PgPoolOptions};
use tonic::{Request, Response, Status, transport::Server};
use tracing::info;
use uuid::Uuid;

use proto::{
    Booking, CreateBookingRequest, CreateBookingResponse, GetSlotRequest, Slot,
    booking_service_server::{BookingService, BookingServiceServer},
};

mod proto {
    tonic::include_proto!("lastslot.booking.v1");
}

#[derive(Clone)]
struct BookingApi {
    pool: PgPool,
}

#[derive(Debug, FromRow)]
struct SlotRow {
    id: Uuid,
    title: String,
    starts_at: DateTime<Utc>,
    booking_id: Option<Uuid>,
    customer_name: Option<String>,
    booking_created_at: Option<DateTime<Utc>>,
}

#[derive(Debug, FromRow)]
struct BookingRow {
    id: Uuid,
    slot_id: Uuid,
    customer_name: String,
    created_at: DateTime<Utc>,
}

impl SlotRow {
    fn into_proto(self) -> Slot {
        let booking = match (self.booking_id, self.customer_name, self.booking_created_at) {
            (Some(id), Some(customer_name), Some(created_at)) => Some(Booking {
                id: id.to_string(),
                customer_name,
                created_at: created_at.to_rfc3339(),
            }),
            _ => None,
        };
        Slot {
            id: self.id.to_string(),
            title: self.title,
            starts_at: self.starts_at.to_rfc3339(),
            status: if booking.is_some() {
                "booked".to_owned()
            } else {
                "available".to_owned()
            },
            booking,
        }
    }
}

impl BookingRow {
    fn as_proto(&self) -> Booking {
        Booking {
            id: self.id.to_string(),
            customer_name: self.customer_name.clone(),
            created_at: self.created_at.to_rfc3339(),
        }
    }
}

#[tonic::async_trait]
impl BookingService for BookingApi {
    async fn get_slot(&self, request: Request<GetSlotRequest>) -> Result<Response<Slot>, Status> {
        let slot_id = parse_uuid("slot_id", &request.into_inner().slot_id)?;
        let slot = load_slot(&self.pool, slot_id).await?;
        Ok(Response::new(slot))
    }

    async fn create_booking(
        &self,
        request: Request<CreateBookingRequest>,
    ) -> Result<Response<CreateBookingResponse>, Status> {
        let request = request.into_inner();
        let slot_id = parse_uuid("slot_id", &request.slot_id)?;
        let idempotency_key = parse_uuid("idempotency_key", &request.idempotency_key)?;
        let customer_name = validate_customer_name(&request.customer_name)?;

        // Fail with the public not-found contract before an insert can surface a
        // foreign-key violation as an internal error. Slots are immutable in this
        // focused case study, so this read cannot race with slot deletion.
        load_slot(&self.pool, slot_id).await?;

        if let Some(existing) = find_by_idempotency_key(&self.pool, idempotency_key).await? {
            return replay_response(&self.pool, existing, slot_id, &customer_name).await;
        }

        let booking_id = Uuid::new_v4();
        let inserted = sqlx::query_as::<_, BookingRow>(
            r#"
            INSERT INTO bookings (id, slot_id, customer_name, idempotency_key)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT DO NOTHING
            RETURNING id, slot_id, customer_name, created_at
            "#,
        )
        .bind(booking_id)
        .bind(slot_id)
        .bind(&customer_name)
        .bind(idempotency_key)
        .fetch_optional(&self.pool)
        .await
        .map_err(internal_status)?;

        if let Some(booking) = inserted {
            let slot = load_slot(&self.pool, slot_id).await?;
            return Ok(Response::new(CreateBookingResponse {
                booking: Some(booking.as_proto()),
                slot: Some(slot),
                replayed: false,
            }));
        }

        if let Some(existing) = find_by_idempotency_key(&self.pool, idempotency_key).await? {
            return replay_response(&self.pool, existing, slot_id, &customer_name).await;
        }

        Err(Status::already_exists("slot_taken"))
    }
}

fn parse_uuid(field: &str, raw: &str) -> Result<Uuid, Status> {
    Uuid::parse_str(raw).map_err(|_| Status::invalid_argument(format!("invalid_{field}")))
}

fn validate_customer_name(raw: &str) -> Result<String, Status> {
    let value = raw.trim();
    let length = value.chars().count();
    if !(2..=80).contains(&length) {
        return Err(Status::invalid_argument("invalid_customer_name"));
    }
    Ok(value.to_owned())
}

async fn load_slot(pool: &PgPool, slot_id: Uuid) -> Result<Slot, Status> {
    sqlx::query_as::<_, SlotRow>(
        r#"
        SELECT
            s.id,
            s.title,
            s.starts_at,
            b.id AS booking_id,
            b.customer_name,
            b.created_at AS booking_created_at
        FROM slots s
        LEFT JOIN bookings b ON b.slot_id = s.id
        WHERE s.id = $1
        "#,
    )
    .bind(slot_id)
    .fetch_optional(pool)
    .await
    .map_err(internal_status)?
    .map(SlotRow::into_proto)
    .ok_or_else(|| Status::not_found("slot_not_found"))
}

async fn find_by_idempotency_key(
    pool: &PgPool,
    idempotency_key: Uuid,
) -> Result<Option<BookingRow>, Status> {
    sqlx::query_as::<_, BookingRow>(
        r#"
        SELECT id, slot_id, customer_name, created_at
        FROM bookings
        WHERE idempotency_key = $1
        "#,
    )
    .bind(idempotency_key)
    .fetch_optional(pool)
    .await
    .map_err(internal_status)
}

async fn replay_response(
    pool: &PgPool,
    booking: BookingRow,
    expected_slot_id: Uuid,
    expected_customer_name: &str,
) -> Result<Response<CreateBookingResponse>, Status> {
    if booking.slot_id != expected_slot_id || booking.customer_name != expected_customer_name {
        return Err(Status::invalid_argument("idempotency_key_reused"));
    }
    let slot = load_slot(pool, booking.slot_id).await?;
    Ok(Response::new(CreateBookingResponse {
        booking: Some(booking.as_proto()),
        slot: Some(slot),
        replayed: true,
    }))
}

fn internal_status(error: sqlx::Error) -> Status {
    tracing::error!(%error, "database operation failed");
    Status::internal("internal_error")
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .json()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "booking_service=info".into()),
        )
        .init();

    let database_url = env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://lastslot:lastslot@127.0.0.1:5432/lastslot".to_owned());
    let bind_address: SocketAddr = env::var("BOOKING_SERVICE_ADDRESS")
        .unwrap_or_else(|_| "127.0.0.1:50051".to_owned())
        .parse()?;
    let pool = PgPoolOptions::new()
        .max_connections(10)
        .connect(&database_url)
        .await?;
    sqlx::migrate!("../../migrations").run(&pool).await?;

    info!(%bind_address, "booking service ready");
    Server::builder()
        .add_service(BookingServiceServer::new(BookingApi { pool }))
        .serve(bind_address)
        .await?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use tonic::Code;

    use super::{parse_uuid, validate_customer_name};

    #[test]
    fn customer_name_is_trimmed_before_persistence() {
        assert_eq!(
            validate_customer_name("  Ada Lovelace  ").expect("valid name"),
            "Ada Lovelace"
        );
    }

    #[test]
    fn customer_name_outside_the_contract_is_rejected() {
        let error = validate_customer_name("A").expect_err("one character must fail");
        assert_eq!(error.code(), Code::InvalidArgument);
        assert_eq!(error.message(), "invalid_customer_name");
    }

    #[test]
    fn identifiers_must_be_uuids() {
        let error = parse_uuid("slot_id", "not-a-uuid").expect_err("invalid UUID must fail");
        assert_eq!(error.code(), Code::InvalidArgument);
        assert_eq!(error.message(), "invalid_slot_id");
    }
}
