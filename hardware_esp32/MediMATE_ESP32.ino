#include <WiFi.h>
#include <WiFiManager.h>
#include <Firebase_ESP_Client.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "time.h"
#include "addons/TokenHelper.h"

// Firebase Config
#define API_KEY "AIzaSyBJRNfUQp6ZW5SoG4j6Vt3_5XdUwL7Zhxs"
#define FIREBASE_PROJECT_ID "medimate-d4d33"
#define USER_EMAIL "esp32@medimate.com"
#define USER_PASSWORD "12345678"
#define DEVICE_ID "ESP32-001"

// Hardware Pins
const int reedPins[4] = {34, 25, 39, 36};
const int buttonPins[4] = {4, 16, 17, 12};
const int ledPins[4] = {19, 14, 27, 26};
const int buzzerPin = 5;

Adafruit_SSD1306 display(128, 64, &Wire, -1);

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
WiFiManager wm;

String slotSchedules[4] = {"--:--", "--:--", "--:--", "--:--"};
String medicineNames[4] = {"Unknown", "Unknown", "Unknown", "Unknown"}; 
String currentOwnerId = "";
int activeSlot = -1;
unsigned long alertStartTime = 0;
int lastTriggerMinute[4] = {-1, -1, -1, -1}; 
unsigned long lastFetch = 0;

void showStatus(String line1, String line2 = "") {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(WHITE);
  display.setCursor(0, 20);
  display.println(line1);
  if(line2 != "") {
    display.setCursor(0, 35);
    display.println(line2);
  }
  display.display();
}

void setup() {
  Serial.begin(9600); 

  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) for(;;);
  showStatus("OLED OK");
  delay(1000);

  pinMode(buzzerPin, OUTPUT);
  for (int i = 0; i < 4; i++) {
    pinMode(reedPins[i], INPUT_PULLUP);
    pinMode(buttonPins[i], INPUT_PULLDOWN);
    pinMode(ledPins[i], OUTPUT);
    digitalWrite(ledPins[i], LOW);
  }

  showStatus("WiFi...");
  wm.autoConnect("MediMATE-Setup");
  showStatus("WiFi OK");
  delay(1000);

  showStatus("NTP Sync");
  configTime(28800, 0, "pool.ntp.org", "time.nist.gov");
  
  struct tm ti;
  while(!getLocalTime(&ti)) delay(500);
  showStatus("READY");
  delay(1000);

  config.api_key = API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.timeout.serverResponse = 15000;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void loop() {
  struct tm ti;
  if (!getLocalTime(&ti)) return;

  if (millis() - lastFetch > 30000 && Firebase.ready()) {
    syncData();
    lastFetch = millis();
  }

  if (activeSlot == -1) {
    char dateStr[11], timeStr[9], checkTime[6];
    strftime(dateStr, sizeof(dateStr), "%d/%m/%Y", &ti);
    strftime(timeStr, sizeof(timeStr), "%H:%M:%S", &ti);
    strftime(checkTime, sizeof(checkTime), "%H:%M", &ti);

    display.clearDisplay();
    display.setTextSize(1);
    display.setCursor(30, 15); display.println(dateStr);
    display.setTextSize(2);
    display.setCursor(15, 35); display.println(timeStr);
    display.display();

    for (int i = 0; i < 4; i++) {
      if (slotSchedules[i] != "--:--" && String(checkTime) == slotSchedules[i] && ti.tm_min != lastTriggerMinute[i]) {
        activeSlot = i;
        alertStartTime = millis();
        lastTriggerMinute[i] = ti.tm_min; 
        Serial.print("> Alert Started: Slot "); Serial.println(i + 1);
        break;
      }
    }
  } else {
    runVerification(activeSlot);
  }
}

