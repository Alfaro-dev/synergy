# Sinergia API — Guía de integración para Flutter

**Base URL:** `https://sinergia-backend-production.up.railway.app`
**Formato:** JSON (`Content-Type: application/json`) salvo endpoints multipart.
**Zona horaria:** Todos los timestamps son UTC en formato RFC3339Nano (`2026-05-01T14:30:00.000000000Z`).

---

## Convenciones

### Autenticación

| Tipo | Header | Cuándo usarlo |
|------|--------|---------------|
| JWT | `Authorization: Bearer <token>` | Todos los endpoints privados |
| Admin Token | `X-Admin-Token: <token>` | Exclusivo para `/admin/*` |

### Envelope de error

Todos los errores devuelven el mismo envelope:

```json
{ "error": "<error_code>" }
```

### Rate limits

| Scope | Límite | Aplica a |
|-------|--------|----------|
| Por IP | 10 req / 5 min | `/auth/nonce`, rutas públicas |
| Por IP | 5 req / min | `/auth/verify` |
| Por IP | 120 req / min | `/public/feed` |
| Por `anon_id` | 60 req / min | Todas las rutas privadas |

Al exceder el límite el servidor responde `429` con `{ "error": "rate_limit_exceeded" }`.

---

## 1. Autenticación (SIWE)

La plataforma usa **Sign-In with Ethereum (SIWE)**. El backend nunca almacena ni devuelve la wallet address — solo deriva un ID anónimo (`anon_id`) mediante Argon2id con un salt guardado en Vault.

> **No existen refresh tokens.** El JWT tiene TTL de 1 hora. Cuando expire, el cliente debe repetir el flujo completo de nonce → firma → verify.

### Flujo completo

```
Cliente                           Servidor
  |                                  |
  |── GET /auth/nonce ───────────────>|  1. Obtener nonce de un solo uso
  |<── { nonce: "a1b2c3..." } ───────|
  |                                  |
  |  [Usuario firma con su wallet]   |  2. Construir mensaje EIP-4361 y firmar
  |                                  |
  |── POST /auth/verify ────────────>|  3. Enviar mensaje + firma
  |<── { token, expires_at, ... } ──|  4. Recibir JWT (TTL 1h)
```

---

### `GET /auth/nonce`

**Propósito:** Genera un nonce de un solo uso (válido por 5 minutos) para incluir en el mensaje SIWE. Debe pedirse inmediatamente antes de mostrar el modal de firma.

**Headers:** Ninguno.

**Respuesta exitosa `200`:**
```json
{
  "nonce": "a1b2c3d4e5f6a1b2c3d4e5f6"
}
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 429 | `rate_limit_exceeded` | Demasiadas solicitudes desde la misma IP |
| 500 | `internal` | Fallo al generar o guardar el nonce |

---

### `POST /auth/verify`

**Propósito:** Valida el mensaje SIWE y la firma criptográfica. Devuelve un JWT con TTL de 1 hora cuyo `subject` es el `anon_id`. La wallet nunca aparece en la respuesta ni en la base de datos.

**Headers:** Ninguno.

**Payload:**

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `message` | `string` | Sí | Mensaje EIP-4361 completo construido por el cliente |
| `signature` | `string` | Sí | Firma hex (`0x...`) producida por la wallet |

**Construcción del mensaje EIP-4361:**
```
sinergia.app quiere que te autentiques con tu cuenta de Ethereum:
<wallet_address>

Iniciar sesión en Sinergia

URI: https://sinergia.app
Version: 1
Chain ID: 8453
Nonce: <nonce_obtenido_de_GET_nonce>
Issued At: <ISO8601>
```

**Respuesta exitosa `200`:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_at": 1746113400,
  "is_new_user": true
}
```

| Campo | Descripción |
|-------|-------------|
| `token` | JWT a incluir como `Bearer` en subsiguientes requests |
| `expires_at` | Unix timestamp (segundos) de expiración del JWT |
| `is_new_user` | `true` si el usuario no ha completado su perfil vía `PUT /profile`. Usar para redirigir al onboarding |

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `invalid_body` | JSON malformado |
| 400 | `invalid_message` | El mensaje no es un EIP-4361 válido |
| 401 | `invalid_nonce` | El nonce no existe, ya fue usado o expiró |
| 401 | `invalid_signature` | La firma criptográfica no es válida para la wallet |
| 429 | `rate_limit_exceeded` | Límite de 5 req/min por IP alcanzado |
| 503 | `server_busy` | Semáforo Argon2id saturado (máximo de hashes concurrentes) |
| 500 | `internal` | Error de Vault u otro error interno |

---

### `POST /auth/logout`

**Propósito:** Revoca el JWT activo añadiéndolo a la blacklist en Redis. Subsiguientes requests con ese token recibirán `401 token_revoked` hasta que el token expire de forma natural.

**Headers:** `Authorization: Bearer <token>` (obligatorio).

**Payload:** Ninguno.

**Respuesta exitosa `204`:** Sin cuerpo.

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 401 | — | Token inválido o expirado |
| 500 | `internal` | Error al escribir en Redis |

> **Comportamiento fail-open — importante para Flutter:** El logout es un proceso de mejor esfuerzo. El cliente **debe limpiar el JWT del almacenamiento local y redirigir al login independientemente de si la llamada al servidor tiene éxito**. Si el dispositivo no tiene conectividad, el token permanecerá válido en el servidor hasta su expiración natural (máx 1 hora), pero el usuario habrá cerrado su sesión local. No mostrar errores al usuario si esta llamada falla.

```dart
Future<void> logout() async {
  try {
    await api.post('/auth/logout');
  } catch (_) {
    // Ignorar errores de red — la limpieza local es la garantía real
  } finally {
    await storage.delete('jwt');         // siempre
    await storage.delete('expires_at'); // siempre
    navigateToLogin();                  // siempre
  }
}
```

---

