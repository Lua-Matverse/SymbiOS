"""
OAuth helper functions for multicloud providers
"""
import httpx
import base64
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from fastapi import HTTPException
import logging

logger = logging.getLogger(__name__)

class OAuthTokenManager:
    """Manages OAuth tokens for multicloud providers"""
    
    def __init__(self, db):
        self.db = db
    
    async def refresh_token_if_needed(self, user_id: str, provider: str) -> Optional[Dict[str, Any]]:
        """Check if token needs refresh and refresh if necessary"""
        
        user = await self.db.users.find_one({"id": user_id})
        if not user or provider not in user.get("oauth_providers", {}):
            return None
        
        provider_data = user["oauth_providers"][provider]
        
        # Check if token is expiring soon (within 5 minutes)
        expires_at = provider_data.get("expires_at")
        if expires_at and isinstance(expires_at, datetime):
            if expires_at <= datetime.utcnow() + timedelta(minutes=5):
                # Token is expiring, refresh it
                return await self._refresh_provider_token(user_id, provider, provider_data)
        
        return provider_data
    
    async def _refresh_provider_token(self, user_id: str, provider: str, provider_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Refresh token for specific provider"""
        
        refresh_token = provider_data.get("refresh_token")
        if not refresh_token:
            logger.warning(f"No refresh token available for user {user_id}, provider {provider}")
            return None
        
        try:
            if provider == "gdrive":
                return await self._refresh_google_token(user_id, refresh_token)
            elif provider == "proton":
                return await self._refresh_proton_token(user_id, refresh_token)
            else:
                logger.warning(f"Refresh not implemented for provider {provider}")
                return provider_data
        
        except Exception as e:
            logger.error(f"Failed to refresh token for {provider}: {str(e)}")
            return None
    
    async def _refresh_google_token(self, user_id: str, refresh_token: str) -> Dict[str, Any]:
        """Refresh Google OAuth token"""
        
        token_data = {
            "client_id": "your-google-client-id",  # From config
            "client_secret": "your-google-client-secret",
            "refresh_token": refresh_token,
            "grant_type": "refresh_token"
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://oauth2.googleapis.com/token",
                data=token_data
            )
            
            if response.status_code != 200:
                raise HTTPException(status_code=400, detail="Failed to refresh Google token")
            
            tokens = response.json()
        
        # Calculate new expiry
        expires_at = datetime.utcnow() + timedelta(seconds=tokens.get("expires_in", 3600))
        
        # Update stored data
        new_provider_data = {
            "access_token": tokens["access_token"],
            "refresh_token": refresh_token,  # Keep original refresh token
            "expires_at": expires_at,
            "scope": tokens.get("scope", "").split(" ") if tokens.get("scope") else []
        }
        
        # Update in database
        await self.db.users.update_one(
            {"id": user_id},
            {"$set": {"oauth_providers.gdrive": new_provider_data}}
        )
        
        return new_provider_data
    
    async def _refresh_proton_token(self, user_id: str, refresh_token: str) -> Dict[str, Any]:
        """Refresh Proton OAuth token"""
        
        # Proton uses different refresh mechanism
        # This is a placeholder - adjust based on Proton's actual OAuth implementation
        token_data = {
            "client_id": "your-proton-client-id",
            "client_secret": "your-proton-client-secret", 
            "refresh_token": refresh_token,
            "grant_type": "refresh_token"
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://account.proton.me/oauth/token",
                data=token_data
            )
            
            if response.status_code != 200:
                raise HTTPException(status_code=400, detail="Failed to refresh Proton token")
            
            tokens = response.json()
        
        expires_at = datetime.utcnow() + timedelta(seconds=tokens.get("expires_in", 3600))
        
        new_provider_data = {
            "access_token": tokens["access_token"],
            "refresh_token": refresh_token,
            "expires_at": expires_at,
            "scope": tokens.get("scope", "").split(" ") if tokens.get("scope") else []
        }
        
        await self.db.users.update_one(
            {"id": user_id},
            {"$set": {"oauth_providers.proton": new_provider_data}}
        )
        
        return new_provider_data

    async def get_valid_token(self, user_id: str, provider: str) -> Optional[str]:
        """Get a valid access token for provider, refreshing if necessary"""
        
        provider_data = await self.refresh_token_if_needed(user_id, provider)
        if provider_data:
            return provider_data.get("access_token")
        
        return None

# Terabox helper (uses basic auth, not OAuth)
class TeraboxAuth:
    """Handles Terabox authentication (basic auth)"""
    
    @staticmethod
    def create_auth_header(username: str, password: str) -> str:
        """Create basic auth header for Terabox"""
        credentials = f"{username}:{password}"
        encoded_credentials = base64.b64encode(credentials.encode()).decode()
        return f"Basic {encoded_credentials}"
    
    @staticmethod
    async def validate_credentials(username: str, password: str) -> bool:
        """Validate Terabox credentials"""
        try:
            auth_header = TeraboxAuth.create_auth_header(username, password)
            
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    "https://terabox.com/api/user/info",  # Placeholder URL
                    headers={"Authorization": auth_header}
                )
                
                return response.status_code == 200
        except Exception as e:
            logger.error(f"Terabox validation failed: {str(e)}")
            return False