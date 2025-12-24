const axios = require('axios');
const cors = require('cors')({ origin: true });
const { JSDOM } = require('jsdom');
const vm = require('vm');

module.exports = async (req, res) => {
  return cors(req, res, async () => {
    if (req.method !== 'POST') {
      return res.status(405).json({ success: false, message: 'Method not allowed' });
    }

    try {
      const { nome, email, password } = req.body;
      
      // Crea una sessione che manterrà i cookie
      const axiosInstance = axios.create({
        withCredentials: true,
        maxRedirects: 5,
      });
      
      // Prima visita la homepage per ottenere i cookie anti-bot
      const initialResponse = await axiosInstance.get('http://redaproject.page.gd/');
      
      // Estrai i cookie dalla risposta
      const cookies = initialResponse.headers['set-cookie'];
      
      // Se c'è protezione anti-bot, estrai e esegui il JavaScript
      if (initialResponse.data.includes('aes.js') && initialResponse.data.includes('slowAES')) {
        try {
          // Crea un ambiente DOM per eseguire lo script
          const dom = new JSDOM(initialResponse.data, {
            runScripts: "dangerously",
            resources: "usable"
          });
          
          // Estrai il cookie dal documento dopo l'esecuzione dello script
          const document = dom.window.document;
          const generatedCookie = document.cookie;
          
          if (generatedCookie) {
            // Aggiungi il cookie generato alle richieste successive
            axiosInstance.defaults.headers.Cookie = generatedCookie;
          }
        } catch (scriptError) {
          console.error('Errore nell\'esecuzione dello script anti-bot:', scriptError);
        }
      }
      
      // Poi effettua la richiesta di registrazione con i cookie impostati
      const response = await axiosInstance.post(
        'http://redaproject.page.gd/register.php',
        { nome, email, password },
        { 
          headers: { 
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36'
          }
        }
      );
      
      // Analizza la risposta per determinare l'esito
      let result = { success: false, message: 'Risposta non riconosciuta' };
      
      if (typeof response.data === 'string') {
        if (response.data.includes('success') && response.data.includes('true')) {
          result = { success: true, message: 'Registrazione completata' };
        } else if (response.data.includes('già utilizzata')) {
          result = { success: false, message: 'Email già registrata' };
        } else {
          // Cerca di estrarre JSON dalla risposta
          try {
            const jsonMatches = response.data.match(/\{.*\}/g);
            if (jsonMatches && jsonMatches.length > 0) {
              const jsonData = JSON.parse(jsonMatches[0]);
              result = jsonData;
            }
          } catch (jsonError) {
            console.error('Errore nel parsing JSON:', jsonError);
          }
        }
      } else if (typeof response.data === 'object') {
        result = response.data;
      }
      
      return res.status(200).json(result);
    } catch (error) {
      console.error('Errore proxy register:', error);
      return res.status(500).json({ 
        success: false, 
        message: `Errore nel server proxy: ${error.message}` 
      });
    }
  });
};
