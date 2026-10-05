const crypto = require('crypto');
const { Prisma } = require('@prisma/client');
const jwt = require('jsonwebtoken');
const prisma = require('../config/prisma');

const JWT_SECRET = process.env.JWT_SECRET || 'dios_delices_super_secret_jwt_key_2026_production_safe';
const LOCATION_SAVE_THROTTLE_MS = 10_000; // 10 seconds between DB saves

// Track last save time per courier to throttle DB writes
const lastLocationSaveTime = new Map();

// Keep a reference to `io` so other modules can broadcast events.
let _io = null;

/**
 * Returns the live Socket.io server instance (or null before init).
 */
function getIO() {
  return _io;
}

/**
 * Broadcast a delivery status change to everyone watching a given order.
 * Can be called from HTTP controllers after updating the delivery.
 */
function broadcastDeliveryStatus({ orderId, status, courierId, extra }) {
  if (!_io) return;
  const roomName = `order_tracking_${orderId}`;
  _io.to(roomName).emit('delivery_status_changed', {
    orderId,
    status,
    courierId: courierId ?? null,
    ...(extra ?? {}),
    timestamp: new Date().toISOString(),
  });
}

// ── helpers ─────────────────────────────────────────────────
function pointSql(latitude, longitude) {
  return Prisma.sql`ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)`;
}

/**
 * Persist a courier location row **with** a PostGIS geography column,
 * and update the user's own `location` column. Fire-and-forget.
 */
async function persistLocation(userId, lat, lng, accuracyM) {
  try {
    // 1. Resolve city (best-effort, nullable)
    let cityId = null;
    try {
      const cities = await prisma.$queryRaw(Prisma.sql`
        SELECT "cityId"
        FROM "cities"
        WHERE "deletedAt" IS NULL
          AND "active" = true
          AND "delivery_enabled" = true
          AND "boundary" IS NOT NULL
          AND ST_Covers("boundary", ${pointSql(lat, lng)})
        LIMIT 1
      `);
      if (cities?.length) cityId = cities[0].cityId;
    } catch (_) { /* city resolution is optional */ }

    // 2. Insert into courier_locations with PostGIS geography
    const locationId = crypto.randomUUID();
    await prisma.$executeRaw(Prisma.sql`
      INSERT INTO "courier_locations" ("id", "livreur_id", "city_id", "latitude", "longitude", "location", "accuracy_m", "recorded_at", "createdAt")
      VALUES (
        ${locationId}::uuid,
        ${userId},
        ${cityId},
        ${lat},
        ${lng},
        ${pointSql(lat, lng)}::geography,
        ${accuracyM},
        NOW(),
        NOW()
      )
    `);

    // 3. Update user's live location
    await prisma.$executeRaw(Prisma.sql`
      UPDATE "users"
      SET "location" = ${pointSql(lat, lng)}::geography,
          ${cityId ? Prisma.sql`"cityId" = ${cityId},` : Prisma.empty}
          "location_updated_at" = NOW(),
          "updatedAt" = NOW()
      WHERE "userId" = ${userId}
    `);

    console.log(`[socket] Persisted location for courier ${userId} (city=${cityId})`);
  } catch (err) {
    console.error('[socket] Error persisting location to DB:', err.message);
  }
}

// ── main initialiser ────────────────────────────────────────
/**
 * Socket.io manager for real-time courier tracking.
 */
