# 📐 Diagrammes UML & C4 — CleanCity

> Générés à partir du code source du projet (`lib/`, `models/`, `services/`, `auth/`, `nav.dart`).  
> Tous les diagrammes utilisent la syntaxe **Mermaid** (compatible GitHub, GitLab, Obsidian, VS Code).

---

## 1. Diagramme de Cas d'Utilisation

```mermaid
graph TD
    GEN((Générateur\nCitoyen))
    COL((Collecteur\nAgent))
    CTR((Centre\nde Tri))
    ADM((Administrateur))
    SYS((Système\nSupabase))

    subgraph "Authentification"
        UC_REG[S'inscrire\nemail / téléphone]
        UC_LOGIN[Se connecter\nemail / Google / OTP]
        UC_ROLE[Choisir son rôle]
        UC_PWD[Réinitialiser\nle mot de passe]
    end

    subgraph "Générateur — Signalements"
        UC_CREAT[Créer un signalement\nde déchets]
        UC_PHOTO[Joindre des photos]
        UC_GPS[Capturer la\nlocalisation GPS]
        UC_LIST[Consulter mes\nsignalements]
        UC_DETAIL[Voir le détail\nd'un signalement]
        UC_CANCEL[Annuler un\nsignalement]
        UC_PAY[Payer via\nMobile Money]
        UC_CHAT_G[Contacter le\ncollecteur]
    end

    subgraph "Collecteur — Missions"
        UC_MISSIONS[Voir les missions\ndisponibles]
        UC_MAP[Visualiser sur\nla carte]
        UC_ACCEPT[Accepter une mission]
        UC_COLLECT[Marquer Collecté]
        UC_DELIVER[Livrer au centre\nde tri]
        UC_CHAT_C[Contacter le\ngénérateur]
    end

    subgraph "Centre de Tri"
        UC_RECEP[Confirmer la\nréception]
        UC_WEIGH[Saisir le poids\nréel en kg]
        UC_PAYOUT[Déclencher le\npaiement collecteur]
        UC_PROC[Enregistrer un\névénement de traitement]
    end

    subgraph "Administration"
        UC_USERS[Gérer les\nutilisateurs]
        UC_REQS[Superviser\ntous les signalements]
        UC_PAYOUTS[Valider / Rejeter\nles demandes de paiement]
        UC_STATS[Consulter les\nstatistiques]
    end

    GEN --> UC_REG
    GEN --> UC_LOGIN
    GEN --> UC_ROLE
    GEN --> UC_PWD
    GEN --> UC_CREAT
    GEN --> UC_LIST
    GEN --> UC_DETAIL
    GEN --> UC_CANCEL
    GEN --> UC_PAY
    GEN --> UC_CHAT_G
    UC_CREAT --> UC_PHOTO
    UC_CREAT --> UC_GPS

    COL --> UC_LOGIN
    COL --> UC_MISSIONS
    COL --> UC_MAP
    COL --> UC_ACCEPT
    COL --> UC_COLLECT
    COL --> UC_DELIVER
    COL --> UC_CHAT_C

    CTR --> UC_LOGIN
    CTR --> UC_RECEP
    CTR --> UC_WEIGH
    CTR --> UC_PAYOUT
    CTR --> UC_PROC
    UC_RECEP --> UC_WEIGH
    UC_RECEP --> UC_PAYOUT
    UC_RECEP --> UC_PROC

    ADM --> UC_LOGIN
    ADM --> UC_USERS
    ADM --> UC_REQS
    ADM --> UC_PAYOUTS
    ADM --> UC_STATS

    SYS --> UC_REG
    SYS --> UC_GPS
    SYS --> UC_PAY
    SYS --> UC_PAYOUT
```

---

## 2. Diagramme de Classes

