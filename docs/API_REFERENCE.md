# API Reference

## Overview

The Triage-BIOS.ai API provides endpoints for AI-powered emergency triage assessment, wearable vitals integration, and hospital routing. All endpoints return JSON responses and support real-time processing.

## Base URL

```
https://api.triage-bios.ai/v1
```

## Authentication

All API requests require authentication using API keys or OAuth 2.0 tokens.

```http
Authorization: Bearer <your-api-token>
Content-Type: application/json
```

## Core Endpoints

### Triage Assessment

#### POST /triage/assess

Performs AI-powered triage assessment combining symptoms and vitals data.

**Request Body:**

```json
{
  "symptoms": "I have chest pain and difficulty breathing",
  "vitals": {
    "heartRate": 130,
    "bloodPressure": "150/95",
    "temperature": 99.8,
    "oxygenSaturation": 92.0,
    "respiratoryRate": 22,
    "timestamp": "2024-01-15T10:30:00Z",
    "deviceSource": "Apple Watch Series 9"
  },
  "demographics": {
    "age": 45,
    "gender": "male",
    "language": "en"
  },
  "location": {
    "latitude": 40.7128,
    "longitude": -74.0060
  }
}
```

**Response:**

```json
{
  "assessmentId": "triage_1705312200000",
  "severityScore": 10.0,
  "confidenceInterval": {
    "lower": 9.5,
    "upper": 10.0
  },
  "urgencyLevel": "CRITICAL",
  "explanation": "Chest pain and breathing difficulties combined with elevated heart rate and low oxygen saturation indicate a potential cardiac emergency requiring immediate attention.",
  "keySymptoms": [
    "chest pain",
    "difficulty breathing"
  ],
  "concerningFindings": [
    "elevated heart rate (130 bpm)",
    "low oxygen saturation (92%)",
    "severe symptoms reported"
  ],
  "recommendedActions": [
    "Call 911 immediately",
    "Do not drive yourself",
    "Stay calm and monitor symptoms"
  ],
  "vitalsContribution": 3.0,
  "vitalsExplanation": "Concerning vitals detected: elevated heart rate (130 bpm), low oxygen saturation (92%). This increased the severity score by +3.0 points.",
  "aiModelVersion": "granite-13b-v1.0.0",
  "timestamp": "2024-01-15T10:30:00Z",
  "processingTime": 650
}
```

**Status Codes:**
- `200 OK` - Assessment completed successfully
- `400 Bad Request` - Invalid input data
- `429 Too Many Requests` - Rate limit exceeded
- `500 Internal Server Error` - AI service unavailable

---

### Health Data Integration

#### GET /health/vitals/latest

Retrieves the latest vitals data from connected wearable devices.

**Query Parameters:**
- `deviceTypes` (optional): Comma-separated list of device types (apple_health, google_fit, fitbit)
- `maxAge` (optional): Maximum age of data in minutes (default: 60)

**Response:**

```json
{
  "vitals": {
    "heartRate": 72,
    "bloodPressure": "120/80",
    "temperature": 98.6,
    "oxygenSaturation": 98.0,
    "respiratoryRate": 16,
    "heartRateVariability": 45.2,
    "timestamp": "2024-01-15T10:25:00Z",
    "deviceSource": "Apple Watch Series 9",
    "dataQuality": 0.95
  },
  "deviceStatus": {
    "connected": true,
    "batteryLevel": 85,
    "lastSync": "2024-01-15T10:25:00Z"
  }
}
```

#### POST /health/permissions/request

Requests permissions for health data access.

**Request Body:**

```json
{
  "permissions": [
    "heart_rate",
    "blood_pressure",
    "temperature",
    "oxygen_saturation",
    "respiratory_rate"
  ],
  "deviceType": "apple_health"
}
```

**Response:**

```json
{
  "status": "granted",
  "permissions": {
    "heart_rate": "granted",
    "blood_pressure": "granted",
    "temperature": "granted",
    "oxygen_saturation": "granted",
    "respiratory_rate": "denied"
  },
  "message": "Most permissions granted. Respiratory rate requires manual approval in Health app."
}
```

---

### Hospital Routing

