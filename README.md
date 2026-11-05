# Foresight
AI-powered iOS inventory management using Meta Muse, computer vision, OCR, and autonomous agents to identify manufacturing parts, track materials, and streamline warehouse operations.

**Built for the Meta AI Developer Hackathon 2026**

Foresight is a native iOS application designed to help manufacturers identify inventory discrepancies, investigate their root causes, and recommend corrective actions using artificial intelligence.

The application combines computer vision, manufacturing inventory data, voice-guided investigations, and Meta AI to simplify inventory control and improve manufacturing accuracy.

---

## The Problem

Manufacturing facilities frequently struggle with inaccurate inventory balances, missing production transactions, undocumented scrap, incorrect bills of materials, and material substitutions.

A typical inventory-control process involves:

1. Extracting updated inventory information from the ERP system.
2. Exporting the data into Excel.
3. Running macros to organize inventory discrepancies.
4. Prioritizing parts with the largest negative balances.
5. Assigning cycle counters to locate and count materials.
6. Reviewing reported quantities.
7. Investigating possible root causes.
8. Completing authorized inventory corrections and preventive actions.

This process requires significant manual effort and can contribute to financial losses, production delays, and inaccurate physical inventories.

**Foresight helps reduce the effort required to identify, investigate, and document these problems.**

---

## Key Features

### AI Manufacturing Part Recognition

- Capture manufacturing parts using the iPhone camera.
- Analyze photographs using Meta AI.
- Identify possible manufacturing components.
- Estimate visible quantities.
- Match identified parts with manufacturing inventory records.
- Allow employees to confirm part identification before continuing.

### Manufacturing Inventory Intelligence

- Search for manufacturing parts by part number.
- Retrieve inventory information through the Foresight backend.
- View inventory balances across manufacturing locations.
- Identify positive, negative, and zero balances.
- Display material specifications and engineering information.
- Review manufacturing revisions, gauge, thickness, standard weight, and scrap factors.
- Explore parent-child bill-of-material relationships.

### AI Voice-Guided Root Cause Analysis

Foresight guides employees through a manufacturing investigation using spoken questions and speech recognition.

Topics include:

- Part identification
- Physical inventory counts
- Inventory locations
- Material specifications
- Coil usage and substitutions
- Engineering revisions
- Standard weights and scrap factors
- Bill-of-material consumption
- Manufacturing orders
- Production reporting and inventory transactions

Employees can provide responses using their voice or keyboard.

### AI-Generated Investigation Reports

Using Meta AI, Foresight generates:

- Investigation summaries
- Inventory and physical count findings
- Completed and outstanding checks
- Possible root causes
- Recommended corrective actions
- Preventive measures
- Follow-up verification plans
- Professional management email drafts

Reports can be stored locally on the device and reopened for review.

### Manufacturing Transaction Interface

Foresight also includes interface workflows for:

- Reporting production
- Transferring pieces
- Reporting scrap
- Issuing materials to manufacturing orders

Inventory-changing operations require a configured transaction service and appropriate approval. Demonstration workflows do not automatically modify production inventory.

---

## Technology Stack

| Technology | Purpose |
|---|---|
| Swift | Native iOS development |
| SwiftUI | Application interface |
| Apple Speech Framework | Speech recognition |
| AVFoundation | Voice synthesis and audio |
| Meta AI | Image analysis and manufacturing RCA |
| Vercel | Hosted backend API |
| Supabase | Manufacturing inventory and engineering data |
| REST APIs | Application-to-backend communication |
| JSON | Data exchange and local report storage |

---

## System Architecture

**iOS Application (SwiftUI)**

↓

**Foresight REST API (Vercel)**

↓

**Supabase Manufacturing Database + Meta AI**

The iOS application communicates with the hosted backend over HTTPS.

Sensitive Supabase and Meta API credentials remain on the backend and are not embedded in the iOS application.

---

## Requirements

To build Foresight, you need:

- A Mac computer
- Xcode with the project's required iOS SDK
- An iPhone Simulator or compatible physical iPhone
- Internet connectivity
- Access to the configured Foresight backend

A physical iPhone is recommended for testing the camera and voice-guided investigation features.

The simulator can be used for interface testing, manual part searches, report viewing, and other supported functionality.

