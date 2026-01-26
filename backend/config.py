"""
Configuration settings

For Azure Container Apps, these come from environment variables
configured in the container app settings.
"""

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # Database - Azure PostgreSQL
    # Format: postgresql+asyncpg://user:password@host.postgres.database.azure.com:5432/dbname?ssl=require
    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/focusphone"

    # Microsoft Entra ID (Azure AD)
    azure_tenant_id: str = ""
    azure_client_id: str = ""

    # MDM Server
    mdm_server_url: str = "https://your-mdm.azurecontainerapps.io"
    mdm_org_name: str = "FocusPhone"
    mdm_org_identifier: str = "com.focusphone"

    # MDM Push Certificate (certificate-based auth for MDM)
    mdm_topic: str = "com.apple.mgmt.External.461f409a-d81a-4b5e-a009-3fb8f607aadc"
    mdm_push_cert: str = "certs/mdm_push_cert.pem"
    mdm_push_key: str = "certs/mdm_push_key.pem"
    apns_production: bool = True

    class Config:
        env_file = ".env"
        extra = "ignore"


@lru_cache
def get_settings() -> Settings:
    return Settings()