## 2. Perfil del Creador

### `PUT /profile`

**Propósito:** Crea o actualiza el perfil público del creador. El `anon_id` vincula el perfil — la wallet nunca se expone. El seudónimo no puede ser una dirección de wallet Ethereum.

**Headers:** `Authorization: Bearer <token>`

**Payload:**

| Campo | Tipo | Obligatorio | Límite | Descripción |
|-------|------|-------------|--------|-------------|
| `pseudonym` | `string` | Sí | 64 chars | Nombre público del creador |
| `bio` | `string` | No | 280 chars | Descripción pública |

```json
{
  "pseudonym": "VoxLibre",
  "bio": "Contenido independiente sobre privacidad digital."
}
```

**Respuesta exitosa `200`:**
```json
{
  "pseudonym": "VoxLibre",
  "bio": "Contenido independiente sobre privacidad digital."
}
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `invalid_body` | JSON malformado |
| 400 | `pseudonym_required` | Campo `pseudonym` vacío |
| 400 | `pseudonym_too_long` | Supera 64 caracteres |
| 400 | `pseudonym_cannot_be_wallet` | El seudónimo parece una wallet Ethereum (`0x...`) |
| 400 | `bio_too_long` | Supera 280 caracteres |
| 401 | `unauthorized` | JWT inválido o ausente |

---

### `GET /profile/membership`

**Propósito:** Devuelve todas las comunidades del usuario en un solo call: las que creó, las de pago con suscripción activa y las gratuitas a las que se unió. Es el endpoint principal para construir la barra lateral o el Home.

**Headers:** `Authorization: Bearer <token>`

**Respuesta exitosa `200`:**
```json
{
  "memberships": [
    {
      "community_id": "550e8400-e29b-41d4-a716-446655440000",
      "metadata_cid": "QmMetaAbCdEf...",
      "role": "creator"
    },
    {
      "community_id": "a1b2c3d4...",
      "metadata_cid": "QmMetaXyZ...",
      "role": "subscriber",
      "expires_at": "2026-06-01T00:00:00Z"
    },
    {
      "community_id": "f1e2d3c4...",
      "metadata_cid": "QmMeta123...",
      "role": "member",
      "joined_at": "2026-05-01T12:00:00Z"
    }
  ]
}
```

| Campo | Descripción |
|-------|-------------|
| `role` | `"creator"` \| `"subscriber"` (pago activo) \| `"member"` (gratuita) |
| `expires_at` | Solo presente para `role=subscriber`. Expiración de la suscripción on-chain |
| `joined_at` | Solo presente para `role=member`. Fecha de unión a la comunidad gratuita |

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 401 | `unauthorized` | JWT inválido o ausente |

---

### `GET /profile`

**Propósito:** Devuelve el perfil del usuario autenticado.

**Headers:** `Authorization: Bearer <token>`

**Respuesta exitosa `200`:**
```json
{
  "pseudonym": "VoxLibre",
  "bio": "Contenido independiente sobre privacidad digital.",
  "avatar_cid": "QmXyZ..."
}
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 401 | `unauthorized` | JWT inválido o ausente |
| 404 | `no_profile` | El usuario aún no ha creado su perfil |

---

### `PATCH /profile/avatar`

**Propósito:** Sube una imagen de avatar del creador. El backend elimina automáticamente metadatos EXIF/IPTC antes de subir a IPFS.

**Headers:** `Authorization: Bearer <token>`, `Content-Type: multipart/form-data`

**Payload (form-data):**

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `avatar` | `file` | Sí | Imagen JPEG, PNG o WebP. Máx 5 MB |

**Respuesta exitosa `200`:**
```json
{
  "avatar_cid": "QmAbCdEfGhIjKlMnOpQrStUvWxYz..."
}
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `missing_avatar` | Campo `avatar` no incluido |
| 400 | `file_too_large` | Supera 5 MB |
| 400 | `unsupported_file_type` | Formato no soportado o archivo corrupto |
| 401 | `unauthorized` | JWT inválido o ausente |
| 500 | `ipfs_unavailable` | Error al subir a IPFS |

---

## 3. Comunidades

### `GET /communities`

**Propósito:** Discovery de comunidades públicas con perfil publicado. Solo aparecen comunidades `active=true`, `is_public=true` y con `metadata_cid` poblado. Paginación por cursor. Soporta búsqueda y filtrado por categoría.

**Headers:** `Authorization: Bearer <token>`

**Query params:**

| Param | Tipo | Descripción |
|-------|------|-------------|
| `before` | RFC3339Nano | Cursor de paginación. Omitir para la primera página |
| `search` | `string` | Texto libre. Filtra por nombre de comunidad o seudónimo del creador (full-text) |
| `category` | `string` | Filtra por categoría exacta (ver `GET /categories`) |

**Respuesta exitosa `200`:**
```json
{
  "communities": [
    {
      "community_id": "a1b2c3d4e5f6...",
      "metadata_cid": "QmMetaAbCdEf...",
      "created_at": "2026-04-15T10:30:00.000000000Z",
      "members_count": 142,
      "posts_count": 37
    }
  ],
  "has_more": true,
  "next_before": "2026-04-15T10:30:00.000000000Z"
}
```

Para paginar: pasar `next_before` como `?before=` en la siguiente llamada. Cuando `has_more=false`, se llegó al final.

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `invalid_before_cursor` | Formato del cursor inválido |
| 401 | `unauthorized` | JWT inválido o ausente |

---

### `GET /categories`

**Propósito:** Devuelve la lista de categorías válidas para etiquetar comunidades. Usar en Flutter para mostrar chips de filtrado en el discovery.

**Headers:** `Authorization: Bearer <token>`

**Respuesta exitosa `200`:**
```json
{
  "categories": [
    "Arte", "Bienestar", "Ciencia", "Deportes", "Educación",
    "Entretenimiento", "Música", "Negocios", "Otro", "Periodismo",
    "Política", "Tecnología"
  ]
}
```

> El orden puede variar (map de Go). Ordenar en cliente antes de renderizar.

---

### `POST /communities`

**Propósito:** Crea una comunidad gratuita (`type=free`) directamente en la base de datos, sin pasar por el smart contract. El contenido no se encripta. Para crear una comunidad de pago (con suscripción on-chain), el creador debe registrarla en el contrato `SinergiaEscrow` directamente desde su wallet.

**Headers:** `Authorization: Bearer <token>`

**Payload:**

| Campo | Tipo | Obligatorio | Límite | Descripción |
|-------|------|-------------|--------|-------------|
| `name` | `string` | Sí | 64 chars | Nombre público de la comunidad |
| `bio` | `string` | No | 280 chars | Descripción pública |
| `category` | `string` | No | — | Categoría de la comunidad. Debe ser un valor de `GET /categories` |

```json
{
  "name": "Periodismo Libre",
  "bio": "Noticias sin filtros.",
  "category": "Periodismo"
}
```

**Respuesta exitosa `201`:**
```json
{
  "community_id": "550e8400-e29b-41d4-a716-446655440000",
  "metadata_cid": "QmMetaAbCdEf..."
}
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `invalid_body` | JSON malformado |
| 400 | `name_required` | Campo `name` vacío |
| 400 | `name_too_long` | Supera 64 caracteres |
| 400 | `bio_too_long` | Supera 280 caracteres |
| 400 | `invalid_category` | La categoría no existe en la lista válida |
| 401 | `unauthorized` | JWT inválido o ausente |
| 500 | `ipfs_unavailable` | Error al subir metadatos a IPFS |

