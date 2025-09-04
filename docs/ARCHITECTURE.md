# Architecture Guide

## System Architecture Overview

Triage-BIOS.ai follows a clean, layered architecture designed for scalability, testability, and maintainability. The system is built using Flutter for cross-platform compatibility and integrates with Google Gemini AI for AI-powered triage decisions.

## Architecture Diagram

```mermaid
graph TB
    subgraph "Presentation Layer"
        PA[Patient Mobile App]
        HD[Hospital Dashboard]
        WA[Web Application]
    end
    
    subgraph "Business Logic Layer"
        TS[Triage Service]
        HS[Health Service]
        RS[Routing Service]
        NS[Notification Service]
    end
    
    subgraph "Data Access Layer"
        TR[Triage Repository]
        HR[Health Repository]
        RR[Routing Repository]
    end
    
    subgraph "Data Sources"
        GS[Gemini Service]
        AH[Apple Health]
        GF[Google Fit]
        CAPI[Custom APIs]
        DB[(SQLite Database)]
    end
    
    subgraph "External Services"
        GM[Google Gemini AI]
        GM[Google Maps]
        FCM[Firebase Cloud Messaging]
    end
    
    PA --> TS
    HD --> TS
    WA --> TS
    
    TS --> TR
    HS --> HR
    RS --> RR
    
    TR --> WS
    HR --> AH
    HR --> GF
    RR --> CAPI
    
    WS --> WX
    RS --> GM
    NS --> FCM
    
    TR --> DB
    HR --> DB
    RR --> DB
```

## Layer Responsibilities

### 1. Presentation Layer

**Purpose**: User interface and user experience
- **Patient Mobile App**: Flutter mobile application for patients
- **Hospital Dashboard**: Web-based dashboard for healthcare providers
- **Web Application**: Responsive web interface for broader access

**Key Components**:
- UI widgets and screens
- State management (BLoC pattern)
- User input validation
- Real-time updates

### 2. Business Logic Layer

**Purpose**: Core application logic and orchestration
- **Triage Service**: Main orchestration for triage assessments
- **Health Service**: Wearable device integration and vitals processing
- **Routing Service**: Hospital routing and optimization
- **Notification Service**: Real-time alerts and communications

**Key Responsibilities**:
- Business rule enforcement
- Data validation and transformation
- Service orchestration
- Error handling and logging

### 3. Data Access Layer

**Purpose**: Data persistence and external service integration
- **Repositories**: Abstract data access patterns
- **Data Sources**: Concrete implementations for data retrieval
- **Models**: Data transfer objects and serialization

**Key Features**:
- Repository pattern implementation
- Data caching strategies
- Offline capability
- Data synchronization

## Core Services Architecture

### Triage Service Flow

```mermaid
sequenceDiagram
    participant Patient
    participant TriageService
    participant GeminiService
    participant HealthService
    participant Database
    
    Patient->>TriageService: Submit symptoms
    TriageService->>HealthService: Get latest vitals
    HealthService-->>TriageService: Return vitals data
    TriageService->>GeminiService: Analyze symptoms + vitals
    GeminiService->>GeminiService: AI processing
    GeminiService-->>TriageService: Return assessment
    TriageService->>Database: Store result
    TriageService-->>Patient: Return triage result
```

### Health Service Integration

```mermaid
graph LR
    subgraph "Wearable Devices"
        AW[Apple Watch]
        GW[Galaxy Watch]
        FB[Fitbit]
        OW[Other Wearables]
    end
    
    subgraph "Health Platforms"
        AH[Apple HealthKit]
        GH[Google Health Connect]
        FP[Fitbit API]
    end
    
    subgraph "Health Service"
        HA[Health Aggregator]
        VP[Vitals Processor]
        VV[Vitals Validator]
    end
    
    AW --> AH
    GW --> GH
    FB --> FP
    OW --> GH
    
    AH --> HA
    GH --> HA
    FP --> HA
    
    HA --> VP
    VP --> VV
    VV --> TS[Triage Service]
```

## Data Models

### Core Entities

```mermaid
classDiagram
    class PatientVitals {
        +int? heartRate
        +String? bloodPressure
        +double? temperature
        +double? oxygenSaturation
        +int? respiratoryRate
        +DateTime timestamp
        +String? deviceSource
        +bool hasCriticalVitals()
        +double vitalsSeverityBoost()
    }
    
    class TriageResult {
        +String assessmentId
        +double severityScore
        +UrgencyLevel urgencyLevel
        +String explanation
        +List~String~ keySymptoms
        +List~String~ recommendedActions
        +PatientVitals? vitals
        +DateTime timestamp
        +bool isCritical()
        +String vitalsExplanation()
    }
    
    class Patient {
        +String id
        +Demographics demographics
        +MedicalHistory medicalHistory
        +CurrentSymptoms currentSymptoms
        +Location location
    }
    
    class Hospital {
        +String id
        +String name
        +Location location
        +Capabilities capabilities
        +Capacity capacity
        +Performance performance
    }
    
    PatientVitals ||--o{ TriageResult
    Patient ||--o{ TriageResult
    TriageResult }o--|| Hospital
    }
```

## AI Processing Pipeline

### Symptom Analysis Flow

```mermaid
flowchart TD
    A[Raw Symptoms Input] --> B[Text Preprocessing]
    B --> C[Symptom Extraction]
    C --> D[Medical Entity Recognition]
    D --> E[Severity Classification]
    
    F[Vitals Data] --> G[Clinical Threshold Check]
    G --> H[Trend Analysis]
    H --> I[Risk Factor Calculation]
    
    E --> J[Score Combination Algorithm]
    I --> J
    
    J --> K{Score ≥ 8?}
    K -->|Yes| L[Critical Alert Pipeline]
    K -->|No| M[Standard Processing]
    
    L --> N[Emergency Services Notification]
    M --> O[Hospital Routing]
    N --> P[Generate Explanation]
    O --> P
    
    P --> Q[Return Triage Result]
```

