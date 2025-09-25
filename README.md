<img width="840" height="1026" alt="492007496-74a93a2e-99a9-4f23-bdb6-800c67ca3f9f" src="https://github.com/user-attachments/assets/3cb28fa0-5ea3-4846-9b9c-93f46c1e199b" /><img src="Software/file_00000000e39c6243bdbea60b0bc8bf00.png" height="25%" width="25%" align="right" />



# Axon Repository

Documenting the reverse engineering of Axon Enterprise Devices, Protocols, Software, Firmware and Mobile Applications looking for secrets and vulnerabilitites. This work is unauthorised and done by members of the Anonymous Automotive Alliance.  

This information is currently stored here privately, and is not publicly accessible. The repository will more than likely be made public anonymously due to fears of reprisals or retaliation from both Axon and/or Law Enforcement. 
<br />



<img width="15%" height="15%" alt="" align="right" src="https://github.com/user-attachments/assets/4f9e54bd-3e80-479a-9c04-b4a9aefb3017" />

## Background
Axon Enterprise devices are used globally around the world by police forces. Axon Enterprise manufactures and supplies **law enforcement technologies**, including:
- Body-worn cameras (e.g., Axon Body series)  
- In-car video systems (Fleet series)  
- Conducted Electrical Weapons (TASER devices)  
- Evidence management platforms (Axon Evidence / Evidence.com)  

These devices are deployed **globally across police and security agencies**, from municipal police forces to federal and international law enforcement bodies. Their widespread adoption creates a **large and distributed attack surface**.

<img width="20%" height="20%" align="right" alt="image" src="https://github.com/user-attachments/assets/c079fe4d-daae-4f78-86f7-69ddf278bcbe" />
  

## Axon MAC Address Structure and Cybersecurity Implications

### MAC Address Basics
- A MAC address is a **48-bit identifier** for a network interface, written as six pairs of hexadecimal digits  
  Example: `00:25:DF:12:34:56`
- **First 3 bytes (OUI)**: `00:25:DF` → belongs to **Axon Enterprise**  
- **Last 3 bytes**: Device-specific identifier, often derived from a **serial number**, making each device unique

### Security and Vulnerability Implications

#### 1. Vendor Fingerprinting
- The OUI is publicly known  
- Any Axon device connecting to Wi-Fi, Bluetooth, or Ethernet immediately reveals its manufacturer  
- For law enforcement gear (body cams, tasers, docking stations), this creates an **operational security risk**

#### 2. Device Tracking
- Last 6 digits are tied to the **serial number**  
- This allows identification of **which exact device** is seen in traffic captures  
- Adversaries could link a device to a specific officer, unit, or agency

#### 3. Network Enumeration
- Scanning for `00:25:DF` makes it easy to spot Axon devices on a network  
- Attackers can tailor reconnaissance or exploits specifically against those devices

#### 4. Spoofing Possibilities
- MAC addresses can be **cloned/spoofed**  
- An attacker could impersonate an Axon device by reprogramming their NIC  
- If systems whitelist by MAC range, spoofing could be a potential **entry vector**

#### 5. Long-Term Privacy Risks
- MAC addresses are **static identifiers**, unlike IP addresses  
- Once logged, they can be used to **track the same device across multiple locations/networks**  
- Without **MAC randomization**, devices are more exposed to long-term surveillance

### Why This Matters
- MAC addresses act as a permanent **digital tattoo** for each device  
- Also great for **attackers doing reconnaissance, tracking, or spoofing**  
- If the last digits map directly to serial numbers, leaks can deanonymize and expose officers or agencies

**Summary:**  
The OUI (`00:25:DF`) is Axon’s digital surname, and the serial-based suffix is its given name. Together, they form a permanent, globally unique identifier. This makes Axon devices easily discoverable and trackable unless mitigations (like **MAC randomization**) are implemented.


<img width="55%" height="55%" align="right" alt="image" src="https://github.com/user-attachments/assets/62842704-f2cb-46e3-9529-ef3226ab0774" />
  

## Software
Softwares developed using the ideas and concepts discovered here are in the software folder. 

### `Police Detector — Proof of Concept`

*Purpose:* passively detect BLE devices whose MAC addresses match the Axon Enterprise OUI.

*How it works:*  
Run passive BLE scans (no probes, no writes). Capture advertisement packets. Extract data and store: timestamp, local MAC, RSSI, adv payload, manufacturer data, service UUIDs, Tx power, connectable flag, advertising interval. Checks captured device MAC addresses.  