---

### `GET /communities/{communityID}/metadata`

**Propósito:** Proxy del JSON de metadatos de la comunidad almacenado en IPFS. Devuelve nombre, bio, `avatar_cid` y contadores en tiempo real.

**Headers:** `Authorization: Bearer <token>`

**Respuesta exitosa `200`** (con `Cache-Control: public, max-age=60`):
```json
{
  "name": "Periodismo Libre",
  "bio": "Noticias sin filtros.",
  "avatar_cid": "QmAvatarAbCdEf...",
  "members_count": 142,
  "posts_count": 37
}
```

> `members_count` suma suscriptores de pago activos + miembros gratuitos. `posts_count` excluye posts borrados. El `Cache-Control` es de 60 segundos (antes era 300) para que los contadores no queden obsoletos.

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 401 | `unauthorized` | JWT inválido o ausente |
| 404 | `no_metadata` | La comunidad no ha publicado su perfil aún |
| 500 | `ipfs_unavailable` | Error al leer de IPFS |

---

### `PATCH /communities/{communityID}/metadata`

**Propósito:** Publica o actualiza el perfil público de la comunidad. Solo el creador puede llamarlo. Si ya existe un `avatar_cid`, se preserva automáticamente.

**Headers:** `Authorization: Bearer <token>`

**Payload:**

| Campo | Tipo | Obligatorio | Límite |
|-------|------|-------------|--------|
| `name` | `string` | Sí | 64 chars |
| `bio` | `string` | No | 280 chars |

**Respuesta exitosa `200`:**
```json
{
  "metadata_cid": "QmMetaNuevo..."
}
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `invalid_body \| name_required \| name_too_long \| bio_too_long` | Validación |
| 401 | `unauthorized` | JWT inválido o ausente |
| 403 | `not_community_creator` | El usuario no es el creador |
| 500 | `ipfs_unavailable` | Error al subir a IPFS |

---

### `PATCH /communities/{communityID}/avatar`

**Propósito:** Sube el avatar de la comunidad. El backend elimina EXIF, sube la imagen a IPFS y actualiza el `metadata_cid` de la comunidad. Solo el creador puede llamarlo.

**Headers:** `Authorization: Bearer <token>`, `Content-Type: multipart/form-data`

**Payload (form-data):**

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `avatar` | `file` | Sí | JPEG, PNG o WebP. Máx 5 MB |

**Respuesta exitosa `200`:**
```json
{
  "avatar_cid": "QmAvatarNuevo..."
}
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `missing_avatar \| file_too_large \| unsupported_file_type` | Validación del archivo |
| 401 | `unauthorized` | JWT inválido o ausente |
| 403 | `not_community_creator` | El usuario no es el creador |

---

### `PATCH /communities/{communityID}/visibility`

**Propósito:** Cambia si la comunidad aparece en el discovery público o es invite-only. Solo el creador puede llamarlo.

**Headers:** `Authorization: Bearer <token>`

**Payload:**

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `is_public` | `bool` | Sí | `true` = aparece en discovery, `false` = privada |

**Respuesta exitosa `200`:**
```json
{
  "is_public": false
}
```

---

### `GET /communities/{communityID}/creator-profile`

**Propósito:** Devuelve el perfil público del creador de una comunidad sin exponer su `anon_id`. Útil para mostrar la identidad del creador en la página de una comunidad.

**Headers:** `Authorization: Bearer <token>`

