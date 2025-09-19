from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.responses import RedirectResponse
from motor.motor_asyncio import AsyncIOMotorDatabase
from datetime import datetime, timedelta
from typing import Optional
import secrets
import httpx
import base64
import json

from .models import User, UserCreate, UserLogin, UserInDB, OAuthCallback, OAuthTokenResponse
from .jwt_handler import (
    verify_password, 
    get_password_hash, 
    create_access_token, 
    create_refresh_token,
    refresh_access_token,
    Token
)
from .dependencies import get_current_user, get_current_active_user

router = APIRouter(prefix="/auth", tags=["authentication"])

# Database will be injected from main app
db = None

# OAuth configuration
OAUTH_CONFIG = {
    "gdrive": {
        "client_id": "your-google-client-id",  # Configure in .env
        "client_secret": "your-google-client-secret",
        "auth_url": "https://accounts.google.com/o/oauth2/auth",
        "token_url": "https://oauth2.googleapis.com/token",
        "scope": "https://www.googleapis.com/auth/drive.file",
        "redirect_uri": "https://progressive-release.preview.emergentagent.com/auth/callback/gdrive"
    },
    "proton": {
        "client_id": "your-proton-client-id",
        "client_secret": "your-proton-client-secret", 
        "auth_url": "https://account.proton.me/oauth/authorize",
        "token_url": "https://account.proton.me/oauth/token",
        "scope": "drive:read drive:write",
        "redirect_uri": "https://progressive-release.preview.emergentagent.com/auth/callback/proton"
    }
}

@router.post("/signup", response_model=dict)
async def signup(user_data: UserCreate):
    """Register new user"""
    
    # Check if user already exists
    existing_user = await db.users.find_one({
        "$or": [
            {"username": user_data.username},
            {"email": user_data.email}
        ]
    })
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Usuário ou email já existe"
        )
    
    # Create user
    hashed_password = get_password_hash(user_data.password)
    user_dict = user_data.dict()
    del user_dict["password"]
    
    user_in_db = UserInDB(**user_dict, hashed_password=hashed_password)
    
    # Insert user
    result = await db.users.insert_one(user_in_db.dict())
    
    # Create tokens
    access_token = create_access_token(data={"sub": user_data.username, "user_id": user_in_db.id})
    refresh_token = create_refresh_token(data={"sub": user_data.username, "user_id": user_in_db.id})
    
    return {
        "message": "Usuário criado com sucesso",
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": User(**user_dict, id=user_in_db.id)
    }

@router.post("/login", response_model=dict)
async def login(user_credentials: UserLogin):
    """Login user with username/password"""
    
    # Find user
    user = await db.users.find_one({"username": user_credentials.username})
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais inválidas",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Verify password
    if not verify_password(user_credentials.password, user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais inválidas",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Update last login
    await db.users.update_one(
        {"_id": user["_id"]}, 
        {"$set": {"last_login": datetime.utcnow()}}
    )
    
    # Create tokens
    access_token = create_access_token(data={"sub": user["username"], "user_id": user["id"]})
    refresh_token = create_refresh_token(data={"sub": user["username"], "user_id": user["id"]})
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": User(**{k: v for k, v in user.items() if k != "hashed_password"})
    }

@router.post("/refresh", response_model=dict)
async def refresh_token(refresh_token: str):
    """Refresh access token"""
    
    new_access_token = refresh_access_token(refresh_token)
    
    return {
        "access_token": new_access_token,
        "token_type": "bearer"
    }

@router.get("/me", response_model=User)
async def get_current_user_info(current_user: User = Depends(get_current_active_user)):
    """Get current user information"""
    return current_user

# OAuth Routes
@router.get("/oauth/{provider}")
async def oauth_login(provider: str, request: Request):
    """Initiate OAuth flow for provider (gdrive, proton)"""
    
    if provider not in OAUTH_CONFIG:
        raise HTTPException(status_code=400, detail="Provider não suportado")
    
    config = OAUTH_CONFIG[provider]
    
    # Generate state for CSRF protection
    state = secrets.token_urlsafe(32)
    
    # Store state in session/cache (for now, we'll use a simple approach)
    # In production, use Redis or proper session management
    
    auth_url = (
        f"{config['auth_url']}?"
        f"client_id={config['client_id']}&"
        f"redirect_uri={config['redirect_uri']}&"
        f"scope={config['scope']}&"
        f"response_type=code&"
        f"state={state}&"
        f"access_type=offline"  # For refresh tokens
    )
    
    return {"auth_url": auth_url, "state": state}

@router.get("/callback/{provider}")
async def oauth_callback(provider: str, code: str, state: str, current_user: User = Depends(get_current_user)):
    """Handle OAuth callback and store tokens"""
    
    if provider not in OAUTH_CONFIG:
        raise HTTPException(status_code=400, detail="Provider não suportado")
    
    config = OAUTH_CONFIG[provider]
    
    # Exchange code for tokens
    token_data = {
        "client_id": config["client_id"],
        "client_secret": config["client_secret"],
        "code": code,
        "grant_type": "authorization_code",
        "redirect_uri": config["redirect_uri"]
    }
    
    async with httpx.AsyncClient() as client:
        response = await client.post(config["token_url"], data=token_data)
        
        if response.status_code != 200:
            raise HTTPException(status_code=400, detail="Falha na autenticação OAuth")
        
        tokens = response.json()
    
    # Calculate expiry
    expires_at = None
    if "expires_in" in tokens:
        expires_at = datetime.utcnow() + timedelta(seconds=tokens["expires_in"])
    
    # Store tokens in user's oauth_providers
    oauth_data = {
        "access_token": tokens.get("access_token"),
        "refresh_token": tokens.get("refresh_token"),
        "expires_at": expires_at,
        "scope": tokens.get("scope", "").split(" ") if tokens.get("scope") else []
    }
    
    # Update user with OAuth tokens
    await db.users.update_one(
        {"id": current_user.id},
        {"$set": {f"oauth_providers.{provider}": oauth_data}}
    )
    
    return {
        "message": f"{provider} conectado com sucesso",
        "provider": provider,
        "expires_at": expires_at
    }

@router.delete("/oauth/{provider}")
async def disconnect_oauth(provider: str, current_user: User = Depends(get_current_active_user)):
    """Disconnect OAuth provider"""
    
    await db.users.update_one(
        {"id": current_user.id},
        {"$unset": {f"oauth_providers.{provider}": ""}}
    )
    
    return {"message": f"{provider} desconectado com sucesso"}

@router.get("/oauth/status")
async def oauth_status(current_user: User = Depends(get_current_active_user)):
    """Get OAuth connection status for all providers"""
    
    user_data = await db.users.find_one({"id": current_user.id})
    oauth_providers = user_data.get("oauth_providers", {})
    
    status = {}
    for provider in OAUTH_CONFIG.keys():
        provider_data = oauth_providers.get(provider, {})
        status[provider] = {
            "connected": bool(provider_data.get("access_token")),
            "expires_at": provider_data.get("expires_at"),
            "scope": provider_data.get("scope", [])
        }
    
    return status