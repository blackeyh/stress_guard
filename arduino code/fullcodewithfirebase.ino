#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_ADXL345_U.h>
#include "MAX30105.h"
#include "spo2_algorithm.h"
#include <DFRobot_DHT11.h>

// Wi-Fi credentials
#define WIFI_SSID "asd"
#define WIFI_PASSWORD "mywolf123"

// Firebase credentials
#define FIREBASE_PROJECT_ID "sterss-gaurd"
#define FIREBASE_API_KEY "AIzaSyAVCoWaCCn1TBUbWhVVHCpAvg1k662s8bc"

// Firestore collection path
String collectionPath = "sensorData";
String firestoreBaseUrl = "https://firestore.googleapis.com/v1/projects/" + String(FIREBASE_PROJECT_ID) + "/databases/(default)/documents/";
const int sensor = 35;  // Use GPIO34 for body temperature sensor
float tempc;  // Variable to store temperature in degree Celsius
float tempf;  // Variable to store temperature in Fahrenheit
float vout;   // Temporary variable to hold sensor reading

// Accelerometer setup
Adafruit_ADXL345_Unified accel = Adafruit_ADXL345_Unified(12345);

// Oximeter setup
MAX30105 particleSensor;
uint32_t irBuffer[100];
uint32_t redBuffer[100];
int32_t bufferLength = 100;
int32_t spo2 = 99;
int8_t validSPO2;
int32_t heartRate;
int8_t validHeartRate;

// DHT11 setup
#define DHT11_PIN 23
DFRobot_DHT11 DHT;

// MQ135 setup
const int mq135Pin = 34;

// Movement and shaking thresholds
const float shakeThreshold = 5.0;
const float movementThreshold = 15.0;

// Time interval for shaking detection
const unsigned long shakeTimeInterval = 1000;
unsigned long lastShakeTime = 0;
int shakeCount = 0;
int adxlReadingsCount = 0;
bool movementDetected = false;

// NTP time settings
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 0;  // Set as needed
const int daylightOffset_sec = 0;  // No daylight savings offset

// New variable for body temperature
double bodyTemperature = 37;  // Placeholder value for body temperature

void setup() {
    Serial.begin(9600);
    delay(2000);
    Serial.println("Initializing sensors...");
  pinMode(sensor, INPUT);

    // Initialize Wi-Fi
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    Serial.print("Connecting to Wi-Fi");
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\nConnected to Wi-Fi");

    // Attempt to connect to the NTP server
    configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
    Serial.print("Connecting to NTP server...");
    for (int i = 0; i < 30; i++) {
        struct tm timeinfo;
        if (getLocalTime(&timeinfo)) {
            Serial.println("Time synchronized with NTP server.");
            break;
        }
        delay(500);
        Serial.print(".");
    }

    Wire.begin();

    // Keep trying to initialize accelerometer until successful
    while (!accel.begin()) {
        Serial.println("No ADXL345 detected, check wiring. Retrying...");
        delay(1000);  // Wait 1 second before retrying
    }
    accel.setRange(ADXL345_RANGE_16_G);
    Serial.println("ADXL345 initialized.");

    // Initialize MAX30105 sensor
    if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
        Serial.println("MAX30105 not found. Check wiring.");
        while (1);
    }
    particleSensor.setup(60, 4, 2, 100, 411, 4096);
    Serial.println("MAX30105 initialized.");

    // Initialize DHT11 sensor
    DHT.read(DHT11_PIN);
    Serial.println("DHT11 initialized.");
}


void loop() {
    sensors_event_t event;
    accel.getEvent(&event);

    float accelerationMagnitude = sqrt(pow(event.acceleration.x, 2) + pow(event.acceleration.y, 2));
    Serial.print("Acceleration magnitude: ");
    Serial.println(accelerationMagnitude);

    if (accelerationMagnitude > movementThreshold) {
        movementDetected = true;
        shakeCount = 0;
        lastShakeTime = millis();
        Serial.println("Normal movement detected.");
    } else if (accelerationMagnitude > shakeThreshold) {
        shakeCount++;
        lastShakeTime = millis();
        Serial.print("Shake detected, shake count: ");
        Serial.println(shakeCount);

        if (shakeCount > 5) {
              Serial.println("Continuous shaking detected.");
        }
    }

    adxlReadingsCount++;
    Serial.print("ADXL reading count: ");
    Serial.println(adxlReadingsCount);

    String status = "idle";  // Default status
    if (movementDetected) {
        status = "moving";
    } else if (shakeCount > 5) {
        status = "shaking";
    }

    if (movementDetected || adxlReadingsCount >= 15) {
        if (adxlReadingsCount >= 15 && !movementDetected) {
            Serial.println("No shaking detected after 15 readings. Setting status to idle.");
        }

        int mq135Value = analogRead(mq135Pin);
        int concentrationPercent = map(mq135Value, 0, 4095, 0, 100);
        Serial.print("MQ135 concentration: ");
        Serial.println(concentrationPercent);

        if (waitForFinger()) {
            collectSpO2AndHeartRate();
            Serial.print("SpO2: ");
            Serial.print(spo2);
            Serial.print("%, Heart Rate: ");
            Serial.println(heartRate);
        } else {
            Serial.println("No finger detected. Skipping SpO2 measurement.");
        }

        DHT.read(DHT11_PIN);
        Serial.print("Temperature (DHT11) = ");
        Serial.print(DHT.temperature);
        Serial.print(" *C, Humidity = ");
        Serial.print(DHT.humidity);
        Serial.println(" %");
          vout = analogRead(sensor);  // Reading the value from the sensor
  vout = (vout * 500.0) / 4095.0;  // Scaling for ESP32's 12-bit ADC (0-4095)
  tempc = vout;  // Store value in Degree Celsius
  tempf = (vout * 1.8) + 32;  // Convert to Fahrenheit

  Serial.print("Body Temperature in Degree Celsius: ");
  Serial.print(tempc);
  Serial.print("\tBody Temperature in Fahrenheit: ");
  Serial.println(tempf);


        submitToFirestore(status, concentrationPercent); // Pass the concentration percent to Firestore

        adxlReadingsCount = 0;
        movementDetected = false;
        shakeCount = 0;
        Serial.println("Data submitted to Firestore. Resetting for new cycle.");
    }

    if (millis() - lastShakeTime >= shakeTimeInterval) {
        shakeCount = 0;
    }

    delay(500);
}

