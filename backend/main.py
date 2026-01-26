"""
FocusPhone MDM Server
- FastAPI backend for MDM protocol
- REST API for iOS/macOS apps
- Run with: uvicorn main:app --reload
"""

from fastapi import FastAPI, Request, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from contextlib import asynccontextmanager
import plistlib

from database import engine, Base, get_db
from routers import auth, devices, profiles, enrollment, users
from mdm import mdm_router

# Create tables and seed data on startup
@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Seed default profiles
    from database import async_session, RestrictionProfile
    from sqlalchemy import select

    async with async_session() as db:
        # Check if profiles exist
        result = await db.execute(select(RestrictionProfile))
        existing = result.scalars().all()

        if not existing:
            # Create default profiles
            import uuid

            # Profile 1: Phone + Contacts (Call Only)
            profile1 = RestrictionProfile(
                id=str(uuid.uuid4()),
                name="Call Only",
                description="Phone and Contacts only - maximum focus mode",
                allow_phone=True,
                allow_messages=False,
                allow_contacts=True,
                allow_camera=False,
                allow_photos=False
            )

            # Profile 2: Phone + Messages + Contacts (Text & Call)
            profile2 = RestrictionProfile(
                id=str(uuid.uuid4()),
                name="Text & Call",
                description="Phone, Messages, and Contacts - focused communication",
                allow_phone=True,
                allow_messages=True,
                allow_contacts=True,
                allow_camera=False,
                allow_photos=False
            )

            # Profile 3: Phone + Messages + Contacts + Camera
            profile3 = RestrictionProfile(
                id=str(uuid.uuid4()),
                name="Text, Call & Camera",
                description="Phone, Messages, Contacts, and Camera",
                allow_phone=True,
                allow_messages=True,
                allow_contacts=True,
                allow_camera=True,
                allow_photos=False
            )

            db.add(profile1)
            db.add(profile2)
            db.add(profile3)
            await db.commit()
            print("Created default profiles: 'Call Only', 'Text & Call', 'Text, Call & Camera'")

    yield

app = FastAPI(
    title="FocusPhone MDM",
    description="Mobile Device Management for digital wellness",
    version="1.0.0",
    lifespan=lifespan
)

# CORS for web frontend and iOS/macOS apps
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000", "*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# Health check
@app.get("/health")
async def health():
    return {"status": "ok"}

# API routes for apps
app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(devices.router, prefix="/api/devices", tags=["devices"])
app.include_router(profiles.router, prefix="/api/profiles", tags=["profiles"])
app.include_router(enrollment.router, prefix="/api/enrollment", tags=["enrollment"])
app.include_router(users.router, prefix="/api/users", tags=["users"])

# MDM protocol routes (Apple devices check in here)
app.include_router(mdm_router.router, tags=["mdm"])


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
