# College Coding Culture

- Started: 2025-12-26
- AI aid: Heavy

This project is to be submitted to the House of Innovation Hackathon conducted by GDG BIT Mesra, Jaipur.

## System Architecture

The application follows a **Service-Oriented Architecture (SOA)** on the client side, relying on Serverless/BaaS infrastructure.

```mermaid
graph TD
    %% Professional Styling Definitions
    classDef flutter fill:#e3f2fd,stroke:#1565c0,stroke-width:2px,color:#0d47a1;
    classDef service fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px,color:#1b5e20;
    classDef cloud fill:#fff3e0,stroke:#ef6c00,stroke-width:2px,color:#e65100;
    classDef db fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px,color:#4a148c;
    classDef actor fill:#eceff1,stroke:#455a64,stroke-width:2px,color:#263238;

    User([User]) --> MainEntry

    subgraph ClientApp ["Flutter Client Application"]
        style ClientApp fill:#fafafa,stroke:#9e9e9e,stroke-width:1px,stroke-dasharray: 5 5
        direction TB
        MainEntry(main.dart) --> AuthGate
        
        subgraph StateRouting ["State & Routing"]
            style StateRouting fill:#ffffff,stroke:#eeeeee
            AuthGate{Auth Gate}
            GlobalState[("Global Session<br/>(data.dart)")]
        end

        subgraph Presentation ["Presentation Layer"]
            style Presentation fill:#ffffff,stroke:#eeeeee
            direction TB
            AuthUI["Auth Page<br/>(Firebase UI)"]
            Onboarding[Onboarding Page]
            MainShell[Global Scaffold]
            
            subgraph MainPages ["Main Pages"]
                style MainPages fill:#f5f5f5,stroke:#e0e0e0
                direction LR
                Feed[Feed]
                Profile[Profile]
                Admin[Admin Console]
                Comm[Communities]
                Events[Events]
                Matching[Matching]
            end
        end

        subgraph LogicData ["Logic & Data Layer"]
            style LogicData fill:#f1f8e9,stroke:#c5e1a5
            DBService[[DatabaseService]]
            Models>Data Models]
        end
        
        %% Navigation Flow
        AuthGate -->|Unauthenticated| AuthUI
        AuthGate -->|New Account| Onboarding
        AuthGate -->|Authenticated| MainShell
        MainShell --> Feed & Profile & Comm & Events & Matching
        MainShell -.->|Role Check| Admin

        %% Data Flow
        AuthGate -.->|Fetch Profile| DBService
        MainShell & Onboarding --> DBService
        Feed & Profile & Admin & Comm & Events --> DBService
        
        DBService -.->|Hydrate| Models
        DBService -->|Cache Profile| GlobalState
        GlobalState -.->|Read| Feed & Profile
    end

    subgraph CloudInfra ["Cloud Infrastructure (BaaS)"]
        style CloudInfra fill:#fffde7,stroke:#fbc02d,stroke-width:1px
        direction TB
        
        FB_Auth[Firebase Auth]
        
        subgraph Firestore["Cloud Firestore (NoSQL)"]
            style Firestore fill:#ffffff,stroke:#ffe0b2
            UsersCol[(Users)]
            PostsCol[(Posts)]
            CommCol[(Communities)]
            EventCol[(Events)]
            ConfigCol[(Metadata/Config)]
        end

        SupaStorage[("Supabase Storage<br/>(Images)")]
    end

    %% Network Connections
    AuthUI <--> FB_Auth
    AuthGate -.->|Stream Auth State| FB_Auth
    
    DBService <-->|Streams/Future| Firestore
    DBService -->|Binary Upload| SupaStorage
    
    %% Database Relationships
    CommCol -.->|Sub-collection| PostsCol
    Admin -- "Destructive Ops" --> Firestore
    
    %% Apply Classes
    class User actor;
    class MainEntry,MainShell,Feed,Profile,Admin,Comm,Events,Matching,Onboarding,AuthUI flutter;
    class DBService,Models,GlobalState service;
    class FB_Auth,SupaStorage,Firestore cloud;
    class UsersCol,PostsCol,CommCol,EventCol,ConfigCol db;
```

## User Journey Flow

This diagram illustrates the process flow from the user's perspective, covering Authentication, Onboarding, and core feature loops.

```mermaid
graph LR
    %% Styling
    classDef start fill:#e1f5fe,stroke:#01579b,stroke-width:2px,color:#01579b;
    classDef action fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px,color:#1b5e20;
    classDef decision fill:#fff9c4,stroke:#fbc02d,stroke-width:2px,color:#f57f17;
    classDef system fill:#f3e5f5,stroke:#4a148c,stroke-width:2px,color:#4a148c;

    Start([Start App]) --> AuthCheck{Auth Session?}
    
    %% Authentication Phase
    AuthCheck -- No --> Login[Login / Register]
    Login -->|Guest| GuestLogic[Set Guest Profile]
    Login -->|Email| Auth[Firebase Auth]
    
    GuestLogic & Auth --> ProfileCheck{Profile Exists?}
    AuthCheck -- Yes --> ProfileCheck
    
    ProfileCheck -- No --> Onboarding["Onboarding<br/>(Skills, Bio)"]
    Onboarding --> SaveProfile[Save User Profile]
    SaveProfile --> Home
    
    ProfileCheck -- Yes --> Home[Home / Feed]
    
    %% Main Functional Loops
    Home --> UserAction{User Action}
    
    %% 1. Posting Loop
    subgraph Posting [Posting]
        direction TB
        UserAction -- Post --> RulesCheck{Daily Limit?}
        RulesCheck -- Pass --> Draft[Draft Post]
        Draft --> Upload[Upload Media]
        Upload --> SavePost[Save to DB]
        SavePost -->|Refresh| Home
    end
    
    %% 2. Features Loop
    subgraph Features [Core Features]
        direction TB
        UserAction -- Communities --> CommPage[Communities]
        CommPage -->|Create/Join| CommFeed[Comm Feed]
        
        UserAction -- Network --> SkillMatch[Matching]
        SkillMatch -->|Match| ProfileView[View Profile]
        ProfileView --> Follow[Follow]
        
        UserAction -- Admin --> IsAdmin{Is Admin?}
        IsAdmin -- Yes --> AdminPanel[Console]
        AdminPanel --> AdminOps[Ops & CleanUp]
    end

    %% Applying Classes
    class Start,Home,CommPage,CommFeed,AdminPanel,SkillMatch,ProfileView start;
    class Login,Onboarding,Draft,AdminOps,Follow action;
    class AuthCheck,ProfileCheck,UserAction,IsAdmin,RulesCheck decision;
    class GuestLogic,Auth,SaveProfile,Upload,SavePost system;
```
