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

# Security & Exposure Review — `combined.sh`

This is an audit of the concatenated script for secrets, identifiers, and operational breadcrumbs that shouldn’t live in a public repo.

---

##  High-risk or “do not publish” material

### 1) Evidence.com / Axon operational endpoints and environments
The script contains **production** and **staging/dogfood** hostnames and concrete request flows (firmware checks, login/device auth, proxy tests). Even without secrets, that’s useful recon and reveals internal patterns.

- Hostnames such as `edca.evidence.com`, `prod.evidence.com`, `time.evidence.com`, and a dogfood/staging environment.
- Full request paths for update/download checks and login/device flows (including query params like `software_id`, long hashes, and `user_code` examples).

**Risk:** Enables targeted probing and maps internal workflow. Move to private docs or redact.

---

### 2) Custom HMAC signing scheme spelled out in comments
Comments document an `x-tasr-authorization` header with an **HMAC-SHA1** recipe:
- `StringToSign = method | contentType | x-tasr-date | agency | expires`
- Signature via `openssl dgst -sha1 -hmac "$SECRET" | base64`
- Example header assembly and `curl` usage.

**Risk:** Teaches an attacker how to forge the client’s auth envelope if a key leaks elsewhere. Keep the code if required, but **remove/relocate explanatory comments** and sample signed requests from any public artifact.

---

### 3) PII in example payloads (emails)
Real email addresses are embedded in sample JSON/comments (e.g., `ngrubb@axon.com`, `sdang@axon.com`, `carsten.tittel@fokus.fraunhofer.de`, `nbd@nbd.name`).

**Risk:** Unnecessary personal data exposure; invites spam and external correlation. Replace with `user@example.com`.

---

### 4) UUIDs and potential device/resource identifiers
Multiple GUIDs (device IDs, user IDs) appear in examples (e.g., `f94b6d4f-8a95-4668-8953-dc3c89295de3`, `18baf9c0-8ca4-4b34-97f9-544858db3945`, etc.).

**Risk:** Low on their own, but still leaks internal object shapes and historic references. Replace with `00000000-0000-0000-0000-000000000000`.

---

### 5) Hardcoded sample values in URLs and queries
Example URLs include long hex `software_id` values, hashes, and short human codes like `user_code=WDJBMJH`.

**Risk:** Some may reference real artifacts or be reused elsewhere. Swap for `<SOFTWARE_ID>` / `<USER_CODE>` placeholders.

---

### 6) Internal environment breadcrumbs and operational details
The script reveals:
- File paths like `/etm/secret/https.crt`, `/www/scripts/...`, `/etm/bin/ecom-*`
- Operational notes and log patterns (auth ok/fail strings), public and private IPs.

**Risk:** Increases attack surface awareness. Fine for private ops docs; **not** for public repos.

---

##  What’s *not* present (good news)
- No hardcoded **access/secret keys** found. Keys are read from config (`uci`) and used to compute signatures.
- No tokens/API keys embedded directly in the script.

Keep it that way.

---

##  Redactions before any public exposure

1. **URLs & hostnames:** Replace `*.evidence.com` and environment names with `<AGENCY_HOST>` / `<INTERNAL_ENV>`.
2. **Auth recipe:** Remove detailed signing comments and any example signed `curl` invocations. If needed, move to a **private** protocol document.
3. **Emails & UUIDs:** Replace with `user@example.com` and zero GUIDs.
4. **IDs in paths/queries:** Replace with `<SOFTWARE_ID>`, `<USER_ID>`, `<DEVICE_ID>`, `<USER_CODE>`, etc.
5. **Logs & IPs:** Remove or anonymize IPs, dates, and log excerpts that describe auth behavior.
6. **Config-only secrets:** Ensure the script **fails closed** if `ACCESS`/`SECRET` are unset.

---




