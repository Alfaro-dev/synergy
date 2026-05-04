# SERVER CHANGES - E2E Encryption

## Overview

This document describes the minimal changes required on the backend to support end-to-end encryption where **the server never sees decrypted content**.

---

## What Changes (Minimal Approach)

### 1. Remove Key Management

**DELETE:**
- `GET /content/communities/{id}/key` - Server no longer stores/distributes group keys
- `POST /content/communities/{id}/rotate-key` - No server-side key rotation
- Vault storage of community AES keys

**RATIONALE:** The server currently holds all community encryption keys. We need to remove this capability entirely.

---

### 2. New Endpoint: Join Community with Key Exchange

**ADD:** `POST /content/communities/{communityID}/join`

**Request:**
```json
{
  "encrypted_key_request": "base64-encoded-ephemeral-key-encrypted-with-admin-public-key"
}
```

**Response:**
```json
{
  "encrypted_group_key": "base64-encoded-group-key-encrypted-with-member-public-key"
}
```

**Logic:**
1. When a user joins a community, they generate an ephemeral key pair
2. User sends ephemeral public key encrypted with admin's public key
3. Server forwards ephemeral public key to community admin
4. Admin encrypts group key with ephemeral public key → sends back to server
5. Server stores this encrypted group key for the user
6. User decrypts group key with ephemeral private key (never stored)

**Security:** Server stores encrypted blob, cannot decrypt it.

---

### 3. New Endpoint: Request Group Key (for returning members)

**ADD:** `GET /content/communities/{communityID}/key`

**Response:**
```json
{
  "encrypted_group_key": "base64-encoded-group-key-encrypted-with-users-public-key"
}
```

**Logic:**
- Server retrieves stored encrypted group key for this user
- User decrypts with their private key
- **Server NEVER sees the group key**

---

### 4. User Registration: Store Escrow Data

**ADD:** `POST /auth/escrow`

**Request:**
```json
{
  "encrypted_private_key": "base64-encoded-user-private-key-encrypted-with-recovery-key"
}
```

**Response:** `204 No Content`

**Logic:**
- User generates key pair for E2E
- User derives recovery key from wallet
- User encrypts private key with recovery key
- Server stores this blob (cannot decrypt it)

---

### 5. User Login: Recover from Escrow

**ADD:** `GET /auth/escrow`

**Response:**
```json
{
  "encrypted_private_key": "base64-encoded-user-private-key-encrypted-with-recovery-key"
}
```

**Logic:**
- Server returns escrow blob
- User recovers by decrypting with wallet-derived recovery key
- **Server cannot decrypt escrow data**

---

### 6. Remove Author Tracking (for posts)

**MODIFY:** Post storage to NOT include author_id

**BEFORE:**
```json
{
  "cid": "Qm...",
  "author_id": "anon_id_hash",
  "encrypted": true
}
```

**AFTER:**
```json
{
  "cid": "Qm...",
  "encrypted": true
}
```

**RATIONALE:** Even if server is compromised, there's no author to identify.

---

### 7. Reports: Anonymous by Count

**MODIFY:** `POST /content/communities/{id}/posts/{cid}/report`

**Request (simplified):**
```json
{
  "severity": "spam|illegal|csam"
}
```

**Response:**
```json
{
  "status": "received"
}
```

**Change:** Remove any tracking that links reporter to report. Server only stores:
- Post CID
- Report count by severity
- No reporter identity

---

## What Stays the Same

| Endpoint | Action |
|----------|--------|
| `POST /auth/nonce` | Keep |
| `POST /auth/verify` | Keep |
| `GET /communities` | Keep |
| `POST /communities` | Keep |
| `GET /communities/{id}/metadata` | Keep |
| `PATCH /communities/{id}/metadata` | Keep |
| `GET /communities/{id}/posts` | Keep (returns ciphertext only) |
| `GET /content/communities/{id}/posts/{cid}` | Keep (returns ciphertext only) |
| `GET /content/feed` | Keep |
| `GET /profile` | Keep |
| `PUT /profile` | Keep |
| `GET /payments/vending-address` | Keep |
| `GET /payments/communities/{id}/balance` | Keep |

---

## Database Schema Changes

### Remove
- `community_keys` table (or equivalent)
- Any column storing encryption keys

### Add
- `user_escrow` table:
  ```sql
  CREATE TABLE user_escrow (
    anon_id VARCHAR(64) PRIMARY KEY,
    encrypted_key TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
  );
  ```

- `community_members` table (if not exists):
  ```sql
  CREATE TABLE community_members (
    community_id VARCHAR(64) NOT NULL,
    anon_id VARCHAR(64) NOT NULL,
    encrypted_group_key TEXT,
    joined_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (community_id, anon_id)
  );
  ```

### Modify
- `posts` table: REMOVE `author_id` column

---

## Security Properties

After these changes:

| Property | Status |
|----------|--------|
| Server can read content | ❌ IMPOSSIBLE |
| Developer can see content | ❌ IMPOSSIBLE |
| Admin can see content | ❌ IMPOSSIBLE (without breaking escrow) |
| Server knows who posted | ❌ IMPOSSIBLE |
| Server knows who reported | ❌ IMPOSSIBLE |
| User can recover keys | ✅ YES (via escrow + wallet) |
| Monetization possible | ✅ YES (user reveals wallet for payment) |

---

## Implementation Priority

1. **Phase 1:** Add escrow endpoints, remove key endpoint
2. **Phase 2:** Add key exchange endpoint, update member storage
3. **Phase 3:** Remove author_id from posts, update reports
4. **Phase 4:** Testing

---

## Contact

For questions: dev.alberfunes@gmail.com