#### POST /routing/find-hospitals

Finds optimal hospitals based on patient condition and location.

**Request Body:**

```json
{
  "location": {
    "latitude": 40.7128,
    "longitude": -74.0060
  },
  "severityScore": 8.5,
  "specialization": "cardiology",
  "maxDistance": 50,
  "preferences": {
    "preferredHospitals": ["hospital_123"],
    "avoidHospitals": ["hospital_456"],
    "insuranceNetwork": "blue_cross"
  }
}
```

**Response:**

```json
{
  "recommendedHospital": {
    "id": "hospital_789",
    "name": "Metropolitan General Hospital",
    "location": {
      "latitude": 40.7589,
      "longitude": -73.9851,
      "address": "1000 Medical Center Dr, New York, NY 10001"
    },
    "distance": 5.2,
    "estimatedTravelTime": 12,
    "estimatedWaitTime": 15,
    "treatmentStartTime": "2024-01-15T11:00:00Z",
    "capacity": {
      "availableBeds": 8,
      "emergencyBeds": 3,
      "icuBeds": 2
    },
    "specializations": ["cardiology", "emergency_medicine"],
    "outcomeConfidence": 0.92
  },
  "alternativeHospitals": [
    {
      "id": "hospital_101",
      "name": "City Medical Center",
      "distance": 7.8,
      "estimatedWaitTime": 25,
      "outcomeConfidence": 0.88
    }
  ],
  "routeDetails": {
    "trafficConditions": "moderate",
    "alternativeRoutes": 2,
    "emergencyRouteAvailable": true
  }
}
```

---

### System Health

#### GET /health/status

Returns system health status and service availability.

**Response:**

```json
{
  "status": "healthy",
  "services": {
    "gemini": {
      "status": "healthy",
      "responseTime": 245,
      "lastCheck": "2024-01-15T10:30:00Z"
    },
    "healthServices": {
      "status": "healthy",
      "connectedDevices": 1,
      "lastSync": "2024-01-15T10:25:00Z"
    },
    "database": {
      "status": "healthy",
      "connections": 5,
      "responseTime": 12
    }
  },
  "version": "1.0.0",
  "uptime": 86400
}
```

---

## Data Models

### PatientVitals

```json
{
  "heartRate": 72,
  "bloodPressure": "120/80",
  "temperature": 98.6,
  "oxygenSaturation": 98.0,
  "respiratoryRate": 16,
  "heartRateVariability": 45.2,
  "timestamp": "2024-01-15T10:25:00Z",
  "deviceSource": "Apple Watch Series 9",
  "dataQuality": 0.95
}
```

### TriageResult

