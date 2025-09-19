from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from motor.motor_asyncio import AsyncIOMotorDatabase
from typing import Optional
from .jwt_handler import verify_token, TokenData  
from .models import User
import os

# Get database from main app (we'll inject this)
from ..server import db

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> User:
    """Get current authenticated user from JWT token"""
    
    # Verify token
    token_data = verify_token(credentials.credentials)
    
    # Get user from database
    user = await db.users.find_one({"username": token_data.username})
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuário não encontrado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    return User(**user)

async def get_current_active_user(
    current_user: User = Depends(get_current_user)
) -> User:
    """Get current active user"""
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="Usuário inativo"
        )
    return current_user

# Optional authentication (for public endpoints that can benefit from user context)
async def get_current_user_optional(
    credentials: HTTPAuthorizationCredentials = Depends(HTTPBearer(auto_error=False))
) -> Optional[User]:
    """Get current user if token is provided, otherwise return None"""
    if credentials is None:
        return None
    
    try:
        token_data = verify_token(credentials.credentials)
        user = await db.users.find_one({"username": token_data.username})
        if user:
            return User(**user)
    except:
        pass  # Invalid token, return None
    
    return None