```mermaid
classDiagram
    direction TB

    class AppUser {
        +String id
        +String email
        +String role
        +String preferredLanguage
        +String phoneE164
        +DateTime createdAt
        +DateTime updatedAt
        +String? fullName
        +String? avatarUrl
        +copyWith(...) AppUser
        +toJson() Map
        +fromJson(Map) AppUser
        +roleLabelFr() String
        +displayNameCapitalized() String
    }

    class WasteRequest {
        +String id
        +String generatorId
        +String? addressId
        +String wasteType
        +double quantityEstimateKg
        +String status
        +String? notes
        +DateTime? scheduledAt
        +String? timeSlot
        +DateTime createdAt
        +DateTime updatedAt
        +Map? address
        +copyWith(...) WasteRequest
        +toJson() Map
        +fromJson(Map) WasteRequest
    }

    class PayoutRequest {
        +String id
        +String userId
        +String provider
        +String phone
        +int amountXaf
        +String status
        +String? adminNote
        +DateTime createdAt
        +DateTime updatedAt
        +copyWith(...) PayoutRequest
        +toJson() Map
        +fromJson(Map) PayoutRequest
    }

    class Pickup {
        +String requestId
        +String collectorId
        +String? centerId
        +DateTime? acceptedAt
        +DateTime? collectedAt
        +DateTime? deliveredAt
        +DateTime updatedAt
    }

    class Address {
        +String id
        +String userId
        +String label
        +String city
        +String neighborhood
        +String details
        +double? latitude
        +double? longitude
    }

    class WasteRequestPhoto {
        +String id
        +String requestId
        +String uploadedBy
        +String url
        +DateTime createdAt
    }

    class EcoTransaction {
        +String id
        +String userId
        +String requestId
        +int points
        +String reason
        +DateTime updatedAt
    }

    class ProcessingEvent {
        +String id
        +String requestId
        +String centerId
        +double weighedKg
        +bool accepted
        +String? notes
        +DateTime createdAt
    }

    class AppUserService {
        -SupabaseClient client
        +getCurrentProfile() AppUser?
        +getProfile(userId) AppUser?
        +upsertProfile(...) void
        +updateRole(role) void
        +updateProfile(...) void
        +updateAvatarUrl(url) void
        +listUsers(...) List~AppUser~
        +ensureProfileForAuthUser(user) AppUser?
    }

    class WasteRequestService {
        -SupabaseClient client
        +listForCurrentGenerator() List~WasteRequest~
        +listAvailableMissions() List~WasteRequest~
        +getById(id) WasteRequest?
        +getMissionForCollector(id) WasteRequest?
        +create(...) WasteRequest
        +cancel(requestId) void
        +acceptMission(requestId) void
        +markCollected(requestId) void
        +markDelivered(requestId) void
        +markDeliveredToCenter(...) void
        +listPhotoUrls(requestId) List~String~
        +addPhotoUrl(...) void
        +confirmReceptionAtCenter(...) void
    }

    class ChatService {
        -SupabaseClient client
        +getOrCreateThreadForRequest(requestId) String
        +getOrCreateDirectThread(otherUserId) String
        +streamMessages(threadId) Stream
        +sendMessage(...) void
        +listThreadsForCurrentUser() List~Map~
    }

    class AuthManager {
        <<abstract>>
        +currentUser AuthUser?
        +signOut() Future
        +deleteUser(context) Future
        +updateEmail(...) Future
        +resetPassword(...) Future
        +resendEmailVerification(...) Future
    }

    class SupabaseAuthManager {
        -SupabaseClient client
        +signInWithEmail(...) AuthUser?
        +createAccountWithEmail(...) AuthUser?
        +signInWithGoogle(...) AuthUser?
        +sendPhoneOtp(...) void
        +verifyPhoneOtp(...) AuthUser?
    }

    AppUser "1" --> "0..*" WasteRequest : crée
    AppUser "1" --> "0..*" PayoutRequest : demande
    AppUser "1" --> "0..*" EcoTransaction : reçoit
    AppUser "1" --> "0..*" Address : possède
    WasteRequest "1" --> "0..*" WasteRequestPhoto : contient
    WasteRequest "1" --> "0..1" Pickup : fait l'objet de
    WasteRequest "1" --> "0..1" Address : localisée à
    WasteRequest "1" --> "0..*" ProcessingEvent : génère
    WasteRequest "1" --> "0..*" EcoTransaction : référence
    Pickup "1" --> "1" AppUser : collecteur
    ProcessingEvent "1" --> "1" AppUser : centre
    SupabaseAuthManager --|> AuthManager
    AppUserService ..> AppUser : manipule
    WasteRequestService ..> WasteRequest : manipule
    WasteRequestService ..> Pickup : manipule
    WasteRequestService ..> ProcessingEvent : manipule
    WasteRequestService ..> EcoTransaction : manipule
    ChatService ..> AppUser : appartient à
```

