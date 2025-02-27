# MediSecure

## 🏥 Overview

MediSecure is a decentralized healthcare records and prescription management platform built on the Stacks blockchain. Our mission is to provide a secure, transparent, and patient-controlled system for managing medical data, teleconsultations, and prescription workflows.

MediSecure combines the security of blockchain technology with the privacy requirements of healthcare to create a system where patients control their data, healthcare providers have streamlined workflows, and all interactions are securely recorded and auditable.

## 📋 Features

### For Patients

- 🔐 **Full Control of Health Records**: Own and manage your health data
- 🩺 **Digital Consultation Management**: Book and track appointments with physicians
- 💊 **Prescription Tracking**: Monitor your medication orders from creation to fulfillment
- 🤝 **Granular Access Control**: Grant and revoke data access to healthcare providers

### For Physicians

- 📝 **Digital Consultation Records**: Document patient visits with cryptographic verification
- 🔄 **Streamlined Workflow**: Manage patient visits and create medication orders efficiently
- 📊 **Patient Data Access**: View authorized patient records securely

### For Dispensers (Pharmacies)

- 📋 **Medication Order Management**: Receive and process medication orders
- ✅ **Verification System**: Validate the authenticity of medication orders
- 📦 **Fulfillment Tracking**: Record medication dispensing with blockchain verification

### Technical Features

- 🔗 **Blockchain Security**: All transactions immutably recorded on Stacks blockchain
- 🔒 **End-to-End Encryption**: Patient data encrypted with public/private key pairs
- 💰 **Token Integration**: Native payment handling with SIP-010 tokens
- ⏱️ **Rate Limiting**: Built-in protection against system overload
- 🕒 **Timeout Handling**: Automatic expiration of unused medication orders

## 🚀 Getting Started

### Prerequisites

- [Stacks Wallet](https://hiro.so/wallet/install-web)
- [Clarinet](https://github.com/hirosystems/clarinet) (for development)
- Basic understanding of blockchain and healthcare workflows

### Installation

1. Clone the repository
   ```bash
   git clone https://github.com/medvault-protocol/medisecure.git
   cd medisecure
   ```

2. Install dependencies
   ```bash
   npm install
   ```

3. Run local development chain
   ```bash
   clarinet integrate
   ```

### Basic Usage

#### Registering as a User

```lisp
(contract-call? .medisecure-core register-account "patient" "PUBLIC_KEY")
```

#### Booking a Visit

```lisp
(contract-call? .medisecure-core book-visit 'PHYSICIAN_ADDRESS)
```

#### Creating a Medication Order

```lisp
(contract-call? .medisecure-core create-medication-order 'PATIENT_ADDRESS "Medication Name" u20)
```

## 🏗️ Architecture

### Smart Contracts

- **MediSecureCore**: The main contract handling user management, health records, visits, and medication orders
- **TokenContract**: SIP-010 compliant token contract for payment handling

### Data Flow

1. Users register with appropriate roles (patient, physician, dispenser)
2. Patients book visits with physicians
3. Physicians record visit summaries and create medication orders
4. Patients select dispensers for their medication orders
5. Dispensers fulfill medication orders
6. All transactions are recorded on-chain with appropriate data privacy

### Security Model

- Health record data is stored off-chain with only cryptographic hashes on-chain
- Public/private key encryption ensures only authorized parties access sensitive data
- Role-based access control enforces proper permissions throughout the system
- Patients maintain granular control over who can access their data

## 📖 API Reference

### Account Management

| Function | Description |
| --- | --- |
| `register-account` | Register a new user with a specific account type |
| `approve-access` | Grant data access to healthcare providers |
| `remove-access` | Revoke previously granted access |

### Visit Management

| Function | Description |
| --- | --- |
| `book-visit` | Schedule a new visit with a physician |
| `record-visit-summary` | Document the outcome of a patient visit |

### Medication Management

| Function | Description |
| --- | --- |
| `create-medication-order` | Create a new medication prescription |
| `choose-dispenser` | Select a pharmacy to fulfill the medication order |
| `fulfill-order` | Record the dispensing of medication |

### Health Record Management

| Function | Description |
| --- | --- |
| `update-health-record` | Update patient health record data |
| `get-health-record` | Retrieve patient health record data (if authorized) |

### Payment Handling

| Function | Description |
| --- | --- |
| `process-payment` | Process a payment between two parties |

## 🔄 Business Rules

- Maximum medication dosage: 1000 units
- Minimum medication dosage: 1 unit
- Visit frequency limit: Maximum 20 visits per physician per 24-hour period
- Medication order validity: 7 days from creation

## 🧪 Testing

Run the test suite to verify contract functionality:

```bash
clarinet test
```

For specific test files:

```bash
clarinet test tests/medisecure-core_test.ts
```

## 🔍 Audit Status

MediSecure smart contracts are currently undergoing security audit by [Security Firm]. Preliminary results show no critical vulnerabilities.

Final audit results will be published upon completion.

## 🤝 Contributing

We welcome contributions from the community! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please read our [Contributing Guidelines](CONTRIBUTING.md) for more details.

## 📅 Roadmap

- **Q1 2025**: Initial mainnet deployment
- **Q2 2025**: Mobile application release
- **Q3 2025**: Integration with electronic health record (EHR) systems
- **Q4 2025**: Cross-chain interoperability with other healthcare DApps

## 🔑 Security and Privacy

MediSecure takes healthcare privacy seriously:

- We comply with healthcare data regulations by storing sensitive data off-chain
- Blockchain records contain only cryptographic proofs of data integrity
- End-to-end encryption ensures data is viewable only by authorized parties
- All smart contracts undergo rigorous security auditing
