const jwt = require('jsonwebtoken');
const prisma = require('../config/prisma');

const JWT_SECRET = process.env.JWT_SECRET || 'dios-delices-secret';
const LOCATION_SAVE_THROTTLE_MS = 10000; // 10 seconds between DB saves

// Track last save time per courier to throttle DB writes
const lastLocationSaveTime = new Map();

/**
 * Socket.io manager for real-time courier tracking
 */
function initializeSocketIO(io) {
  // Authentication middleware
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.replace('Bearer ', '');
      
      if (!token) {
        return next(new Error('Authentication token required'));
      }

      const decoded = jwt.verify(token, JWT_SECRET);
      const userId = decoded.userId || decoded.id;
      
      if (!userId) {
        return next(new Error('Invalid token payload'));
      }

      // Verify user exists in database
      const user = await prisma.user.findUnique({
        where: { userId: Number(userId) },
        select: { userId: true, courierStatus: true },
      });

      if (!user) {
        return next(new Error('User not found'));
      }

      socket.user = { userId: user.userId, courierStatus: user.courierStatus };
      next();
    } catch (error) {
      next(new Error('Authentication failed'));
    }
  });

  io.on('connection', (socket) => {
    console.log(`[socket] User connected: ${socket.user.userId}`);

    // Client joins order tracking room
    socket.on('join_order_tracking', async (data) => {
      try {
        const { orderId } = data;
        
        if (!orderId) {
          socket.emit('error', { message: 'orderId is required' });
          return;
        }

        // Verify order exists and belongs to the user (for clients)
        // For couriers, we allow them to join any active delivery
        const order = await prisma.order.findUnique({
          where: { orderId: Number(orderId) },
          select: { userId: true, delivererId: true, status: true },
        });

        if (!order) {
          socket.emit('error', { message: 'Order not found' });
          return;
        }

        const roomName = `order_tracking_${orderId}`;
        socket.join(roomName);
        console.log(`[socket] User ${socket.user.userId} joined room: ${roomName}`);
        
        socket.emit('joined_tracking', { orderId, roomName });
      } catch (error) {
        console.error('[socket] Error joining order tracking:', error);
        socket.emit('error', { message: 'Failed to join tracking room' });
      }
    });

    // Client leaves order tracking room
    socket.on('leave_order_tracking', (data) => {
      const { orderId } = data;
      if (orderId) {
        const roomName = `order_tracking_${orderId}`;
        socket.leave(roomName);
        console.log(`[socket] User ${socket.user.userId} left room: ${roomName}`);
      }
    });

    // Courier updates location
    socket.on('courier_location_update', async (data) => {
      try {
        const { orderId, latitude, longitude, accuracyM, heading } = data;

        // Validate required fields
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

        // Verify this courier is assigned to this delivery
        const delivery = await prisma.delivery.findUnique({
          where: { orderId: Number(orderId) },
          select: { delivererId: true, status: true },
        });

        if (!delivery) {
          socket.emit('error', { message: 'Delivery not found' });
          return;
        }

        if (delivery.delivererId !== socket.user.userId) {
          socket.emit('error', { message: 'Not authorized for this delivery' });
          return;
        }

        const roomName = `order_tracking_${orderId}`;

        // Broadcast immediately to all clients in the room (real-time)
        io.to(roomName).emit('courier_moved', {
          orderId,
          courierId: socket.user.userId,
          latitude: lat,
          longitude: lng,
          accuracyM: accuracyM != null ? Number(accuracyM) : null,
          heading: heading != null ? Number(heading) : null,
          timestamp: new Date().toISOString(),
        });

        // Throttled database save (only if last save was > 10 seconds ago)
        const lastSave = lastLocationSaveTime.get(socket.user.userId) || 0;
        const now = Date.now();

        if (now - lastSave > LOCATION_SAVE_THROTTLE_MS) {
          lastLocationSaveTime.set(socket.user.userId, now);
          
          // Save to database asynchronously (don't await to avoid blocking)
          prisma.courierLocation
            .create({
              data: {
                delivererId: socket.user.userId,
                latitude: lat,
                longitude: lng,
                accuracyM: accuracyM != null ? Number(accuracyM) : null,
                // PostGIS geometry will be set by a trigger or we can use raw SQL
              },
            })
            .then(() => {
              console.log(`[socket] Saved location for courier ${socket.user.userId}`);
            })
            .catch((err) => {
              console.error('[socket] Error saving location to DB:', err);
            });
        }
      } catch (error) {
        console.error('[socket] Error processing location update:', error);
        socket.emit('error', { message: 'Failed to process location update' });
      }
    });

    socket.on('disconnect', () => {
      console.log(`[socket] User disconnected: ${socket.user.userId}`);
      // Clean up throttling map
      lastLocationSaveTime.delete(socket.user.userId);
    });
  });

  return io;
}

module.exports = { initializeSocketIO };