*Implementation notes:*  
Any consumer grade hardware that is capable of scanning for Bluetooth Low Energy devices is capable of detecting an Axon Enterprise device. The specific Bluetooth Stacks used in the proof of concept software are Linux + BlueZ  (hcidump/btmgmt and libraries: pybluez/bleak/simplepyble.) Software has been made to run on Windows, Linux and Android operating systems and a variety of hardware.  

### `Square Kilometre Array - Weaponisation Concept`   
A LoRaWAN mesh network that covers a large area, and passively scans for a detects Axon Enterprise devices, and reports their presence back to a central node, while tracking the devices in real time throughout the network.  

### `Proximity Detection`
The devices are constantly broadcasting advertising packets containing the MAC address and are detectable from a distance. There is a proof of concept python script in the software folder.  

 
<img width="30%" height="30%" alt="signal-2024-03-15-154525_002" src="https://github.com/user-attachments/assets/a750a47a-ad8c-46fc-90e3-d47acedee35f" />

<br /> <br /> 


<img width="13%" height="13%" alt="image" src="https://github.com/user-attachments/assets/5029c7a2-2d60-4663-b358-2cf309ba7227" align="right"/>

## Firmware
Obtained raw firmware binary files from `https://my.axon.com/` an account was required to download. You are not able to register an account via the Axon website, however one email to technical support claiming to work in the security industry was all it took to gain access and download firmware files. 
   
Delving into the firmware has begun...
```                                                                                
                                         -A.                                    
                                         AXO-                                   
                                        /AXON:                                  
                                   :.  `AXONAX+                                 
                                  +A   AXONAXONA                                
                                `AX.  -AXONAXONAX`                              
                               `AX+   AXONAXONAXON.                             
                              .AXO`  /AXONAXONAXONA-                            
                             -AXO:  `AXONAXONAXONAXO:                           
                            :AXON   AXONAXONAXONAXONA/                          
                           +AXON.  .AXONAXONAXONAXONAXO                         
                          AXONAX   .AXONAXONAXONAXONAXON`                       
                        `AXONAX:    -AXONAXONAXONAXONAXON`                      
                       .AXONAXO+      `-::::::::/+AXONAXON.                     
                      -AXONAXONA.                   .+AXONn:                    
                     :AXONAXONAXO.                    `/AXON/                   
                    /AXONAXONAXONA.             .-::.   `AXON+                  
                   +AXONAXONAXONAXO:          -AXONAXO/   .AXON`                
                 `AXONAXONAXONAXONAX/        :AXONAXONAXO:   :AX`               
                `AXONAXONAXONAXONAXON`      /AXONAXONAXONA.   /AX.              
               .AXONAXONAXONAXONAXONA      AXONAXONAXONAXONA`  `AX-             
              :AXONAXONAXONAXONAXON/`    -AXONAXONAXONAXONAXO/   .A/            
             /AXONAXONAXONAXON+:.`    `:AXONAXONAXONAXONAXONAXO:   :-           
            +AXONAXONAXON/-`     `-/AXONAXONAXONAXONAXONAXONAXONA.              
          `AXONAXON+:-`     .:+AXONAXONAXONAXONAXONAXONAXONAXONAXON`            
         `AXON/:.     `-/AXONAXONAXONAXONAXONAXONAXONAXONAXONAXONAXO/           
          .`     .:+AXONAXONAXONAXONAXONAXONAXONAXONAXONAXONAXONAXONAX:         
            `:+AXONAXONAXONAXONAXONAXONAXONAXONAXONAXONAXONAXONAXONAXON+        
                                                                                
        ,.           :,             ,,        +DDDDD            +              ,
        DDD+          ZD           DO      DDD      ZDD,       DID8            D
       /D =D           ZD         DO     $DI           DD      D: DD           D
       D   ND           ~D       N=     DD              ZN     D:  DD          D
      NO    D8            D,    N      ?N                8D    D:   8D         D
     DD      D            ,D   N       D/                 D    D:    =D        D
     D       DD             DDD        D                  DO   D:      DO      D
    D$        ND           OD=DO       D                  NZ   D:       ND     D
   DD          D          ND   DN      DD                 D    D:        NN    D
  =DNDDDDDDDDDZID        DD     DD      D                DN    D:         DD   D
  D~            DD      DD       DD     ~D              DD     D:          IN  D
 ND              D+    ND         DD      DD          ND$      D:            D:D
/D               ~D   DD           DD       DDD8.,?DDD8        D:             DD
 
--------------------------------------------------------------------------------
 AXON DOCK 3.17.230825.0415                                   TASER International
