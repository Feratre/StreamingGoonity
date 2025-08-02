<?php
// Abilita CORS e disabilita controlli anti-bot per le chiamate API
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, X-Requested-With, X-API-KEY");
header("Content-Type: application/json; charset=UTF-8");

// API KEY segreta - usa la stessa del file register.php
define('API_KEY', 'fK8dH2pL9qR5tZ3xW7cV6bN4mJ1gS0aE');

// Gestisci preflight request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

// Avvia la sessione per il login web
session_start();

// Connessione al database
$host = "sql309.infinityfree.com"; // Sostituisci con il tuo host MySQL
$dbname = "if0_39567664_streaming"; // Sostituisci con il nome del tuo database
$username = "if0_39567664"; // Sostituisci con il tuo username MySQL
$password = "la-tua-password"; // Sostituisci con la tua password MySQL

try {
    $conn = new PDO("mysql:host=$host;dbname=$dbname", $username, $password);
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch(PDOException $e) {
    if (isApiRequest()) {
        // Restituisci errore in JSON per richieste API
        outputJsonResponse(false, "Errore di connessione al database: " . $e->getMessage());
    } else {
        // Per richieste browser, mostra messaggio HTML
        die("Errore di connessione al database: " . $e->getMessage());
    }
}

// Determina se è una richiesta API o normale
function isApiRequest() {
    // Controlla header API KEY
    $headers = getallheaders();
    $apiKey = isset($headers['X-API-KEY']) ? $headers['X-API-KEY'] : '';
    
    if ($apiKey === API_KEY) {
        return true;
    }
    
    // Controlla parametro URL
    if (isset($_GET['key']) && $_GET['key'] === API_KEY) {
        return true;
    }
    
    // Controlla User-Agent
    return isset($_SERVER['HTTP_USER_AGENT']) && 
           (strpos($_SERVER['HTTP_USER_AGENT'], 'Flutter') !== false || 
            strpos($_SERVER['HTTP_USER_AGENT'], 'Dart') !== false ||
            isset($_SERVER['HTTP_X_REQUESTED_WITH']) && 
            $_SERVER['HTTP_X_REQUESTED_WITH'] === 'flutter-app');
}

// Funzione per generare risposte JSON standardizzate
function outputJsonResponse($success, $message, $data = null) {
    header('Content-Type: application/json');
    $response = [
        'success' => $success,
        'message' => $message
    ];
    
    if ($data !== null) {
        $response['data'] = $data;
    }
    
    echo json_encode($response);
    exit;
}

// Gestione richieste API (JSON) o verifico se è un test
if (isApiRequest() || isset($_GET['test'])) {
    // Test endpoint per verificare la connessione
    if (isset($_GET['test'])) {
        outputJsonResponse(true, "API funzionante", [
            'timestamp' => date('Y-m-d H:i:s'),
            'server' => 'InfinityFree'
        ]);
    }
    
    // Leggi i dati JSON inviati
    $inputJSON = file_get_contents('php://input');
    $input = json_decode($inputJSON, TRUE);
    
    // Fallback a POST se non è JSON
    if ($input === null) {
        $input = $_POST;
    }
    
    // Estrai i dati
    $email = isset($input['email']) ? trim($input['email']) : '';
    $password = isset($input['password']) ? $input['password'] : '';
    
    // Validazione
    if (empty($email) || empty($password)) {
        outputJsonResponse(false, "Email e password sono obbligatori");
    }
    
    // Cerca l'utente nel database
    $stmt = $conn->prepare("SELECT id, nome, email, password FROM utenti WHERE email = :email");
    $stmt->bindParam(':email', $email);
    $stmt->execute();
    
    if ($stmt->rowCount() === 0) {
        outputJsonResponse(false, "Utente non trovato");
    }
    
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    // Verifica la password
    if (!password_verify($password, $user['password'])) {
        outputJsonResponse(false, "Password non corretta");
    }
    
    // Login riuscito - rimuovi il campo password per la risposta
    unset($user['password']);
    
    outputJsonResponse(true, "Login effettuato con successo", ['user' => $user]);
}

// Gestione richieste da browser web (form HTML)
if ($_SERVER['REQUEST_METHOD'] === 'POST' && !isApiRequest()) {
    $email = isset($_POST['email']) ? trim($_POST['email']) : '';
    $password = isset($_POST['password']) ? $_POST['password'] : '';
    
    // Validazione
    $errors = [];
    
    if (empty($email)) {
        $errors[] = "L'email è obbligatoria";
    }
    
    if (empty($password)) {
        $errors[] = "La password è obbligatoria";
    }
    
    // Se non ci sono errori, procedi con il login
    if (empty($errors)) {
        // Cerca l'utente nel database
        $stmt = $conn->prepare("SELECT id, nome, email, password FROM utenti WHERE email = :email");
        $stmt->bindParam(':email', $email);
        $stmt->execute();
        
        if ($stmt->rowCount() === 0) {
            $errors[] = "Utente non trovato";
        } else {
            $user = $stmt->fetch(PDO::FETCH_ASSOC);
            
            // Verifica la password
            if (!password_verify($password, $user['password'])) {
                $errors[] = "Password non corretta";
            } else {
                // Login riuscito
                $_SESSION['user_id'] = $user['id'];
                $_SESSION['user_nome'] = $user['nome'];
                $_SESSION['user_email'] = $user['email'];
                
                // Reindirizza alla pagina principale o dashboard
                header("Location: index.php");
                exit;
            }
        }
    }
}

// Se il codice arriva qui, è una richiesta normale (non API) o ci sono errori nel form
?>
<!DOCTYPE html>
<html>
<head>
    <title>Login</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 500px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            text-align: center;
            color: #333;
        }
        .form-group {
            margin-bottom: 15px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
        }
        input[type="email"],
        input[type="password"] {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
            box-sizing: border-box;
        }
        .error {
            color: red;
            margin-bottom: 15px;
        }
        .success {
            color: green;
            margin-bottom: 15px;
        }
        .btn {
            background-color: #4CAF50;
            color: white;
            padding: 10px 15px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
        }
        .btn:hover {
            background-color: #45a049;
        }
        .register-link {
            text-align: center;
            margin-top: 15px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Login</h1>
        
        <?php if(isset($_GET['registered']) && $_GET['registered'] === 'true'): ?>
            <div class="success">
                <p>Registrazione completata con successo. Ora puoi accedere.</p>
            </div>
        <?php endif; ?>
        
        <?php if(isset($errors) && !empty($errors)): ?>
            <div class="error">
                <?php foreach($errors as $error): ?>
                    <p><?php echo htmlspecialchars($error); ?></p>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>
        
        <form method="post" action="">
            <div class="form-group">
                <label for="email">Email:</label>
                <input type="email" id="email" name="email" value="<?php echo isset($email) ? htmlspecialchars($email) : ''; ?>">
            </div>
            
            <div class="form-group">
                <label for="password">Password:</label>
                <input type="password" id="password" name="password">
            </div>
            
            <div class="form-group">
                <button type="submit" class="btn">Accedi</button>
            </div>
            
            <div class="register-link">
                Non hai un account? <a href="register.php">Registrati</a>
            </div>
        </form>
    </div>
</body>
</html>