void syncData() {
  // Fetch Schedule & Owner from Device Doc
  String devicePath = "devices/" + String(DEVICE_ID);
  if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", devicePath.c_str(), "")) {
    String payload = fbdo.payload();
    for (int i = 0; i < 4; i++) {
      String tKey = "slot" + String(i + 1) + "_time";
      int tIdx = payload.indexOf(tKey);
      if (tIdx != -1) {
        int vS = payload.indexOf("stringValue", tIdx);
        int q1 = payload.indexOf("\"", vS + 13);
        int q2 = payload.indexOf("\"", q1 + 1);
        slotSchedules[i] = payload.substring(q1 + 1, q2);
      }
    }
    int oIdx = payload.indexOf("ownerId");
    if (oIdx != -1) {
       int vS = payload.indexOf("stringValue", oIdx);
       int q1 = payload.indexOf("\"", vS + 13);
       int q2 = payload.indexOf("\"", q1 + 1);
       currentOwnerId = payload.substring(q1 + 1, q2);
    }
  }

  // Fetch Med Names from User Doc
  if (currentOwnerId != "" && Firebase.ready()) {
    String userPath = "users/" + currentOwnerId;
    if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", userPath.c_str(), "")) {
      String uPayload = fbdo.payload();
      for (int i = 0; i < 4; i++) {
        String slotKey = "slot" + String(i + 1);
        int sIdx = uPayload.indexOf(slotKey);
        if (sIdx != -1) {
          int mNameIdx = uPayload.indexOf("medicineName", sIdx);
          if (mNameIdx != -1) {
            int vS = uPayload.indexOf("stringValue", mNameIdx);
            int q1 = uPayload.indexOf("\"", vS + 13);
            int q2 = uPayload.indexOf("\"", q1 + 1);
            medicineNames[i] = uPayload.substring(q1 + 1, q2);
          }
        }
      }
      Serial.println("> Med Names Synced Successfully");
    }
  }
}

void runVerification(int s) {
  int elapsed = (millis() - alertStartTime) / 1000;
  int countdown = 60 - elapsed;
  
  bool lidOpen = digitalRead(reedPins[s]) == HIGH;
  bool btnPressed = digitalRead(buttonPins[s]) == HIGH;

  if (lidOpen && btnPressed) {
    noTone(buzzerPin);
    digitalWrite(ledPins[s], LOW);
    finalizeAction(s, "taken");
    return;
  }

  digitalWrite(ledPins[s], HIGH);
  if ((millis() / 100) % 2 == 0) {
    tone(buzzerPin, 3000); 
  } else {
    noTone(buzzerPin);
  }

  display.clearDisplay();
  display.setTextSize(2);
  display.setCursor(10, 10); display.print("SLOT "); display.println(s+1);
  display.setCursor(10, 35); display.print("T-"); display.print(countdown); display.println("s");
  display.display();

  if (countdown <= 0) {
    finalizeAction(s, "missed");
  }
}

void finalizeAction(int s, String status) {
  noTone(buzzerPin); 
  digitalWrite(ledPins[s], LOW);
  
  display.clearDisplay();
  display.setTextSize(2);
  display.setCursor(10, 15); display.print("SLOT "); display.println(s+1);
  display.setCursor(10, 40); display.println(status == "taken" ? "TAKEN" : "MISSED");
  display.display();
  
  if (currentOwnerId != "" && Firebase.ready()) {
    time_t now; time(&now);
    struct tm ts; localtime_r(&now, &ts);
    char dBuf[11], tBuf[6];
    strftime(dBuf, sizeof(dBuf), "%d/%m/%Y", &ts);
    strftime(tBuf, sizeof(tBuf), "%H:%M", &ts);

    FirebaseJson content; 
    content.set("fields/date/stringValue", String(dBuf));
    content.set("fields/time/stringValue", String(tBuf));
    content.set("fields/slot/stringValue", String(s + 1));
    content.set("fields/status/stringValue", status);
    content.set("fields/medicineName/stringValue", medicineNames[s]); 
    content.set("fields/isReadPatient/booleanValue", false); 
    content.set("fields/isReadCaregiver/booleanValue", false);
    content.set("fields/timestamp/integerValue", String((long)now));

    String logP = "users/" + currentOwnerId + "/history/" + String((long)now);
    Firebase.Firestore.createDocument(&fbdo, FIREBASE_PROJECT_ID, "", logP.c_str(), content.raw());
  }
  
  delay(3000); 
  activeSlot = -1; 
}
