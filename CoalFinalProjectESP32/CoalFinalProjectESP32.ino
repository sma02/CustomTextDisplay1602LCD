// ESP32 Board: DOIT ESP32 DEVKIT V1

#include <WiFi.h>
#include <PubSubClient.h>  
#include <Firebase_ESP_Client.h>

// Provide the token generation process info.
#include "addons/TokenHelper.h"
// Provide the RTDB payload printing info and other helper functions.
#include "addons/RTDBHelper.h"

// WiFi Credentials
const char *ssid = "espnet839093";  // Enter your WiFi name
const char *password = "12345678";        // Enter WiFi password

// MQTT Broker
const char *mqtt_broker = "test.mosquitto.org";
const char *topic = "2022-CS-83-90-93/q3vjw7-recv";
const int mqtt_port = 1883;


// Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Variable to save USER UID
String uid;

// Variables to save database paths
String databasePath;


WiFiClient espClient;
PubSubClient client(espClient);

void setup() {
  // Use ESP32 buit-in LED to indicate the state of WiFi and MQTT
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);

  // connecting to a WiFi network
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    digitalWrite(LED_BUILTIN, HIGH);  // LED ON while No WiFi
    delay(500);
  }
  digitalWrite(LED_BUILTIN, LOW);  // LED OFF when connected to WiFi
  //connecting to a mqtt broker
  client.setServer(mqtt_broker, mqtt_port);
  client.setCallback(callback);

  while (!client.connected()) {
    digitalWrite(LED_BUILTIN, HIGH);  // LED ON while No MQTT Connection
    String client_id = "esp32-client-";
    client_id += String(WiFi.macAddress());
    if (client.connect(client_id.c_str())) {
      digitalWrite(LED_BUILTIN, LOW);  // LED OFF when connected to MQTT Server
    } else {
      delay(2000);
    }
  }
  client.subscribe(topic);  // Subscribing to a MQTT topic


  // Assign the api key
  config.api_key = "AIzaSyD6VLAGIQ54X3hEnepiHbW42m8qR5E-OJA";

  // Assign the user sign in credentials
  auth.user.email = "server@coalproject.com";
  auth.user.password = "12345678";

  // Assign the RTDB URL
  config.database_url = "https://coal-project-default-rtdb.firebaseio.com/";

  Firebase.reconnectWiFi(true);
  fbdo.setResponseSize(4096);


  // Assign the callback function for the long running token generation task
  config.token_status_callback = tokenStatusCallback;

  // Assign the maximum retry of token generation
  config.max_token_generation_retry = 5;

  // Initialize the library with the Firebase authen and config
  Firebase.begin(&config, &auth);

  // Getting the user UID might take a few seconds
  while ((auth.token.uid) == "") {
    delay(1000);
  }
  // Print user UID
  uid = auth.token.uid.c_str();
  // Update database path
  databasePath = "/UsersData/" + uid;

  Serial.begin(9600);
}

void callback(char *topic, byte *payload, unsigned int length) {
  String msg = "";
  for (int i = 0; i < length; i++) {
    Serial.print((char)payload[i]);
    msg += (char)payload[i];
  }
  Serial.write(0xd); // Write Carriage return character
  while (!Firebase.RTDB.pushString(&fbdo, "/UsersData/" + uid + "/msgs", msg)); // Pushing data to Firebase database 
}

void loop() {
  client.loop();
}