**Respuesta exitosa `200`** (con `Cache-Control: public, max-age=300`):
```json
{
  "pseudonym": "VoxLibre",
  "bio": "Contenido independiente.",
  "avatar_cid": "QmAvatarAbCdEf..."
}
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 404 | `community_not_found` | La comunidad no existe |
| 404 | `no_profile` | El creador no ha creado su perfil |

---

### `POST /communities/{communityID}/join`

**Propósito:** Une al usuario a una comunidad gratuita con un solo clic. Para comunidades de pago, el acceso se otorga automáticamente vía suscripción on-chain — no usar este endpoint.

**Headers:** `Authorization: Bearer <token>`

**Payload:** Ninguno.

**Respuesta exitosa `200`:**
```json
{ "status": "joined" }
```

Si el usuario ya era miembro, la respuesta es igualmente `200` (idempotente).

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 401 | `unauthorized` | JWT inválido o ausente |
| 403 | `paid_community` | La comunidad es de pago; el acceso requiere suscripción on-chain |
| 404 | `not_found` | La comunidad no existe o no está activa |

---

## 4. Contenido

### Modelo de cifrado

Los posts de comunidades de pago se cifran con **AES-256-GCM** antes de subir a IPFS. La clave vive en Vault y el servidor **nunca sirve contenido descifrado**. El cliente descifra localmente con la clave obtenida de `GET /key`.

Cada comunidad puede tener múltiples versiones de su clave (tras rotaciones). El campo `key_version` en cada post indica qué versión se usó para cifrarlo — necesario para solicitar la clave correcta.

---

### `GET /public/feed`

**Propósito:** Feed público sin autenticación. Devuelve los últimos posts de comunidades públicas activas y posts globales. `has_access` siempre es `false` (sin sesión). Rate-limited por IP.

**Headers:** Ninguno.

**Query params:**

| Param | Tipo | Descripción |
|-------|------|-------------|
| `before` | RFC3339Nano | Cursor de paginación |
| `limit` | `integer` | Posts por página (default 20, máx 50) |

**Respuesta exitosa `200`:**
```json
{
  "posts": [
    {
      "community_id": "a1b2c3...",
      "metadata_cid": "QmMeta...",
      "cid": "QmPostBinario...",
      "encrypted": true,
      "has_access": false,
      "title": "Titular del post",
      "created_at": "2026-05-01T12:00:00.000000000Z"
    }
  ],
  "has_more": true,
  "next_before": "2026-05-01T12:00:00.000000000Z"
}
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `invalid_before_cursor` | Cursor malformado |
| 429 | `rate_limit_exceeded` | Más de 120 req/min por IP |

---

### `GET /content/feed`

**Propósito:** Feed global autenticado. Igual que `/public/feed` pero `has_access` refleja el estado real de suscripción del usuario en cada comunidad (verificado en DB, sin llamadas on-chain por post).

**Headers:** `Authorization: Bearer <token>`

**Query params:**

| Param | Tipo | Descripción |
|-------|------|-------------|
| `before` | RFC3339Nano | Cursor de paginación |

**Respuesta exitosa `200`:** Mismo formato que `/public/feed` con `has_access` real.

---

### `GET /content/communities/{communityID}/posts`

**Propósito:** Lista los posts de una comunidad en orden cronológico descendente. Incluye `key_version` para que el cliente pueda solicitar la versión correcta de la clave de descifrado.

**Headers:** `Authorization: Bearer <token>`

**Query params:**

| Param | Tipo | Descripción |
|-------|------|-------------|
| `before` | RFC3339Nano | Cursor de paginación |

**Respuesta exitosa `200`:**
```json
{
  "posts": [
    {
      "cid": "QmPostBinario...",
      "author_id": "a1b2c3d4...",
      "encrypted": true,
      "key_version": 2,
      "title": "Artículo exclusivo",
      "body": "Introducción del artículo...",
      "author": {
        "pseudonym": "VoxLibre",
        "avatar_cid": "QmAvatarAbCdEf..."
      },
      "created_at": "2026-05-01T12:00:00.000000000Z"
    }
  ],
  "has_more": false
}
```

> `title` y `body` ya vienen descifrados por el servidor (cifrado personal del autor). Solo el binario en IPFS (`cid`) requiere descifrado local con la clave de la comunidad.

---

### `GET /content/communities/{communityID}/key`

**Propósito:** Entrega la clave AES-256 necesaria para descifrar el contenido de IPFS. **El contrato on-chain confirma que la suscripción está activa antes de entregar la clave.** Si se pasa `?version=N`, devuelve la versión histórica correspondiente al `key_version` del post.

**Headers:** `Authorization: Bearer <token>`

**Query params:**

| Param | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `version` | `integer` | No | Versión de la clave (omitir para la clave activa). Usar el `key_version` del post listado |

**Respuesta exitosa `200`:**
```json
{
  "key": "<bytes_hex_de_la_clave_AES>",
  "version": 2
}
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `invalid_version` | `?version` no es un entero positivo |
| 401 | `unauthorized` | JWT inválido o ausente |
| 403 | `no_active_subscription` | El contrato on-chain no confirma suscripción activa |
| 404 | `version_not_found` | La versión solicitada no existe en Vault |
| 500 | `internal` | Error de Vault o RPC |

#### Flujo completo de descifrado de contenido

```
1. GET /content/communities/{id}/posts
   → posts[n].cid          = "QmPostBinario..."
   → posts[n].key_version  = 2       ← guardar este valor
   → posts[n].encrypted    = true

2. GET /content/communities/{id}/key?version=2
   → key = "<hex_de_32_bytes>"

3. GET /content/communities/{id}/posts/{cid}
   → Respuesta binaria (stream)
   → Header X-Encrypted: true

4. [Cliente] AES-256-GCM decrypt(binario, hex.decode(key))
   → Contenido descifrado listo para mostrar