---

## 3. Diagrammes de Séquence

### 3.1 — Signalement d'un déchet (Générateur)

```mermaid
sequenceDiagram
    actor Gen as Générateur
    participant App as Flutter App
    participant GPS as Geolocator
    participant Store as Supabase Storage
    participant DB as Supabase DB
    participant Notif as PushNotification

    Gen->>App: Ouvre Nouveau Signalement
    App->>GPS: getCurrentLocation()
    GPS-->>App: LatLng(lat, lng)

    Gen->>App: Prend / sélectionne une photo
    App->>Store: uploadRequestPhoto(file)
    Store-->>App: URL publique

    Gen->>App: Saisit type, quantité, adresse, créneau
    Gen->>App: Valide le formulaire

    App->>DB: addresses.insert(city, neighborhood, lat, lng)
    DB-->>App: addressId

    App->>DB: waste_requests.insert(generatorId, addressId, type, qty, status=pending)
    DB-->>App: WasteRequest créé

    App->>DB: waste_request_photos.insert(requestId, url)
    DB-->>App: OK

    App-->>Gen: Confirmation - Signalement envoyé

    DB->>Notif: Déclenche notification collecteurs
    Notif-->>COL: Push - Nouvelle mission disponible
```

---

### 3.2 — Acceptation et collecte d'une mission (Collecteur)

```mermaid
sequenceDiagram
    actor Col as Collecteur
    participant App as Flutter App
    participant DB as Supabase DB
    participant NotifSvc as PushNotification
    actor Gen as Générateur

    Col->>App: Ouvre tableau de bord collecteur
    App->>DB: waste_requests.select(status=pending)
    DB-->>App: Liste des missions

    Col->>App: Sélectionne une mission
    App->>DB: waste_requests + addresses par id
    DB-->>App: Détail + coordonnées GPS

    Col->>App: Clique Accepter la mission
    App->>DB: pickups.insert(requestId, collectorId, acceptedAt)
    DB-->>App: OK ou MISSION_ALREADY_ACCEPTED

    App->>DB: waste_requests.update(status=accepted)
    DB-->>App: OK

    App-->>Col: Mission acceptée

    DB->>NotifSvc: Notifie le générateur
    NotifSvc-->>Gen: Push - Votre déchet sera collecté

    Note over Col,App: Collecteur se rend sur place

    Col->>App: Clique Marquer Collecté
    App->>DB: pickups.update(collectedAt)
    App->>DB: waste_requests.update(status=collected)
    DB-->>App: OK

    Col->>App: Choisit le centre de tri
    Col->>App: Clique Livrer au centre
    App->>DB: pickups.update(deliveredAt, centerId)
    App->>DB: waste_requests.update(status=delivered, centerId)
    DB-->>App: OK

    App-->>Col: Mission livrée avec succès
```

---

### 3.3 — Réception au centre de tri et paiement (Centre)

```mermaid
sequenceDiagram
    actor Ctr as Centre de Tri
    participant App as Flutter App
    participant DB as Supabase DB
    actor Col as Collecteur

    Ctr->>App: Ouvre formulaire de réception
    App->>DB: waste_requests.select(status=delivered, centerId)
    DB-->>App: Liste des livraisons

    Ctr->>App: Saisit le poids réel et notes
    Ctr->>App: Valide la réception

    App->>DB: processing_events.insert(requestId, centerId, weighedKg, accepted=true)
    DB-->>App: OK

    App->>DB: pickups.select(collector_id) par requestId
    DB-->>App: collectorId

    App->>DB: eco_transactions.select() - vérifie double paiement
    DB-->>App: résultat

    alt Premier paiement
        App->>DB: waste_requests.select(waste_type)
        DB-->>App: wasteType ex plastic

        Note right of App: Taux appliqués par type\nplastic=150 XAF/kg\nmixed=75 / metal=200\newaste=300 / organic=50

        App->>DB: eco_transactions.insert(userId=collectorId, points=amountXaf, reason=payout)
        DB-->>App: Transaction créée

        DB->>Col: Notification - Paiement reçu X XAF
    else Paiement déjà effectué
        App-->>Ctr: Paiement déjà traité
    end

    Ctr->>App: Demande un retrait Mobile Money
    App->>DB: payout_requests.insert(userId, provider, phone, amount)
    DB-->>App: PayoutRequest status=pending

    Note over DB: Admin valide manuellement

    DB->>Ctr: Notification statut paid ou rejected
```

