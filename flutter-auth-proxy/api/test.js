module.exports = (req, res) => {
  res.status(200).json({ 
    status: 'ok',
    message: 'Il server proxy è attivo!',
    timestamp: new Date().toISOString()
  });
};