```

> Si el creador rota la clave (`POST /rotate-key`), los posts antiguos conservan su `key_version` original. El cliente siempre debe pasar `?version=<key_version_del_post>` para obtener la clave correcta.

---

### `GET /content/communities/{communityID}/posts/{cid}`

**Propósito:** Descarga el binario de un post desde IPFS. Si el post está cifrado, el cuerpo es el blob AES-256-GCM y el cliente debe descifrarlo localmente. El header `X-Encrypted` indica el estado.

**Headers:** `Authorization: Bearer <token>`

**Respuesta exitosa `200`:**
- Body: stream binario
- `X-Encrypted: true | false`
- `Cache-Control: private, max-age=3600`

**Manejo de MIME type según `X-Encrypted`:**

| `X-Encrypted` | `Content-Type` de respuesta | Qué debe hacer el cliente |
|---------------|-----------------------------|---------------------------|
| `false` | Tipo real detectado por el servidor (`image/jpeg`, `video/mp4`, etc.) | Usar el `Content-Type` directamente para renderizar |
| `true` | Siempre `application/octet-stream` | **Ignorar el `Content-Type`**. Tras descifrar, detectar el tipo real por los magic bytes del resultado |

```dart
// Detección de MIME por magic bytes tras descifrar
String sniffMimeType(Uint8List bytes) {
  if (bytes.length < 4) return 'application/octet-stream';
  // JPEG
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
  // PNG
  if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'image/png';
  // WebP (RIFF....WEBP)
  if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[8] == 0x57 && bytes[9] == 0x45) return 'image/webp';
  // MP4
  if (bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) return 'video/mp4';
  return 'application/octet-stream';
}
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 401 | `unauthorized` | JWT inválido o ausente |
| 404 | `not_found` | CID no encontrado para esta comunidad |
| 451 | `content_removed` | CID en lista negra del administrador |
| 503 | `server_busy` | Límite de 10 descargas simultáneas alcanzado |

---

### `POST /content/communities/{communityID}/posts`

**Propósito:** Sube contenido a una comunidad. Solo el creador puede publicar. El backend sanitiza metadatos EXIF y cifra automáticamente si la comunidad es de pago.

**Headers:** `Authorization: Bearer <token>`, `Content-Type: multipart/form-data`

**Payload (form-data):**

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `file` | `file` | Sí | Imagen o video. Máx 20 MB |
| `title` | `string` | No | Título del post (se cifra con clave personal del autor) |
| `body` | `string` | No | Cuerpo del post (se cifra con clave personal del autor) |

**Respuesta exitosa `201`:**
```json
{
  "cid": "QmPostBinario...",
  "encrypted": true
}
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `missing_file \| file_too_large \| unsupported_file_type` | Validación del archivo |
| 401 | `unauthorized` | JWT inválido o ausente |
| 403 | `not_community_creator` | Solo el creador puede publicar |
| 409 | `duplicate_post` | El mismo autor ya publicó el mismo contenido en esta comunidad |
| 500 | `ipfs_unavailable` | Error al subir a IPFS |

---

### `POST /content/communities/{communityID}/rotate-key`

**Propósito:** Genera una nueva versión de la clave AES de la comunidad en Vault. El contenido histórico sigue siendo descifrable con su `key_version` original. Solo disponible para comunidades de pago. Solo el creador puede ejecutarlo.

**Headers:** `Authorization: Bearer <token>`

**Payload:** Ninguno.

**Respuesta exitosa `200`:**
```json
{
  "new_version": 3
}
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 401 | `unauthorized` | JWT inválido o ausente |
| 403 | `not_community_creator` | El usuario no es el creador |
| 403 | `free_community` | Las comunidades gratuitas no cifran contenido |

---

### `POST /content/posts`

**Propósito:** Publica un post global de usuario (sin comunidad). Cualquier usuario autenticado puede publicar. El contenido nunca se cifra. El archivo es opcional — se aceptan posts de solo texto.

**Headers:** `Authorization: Bearer <token>`, `Content-Type: multipart/form-data`

**Payload (form-data):**

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `file` | `file` | No | Imagen o video. Máx 20 MB |
| `title` | `string` | No | Título (al menos uno de `file`, `title` o `body` es requerido) |
| `body` | `string` | No | Cuerpo del post |

**Respuesta exitosa `201`:**
```json
{
  "cid": "QmPostGlobal...",
  "encrypted": false
}
```

> Para posts de solo texto sin archivo: `cid` no aparece en la respuesta.

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `missing_content` | No se envió `file`, `title` ni `body` |
| 400 | `file_too_large \| unsupported_file_type` | Validación del archivo |
| 409 | `duplicate_post` | Misma combinación de título/cuerpo/archivo ya publicada |

---

### `GET /content/posts/{cid}`

**Propósito:** Descarga un post global desde IPFS. El contenido nunca está cifrado en posts globales.

**Headers:** `Authorization: Bearer <token>`

**Respuesta exitosa `200`:** Stream binario con `X-Encrypted: false`.

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 404 | `not_found` | CID no existe como post global |
| 451 | `content_removed` | CID en lista negra |
| 503 | `server_busy` | Límite de streams simultáneos |

---

### `POST /content/communities/{communityID}/posts/{cid}/report`

**Propósito:** Reporta un post de una comunidad. Para evitar report bombing, solo puede reportar quien tiene **suscripción activa** en la comunidad o es su creador — garantiza que el reporter realmente puede ver el contenido que denuncia.

**Headers:** `Authorization: Bearer <token>`

**Payload:**

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `severity` | `string` | Sí | `"spam"` \| `"illegal"` \| `"csam"` |
| `phash` | `string` | No | Hash perceptual (dHash/pHash) del contenido descifrado localmente. Permite comparar contra bases de datos sin enviar el contenido |
| `witness_enc` | `string` | No | Contenido re-encriptado con la clave pública del admin para revisión humana (casos graves). Ver protocolo completo en Apéndice D |

```json
{
  "severity": "illegal",
  "phash": "f3a4b5c6d7e8f9a0",
  "witness_enc": "base64..."
}
```

**Respuesta exitosa `202`:**
```json
{ "status": "received" }
```

Si el usuario lleva 4 strikes (un dismiss más lo banearía), la respuesta incluye un campo adicional:
```json
{
  "status": "received",
  "warning": "Has alcanzado 4 reportes falsos. Uno más y perderás el acceso a esta función."
}
```
Muéstrale este aviso al usuario de forma visible antes de cerrar la pantalla.

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `invalid_body \| invalid_severity` | Validación |
| 401 | `unauthorized` | JWT inválido o ausente |
| 403 | `no_access` | El usuario no tiene suscripción activa en la comunidad |
| 403 | `reporting_access_denied` | El usuario acumuló 5 reportes falsos y perdió acceso |