---

## 4. Diagrammes C4

### 4.1 — C4 Niveau 1 : Contexte Système

```mermaid
graph TB
    subgraph "Utilisateurs"
        GEN_U["👤 Générateur\nCitoyen / Entreprise\nSignale des déchets"]
        COL_U["🚛 Collecteur\nAgent terrain\nCollecte et livre"]
        CTR_U["🏭 Centre de Tri\nValide et traite\nles déchets reçus"]
        ADM_U["⚙️ Administrateur\nSupervise la plateforme"]
    end

    subgraph "CleanCity System"
        CC["📱🌐 CleanCity\nApplication Flutter\nmobile + web"]
    end

    subgraph "Systèmes externes"
        SUP["🗄️ Supabase\nPostgreSQL + Auth\n+ Storage + Realtime"]
        GMAP["🗺️ Google Maps\nOpenRouteService\nCartographie"]
        ONESIG["🔔 OneSignal\nNotifications push"]
        MOBMONEY["💳 Mobile Money\nOrange Money / MTN\nPaiements locaux"]
        CICD["🔧 GitHub Actions\nCodemagic\nCI/CD builds"]
    end

    GEN_U -->|Signale, suit, paie| CC
    COL_U -->|Accepte, collecte, livre| CC
    CTR_U -->|Reçoit, valide, paie| CC
    ADM_U -->|Gère utilisateurs et paiements| CC

    CC -->|Auth, DB, Storage, Realtime| SUP
    CC -->|Géolocalisation, cartes| GMAP
    CC -->|Envoi de push| ONESIG
    CC -->|Paiement intégré| MOBMONEY
    CICD -->|Build APK, Web, iOS| CC
```

---

### 4.2 — C4 Niveau 2 : Conteneurs

```mermaid
graph TB
    subgraph "CleanCity Conteneurs"
        subgraph "Application Flutter"
            MOB["Flutter Mobile\nAndroid et iOS\nDart / go_router / provider"]
            WEB["Flutter Web\nAdministration\nDart / go_router"]
        end

        subgraph "Supabase BaaS"
            AUTH["Supabase Auth\nEmail, OTP, Google OAuth\nRLS policies"]
            POSTGRES["PostgreSQL\nusers, waste_requests\naddresses, pickups\nprocessing_events\neco_transactions\nchat_threads\npayout_requests"]
            STORAGE["Supabase Storage\nrequest_photos\nuser_uploads"]
            RT["Realtime\nChat polling\nSubscriptions"]
        end
    end

    subgraph "Services tiers"
        GMAPS2["Google Maps API\nOpenRouteService"]
        ONESIG2["OneSignal SDK"]
        MOBILE2["Mobile Money API"]
    end

    MOB -->|REST / Realtime| AUTH
    MOB -->|PostgREST queries| POSTGRES
    MOB -->|S3 upload| STORAGE
    MOB -->|Subscriptions| RT
    MOB -->|SDK| GMAPS2
    MOB -->|Push| ONESIG2
    MOB -->|Paiement| MOBILE2

    WEB -->|REST| AUTH
    WEB -->|PostgREST| POSTGRES
    WEB -->|Admin seulement| STORAGE
```

---

### 4.3 — C4 Niveau 3 : Composants (Application Flutter)