---

## Manufacturing Test Images

The `sample-images/` directory contains example manufacturing photographs for testing Foresight's computer vision and AI inventory recognition features.

### How to Test

1. Download the sample images from this repository.
2. Save the selected image to your iPhone's Photos library or the iOS Simulator.
3. Launch the Foresight application.
4. Select **Choose Existing Photo**.
5. Choose one of the manufacturing images.
6. Run the AI scanning and recognition workflow.
7. Review the detected components and estimated quantities.
8. Confirm the part identification before proceeding with the manufacturing investigation.

Images may include raw materials, manufactured components, inventory storage locations, and production environments.

AI recognition results are estimates and should be confirmed before making inventory decisions.

## Installation Instructions

### Step 1 — Clone the GitHub Repository

Open Terminal on your Mac and run:

```bash
git clone https://github.com/YOUR_USERNAME/Foresight.git
```

Replace `YOUR_USERNAME` with the actual GitHub account hosting the repository.

Navigate to the project directory:

```bash
cd Foresight
```

### Step 2 — Open the Xcode Project

Locate:

```text
Foresight.xcodeproj
```

Double-click the project or run:

```bash
open Foresight.xcodeproj
```

Wait for Xcode to load the project.

### Step 3 — Resolve Dependencies

If Xcode requests package resolution, allow it to finish.

You can also select:

**File → Packages → Resolve Package Versions**

### Step 4 — Configure the Run Destination

In Xcode:

1. Select the Foresight scheme.
2. Choose a compatible iPhone Simulator.
3. Ensure the Foresight app target is selected.
4. Press **Command + R** to build and run.

For a physical iPhone, connect the device and configure code signing under:

**Target → Signing & Capabilities**

Select your own Apple development team if required.

### Step 5 — Launch Foresight

Once the application launches, you can begin exploring the manufacturing inventory features.

No in-app user account is required for the hackathon demonstration.

---

## How to Test Foresight

### Test 1 — Manufacturing Part Lookup

1. Launch Foresight.
2. Locate **Manufacturing Part Lookup**.
3. Enter a part number available in the configured backend inventory.
4. Tap **Search Manufacturing Database**.
5. Review the part description, inventory quantities, and manufacturing details.

### Test 2 — AI Part Recognition

1. Tap **Open Camera** or **Choose Existing Photo**.
2. Capture or select a photograph of manufacturing components.
3. Tap **Scan, Identify & Count**.
4. Review the detected items and estimated quantities.
5. Select or manually enter the correct manufacturing part number.
6. Open the corresponding part details.

AI identification and quantity estimates require employee confirmation.

### Test 3 — Manufacturing Inventory Details

From Part Details, review:

- Part number and description
- ERP inventory balance
- Inventory quantities by area
- Material and revision
- Gauge and thickness
- Standard weight
- Scrap factor
- Bill-of-material components, where available

Some engineering specifications are synthetic test records associated with imported manufacturing part identifiers.

### Test 4 — AI Root Cause Investigation

1. Open a manufacturing part.
2. Select **Analyze This Part**.
3. Follow the voice-guided investigation.
4. Answer questions about physical counts, materials, production, scrap, and manufacturing orders.
5. Advance through the investigation.
6. Select **Generate AI Root Cause Report**.

Foresight sends the investigation information to the backend for AI analysis.

### Test 5 — Review the AI Report

The generated report may include:

- Investigation summary
- Inventory and physical count information
- Possible root causes
- Corrective-action recommendations
- Preventive measures
- Outstanding investigations
- Management communication

Select **Email Management** or the available sharing option to prepare the report for review.

Sending an email requires a configured email application or supported sharing destination.

### Test 6 — Saved Investigations

Open **Saved Root Cause Reports** from the application.

Previously saved reports can be reopened on the same device.

Local reports are stored in the application's private storage and are not automatically synchronized between devices.

---

## Backend Configuration

The iOS application connects to the hosted Foresight API:

```text
https://foresight-omega.vercel.app
```

The backend includes routes for manufacturing part lookup, image analysis, scanning, and root cause analysis.

Example endpoints:

```text
GET  /api/parts/{partNumber}
POST /api/scan
POST /api/analyze
GET  /api/rca/part?number={partNumber}
POST /api/rca/analyze
```

