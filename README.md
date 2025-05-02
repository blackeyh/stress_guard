#  Stress Guardian

**Stress Guardian** is an integrated IoT-based system that detects and monitors physical stress indicators using biological and environmental sensors. It connects to a mobile Flutter app for real-time data visualization and logs data to Firebase Firestore for long-term monitoring.

---

## Key Features

- **Real-time Stress Tracking**: Monitors heart rate, SpO2, body temperature, air quality, humidity, and motion activity to assess stress.
- **Mobile Visualization**: Provides an intuitive Flutter app to visualize real-time sensor data.
- **Firebase Integration**: Data is stored and managed in Firebase Firestore, ensuring cloud-based access and real-time updates.
- **Environmental Monitoring**: Measures temperature, humidity, and air quality, all of which influence stress levels.
- **User-Friendly Interface**: The mobile app is designed to present data in a clear and actionable format, making it easy to track and manage stress.

---



## Data Schema (Firestore)

When data is uploaded to Firebase Firestore, the following fields are used for each document:

- **status**: Current motion or activity status (e.g., "moving", "shaking", "idle").
- **SpO2**: Blood oxygen saturation percentage.
- **heartRate**: Beats per minute (bpm).
- **temperature**: Temperature from the DHT11 sensor (°C).
- **bodyTemperature**: Body temperature from the analog sensor (°C).
- **humidity**: Humidity level from the DHT11 sensor (%).
- **MQ135**: Air quality index (percentage).
- **timestamp**: Timestamp of when the data was collected (formatted as `YYYY-MM-DD-HH-MM-SS`).

---

## Mobile Application (Flutter)

The **Flutter mobile app** displays real-time data collected from the sensors. It communicates with Firebase to retrieve data and present it in a user-friendly format. The app includes:

- **Real-time charts** for SpO2, heart rate, body temperature, etc.
- **Notifications** to alert the user of abnormal readings (e.g., elevated heart rate or low SpO2).
- **Data history** to track trends in stress levels over time.

##  Components & Technologies Used

###  Hardware Components

| Component             | Purpose                                   |
|----------------------|-------------------------------------------|
| **ESP32**            | Microcontroller with Wi-Fi                |
| **MAX30105**         | Measures heart rate and SpO₂              |
| **ADXL345**          | Detects movement and shaking              |
| **DHT11**            | Monitors temperature and humidity         |
| **MQ135**            | Measures air quality (gas concentration)  |
| **Body Temp Sensor** | Reads human body surface temperature      |

###  Software & Libraries

#### Arduino Side
- **Arduino IDE**
- `WiFi.h` – For ESP32 Wi-Fi connection
- `HTTPClient.h` – For HTTP requests to Firestore
- `ArduinoJson.h` – For JSON formatting
- `Adafruit_ADXL345_U.h` – ADXL345 accelerometer library
- `MAX30105.h`, `spo2_algorithm.h` – Heart rate & SpO₂ measurement
- `DFRobot_DHT11.h` – DHT11 sensor
- `Wire.h` – I²C communication

#### Mobile App (Flutter)
- **Flutter SDK**
- `firebase_core`, `cloud_firestore`, `firebase_auth` – Firebase backend
- `fl_chart` – Data visualization

##  Example Screenshots

Here are a few screenshots from the Flutter mobile app:

screen shot for graph plotted by the app

  ![Graphing](graphing.png) 

the main interface of the app

  ![Interface](interface.png) 
  
warning when stress is detected and sensors values are off threshold

  ![Warning](warning.png) |



---

## How It Works

1. **Sensor Data Collection**: The **ESP32** microcontroller collects data from the sensors at regular intervals. The sensors measure various parameters (e.g., heart rate, SpO2, body temperature).
2. **Data Upload to Firebase**: The collected data is processed and sent to **Firebase Firestore**, where it's stored and made available for the mobile app.
3. **Real-Time Mobile Display**: The **Flutter app** continuously polls Firebase for new data and updates the display to show the latest values.
4. **Stress Monitoring**: Based on the data, the app can display warnings or notifications when stress-indicating parameters (e.g., high heart rate, poor air quality) exceed predefined thresholds.

---

## Conclusion

The **Stress Monitoring System** provides an integrated solution for real-time tracking of various parameters that contribute to stress. By combining IoT sensor technology and mobile app visualization, users can monitor their physiological and environmental conditions, helping them manage stress effectively and proactively.


---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgements

- **Flutter**: For building the mobile app.
- **Arduino IDE**: For programming the ESP32 and integrating the sensors.
- **Firebase**: For real-time database and data management.


