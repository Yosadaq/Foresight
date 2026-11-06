Foresight

AI-Powered Inventory Intelligence, Computer Vision & Root Cause Analysis

Foresight is a native iOS application that uses Meta AI, computer vision, and voice-guided investigations to help identify physical objects, recognize manufacturing parts, analyze inventory discrepancies, and recommend corrective actions.

Built for the Meta AI Developer Hackathon 2026

Foresight combines AI-powered image recognition, manufacturing inventory data, speech recognition, and root-cause analysis into a unified mobile experience.

Although Foresight focuses on manufacturing environments, its image recognition feature can also analyze everyday objects. Users can photograph objects using their iPhone camera or select existing pictures from their photo library.

The application demonstrates how AI can connect visual observations with structured inventory information and help employees investigate discrepancies more efficiently.

⸻

The Problem

Manufacturing facilities frequently struggle with inaccurate inventory balances, missing production transactions, undocumented scrap, incorrect bills of materials, and material substitutions.

A typical inventory-control process involves:

1. Extracting updated inventory information from the ERP system.
2. Exporting data into Excel.
3. Running macros to organize inventory discrepancies.
4. Prioritizing parts with the largest negative balances.
5. Assigning cycle counters to locate and count materials.
6. Reviewing reported quantities.
7. Investigating possible root causes.
8. Completing authorized inventory corrections and preventive actions.

This process requires significant manual effort and can contribute to financial losses, production delays, and inaccurate physical inventories.

Foresight helps reduce the effort required to identify, investigate, and document these problems.

⸻

Key Features

AI Object Recognition & Inventory Scanning

Foresight allows users to:

* Take a picture using the iPhone camera.
* Select an existing photograph from the photo library.
* Identify visible objects using Meta AI.
* Describe physical characteristics, materials, and markings.
* Detect multiple object types in a single image.
* Estimate or count visible quantities.
* Extract readable manufacturing part numbers and labels.
* Search for possible matches in the manufacturing database.
* Review and confirm AI-generated results.

You do not need a manufacturing photograph to test image recognition.

For example, users can photograph a collection of pens, bolts, tools, boxes, electronic components, or other physical objects.

Foresight attempts to identify and count the visible objects. If the database does not contain a corresponding manufacturing record, the application can still return visual analysis results without claiming a verified catalog match.

AI-generated descriptions and quantities should always be reviewed for accuracy.

Manufacturing Inventory Intelligence

Users can search for manufacturing parts by part number and retrieve associated inventory information.

Available information may include:

* Part number and description
* ERP inventory balances
* Inventory quantities by location
* Material specifications
* Engineering revisions
* Material gauge and thickness
* Standard weights
* Scrap factors
* Parent-child bill-of-material relationships

Some engineering specifications are synthetic demonstration records and are not approved production standards.

AI Voice-Guided Root Cause Analysis

Foresight guides users through an inventory investigation using spoken questions and speech recognition.

Investigation topics include:

* Part identification
* Physical inventory counts
* Inventory locations
* Material specifications
* Coil usage and substitutions
* Engineering revisions
* Standard weights and scrap factors
* Bill-of-material consumption
* Manufacturing orders
* Production reporting
* Inventory transactions

Users can answer using voice recognition or keyboard input.

AI-Generated Investigation Reports

Using Meta AI, Foresight generates:

* Investigation summaries
* Inventory and physical count findings
* Completed and outstanding checks
* Possible root causes
* Recommended corrective actions
* Preventive measures
* Follow-up verification plans
* Professional management email drafts

Reports can be saved locally and reopened for review.

Manufacturing Transaction Interface

Foresight also demonstrates workflows for:

* Reporting production
* Transferring pieces
* Reporting scrap
* Issuing materials to manufacturing orders

Inventory-changing operations require an appropriately configured transaction service and authorization. Demonstration workflows do not automatically modify production inventory.

⸻

Technology Stack

Technology	Purpose
Swift	Native iOS development
SwiftUI	Application interface
Apple Speech Framework	Speech recognition
AVFoundation	Voice synthesis and audio
Meta AI	Image analysis and root-cause investigations
Vercel	Hosted backend API
Supabase	Manufacturing inventory and engineering data
Upstash Redis	Server-side AI rate limiting
REST APIs	Application-to-backend communication
JSON	Data exchange and local report storage