The exact capabilities of these routes depend on the deployed backend configuration.

### Environment Variables

The backend uses server-side environment variables, including:

```text
SUPABASE_URL
SUPABASE_SECRET_KEY
MODEL_API_KEY
```

The Meta API key variable must match the configuration used by the deployed backend.

**Never commit actual API keys, database secrets, or private credentials to GitHub.**

The iOS project uses the hosted API. Running a completely independent backend requires the backend source code, database setup, and corresponding environment configuration.

---

### AI API Access for Hackathon Judges

Foresight uses a hosted Vercel backend for Meta AI inference and manufacturing inventory retrieval.

The iOS application does not require judges to obtain or configure Meta AI or Supabase API keys.

**Hosted demonstration API:** https://foresight-omega.vercel.app

To run the demonstration:

1. Clone this repository.
2. Open `Foresight.xcodeproj` in Xcode.
3. Select a compatible iPhone simulator or physical device.
4. Build and launch the application.
5. Connect to the internet to access the hosted manufacturing and AI services.

The hosted backend contains the required server-side credentials. These credentials are not distributed with the source code.

For an independent backend deployment, developers must configure their own Meta AI and Supabase credentials, along with the required database resources.

The hosted demonstration uses test data and should not be used for production inventory adjustments.

## Example Manufacturing Investigation

Consider an inventory part with a negative ERP balance.

An employee locates the part, reviews the manufacturing information, and performs a physical count.

During the investigation, Foresight asks questions such as:

- Does the physical part match the inventory record?
- Which locations were counted?
- Was the correct coil or material used?
- Were rejected pieces reported as scrap?
- Does the manufacturing order reference the correct components?
- Were production and material transactions posted correctly?

Meta AI evaluates the available information and generates potential explanations and recommended follow-up actions.

The application does not treat a possible cause as confirmed without supporting evidence.

---

## Safety and Data Considerations

Foresight is a hackathon prototype.

Some engineering specifications and manufacturing relationships are generated for demonstration purposes and should not be used as approved production standards.

Inventory corrections, material substitutions, manufacturing-order changes, and engineering revisions require appropriate human review and authorization.

AI responses are recommendations, not automatic production decisions.

The public demonstration should not contain confidential manufacturing information, private employee information, or production credentials.

---

## Troubleshooting

### Application Does Not Build

- Confirm Xcode is installed.
- Select a compatible simulator.
- Resolve package dependencies.
- Confirm all required Swift files are included in the Foresight target.

### Camera Is Unavailable

Use a physical iPhone or select an existing photograph from the photo library.

### Voice Recognition Does Not Work

- Allow microphone permission.
- Allow speech recognition permission.
- Confirm speech recognition is supported and available on the device.

### Manufacturing Data Does Not Load

- Confirm internet connectivity.
- Verify that the hosted Vercel backend is operational.
- Confirm the requested part exists in the configured inventory database.

### AI Report Generation Fails

- Check internet connectivity.
- Confirm the Meta AI backend is configured.
- Review Vercel logs for timeout or API errors.
- Retry without discarding the recorded investigation answers.

---

## Project Vision

Manufacturing inventory discrepancies affect far more than physical counts.

They influence material purchasing, production planning, financial reporting, labor efficiency, and manufacturing operations.

Foresight explores how AI can help manufacturers move from reactive inventory corrections toward proactive investigation and prevention.

The long-term vision includes:

- Intelligent cycle-count prioritization
- Automated discrepancy detection
- Manufacturing-order reconciliation
- Material substitution tracking
- Scrap analysis
- AI-assisted root-cause investigations
- Administrator review and approval workflows
- Multi-facility manufacturing intelligence

---

## Hackathon

**Project:** Foresight — AI Manufacturing Intelligence

**Event:** Meta AI Developer Hackathon 2026

**Platform:** Native iOS Application

**Primary Technologies:** SwiftUI, Meta AI, Vercel, Supabase

**Project Focus:** Manufacturing inventory accuracy, artificial intelligence, computer vision, and root-cause analysis.

---

## Developer

Developed as an independent manufacturing technology project inspired by firsthand experience with inventory control, cycle counting, and production discrepancies.

**Foresight — Identify. Investigate. Correct. Prevent.**
