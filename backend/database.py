"""
Database configuration and models
"""

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
from sqlalchemy import String, Boolean, DateTime, ForeignKey, Text, LargeBinary
from datetime import datetime, timezone
from typing import Optional, List


def utc_now() -> datetime:
    """Return current UTC datetime (timezone-aware)."""
    return datetime.now(timezone.utc)

from config import get_settings

settings = get_settings()

# Configure engine based on database type
connect_args = {}
if "azure.com" in settings.database_url:
    connect_args["ssl"] = "require"
elif "sqlite" in settings.database_url:
    connect_args["check_same_thread"] = False

engine = create_async_engine(
    settings.database_url,
    echo=True,
    connect_args=connect_args
)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


# Dependency for routes
async def get_db():
    async with async_session() as session:
        yield session


# MARK: - Models

class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(255))
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(50), default="user")  # "admin" or "user"
    provider: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)  # "microsoft", "google", "apple"
    phone_number: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    phone_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)

    devices: Mapped[List["Device"]] = relationship(back_populates="owner")
    enrollment_tokens: Mapped[List["EnrollmentToken"]] = relationship(back_populates="owner")


class Device(Base):
    __tablename__ = "devices"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    udid: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(255))
    model: Mapped[str] = mapped_column(String(255), default="")
    os_version: Mapped[str] = mapped_column(String(50), default="")
    serial_number: Mapped[str] = mapped_column(String(255), default="")

    # MDM specific
    push_token: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # APNs token
    push_magic: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    unlock_token: Mapped[Optional[bytes]] = mapped_column(LargeBinary, nullable=True)

    # Device status
    battery_level: Mapped[Optional[float]] = mapped_column(nullable=True)  # 0-100
    latitude: Mapped[Optional[float]] = mapped_column(nullable=True)
    longitude: Mapped[Optional[float]] = mapped_column(nullable=True)
    location_updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    status: Mapped[str] = mapped_column(String(50), default="pending")
    # pending -> enrolled -> managed -> unenrolling -> removed

    enrolled_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
    last_checkin: Mapped[datetime] = mapped_column(DateTime, default=utc_now)

    owner_id: Mapped[Optional[str]] = mapped_column(ForeignKey("users.id"), nullable=True)
    owner: Mapped[Optional["User"]] = relationship(back_populates="devices")

    profile_id: Mapped[Optional[str]] = mapped_column(ForeignKey("profiles.id"), nullable=True)
    profile: Mapped[Optional["RestrictionProfile"]] = relationship(back_populates="devices")

    commands: Mapped[List["MDMCommand"]] = relationship(back_populates="device")


class RestrictionProfile(Base):
    __tablename__ = "profiles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    name: Mapped[str] = mapped_column(String(255))
    description: Mapped[str] = mapped_column(Text, default="")

    allow_phone: Mapped[bool] = mapped_column(Boolean, default=True)
    allow_messages: Mapped[bool] = mapped_column(Boolean, default=True)
    allow_contacts: Mapped[bool] = mapped_column(Boolean, default=True)
    allow_camera: Mapped[bool] = mapped_column(Boolean, default=False)
    allow_photos: Mapped[bool] = mapped_column(Boolean, default=False)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)

    devices: Mapped[List["Device"]] = relationship(back_populates="profile")

    @property
    def allowed_bundle_ids(self) -> list[str]:
        bundles = []
        if self.allow_phone:
            bundles.append("com.apple.mobilephone")
        if self.allow_messages:
            bundles.append("com.apple.MobileSMS")
        if self.allow_contacts:
            bundles.append("com.apple.MobileAddressBook")
        if self.allow_camera:
            bundles.append("com.apple.camera")
        if self.allow_photos:
            bundles.append("com.apple.mobileslideshow")
        return bundles


class MDMCommand(Base):
    __tablename__ = "mdm_commands"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    command_uuid: Mapped[str] = mapped_column(String(36), unique=True, index=True)
    command_type: Mapped[str] = mapped_column(String(100))
    payload: Mapped[Optional[bytes]] = mapped_column(LargeBinary, nullable=True)

    status: Mapped[str] = mapped_column(String(50), default="pending")
    # pending -> sent -> acknowledged -> failed

    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
    sent_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    acknowledged_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    device_id: Mapped[str] = mapped_column(ForeignKey("devices.id"))
    device: Mapped["Device"] = relationship(back_populates="commands")


class EnrollmentToken(Base):
    __tablename__ = "enrollment_tokens"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    token: Mapped[str] = mapped_column(String(255), unique=True, index=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
    expires_at: Mapped[datetime] = mapped_column(DateTime)
    used_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    is_used: Mapped[bool] = mapped_column(Boolean, default=False)

    owner_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    owner: Mapped["User"] = relationship(back_populates="enrollment_tokens")

    profile_id: Mapped[Optional[str]] = mapped_column(ForeignKey("profiles.id"), nullable=True)
    profile: Mapped[Optional["RestrictionProfile"]] = relationship()

    @property
    def is_valid(self) -> bool:
        return not self.is_used and utc_now() < self.expires_at