### Vitals Processing Algorithm

```mermaid
flowchart TD
    A[Raw Vitals Data] --> B[Data Validation]
    B --> C[Quality Assessment]
    C --> D{Quality > Threshold?}
    
    D -->|No| E[Flag Low Quality]
    D -->|Yes| F[Clinical Threshold Analysis]
    
    F --> G[Heart Rate Check]
    F --> H[SpO2 Check]
    F --> I[Temperature Check]
    F --> J[Blood Pressure Check]
    
    G --> K[Calculate HR Boost]
    H --> L[Calculate SpO2 Boost]
    I --> M[Calculate Temp Boost]
    J --> N[Calculate BP Boost]
    
    K --> O[Combine Boosts]
    L --> O
    M --> O
    N --> O
    
    O --> P[Apply Boost Cap (3.0)]
    E --> Q[Return with Warning]
    P --> R[Return Enhanced Score]
```

## Security Architecture

### Data Protection Flow

```mermaid
graph TB
    subgraph "Data Input"
        UI[User Interface]
        API[API Endpoints]
        WD[Wearable Devices]
    end
    
    subgraph "Security Layer"
        AUTH[Authentication]
        AUTHZ[Authorization]
        ENC[Encryption]
        VAL[Validation]
    end
    
    subgraph "Data Processing"
        BL[Business Logic]
        AI[AI Processing]
        DB[Database]
    end
    
    subgraph "Audit & Compliance"
        LOG[Audit Logging]
        MON[Monitoring]
        COMP[Compliance Check]
    end
    
    UI --> AUTH
    API --> AUTH
    WD --> AUTH
    
    AUTH --> AUTHZ
    AUTHZ --> VAL
    VAL --> ENC
    
    ENC --> BL
    BL --> AI
    AI --> DB
    
    BL --> LOG
    AI --> LOG
    DB --> LOG
    
    LOG --> MON
    MON --> COMP
```

## Scalability Considerations

### Horizontal Scaling Strategy

```mermaid
graph TB
    subgraph "Load Balancer"
        LB[Load Balancer]
    end
    
    subgraph "Application Tier"
        APP1[App Instance 1]
        APP2[App Instance 2]
        APP3[App Instance N]
    end
    
    subgraph "Service Tier"
        TS1[Triage Service 1]
        TS2[Triage Service 2]
        HS1[Health Service 1]
        HS2[Health Service 2]
    end
    
    subgraph "Data Tier"
        CACHE[Redis Cache]
        DB1[Database Primary]
        DB2[Database Replica]
    end
    
    subgraph "External Services"
        GM[Gemini AI]
        HEALTH[Health APIs]
    end
    
    LB --> APP1
    LB --> APP2
    LB --> APP3
    
    APP1 --> TS1
    APP2 --> TS2
    APP3 --> HS1
    
    TS1 --> CACHE
    TS2 --> CACHE
    HS1 --> DB1
    HS2 --> DB2
    
    TS1 --> WX
    HS1 --> HEALTH
```

## Performance Optimization

### Caching Strategy

```mermaid
graph LR
    subgraph "Cache Layers"
        L1[L1: In-Memory Cache]
        L2[L2: Redis Cache]
        L3[L3: Database Cache]
    end
    
    subgraph "Data Sources"
        GM[Gemini AI API]
        HEALTH[Health APIs]
        DB[Database]
    end
    
    APP[Application] --> L1
    L1 -->|Miss| L2
    L2 -->|Miss| L3
    L3 -->|Miss| GM
    L3 -->|Miss| HEALTH
    L3 -->|Miss| DB
    
    L1 -.->|TTL: 5min| L1
    L2 -.->|TTL: 1hr| L2
    L3 -.->|TTL: 24hr| L3
```

## Error Handling Strategy

### Circuit Breaker Pattern

```mermaid
stateDiagram-v2
    [*] --> Closed
    Closed --> Open : Failure threshold reached
    Open --> HalfOpen : Timeout elapsed
    HalfOpen --> Closed : Success
    HalfOpen --> Open : Failure
    
    Closed : Normal operation
    Open : Fail fast, use fallback
    HalfOpen : Test if service recovered
```

## Deployment Architecture

### Cloud Infrastructure

```mermaid
graph TB
    subgraph "IBM Cloud"
        subgraph "Compute"
            K8S[Kubernetes Cluster]
            CF[Cloud Functions]
        end
        
        subgraph "AI Services"
            GM[Gemini AI]
        end
        
        subgraph "Data Services"
            DB2[Db2 Database]
            COS[Cloud Object Storage]
        end
        
        subgraph "Integration"
            API[API Gateway]
            MQ[Message Queue]
        end
    end
    
    subgraph "External Services"
        HEALTH[Health APIs]
        MAPS[Maps APIs]
        NOTIFY[Notification Services]
    end
    
    K8S --> WX
    K8S --> WD
    K8S --> DB2
    CF --> COS
    
    API --> K8S
    MQ --> CF
    
    K8S --> HEALTH
    K8S --> MAPS
    CF --> NOTIFY
```

This architecture ensures:
- **Scalability**: Horizontal scaling with load balancing
- **Reliability**: Circuit breakers and fallback mechanisms
- **Performance**: Multi-layer caching and optimization
- **Security**: End-to-end encryption and audit logging
- **Maintainability**: Clean separation of concerns and modular design