⸻

System Architecture

             iOS Application
                 SwiftUI
                    |
                    | HTTPS
                    v
          Foresight REST API
                 Vercel
                    |
          +---------+---------+
          |         |         |
          v         v         v
       Meta AI   Supabase   Upstash
       Models    Database    Redis
          |         |         |
          v         v         v
       Visual    Inventory   AI Usage
       Analysis  Records     Limits
          |
          v
     AI Investigation
          |
          v
     Root Cause Report

The iOS application communicates with the hosted backend over HTTPS.

Meta API credentials, Supabase credentials, and Upstash Redis credentials remain on the server.

No private API keys are embedded in the iOS application.

⸻

Requirements

To build and test Foresight, you need:

* A Mac computer
* Xcode with the project’s required iOS SDK
* A compatible iPhone Simulator or physical iPhone
* Internet connectivity
* Access to the hosted Foresight backend

A physical iPhone is recommended for testing the camera and voice-guided investigation features.

The simulator supports interface testing, manual part searches, report viewing, and other available functionality.

⸻

Installation Instructions

Step 1 — Clone the Repository

Open Terminal and run:

git clone https://github.com/Yosadaq/Foresight.git

Navigate into the project:

cd Foresight

Step 2 — Open the Xcode Project

Open:

Foresight.xcodeproj

Or run:

open Foresight.xcodeproj

Step 3 — Resolve Dependencies

If Xcode requests package resolution, allow it to complete.

Alternatively, select:

File → Packages → Resolve Package Versions

Step 4 — Configure the Run Destination

1. Select the Foresight scheme.
2. Choose a compatible iPhone Simulator.
3. Confirm the Foresight app target.
4. Press Command + R to build and run.

For a physical iPhone, connect your device and configure code signing under:

Target → Signing & Capabilities

Step 5 — Launch Foresight

Once the application launches, you can explore the image recognition, manufacturing inventory, and AI investigation features.

No in-app user account is required for the hackathon demonstration.

⸻

Quick Start — Test Foresight

Foresight offers two main demonstration workflows.

Option A: Scan a photograph

Use the camera or photo library to analyze visible objects.

Option B: Search a manufacturing part

Enter a manufacturing part number, retrieve inventory details, and run the AI root-cause investigation.

These workflows can be tested independently.

⸻

Test 1 — Scan Any Object With AI

You do not need a special manufacturing image.

Using Your Camera

1. Launch Foresight.
2. Select Open Camera.
3. Photograph one or more physical objects.
4. Tap Scan, Identify & Count.
5. Wait for Meta AI to process the image.
6. Review the identified objects.
7. Review the visible quantities and descriptions.
8. Confirm or correct the results.

Using Your Photo Library

1. Launch Foresight.
2. Select Choose Existing Photo.
3. Select a photograph from your library.
4. Tap Scan, Identify & Count.
5. Review the AI-generated results.

Suggested Objects for Testing

You can experiment with photographs containing:

* Pens, pencils, or markers
* Nuts, bolts, and washers
* Hand tools
* Electronic components
* Boxes or packaged products
* Metal components
* Storage bins
* Everyday household objects

Images with clear lighting, minimal overlap, and visible object boundaries generally provide better conditions for recognition and counting.

Expected Results

Foresight may return:

* Object descriptions
* Visible quantities
* Readable text or markings
* Possible part numbers
* Catalog match candidates
* Warnings about uncertain counts
* Requests for additional verification

Important: Not every object will exist in the manufacturing database.

When a catalog match is unavailable, the AI scan can still demonstrate visual recognition without inventing a manufacturing part number.

⸻

Test 2 — Manufacturing Part Number Lookup

Foresight includes a manufacturing inventory lookup feature connected to the hosted backend.

To test:

1. Launch Foresight.
2. Open Manufacturing Part Lookup.
3. Enter a part number from the configured demonstration database.
4. Tap Search Manufacturing Database.
5. Review the returned part information.
6. Open Part Details to examine available inventory and engineering data.

