const axios = require('axios');

async function geoIpMiddleware(req, res, next) {
  let country = req.headers['cf-ipcountry'] || 
                req.headers['x-vercel-ip-country'] || 
                req.headers['x-country-code'];
  
  if (!country) {
    let ip = req.headers['x-forwarded-for'] || req.connection?.remoteAddress || req.ip;
    if (ip && ip.includes(',')) ip = ip.split(',')[0].trim();

    if (!ip || ip === '127.0.0.1' || ip === '::1' || ip.includes('127.0.0.1')) {
      country = 'BJ';
    } else {
      try {
        const response = await axios.get(`http://ip-api.com/json/${ip}`);
        if (response.data && response.data.countryCode) {
          country = response.data.countryCode;
        }
      } catch (err) {
        country = 'BJ';
      }
    }
  }

  req.userCountry = (country || 'BJ').toUpperCase();
  next();
}

module.exports = geoIpMiddleware;