function initializeSocketIO(io) {
  _io = io;

  // ── Authentication middleware ───────────────────────────
  io.use(async (socket, next) => {
    try {
      const rawHeader = socket.handshake.headers?.authorization || '';
      const token =
        socket.handshake.auth?.token ||
        socket.handshake.query?.token ||
        (rawHeader.startsWith('Bearer ') ? rawHeader.slice(7).trim() : null);

      if (!token) return next(new Error('Authentication token required'));

      const secret = process.env.JWT_SECRET || JWT_SECRET;
      const decoded = jwt.verify(token, secret);
      const userId = decoded.userId || decoded.id || decoded.sub;
      if (!userId) return next(new Error('Invalid token payload'));

      const parsedId = Number.parseInt(userId, 10);
      const user = await prisma.user.findFirst({
        where: {
          OR: [
            ...(Number.isInteger(parsedId) ? [{ userId: parsedId }] : []),
            { id: String(userId) },
          ],
          deletedAt: null,
        },
        select: { userId: true, courierStatus: true, roleId: true },
      });

      if (!user) return next(new Error('User not found'));

      socket.user = { userId: user.userId, courierStatus: user.courierStatus, roleId: user.roleId };
      next();
    } catch (err) {
      console.warn('[socket] Handshake auth error:', err.message);
      next(new Error('Authentication failed'));
    }
  });

  // ── Connection handler ─────────────────────────────────
  io.on('connection', (socket) => {
    console.log(`[socket] ✔ User connected: ${socket.user.userId}`);

    // ─ Client joins order tracking room ──────────────────
    socket.on('join_order_tracking', async (data) => {
      try {
        const rawId = typeof data === 'object' && data !== null ? data.orderId : data;
        const orderId = rawId != null ? String(rawId).trim() : null;
        if (!orderId) {
          socket.emit('error', { message: 'orderId is required' });
          return;
        }

        const parsedOrderId = Number.parseInt(orderId, 10);
        const order = await prisma.order.findFirst({
          where: {
            OR: [
              ...(Number.isInteger(parsedOrderId) ? [{ orderId: parsedOrderId }] : []),
              { id: String(orderId) },
            ],
            deletedAt: null,
          },
          select: { orderId: true, userId: true, delivererId: true, status: true },
        });

        if (!order) {
          socket.emit('error', { message: 'Order not found' });
          return;
        }

        const roomName = `order_tracking_${order.orderId}`;
        socket.join(roomName);
        if (orderId !== String(order.orderId)) {
          socket.join(`order_tracking_${orderId}`);
        }
        console.log(`[socket] User ${socket.user.userId} joined room ${roomName}`);

        socket.emit('joined_tracking', { orderId: order.orderId, roomName });

        // If a courier is assigned, immediately send the courier's latest known position
        const courierId = order.delivererId;
        if (courierId) {
          try {
            const latestLoc = await prisma.courierLocation.findFirst({
              where: { delivererId: courierId },
              orderBy: { recordedAt: 'desc' },
            });
            if (latestLoc) {
              socket.emit('courier_moved', {
                orderId: order.orderId,
                courierId,
                latitude: latestLoc.latitude,
                longitude: latestLoc.longitude,
                accuracyM: latestLoc.accuracyM,
                heading: null,
                timestamp: latestLoc.recordedAt.toISOString(),
              });
            }
          } catch (_) {}
        }
      } catch (error) {
        console.error('[socket] Error joining order tracking:', error.message);
        socket.emit('error', { message: 'Failed to join tracking room' });
      }
    });

    // ─ Client leaves order tracking room ─────────────────
    socket.on('leave_order_tracking', (data) => {
      const rawId = typeof data === 'object' && data !== null ? data.orderId : data;
      const orderId = rawId != null ? String(rawId).trim() : null;
      if (orderId) {
        const roomName = `order_tracking_${orderId}`;
        socket.leave(roomName);
        console.log(`[socket] User ${socket.user.userId} left room ${roomName}`);
      }
    });

    // ─ Courier sends live position ───────────────────────
    socket.on('courier_location_update', async (data) => {
      try {
        const { orderId, latitude, longitude, accuracyM, heading } = data ?? {};

        if (!orderId || latitude == null || longitude == null) {
          socket.emit('error', { message: 'orderId, latitude, and longitude are required' });
          return;
        }

        const lat = Number(latitude);
        const lng = Number(longitude);

        if (!Number.isFinite(lat) || !Number.isFinite(lng) ||
            lat < -90 || lat > 90 || lng < -180 || lng > 180) {
          socket.emit('error', { message: 'Invalid coordinates' });
          return;
        }

        const parsedOrderId = Number.parseInt(orderId, 10);
        // Verify this courier is assigned to this delivery or order
        const delivery = await prisma.delivery.findFirst({
          where: {
            OR: [
              ...(Number.isInteger(parsedOrderId) ? [{ orderId: parsedOrderId }] : []),
              { deliveryId: String(orderId) },
              { id: String(orderId) },
            ],
          },
          select: { delivererId: true, status: true, orderId: true },
        });

        if (delivery && delivery.delivererId && delivery.delivererId !== socket.user.userId) {
          socket.emit('error', { message: 'Not authorized for this delivery' });
          return;
        }

        const safeAccuracy = accuracyM != null ? Number(accuracyM) : null;
        const safeHeading  = heading  != null ? Number(heading)  : null;
        const targetOrderId = delivery?.orderId ?? (Number.isInteger(parsedOrderId) ? parsedOrderId : orderId);

        const payload = {
          orderId: targetOrderId,
          courierId: socket.user.userId,
          latitude: lat,
          longitude: lng,
          accuracyM: safeAccuracy,
          heading: safeHeading,
          timestamp: new Date().toISOString(),
        };

        // ── 1. Broadcast immediately (real-time to client) ──
        io.to(`order_tracking_${targetOrderId}`).emit('courier_moved', payload);
        if (String(orderId) !== String(targetOrderId)) {
          io.to(`order_tracking_${orderId}`).emit('courier_moved', payload);
        }

        // ── 2. Throttled PostGIS-aware DB save ──────────────
        const lastSave = lastLocationSaveTime.get(socket.user.userId) || 0;
        const now = Date.now();

        if (now - lastSave > LOCATION_SAVE_THROTTLE_MS) {
          lastLocationSaveTime.set(socket.user.userId, now);
          // Fire-and-forget — don't block the socket event loop.
          persistLocation(socket.user.userId, lat, lng, safeAccuracy);
        }
      } catch (error) {
        console.error('[socket] Error processing location update:', error.message);
        socket.emit('error', { message: 'Failed to process location update' });
      }
    });

    // ─ Disconnect cleanup ────────────────────────────────
    socket.on('disconnect', () => {
      console.log(`[socket] ✖ User disconnected: ${socket.user.userId}`);
      lastLocationSaveTime.delete(socket.user.userId);
    });
  });

  return io;
}

module.exports = { initializeSocketIO, getIO, broadcastDeliveryStatus };