---

### `POST /content/posts/{cid}/report`

**Propósito:** Reporta un post global. Cualquier usuario autenticado puede reportar (los posts globales son públicos).

**Headers:** `Authorization: Bearer <token>`

**Payload:** Igual que `ReportCommunityPost` (sin restricción de suscripción).

**Respuesta exitosa `202`:** Igual que `ReportCommunityPost` — incluye `"warning"` si el usuario lleva 4 strikes.

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `invalid_body \| invalid_severity` | Validación |
| 401 | `unauthorized` | JWT inválido o ausente |
| 403 | `reporting_access_denied` | El usuario acumuló 5 reportes falsos y perdió acceso |

---

### `PATCH /content/communities/{communityID}/posts/{cid}`

**Propósito:** Edita el título y/o body de un post ya publicado. Solo el autor puede editar. El binario en IPFS no se modifica — solo se actualizan los campos de texto en la base de datos.

> Los campos `title` y `body` se re-cifran con la clave personal del autor (gestionada por Vault). El cliente los descifra igual que siempre usando `GET /content/communities/{id}/key` + la postKey del autor.

**Headers:** `Authorization: Bearer <token>`

**Payload** (al menos uno de los dos campos es obligatorio):

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `title` | `string` | Nuevo título del post |
| `body` | `string` | Nuevo cuerpo del post |

```json
{
  "title": "Título corregido",
  "body": "Cuerpo actualizado con más contexto."
}
```

**Respuesta exitosa `200`:**
```json
{ "status": "updated" }
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `invalid_body` | JSON malformado |
| 400 | `nothing_to_update` | Ningún campo enviado |
| 401 | `unauthorized` | JWT inválido o ausente |
| 403 | `forbidden` | El usuario no es el autor del post |
| 404 | `not_found` | Post no encontrado o ya borrado |

---

### `DELETE /content/communities/{communityID}/posts/{cid}`

**Propósito:** Borra un post de forma lógica (soft-delete). El post desaparece de todos los feeds y listados. El binario en IPFS permanece (IPFS es inmutable por diseño). Solo el autor o el creador de la comunidad pueden borrar.

**Headers:** `Authorization: Bearer <token>`

**Respuesta exitosa `200`:**
```json
{ "status": "deleted" }
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 401 | `unauthorized` | JWT inválido o ausente |
| 403 | `forbidden` | El usuario no es el autor ni el creador de la comunidad |
| 404 | `not_found` | Post no encontrado o ya borrado |

---

## 5. Pagos (Vending Machine)

### Modelo de pagos

El sistema usa una **Vending Machine** para desacoplar la identidad del suscriptor de sus transacciones on-chain:

```
Suscriptor                      Backend                    Contrato SinergiaEscrow
    |                              |                                |
    |── GET /payments/             |                                |
    |      vending-address ───────>|  Deriva dirección única HD     |
    |<── { address: "0x..." } ────|  determinística por anon_id    |
    |                              |                                |
    |  Transfiere USDC a 0x... ───────────────────────────────────>|
    |  (ERC-20, no requiere        |                                |
    |   approve previo)            |                                |
    |                              |<── Sweeper detecta balance ────|
    |                              |    Sweep: approve + deposit()  |
    |                              |    cada 30 segundos            |
    |                              |                                |
    |                              |<── Evento Deposited emitido ───|
    |                              |    (12 confirmaciones para     |
    |                              |     protección anti-reorg)     |
```

> **Protección anti-reorg:** El backend espera **12 confirmaciones** antes de acreditar el depósito internamente. En Base L2 esto equivale a ~3 minutos. El suscriptor puede verificar su suscripción activa en el contrato una vez que el listener lo procese.

### `GET /payments/vending-address`

**Propósito:** Devuelve la dirección EVM única y permanente del usuario para depositar USDC. La dirección es **determinística** — mismo `anon_id` + mismo `masterSeed` = misma dirección siempre. Si se pierde el token JWT, la dirección se puede recuperar volviendo a autenticarse.

**Headers:** `Authorization: Bearer <token>`

**Respuesta exitosa `200`:**
```json
{
  "address": "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
}
```

**Flujo de pago completo:**

1. `GET /payments/vending-address` → obtener `address`
2. Cliente envía USDC ERC-20 a `address` (transfer estándar, sin approve)
3. El sweeper detecta el balance cada 30 segundos y ejecuta `approve + deposit()` en el contrato
4. Tras 12 confirmaciones, el evento `Deposited` se procesa y el balance interno se acredita
5. El contrato actualiza la suscripción del usuario a la comunidad objetivo

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 401 | `unauthorized` | JWT inválido o ausente |
| 500 | `internal_error` | Error al derivar o cachear la dirección |

---

### `GET /payments/communities/{communityID}/balance`

**Propósito:** Lee el balance acumulado del creador directamente del mapping `creatorBalance` del contrato. Informa cuánto puede retirar el creador llamando `withdraw()` en el contrato desde su wallet.

> **El backend no ejecuta retiros.** El creador llama `withdraw()` directamente desde su wallet — el servidor solo informa el saldo disponible.

**Headers:** `Authorization: Bearer <token>`

**Path params:**

| Param | Descripción |
|-------|-------------|
| `communityID` | `bytes32` hex de 64 caracteres, sin prefijo `0x` |

**Respuesta exitosa `200`:**
```json
{
  "community_id": "a1b2c3d4e5f6...",
  "balance_wei": "1500000000000000000"
}
```

> `balance_wei` es un string para evitar overflow de enteros de 256 bits. Dividir por `1e18` para ETH equivalente o por `1e6` para USDC (6 decimales).

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `invalid_community_id` | El ID no tiene 64 caracteres hex |
| 401 | `unauthorized` | JWT inválido o ausente |
| 500 | `internal_error` | Error al leer el contrato vía RPC |

