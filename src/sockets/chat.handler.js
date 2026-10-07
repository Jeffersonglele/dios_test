const prisma = require('../config/prisma');
const { canAccessOrderChat } = require('../controllers/chat.controller');

/**
 * Vérifie si une chaîne ressemble à un UUID valide (format avec tirets, 36 caractères)
 */
function isValidUUID(str) {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(str);
}

/**
 * Enregistre les gestionnaires d'événements Socket.io pour la messagerie instantanée (Chat).
 * 
 * @param {import('socket.io').Server} io
 * @param {import('socket.io').Socket} socket
 */
function registerChatHandlers(io, socket) {
  const currentUserId = socket.user?.userId;

  // ── 1. Rejoindre le salon de chat d'une commande ─────────
  socket.on('join_order_chat', async (data) => {
    try {
      const rawId = typeof data === 'object' && data !== null ? data.orderId : data;
      const orderId = rawId != null ? String(rawId).trim() : null;

      if (!orderId) {
        socket.emit('chat_error', { message: 'orderId est requis pour rejoindre le chat.' });
        return;
      }

      const parsedOrderId = Number.parseInt(orderId, 10);
      const order = await prisma.order.findFirst({
        where: {
          OR: [
            ...(Number.isInteger(parsedOrderId) ? [{ orderId: parsedOrderId }] : []),
            ...(isValidUUID(orderId) ? [{ id: String(orderId) }] : []),
          ],
          deletedAt: null,
        },
        select: {
          id: true,
          orderId: true,
          userId: true,
          legacyUserId: true,
          restaurantId: true,
          restaurateurId: true,
          legacyRestaurateurId: true,
          delivererId: true,
        },
      });

      if (!order) {
        socket.emit('chat_error', { message: 'Commande introuvable.' });
        return;
      }

      // Vérification de sécurité
      const hasAccess = await canAccessOrderChat(order, currentUserId, socket.user?.roleId);
      if (!hasAccess) {
        socket.emit('chat_error', { message: 'Accès non autorisé à cette discussion.' });
        return;
      }

      const roomName = `order_chat_${order.orderId}`;
      socket.join(roomName);
      if (orderId !== String(order.orderId)) {
        socket.join(`order_chat_${orderId}`);
      }

      console.log(`[chat] ✔ Utilisateur ${currentUserId} a rejoint le salon ${roomName}`);
      socket.emit('joined_chat', {
        orderId: order.orderId,
        roomName,
        userId: currentUserId,
      });
    } catch (error) {
      console.error('[chat] Erreur join_order_chat:', error.message);
      socket.emit('chat_error', { message: 'Impossible de rejoindre le salon de chat.' });
    }
  });

  // ── 2. Quitter le salon de chat ──────────────────────────
  socket.on('leave_order_chat', (data) => {
    try {
      const rawId = typeof data === 'object' && data !== null ? data.orderId : data;
      const orderId = rawId != null ? String(rawId).trim() : null;
      if (orderId) {
        const roomName = `order_chat_${orderId}`;
        socket.leave(roomName);
        console.log(`[chat] Utilisateur ${currentUserId} a quitté le salon ${roomName}`);
        socket.emit('left_chat', { orderId, roomName });
      }
    } catch (_) {}
  });

  // ── 3. Envoi et persistance d'un message ─────────────────
  socket.on('send_message', async (data) => {
    try {
      const {
        orderId: rawOrderId,
        toUserId: rawToUserId,
        text,
        messageType = 'TEXT',
        mediaUrl = null,
        mediaDuration = null,
        mediaMimeType = null,
        mediaSize = null,
      } = data || {};

      if (!rawOrderId) {
        socket.emit('chat_error', { message: 'orderId est requis.' });
        return;
      }

      // Valider qu'il y a un contenu (texte ou média)
      if ((!text || !text.trim()) && !mediaUrl) {
        socket.emit('chat_error', { message: 'Le message doit contenir du texte ou un média.' });
        return;
      }

      const parsedOrderId = Number.parseInt(rawOrderId, 10);
      const order = await prisma.order.findFirst({
        where: {
          OR: [
            ...(Number.isInteger(parsedOrderId) ? [{ orderId: parsedOrderId }] : []),
            ...(isValidUUID(rawOrderId) ? [{ id: String(rawOrderId) }] : []),
          ],
          deletedAt: null,
        },
        select: {
          id: true,
          orderId: true,
          userId: true,
          restaurantId: true,
          restaurateurId: true,
          delivererId: true,
        },
      });

      if (!order) {
        socket.emit('chat_error', { message: 'Commande introuvable.' });
        return;
      }

      const hasAccess = await canAccessOrderChat(order, currentUserId, socket.user?.roleId);
      if (!hasAccess) {
        socket.emit('chat_error', { message: 'Accès non autorisé à cette discussion.' });
        return;
      }

      // Déterminer le destinataire par défaut si non spécifié
      let toUserId = rawToUserId != null ? Number.parseInt(rawToUserId, 10) : null;
      if (!toUserId || Number.isNaN(toUserId)) {
        if (currentUserId === order.userId) {
          // Si l'émetteur est le client -> destinataire = livreur assigné ou restaurateur
          toUserId = order.delivererId || order.restaurateurId || null;
        } else {
          // Si l'émetteur est le livreur ou le restaurateur -> destinataire = client
          toUserId = order.userId || null;
        }
      }

      // Sauvegarde dans la base de données PostgreSQL via Prisma
      const savedMessage = await prisma.message.create({
        data: {
          orderId: order.orderId,
          fromUserId: currentUserId,
          toUserId: toUserId,
          text: text ? text.trim() : null,
          messageType: String(messageType).toUpperCase(),
          mediaUrl: mediaUrl ? String(mediaUrl).trim() : null,
          mediaDuration: mediaDuration != null ? Number.parseInt(mediaDuration, 10) : null,
          mediaMimeType: mediaMimeType ? String(mediaMimeType).trim() : null,
          mediaSize: mediaSize != null ? Number.parseInt(mediaSize, 10) : null,
          read: false,
        },
      });

      console.log(`[chat] Message ${savedMessage.id} créé par user ${currentUserId} pour commande ${order.orderId}`);

      // Diffusion en temps réel à tous les participants du salon
      const roomName = `order_chat_${order.orderId}`;
      io.to(roomName).emit('new_message', savedMessage);

      // Si l'ID d'origine était une chaîne UUID différente, diffuser également dessus
      if (rawOrderId !== String(order.orderId)) {
        io.to(`order_chat_${rawOrderId}`).emit('new_message', savedMessage);
      }
    } catch (error) {
      console.error('[chat] Erreur send_message:', error.message);
      socket.emit('chat_error', { message: 'Impossible d’envoyer le message.' });
    }
  });

  // ── 4. Accusés de lecture ────────────────────────────────
  socket.on('mark_as_read', async (data) => {
    try {
      const { messageIds, orderId } = data || {};
      if (!Array.isArray(messageIds) || !messageIds.length) return;

      const now = new Date();

      // Mettre à jour les messages reçus par l'utilisateur connecté
      await prisma.message.updateMany({
        where: {
          id: { in: messageIds },
          fromUserId: { not: currentUserId },
          read: false,
        },
        data: {
          read: true,
          readAt: now,
        },
      });

      if (orderId) {
        const roomName = `order_chat_${orderId}`;
        io.to(roomName).emit('messages_read', {
          orderId,
          messageIds,
          readAt: now.toISOString(),
          readerId: currentUserId,
        });
      }
    } catch (error) {
      console.error('[chat] Erreur mark_as_read:', error.message);
    }
  });

  // ── 5. Indicateur de saisie (typing) ─────────────────────
  socket.on('user_typing', (data) => {
    try {
      const { orderId, isTyping = true } = data || {};
      if (!orderId) return;

      const roomName = `order_chat_${orderId}`;
      socket.to(roomName).emit('user_typing', {
        orderId,
        userId: currentUserId,
        isTyping: Boolean(isTyping),
      });
    } catch (_) {}
  });
}

module.exports = {
  registerChatHandlers,
};