```json
{
  "assessmentId": "triage_1705312200000",
  "severityScore": 7.5,
  "confidenceInterval": {
    "lower": 7.0,
    "upper": 8.0
  },
  "urgencyLevel": "URGENT",
  "explanation": "Symptoms indicate urgent medical attention needed",
  "keySymptoms": ["chest pain", "shortness of breath"],
  "concerningFindings": ["elevated heart rate"],
  "recommendedActions": ["Seek emergency care promptly"],
  "vitalsContribution": 2.0,
  "aiModelVersion": "granite-13b-v1.0.0",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Hospital

```json
{
  "id": "hospital_789",
  "name": "Metropolitan General Hospital",
  "location": {
    "latitude": 40.7589,
    "longitude": -73.9851,
    "address": "1000 Medical Center Dr, New York, NY 10001"
  },
  "capabilities": {
    "traumaLevel": 1,
    "specializations": ["cardiology", "neurology", "emergency_medicine"],
    "certifications": ["joint_commission", "magnet"],
    "equipment": ["cath_lab", "ct_scanner", "mri"]
  },
  "capacity": {
    "totalBeds": 500,
    "availableBeds": 45,
    "icuBeds": 8,
    "emergencyBeds": 12
  },
  "performance": {
    "averageWaitTime": 18,
    "patientSatisfaction": 4.2,
    "outcomeMetrics": {
      "mortalityRate": 0.02,
      "readmissionRate": 0.08
    }
  }
}
```

---

## Error Responses

### Standard Error Format

```json
{
  "error": {
    "code": "INVALID_VITALS_DATA",
    "message": "Heart rate value is outside valid range (30-200 bpm)",
    "details": {
      "field": "vitals.heartRate",
      "value": 250,
      "validRange": "30-200"
    },
    "timestamp": "2024-01-15T10:30:00Z",
    "requestId": "req_1705312200000"
  }
}
```

### Common Error Codes

| Code | Description | HTTP Status |
|------|-------------|-------------|
| `INVALID_INPUT` | Request validation failed | 400 |
| `MISSING_REQUIRED_FIELD` | Required field not provided | 400 |
| `INVALID_VITALS_DATA` | Vitals data outside valid ranges | 400 |
| `UNAUTHORIZED` | Invalid or missing authentication | 401 |
| `FORBIDDEN` | Insufficient permissions | 403 |
| `RESOURCE_NOT_FOUND` | Requested resource not found | 404 |
| `RATE_LIMIT_EXCEEDED` | Too many requests | 429 |
| `AI_SERVICE_UNAVAILABLE` | Gemini AI service down | 503 |
| `HEALTH_SERVICE_ERROR` | Wearable device connection failed | 503 |
| `INTERNAL_ERROR` | Unexpected server error | 500 |

---

## Rate Limits

| Endpoint | Rate Limit | Window |
|----------|------------|--------|
| `/triage/assess` | 100 requests | 1 hour |
| `/health/vitals/latest` | 1000 requests | 1 hour |
| `/routing/find-hospitals` | 500 requests | 1 hour |
| `/health/status` | 10000 requests | 1 hour |

Rate limit headers are included in all responses:

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1705315800
```

---

## SDKs and Libraries

### Flutter/Dart SDK

```dart
import 'package:triage_bios_ai/triage_client.dart';

final client = TriageClient(
  apiKey: 'your-api-key',
  baseUrl: 'https://api.triage-bios.ai/v1',
);

final result = await client.assessSymptoms(
  symptoms: 'I have chest pain',
  vitals: PatientVitals(
    heartRate: 130,
    oxygenSaturation: 92.0,
    timestamp: DateTime.now(),
  ),
);
```

### JavaScript SDK

```javascript
import { TriageClient } from '@triage-bios-ai/js-sdk';

const client = new TriageClient({
  apiKey: 'your-api-key',
  baseUrl: 'https://api.triage-bios.ai/v1'
});

const result = await client.assessSymptoms({
  symptoms: 'I have chest pain',
  vitals: {
    heartRate: 130,
    oxygenSaturation: 92.0,
    timestamp: new Date().toISOString()
  }
});
```

---

## Webhooks

### Triage Alert Webhook

Triggered when a critical triage assessment (score ≥ 8) is completed.

**Payload:**

```json
{
  "event": "triage.critical_alert",
  "timestamp": "2024-01-15T10:30:00Z",
  "data": {
    "assessmentId": "triage_1705312200000",
    "severityScore": 9.5,
    "urgencyLevel": "CRITICAL",
    "patientLocation": {
      "latitude": 40.7128,
      "longitude": -74.0060
    },
    "recommendedHospital": {
      "id": "hospital_789",
      "name": "Metropolitan General Hospital",
      "estimatedArrivalTime": "2024-01-15T10:45:00Z"
    }
  }
}
```

### Webhook Configuration

```http
POST /webhooks/configure

{
  "url": "https://your-server.com/webhooks/triage",
  "events": ["triage.critical_alert", "triage.completed"],
  "secret": "your-webhook-secret"
}
```

---

## Testing

### Test Environment

Base URL: `https://api-test.triage-bios.ai/v1`

Test API keys are available in the developer console.

### Mock Data

The test environment provides realistic mock responses for development and testing:

```bash
curl -X POST https://api-test.triage-bios.ai/v1/triage/assess \
  -H "Authorization: Bearer test-api-key" \
  -H "Content-Type: application/json" \
  -d '{"symptoms": "test chest pain", "vitals": {"heartRate": 130}}'
```

This comprehensive API reference provides all the information needed to integrate with the Triage-BIOS.ai platform.