---

## 6. Administración

Todos los endpoints `/admin/*` requieren el header `X-Admin-Token: <token>` (configurado en la variable de entorno `ADMIN_TOKEN` del backend). Si el token está vacío o es incorrecto, la respuesta es `401 unauthorized`.

### `GET /admin/reports`

**Propósito:** Lista reportes de contenido filtrados por estado. Vista principal de moderación.

**Headers:** `X-Admin-Token: <token>`

**Query params:**

| Param | Valores | Default |
|-------|---------|---------|
| `status` | `pending` \| `actioned` \| `dismissed` | `pending` |

**Respuesta exitosa `200`:**
```json
{
  "reports": [
    {
      "id": 42,
      "cid": "QmPostAbCdEf...",
      "severity": "illegal",
      "reporter_id": "a1b2c3d4...",
      "witness_enc": "base64...",
      "status": "pending",
      "created_at": "2026-05-02T15:00:00Z"
    }
  ]
}
```

---

### `POST /admin/reports/{id}/action`

**Propósito:** Toma una acción sobre un reporte pendiente.

- `blacklist`: bloquea el CID (aparece como `451` para cualquier usuario), hace unpin en Pinata y marca el reporte como `actioned`.
- `dismiss`: descarta el reporte y aplica un **strike automático** al reporter. Al quinto strike, el reporter queda baneado de reportar.

**Headers:** `X-Admin-Token: <token>`

**Payload:**

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `action` | `string` | `"blacklist"` \| `"dismiss"` |
| `reason` | `string` | Motivo (requerido para `blacklist`) |

```json
{ "action": "dismiss" }
```

**Respuesta exitosa `200`:**
```json
{ "status": "dismissed" }
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `invalid_request \| invalid_action` | Validación |
| 404 | `not_found` | Reporte no encontrado o ya procesado |

---

### `PATCH /admin/reporters/{anonID}`

**Propósito:** Gestiona los strikes de un reporter. Permite levantar un baneo por error o resetear el contador completo.

**Headers:** `X-Admin-Token: <token>`

**Payload** (al menos uno de los dos campos):

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `banned` | `bool` | `false` para levantar el baneo sin resetear el contador |
| `reset_strikes` | `bool` | `true` para poner el contador a 0 y levantar el baneo |

```json
{ "reset_strikes": true }
```

**Respuesta exitosa `200`:**
```json
{ "status": "updated" }
```

**Errores:**

| Código | `error` | Causa |
|--------|---------|-------|
| 400 | `invalid_request` | Body vacío o ningún campo válido |
| 404 | `not_found` | El usuario no tiene strikes registrados |

---

### `GET /admin/blacklist`

**Propósito:** Lista todos los CIDs bloqueados.

**Headers:** `X-Admin-Token: <token>`

---

### `POST /admin/blacklist`

**Propósito:** Bloquea un CID manualmente (sin reporte previo).

**Headers:** `X-Admin-Token: <token>`

**Payload:** `{ "cid": "QmAbC...", "reason": "motivo" }`

---

### `DELETE /admin/blacklist/{cid}`

**Propósito:** Desbloquea un CID.

**Headers:** `X-Admin-Token: <token>`

---

### `GET /admin/metrics`

**Propósito:** Métricas del sistema en JSON: estado de Vault, TTL del token, blockchain, sweeper, contenido y comunidades.

**Headers:** `X-Admin-Token: <token>`

---

### `GET /admin/monitor`

**Propósito:** Dashboard de monitoreo en tiempo real (HTML). Accesible en el navegador.

**Headers:** `X-Admin-Token` como query param `?token=` (EventSource no soporta headers personalizados).

---

## 8. Health Check

### `GET /health`

**Propósito:** Verificación de salud del sistema. Comprueba que Vault sea accesible y esté unsealed. Si Vault está caído, el backend no puede autenticar usuarios — reporta `503`.

**Headers:** Ninguno.

**Respuesta exitosa `200`:** Sin cuerpo.

**Respuesta degradada `503`:**
```json
{
  "status": "degraded",
  "vault": "vault inalcanzable: connection refused"
}
```

---

## Apéndice A — Tabla de errores comunes

| `error` | Código HTTP | Descripción |
|---------|-------------|-------------|
| `unauthorized` | 401 | JWT ausente, malformado o expirado |
| `token_revoked` | 401 | JWT revocado vía `POST /auth/logout` |
| `invalid_nonce` | 401 | Nonce ya usado, expirado o inexistente |
| `invalid_signature` | 401 | Firma SIWE inválida para la wallet |
| `not_community_creator` | 403 | Acción restringida al creador de la comunidad |
| `no_active_subscription` | 403 | El contrato on-chain no confirma suscripción |
| `no_access` | 403 | Sin suscripción activa ni rol de creador |
| `free_community` | 403 | Operación no disponible en comunidades gratuitas |
| `paid_community` | 403 | Operación exclusiva de comunidades de pago (ej: join es solo para free) |
| `reporting_access_denied` | 403 | El usuario acumuló 5 reportes falsos y perdió acceso a reportar |
| `forbidden` | 403 | El usuario no tiene permisos para esta acción sobre el recurso |
| `not_found` | 404 | CID o recurso no encontrado |
| `content_removed` | 451 | CID en lista negra por el administrador |
| `duplicate_post` | 409 | El mismo contenido ya fue publicado por este usuario |
| `rate_limit_exceeded` | 429 | Límite de requests alcanzado |
| `server_busy` | 503 | Semáforo saturado (Argon2id o streams IPFS) |
| `ipfs_unavailable` | 500 | Error al leer o escribir en IPFS |
| `internal` | 500 | Error interno no clasificado |

---

## Apéndice B — Paginación por cursor

Todos los endpoints de listado usan el mismo patrón:

```dart
// Primera página
final res = await api.get('/content/communities/{id}/posts');
final posts = res['posts'];
final hasMore = res['has_more'];
String? cursor = res['next_before'];