// Submit data to Firestore
void submitToFirestore(String status, int concentrationPercent) {
    Serial.println("Preparing data for Firestore submission...");
  vout = analogRead(sensor);  // Reading the value from the sensor
  vout = (vout * 500.0) / 4095.0;  // Scaling for ESP32's 12-bit ADC (0-4095)
  tempc = vout;  // Store value in Degree Celsius
  tempf = (vout * 1.8) + 32;  // Convert to Fahrenheit

  Serial.print("Body Temperature in Degree Celsius: ");
  Serial.print(tempc);
  Serial.print("\tBody Temperature in Fahrenheit: ");
  Serial.println(tempf);

    String timestamp = getTimestamp();
    String url = firestoreBaseUrl + collectionPath + "/" + timestamp + "?key=" + FIREBASE_API_KEY;

    DynamicJsonDocument doc(1024);
    doc["fields"]["status"]["stringValue"] = status;
    doc["fields"]["SpO2"]["integerValue"] = spo2;
    doc["fields"]["heartRate"]["integerValue"] = heartRate;
    doc["fields"]["temperature"]["doubleValue"] = DHT.temperature;  // Existing temperature
    doc["fields"]["bodyTemperature"]["doubleValue"] = tempc; // Include new body temperature variable
    doc["fields"]["humidity"]["doubleValue"] = DHT.humidity;
    doc["fields"]["MQ135"]["integerValue"] = concentrationPercent; // Use the mapped concentration percent
    doc["fields"]["timestamp"]["stringValue"] = timestamp; // Set the timestamp as a field

    String jsonPayload;
    serializeJson(doc, jsonPayload);

    HTTPClient http;
    http.begin(url);
    http.addHeader("Content-Type", "application/json");

    int httpResponseCode = http.PATCH(jsonPayload);
    if (httpResponseCode > 0) {
        Serial.println("Data submitted successfully: " + http.getString());
    } else {
        Serial.print("Error submitting data: ");
        Serial.println(http.errorToString(httpResponseCode));
    }
    http.end();
}

// Wait for a finger to be detected
bool waitForFinger() {
    Serial.println("Waiting for finger to be placed on oximeter...");
    unsigned long startTime = millis();
    while (millis() - startTime < 5000) {
        particleSensor.check();
        if (particleSensor.available()) {
            if (particleSensor.getIR() > 25000) {
                Serial.println("Finger detected on oximeter.");
                return true;
            }
            particleSensor.nextSample();
        }
        delay(100);
    }
    Serial.println("No finger detected after timeout.");
    return false;
}

// Collect SpO2 and heart rate
void collectSpO2AndHeartRate() {
    Serial.println("Collecting SpO2 and heart rate data...");
    unsigned long startTime = millis(); // Track start time for timeout
    const unsigned long timeoutDuration = 5000; // 5 seconds timeout duration

    for (byte i = 0; i < bufferLength; i++) {
        while (!particleSensor.available()) {
            particleSensor.check();
            Serial.println("Data not available yet...");
            
            // Check for timeout
            if (millis() - startTime > timeoutDuration) {
                Serial.println("Timeout: Sensor data not available.");
                return; // Exit the function if sensor data is not available within the timeout period
            }
        }

        // Reset the timeout for the next sample
        startTime = millis();

        // Get the sample data once available
        redBuffer[i] = particleSensor.getRed();
        irBuffer[i] = particleSensor.getIR();
        particleSensor.nextSample();
    }

    maxim_heart_rate_and_oxygen_saturation(irBuffer, bufferLength, redBuffer, &spo2, &validSPO2, &heartRate, &validHeartRate);
    Serial.println("SpO2 and heart rate data collected.");
}


// Get timestamp as a string
String getTimestamp() {
    struct tm timeinfo;
    if (!getLocalTime(&timeinfo)) {
        return "unknown";
    }
    char timeString[30];
    strftime(timeString, sizeof(timeString), "%Y-%m-%d-%H-%M-%S", &timeinfo);
    return String(timeString);
}