Demonstration Part Numbers

Use the following section to document part numbers verified to exist in the hosted Supabase demonstration database.

The actual database part numbers must be added before publishing this section as a judge-ready lookup list.

Part Number	Description	Demonstration
To be populated	Manufacturing component	Inventory lookup and RCA
To be populated	Raw material	Material specifications
To be populated	Manufactured assembly	Bill-of-material relationships
To be populated	Inventory discrepancy example	Root-cause investigation

For the strongest demonstration, include at least one verified part with a negative ERP balance and enough associated inventory data to support a meaningful root-cause investigation.

These identifiers should be taken directly from the configured test database rather than invented.

⸻

Test 3 — Review Manufacturing Inventory Details

After successfully finding a manufacturing part, open its details.

Available fields may include:

* Part number
* Description
* ERP inventory balance
* Inventory quantities by area
* Material type
* Engineering revision
* Gauge and thickness
* Standard weight
* Scrap factor
* Bill-of-material components

The fields displayed depend on the selected record and available backend data.

Some engineering specifications are synthetic demonstration data.

⸻

Test 4 — Run AI Root Cause Analysis

This is one of Foresight’s primary demonstration features.

Steps

1. Open Manufacturing Part Lookup.
2. Search for a verified manufacturing part number.
3. Open the returned part.
4. Select Analyze This Part.
5. Follow the voice-guided investigation.
6. Answer questions about inventory counts, materials, scrap, and manufacturing orders.
7. Continue through the investigation.
8. Select Generate AI Root Cause Report.

Foresight sends the investigation context to the backend for AI analysis.

Example Investigation Questions

Foresight may ask:

* Does the physical part match the inventory record?
* What quantity was physically counted?
* Which storage locations were inspected?
* Was the correct raw material used?
* Were rejected pieces reported as scrap?
* Was the correct engineering revision used?
* Were manufacturing transactions recorded correctly?
* Does the manufacturing order reference the correct components?
* Could an unrecorded material substitution explain the discrepancy?

The AI uses the available responses to identify potential causes and recommend follow-up actions.

A potential cause is not treated as confirmed without supporting evidence.

⸻

Test 5 — Generate an AI Investigation Report

After completing the investigation, select Generate AI Root Cause Report.

The report may contain:

* Investigation summary
* Inventory and physical count information
* Potential root causes
* Completed checks
* Outstanding verification steps
* Corrective-action recommendations
* Preventive measures
* Follow-up investigation tasks
* Management communication

Select Email Management or the available sharing option to prepare the report for review.

Sending an email requires a configured email application or supported sharing destination.

⸻

Test 6 — Saved Investigations

Open Saved Root Cause Reports in the application.

Previously saved investigations can be reopened on the same device.

Reports are stored in the application’s private local storage and are not automatically synchronized between devices.

⸻

Backend Configuration

The iOS application connects to the hosted Foresight API:

https://foresight-omega.vercel.app

The backend supports manufacturing part lookup, image scanning, and root-cause analysis.

Example endpoints:

GET  /api/parts/{partNumber}
POST /api/scan
POST /api/analyze
GET  /api/rca/part?number={partNumber}
POST /api/rca/analyze

The exact capabilities and availability of these routes depend on the deployed backend configuration.

Environment Variables

The backend uses server-side environment variables, including:

SUPABASE_URL
SUPABASE_SECRET_KEY
MODEL_API_KEY
META_MODEL
UPSTASH_REDIS_REST_URL
UPSTASH_REDIS_REST_TOKEN

META_MODEL is optional when the backend provides a default model identifier.

Never commit API keys, Redis tokens, database secrets, or other private credentials to GitHub.

AI Rate Limits

To protect the shared hackathon demonstration backend, Foresight uses Upstash Redis for server-side AI rate limiting.

AI Operation	Limit
Root-cause analysis	5 requests per IP per hour
Image analysis	10 requests per IP per hour
Combined AI requests	100 requests per day across all users

The daily limit is shared across the hosted demonstration, not allocated individually to each user.

When a limit is reached, the API returns an HTTP 429 response. If the rate-limit service is unavailable, AI requests are blocked temporarily.

⸻

AI API Access for Hackathon Judges

