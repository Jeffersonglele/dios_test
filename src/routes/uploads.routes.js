const express = require('express');
const multer = require('multer');

const { uploadImage } = require('../services/storage.service');
const { authenticate } = require('../middlware/auth.middleware');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024, files: 5 } });

function uploadError(error, req, res, next) { // eslint-disable-line no-unused-vars
  if (error instanceof multer.MulterError) {
    error.statusCode = error.code === 'LIMIT_FILE_SIZE' ? 413 : 400;
    error.message = error.code === 'LIMIT_FILE_SIZE' ? 'Une image ne peut pas dépasser 5 Mo.' : 'Téléversement invalide.';
  }
  return next(error);
}

async function uploadOne(req, res, next) {
  try {
    const media = await uploadImage(req.file, req.body.scope || 'images');
    return res.status(201).json({ data: media });
  } catch (error) {
    return next(error);
  }
}

async function uploadMany(req, res, next) {
  try {
    if (!req.files?.length) {
      const error = new Error('Aucune image reçue.');
      error.statusCode = 400;
      throw error;
    }
    const media = await Promise.all(req.files.map((file) => uploadImage(file, req.body.scope || 'images')));
    return res.status(201).json({ data: media });
  } catch (error) {
    return next(error);
  }
}

router.post('/uploads/image', authenticate, upload.single('image'), uploadOne, uploadError);
router.post('/uploads/images', authenticate, upload.array('images', 5), uploadMany, uploadError);

module.exports = router;