// Páginas siguientes
while (hasMore && cursor != null) {
  final res = await api.get('/content/communities/{id}/posts?before=$cursor');
  posts.addAll(res['posts']);
  hasMore = res['has_more'];
  cursor = res['next_before'];
}
```

---

## Apéndice C — Descifrado en Flutter

```dart
import 'dart:convert';
import 'package:pointycastle/export.dart';

Uint8List decryptAesGcm(Uint8List ciphertext, String keyHex) {
  // La clave viene como hex de 32 bytes (256 bits)
  final key = Uint8List.fromList(
    List.generate(32, (i) => int.parse(keyHex.substring(i * 2, i * 2 + 2), radix: 16))
  );

  // Formato del ciphertext: [12 bytes nonce][N bytes ciphertext+tag]
  final nonce = ciphertext.sublist(0, 12);
  final data  = ciphertext.sublist(12);

  final cipher = GCMBlockCipher(AESEngine())
    ..init(false, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));

  return cipher.process(data);
}
```

**Flujo completo en Dart:**
```dart
// 1. Listar posts y extraer key_version
final posts = await api.listPosts(communityId);
final post = posts.first;

// 2. Obtener la clave correspondiente a key_version
final keyResponse = await api.getContentKey(communityId, version: post.keyVersion);
final keyHex = keyResponse['key'] as String;

// 3. Descargar el blob cifrado de IPFS
final cipherBytes = await api.getPost(communityId, post.cid);

// 4. Descifrar localmente
final plainBytes = decryptAesGcm(cipherBytes, keyHex);

// 5. Mostrar — plainBytes es el archivo multimedia original (EXIF ya eliminado por el servidor)
```

---

## Apéndice D — Protocolo Witness (Moderación)

El campo `witness_enc` permite al reportador re-encriptar el contenido descifrado localmente con la clave pública del administrador. Solo el admin puede leer el resultado. El servidor nunca ve el contenido en claro.

### Clave pública del administrador

La clave pública del admin es una constante **embebida en el binario de la app en tiempo de compilación**, no un endpoint de red. Esto evita ataques MITM en los que un intermediario sustituya la clave antes de que el cliente la use para cifrar evidencia.

```dart
// lib/constants/admin_keys.dart
// Actualizar esta constante cuando el admin rote su par de llaves.
// Formato: RSA-OAEP 2048-bit, PEM.
const String kAdminPublicKeyPem = '''
-----BEGIN PUBLIC KEY-----
<PEGAR_AQUI_LA_CLAVE_PUBLICA_RSA_DEL_ADMIN>
-----END PUBLIC KEY-----
''';
```

> **Procedimiento de actualización de la clave:** Cuando el admin genere un nuevo par de llaves, debe distribuir la clave pública al equipo de Flutter para actualizar esta constante y publicar una nueva versión de la app. La clave privada correspondiente nunca sale del entorno del administrador.

### Cuándo incluir `witness_enc`

| `severity` | ¿Incluir `witness_enc`? | Justificación |
|------------|-------------------------|---------------|
| `spam` | No | El admin puede actuar solo con el `phash` y el CID |
| `illegal` | Opcional | Recomendado si el contenido es inequívoco |
| `csam` | Sí, obligatorio | El admin necesita contexto para escalar a autoridades |

### Implementación en Flutter

```dart
import 'package:pointycastle/export.dart';
import 'package:asn1lib/asn1lib.dart';

// 1. Descifrar el contenido localmente (ya tienes plainBytes del flujo normal)
final plainBytes = decryptAesGcm(cipherBytes, keyHex);

// 2. Cargar la clave pública del admin embebida
RSAPublicKey loadAdminPublicKey() {
  final pemBody = kAdminPublicKeyPem
    .replaceAll('-----BEGIN PUBLIC KEY-----', '')
    .replaceAll('-----END PUBLIC KEY-----', '')
    .replaceAll('\n', '').trim();

  final derBytes = base64.decode(pemBody);
  final asn1Parser = ASN1Parser(Uint8List.fromList(derBytes));
  final topSeq = asn1Parser.nextObject() as ASN1Sequence;
  final bitString = topSeq.elements[1] as ASN1BitString;
  final pubKeyParser = ASN1Parser(bitString.contentBytes()!);
  final pubKeySeq = pubKeyParser.nextObject() as ASN1Sequence;

  final modulus = (pubKeySeq.elements[0] as ASN1Integer).valueAsBigInteger;
  final exponent = (pubKeySeq.elements[1] as ASN1Integer).valueAsBigInteger;
  return RSAPublicKey(modulus, exponent);
}

// 3. Cifrar con RSA-OAEP
String encryptForWitness(Uint8List plainBytes) {
  final publicKey = loadAdminPublicKey();
  final cipher = OAEPEncoding(RSAEngine())
    ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

  // RSA-OAEP 2048 puede cifrar hasta 214 bytes por bloque.
  // Si plainBytes > 214 bytes, cifrar solo los primeros 214 (thumbnail o extracto).
  final chunk = plainBytes.length > 214 ? plainBytes.sublist(0, 214) : plainBytes;
  final encrypted = cipher.process(chunk);
  return base64.encode(encrypted);
}

// 4. Construir el reporte
await api.post(
  '/content/communities/$communityId/posts/$cid/report',
  body: {
    'severity': 'csam',
    'phash': computedPHash,
    'witness_enc': encryptForWitness(plainBytes),
  },
);
```

> **Nota sobre el tamaño:** RSA-OAEP 2048 tiene un límite de 214 bytes por operación. Para contenido multimedia, lo correcto es cifrar un **hash del contenido descifrado** (SHA-256 de `plainBytes`) o los primeros bytes a modo de extracto identificable, no el archivo completo. El campo `phash` ya cumple la función de identificación — `witness_enc` es evidencia complementaria para revisión humana.