--------------------------------------------------------------------------------
                                AUTHORIZED USE ONLY!
 
 This system is for the use of authorized users only. Unauthorized access to 
 this computer system and software is prohibited by Title 18, United States 
 Code, Section 1030, Fraud and Related Activity in Connection with Computers. 
 
 Individuals using this computer system without authority, or in excess of 
 their authority, are subject to having all of their activities on this 
 system monitored and recorded by system personnel.
 
 Disclosure of information found in this system for any unauthorized use is
 STRICTLY PROHIBITED. 
 ```


<img width="10%" height="10%" alt="image" src="https://github.com/user-attachments/assets/95de0f1e-1c29-44e5-87dc-7530faba6915" align="right"/>

  
## Android Applications
Android APK files available in the google play store were reverse engineered to obtain the source code. The source code was found not to be obfuscated nor protected from decompilation in any way, and it was simple to recover the code from the APK files and begin analysis.
A breakdown of the **official Android apps** developed by **Axon Enterprise, Inc.**  
These apps are primarily used by law enforcement and public safety agencies for evidence collection, management, and situational awareness.

### Core Applications

| App Name | Purpose / Use-Case | Key Features | Rating / Notes |
|----------|--------------------|--------------|----------------|
| **Axon** | Unified mobile app for law enforcement / public safety personnel to manage evidence, records, and dashboards. | • Evidence Management (DEMS)<br>• Records Management (RMS)<br>• Dashboard of missing evidence<br>• Community evidence submissions<br>• Biometric security & dictation | ~10K+ installs<br>~4.8★ (149 reviews) |
| **Axon Capture** | Field app for collecting photos, videos, and audio as digital evidence. | • Capture/categorize evidence (GPS, category, title)<br>• Upload to Evidence.com<br>• Integration with Axon Citizen | ~50K+ installs<br>~3.9★ rating |
| **Axon View** | Allows officers to view and manage video from Axon body/flex cameras. | • Live streaming / preview from cameras<br>• View stored videos<br>• Adjust field-of-view | ~100K+ installs<br>~2.9★ rating |
| **Axon Device Manager** | For administrators to assign and manage Axon devices. | • NFC scanning of devices<br>• Assign device to officer<br>• Search via Evidence.com | ~10K+ installs<br>~4.0★ rating |


### Command & Oversight

| App Name | Purpose / Use-Case | Key Features | Rating / Notes |
|----------|--------------------|--------------|----------------|
| **Axon Respond** | Situational awareness for supervisors/commanders. | • Map view of officers<br>• Live bodycam streaming<br>• Alerts & event monitoring<br>• Search/filter devices & officers | ~5K+ installs<br>~3.1★ rating |
| **Axon Fleet Dashboard** | Companion app for Axon Fleet (vehicle camera systems). | • Manage in-vehicle cameras<br>• Metadata tagging<br>• ALPR notifications<br>• Remote config | ~1K+ installs<br>~4.3★ rating |


### Device & Shift Operations

| App Name | Purpose / Use-Case | Key Features | Rating / Notes |
|----------|--------------------|--------------|----------------|
| **Axon Device Checkout** | Lets officers self-assign devices during shifts using RFID. | • Assign RFID cards to officers<br>• Officers check out devices with RFID<br>• Tracks assignment via Evidence.com | ~100+ installs (low usage, agency-specific) |
| **MyAxon** | Community and support portal app. | • Product guides & support<br>• Notifications<br>• Community/instructor network | ~500+ installs<br>Limited usage |


### Notes & Observations

- Many apps **require agency subscriptions** (Evidence.com, Axon Records) or **specific hardware** (Axon Body cameras, RFID readers).  
- **Security features**: biometrics, PIN lock, encrypted uploads.  
- Apps are split by **functional domains**:  
  - **Collection** → Axon Capture  
  - **Management** → Axon, Device Manager  
  - **Oversight** → Respond, Fleet Dashboard  
  - **Shift Ops & Support** → Device Checkout, MyAxon  
- Ratings vary widely. **Axon View** is criticized (~2.9★) due to device compatibility issues, while **Axon** itself is highly rated (~4.8★).


<img width="12%" height="12%" alt="image" src="https://github.com/user-attachments/assets/c0385572-c1f7-49c4-ab77-61c3054f5c4a" align="right" />

## Bluetooth Protocol Stack
The Bluetooth stack has been found in the Axon Device Manager APK source code and is a pretty typical bluetooth low energy implementation. 

## Camera Activation Command and Other Commands