```mermaid
graph TB
    subgraph "Module Auth"
        AM["SupabaseAuthManager\nSignIn / SignUp / OTP\nGoogle OAuth"]
        AS["AuthScreens\nLogin / Signup\nPhone / RoleSelection"]
    end

    subgraph "Module Générateur"
        GD["GeneratorDashboard\nListe des signalements"]
        CR["CreateRequestScreen\nFormulaire + GPS + Photo"]
        RD["RequestDetailsScreen\nStatut + Chat"]
    end

    subgraph "Module Collecteur"
        CD["CollectorDashboard\nMissions + Carte"]
        MD["MissionDetailsScreen\nDétail + Acceptation"]
    end

    subgraph "Module Centre"
        CTD["CenterDashboard\nLivraisons reçues"]
        RF["ReceptionFormScreen\nPoids + Validation"]
    end

    subgraph "Module Admin"
        AD["AdminDashboard\nUtilisateurs + Paiements\n+ Statistiques"]
    end

    subgraph "Module Chat"
        CTS["ChatThreadsScreen\nListe conversations"]
        CRM["ChatRoomScreen\nMessages temps réel"]
    end

    subgraph "Services"
        AUS["AppUserService"]
        WRS["WasteRequestService"]
        PRS["PayoutRequestService"]
        CS["ChatService"]
        MUS["MediaUploadService"]
        MS["MapsService"]
        PNS["PushNotificationService"]
    end

    subgraph "Navigation"
        NAV["AppRouter\ngo_router\nRoute guards"]
    end

    AM --> AUS
    AS --> AM
    GD --> WRS
    CR --> WRS
    CR --> MUS
    CR --> MS
    RD --> WRS
    RD --> CS
    CD --> WRS
    CD --> MS
    MD --> WRS
    MD --> CS
    CTD --> WRS
    RF --> WRS
    AD --> AUS
    AD --> PRS
    CTS --> CS
    CRM --> CS

    NAV --> AS
    NAV --> GD
    NAV --> CD
    NAV --> CTD
    NAV --> AD
    NAV --> CTS
```

---

## 5. Diagramme Entité-Relation (Base de Données)

```mermaid
erDiagram
    users {
        uuid id PK
        string email
        string role
        string full_name
        string phone_e164
        string preferred_language
        string avatar_url
        timestamp created_at
        timestamp updated_at
    }

    addresses {
        uuid id PK
        uuid user_id FK
        string label
        string city
        string neighborhood
        string details
        float latitude
        float longitude
    }

    waste_requests {
        uuid id PK
        uuid generator_id FK
        uuid address_id FK
        uuid center_id FK
        string waste_type
        float quantity_estimate_kg
        string status
        string notes
        string time_slot
        timestamp scheduled_at
        timestamp created_at
        timestamp updated_at
    }

    waste_request_photos {
        uuid id PK
        uuid request_id FK
        uuid uploaded_by FK
        string url
        timestamp created_at
    }

    pickups {
        uuid request_id PK
        uuid collector_id FK
        uuid center_id FK
        timestamp accepted_at
        timestamp collected_at
        timestamp delivered_at
        timestamp updated_at
    }

    processing_events {
        uuid id PK
        uuid request_id FK
        uuid center_id FK
        float weighed_kg
        boolean accepted
        string notes
        timestamp created_at
    }

    eco_transactions {
        uuid id PK
        uuid user_id FK
        uuid request_id FK
        int points
        string reason
        timestamp updated_at
    }

    payout_requests {
        uuid id PK
        uuid user_id FK
        string provider
        string phone
        int amount_xaf
        string status
        string admin_note
        timestamp created_at
        timestamp updated_at
    }

    chat_threads {
        uuid id PK
        uuid request_id FK
        string kind
        string direct_key
        timestamp created_at
    }

    chat_messages {
        uuid id PK
        uuid thread_id FK
        uuid sender_id FK
        string body
        timestamp created_at
    }

    chat_thread_members {
        uuid thread_id FK
        uuid user_id FK
        timestamp created_at
    }

    users ||--o{ waste_requests : "crée"
    users ||--o{ addresses : "possède"
    users ||--o{ payout_requests : "demande"
    users ||--o{ eco_transactions : "reçoit"
    users ||--o{ waste_request_photos : "uploade"
    users ||--o{ chat_thread_members : "est membre de"
    users ||--o{ chat_messages : "envoie"
    waste_requests ||--o{ waste_request_photos : "contient"
    waste_requests ||--o| pickups : "fait l'objet de"
    waste_requests ||--o| addresses : "localisée à"
    waste_requests ||--o{ processing_events : "traitement"
    waste_requests ||--o{ eco_transactions : "référencée"
    waste_requests ||--o| chat_threads : "discussion"
    chat_threads ||--o{ chat_messages : "contient"
    chat_threads ||--o{ chat_thread_members : "membres"
    users ||--o{ pickups : "collecteur"
    users ||--o{ processing_events : "centre"
```

---

> **Visualisation :**  
> - **VS Code** : Extension *Markdown Preview Mermaid Support*  
> - **GitHub / GitLab** : Rendu natif dans les `.md`  
> - **En ligne** : [mermaid.live](https://mermaid.live)  
> - **Obsidian** : Plugin Mermaid intégré