Foresight uses a hosted Vercel backend for Meta AI inference and manufacturing inventory retrieval.

Judges do not need to obtain or configure their own Meta AI, Supabase, or Upstash credentials to use the hosted demonstration.

Hosted demonstration API:

https://foresight-omega.vercel.app

To run the application:

1. Clone the repository.
2. Open Foresight.xcodeproj.
3. Select a compatible iPhone Simulator or physical device.
4. Build and launch Foresight.
5. Connect to the internet.
6. Test object recognition using the camera or photo library.
7. Search a verified manufacturing part number.
8. Run the AI root-cause investigation.

The hosted demonstration uses test data and must not be used for production inventory adjustments.

For independent deployment, developers must configure their own backend credentials and database resources.

⸻

Example Manufacturing Investigation

Consider a manufacturing part with a negative ERP inventory balance.

An employee locates the part, reviews the manufacturing record, and performs a physical count.

Foresight guides the employee through questions about storage locations, material usage, production transactions, scrap reporting, and engineering revisions.

Meta AI then evaluates the investigation responses and generates potential explanations.

Possible findings might include:

* An unreported scrap transaction
* Incorrect material consumption
* An inventory transfer not recorded
* A manufacturing-order reporting error
* An incorrect bill-of-material quantity
* A material substitution
* An incorrect physical count

These are examples of possible findings, not confirmed diagnoses.

The employee reviews the recommendations and determines which follow-up actions are appropriate.

⸻

Safety and Data Considerations

Foresight is a hackathon prototype.

Some engineering specifications and manufacturing relationships are generated for demonstration purposes.

They must not be treated as approved manufacturing standards.

Inventory corrections, material substitutions, manufacturing-order changes, and engineering revisions require appropriate human review and authorization.

AI responses are recommendations rather than automatic production decisions.

Do not upload confidential manufacturing photographs, sensitive employee information, private production records, or credentials to the public demonstration.

⸻

Troubleshooting

Application Does Not Build

* Confirm Xcode is installed.
* Select a compatible simulator.
* Resolve package dependencies.
* Confirm required Swift files are included in the Foresight target.

Camera Is Unavailable

Use a physical iPhone or select an existing photograph from the photo library.

Image Recognition Fails

* Confirm internet connectivity.
* Use a clear photograph with adequate lighting.
* Avoid excessive image overlap.
* Verify the hosted Meta API is available.
* Check whether the demonstration AI usage limit has been reached.

Manufacturing Part Is Not Found

* Confirm the part number is entered correctly.
* Use a verified demonstration part number.
* Check internet connectivity.
* Confirm the hosted manufacturing database is available.

Voice Recognition Does Not Work

* Allow microphone permission.
* Allow speech recognition permission.
* Confirm speech recognition is supported on the device.

AI Report Generation Fails

* Confirm internet connectivity.
* Check whether the AI usage limit has been reached.
* Verify the Meta AI backend is available.
* Review Vercel logs for timeout or API errors.
* Retry without discarding recorded investigation answers.

⸻

Project Vision

Manufacturing inventory discrepancies affect far more than physical counts.

They influence purchasing, production planning, financial reporting, labor efficiency, and manufacturing operations.

Foresight explores how AI can help manufacturers move from reactive inventory corrections toward proactive investigation and prevention.

The long-term vision includes:

* Intelligent cycle-count prioritization
* Automated discrepancy detection
* Manufacturing-order reconciliation
* Material substitution tracking
* Scrap analysis
* AI-assisted root-cause investigations
* Administrator review and approval workflows
* Multi-facility manufacturing intelligence

⸻

Hackathon

Project: Foresight — AI Manufacturing Intelligence

Event: Meta AI Developer Hackathon 2026

Platform: Native iOS Application

Primary Technologies: SwiftUI, Meta AI, Vercel, Supabase, Upstash Redis

Project Focus: Manufacturing inventory accuracy, artificial intelligence, computer vision, and root-cause analysis.

⸻

Developer

Developed as an independent manufacturing technology project inspired by firsthand experience with inventory control, cycle counting, and production discrepancies.

Foresight — Identify. Investigate. Correct. Prevent.
