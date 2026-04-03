// LegalView.swift
// Thump iOS
//
// Full Terms of Service and Privacy Policy screens.
// Presented modally during onboarding (must accept to proceed) and
// accessible at any time from Settings > About.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - Legal Document Type

enum LegalDocument {
    case terms
    case privacy
}

// MARK: - LegalGateView

/// Full-screen legal acceptance gate shown before the app is first used.
///
/// The user must scroll through both the Terms of Service and the Privacy
/// Policy and tap "I Agree" before onboarding can continue. Acceptance is
/// persisted in UserDefaults so it is only shown once.
struct LegalGateView: View {

    let onAccepted: () -> Void

    @State private var selectedTab: LegalDocument = .terms
    @State private var termsScrolledToBottom = false
    @State private var privacyScrolledToBottom = false
    @State private var showMustReadAlert = false

    private var bothRead: Bool {
        termsScrolledToBottom && privacyScrolledToBottom
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("Document", selection: $selectedTab) {
                    Text("Terms of Service").tag(LegalDocument.terms)
                    Text("Privacy Policy").tag(LegalDocument.privacy)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Document content
                if selectedTab == .terms {
                    LegalScrollView(document: .terms, onScrolledToBottom: {
                        termsScrolledToBottom = true
                    })
                } else {
                    LegalScrollView(document: .privacy, onScrolledToBottom: {
                        privacyScrolledToBottom = true
                    })
                }

                // Read status indicators
                HStack(spacing: 16) {
                    readIndicator(label: "Terms", done: termsScrolledToBottom)
                    readIndicator(label: "Privacy", done: privacyScrolledToBottom)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                // Accept button
                Button {
                    if bothRead {
                        UserDefaults.standard.set(true, forKey: "thump_legal_accepted_v1")
                        onAccepted()
                    } else {
                        showMustReadAlert = true
                    }
                } label: {
                    Text("I Have Read and I Agree")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            bothRead ? Color.pink : Color.gray,
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .animation(.easeInOut(duration: 0.2), value: bothRead)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Before You Begin")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Please Read Both Documents", isPresented: $showMustReadAlert) {
            Button("OK") {}
        } message: {
            Text("Scroll through the Terms of Service and Privacy Policy before agreeing.")
        }
    }

    private func readIndicator(label: String, done: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(done ? .green : .secondary)
            Text(label + (done ? " — Read" : " — Scroll to read"))
                .font(.caption2)
                .foregroundStyle(done ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - LegalScrollView

/// A scrollable legal document that fires a callback when the user
/// scrolls to within a small threshold of the bottom.
///
/// Uses `GeometryReader` inside a scroll coordinate space to detect
/// when the content's bottom edge is visible in the viewport.
/// The sentinel approach (`Color.clear.onAppear`) is unreliable
/// because SwiftUI may render the bottom element into the view
/// hierarchy before the user actually scrolls, especially on
/// devices with tall screens or small legal documents.
struct LegalScrollView: View {

    let document: LegalDocument
    let onScrolledToBottom: () -> Void

    @State private var hasReachedBottom = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if document == .terms {
                    TermsOfServiceContent()
                } else {
                    PrivacyPolicyContent()
                }

                // Bottom sentinel measured against the scroll viewport
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geo.frame(in: .named("legalScroll")).maxY
                        )
                }
                .frame(height: 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .coordinateSpace(name: "legalScroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { bottomY in
            // Fire when the bottom of content is within 60pt of the
            // scroll view's visible area. This ensures the user has
            // genuinely scrolled to the end.
            guard !hasReachedBottom, bottomY < UIScreen.main.bounds.height + 60 else { return }
            hasReachedBottom = true
            onScrolledToBottom()
        }
    }
}

/// Preference key for tracking the bottom edge of legal scroll content.
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Standalone Sheet Wrappers (for Settings)

/// Presents the Terms of Service as a modal sheet.
struct TermsOfServiceSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                TermsOfServiceContent()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Presents the Privacy Policy as a modal sheet.
struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                PrivacyPolicyContent()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Terms of Service Content

struct TermsOfServiceContent: View {

    private let effectiveDate = "March 29, 2026"
    private let appName = "Thump"
    private let companyName = "Thump App, Inc."
    private let contactEmail = "legal@thump.app"

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            legalHeader(
                title: "Terms of Service Agreement",
                effectiveDate: effectiveDate
            )

            // Preamble
            paragraphs([
                "PLEASE READ THESE TERMS OF SERVICE CAREFULLY BEFORE DOWNLOADING, INSTALLING, ACCESSING, OR USING THE THUMP APPLICATION. THIS IS A LEGALLY BINDING CONTRACT. BY PROCEEDING, YOU ACKNOWLEDGE THAT YOU HAVE READ, UNDERSTOOD, AND AGREE TO BE BOUND BY ALL TERMS AND CONDITIONS SET FORTH HEREIN.",
                "IF YOU DO NOT AGREE TO EVERY PROVISION OF THESE TERMS, YOUR SOLE AND EXCLUSIVE REMEDY IS TO DISCONTINUE ALL USE OF THE APPLICATION AND TO DELETE IT FROM ALL DEVICES IN YOUR POSSESSION OR CONTROL."
            ])

            legalSection(number: "1", title: "Definitions") {
                paragraphs([
                    "As used in this Agreement, the following terms shall have the meanings ascribed to them herein:",
                    "\"Agreement\" or \"Terms\" means this Terms of Service Agreement, as amended from time to time, together with all incorporated documents, schedules, and exhibits.",
                    "\"Application\" means the Thump mobile software application, including all updates, upgrades, patches, new versions, supplementary features, and related documentation made available by the Company.",
                    "\"Company,\" \"we,\" \"us,\" or \"our\" means \(companyName), a corporation organized under the laws of the State of California, and its successors, assigns, officers, directors, employees, agents, affiliates, licensors, and service providers.",
                    "\"User,\" \"you,\" or \"your\" means the individual who downloads, installs, accesses, or uses the Application.",
                    "\"Health Data\" means any biometric, physiological, fitness, or wellness information read from Apple HealthKit or generated by the Application, including but not limited to heart rate, heart rate variability, recovery metrics, VO2 max estimates, step counts, sleep data, and workout metrics.",
                    "\"Output\" means any score, insight, trend, nudge, suggestion, indicator, visualization, alert, or other information generated, computed, or displayed by the Application.",
                    "\"Subscription\" means a paid recurring entitlement to premium features within the Application, available in the tiers described in Section 6.",
                    "\"Account Data\" means the information collected through Sign in with Apple, including your name (if provided), email address (if provided), and a pseudonymous user identifier used to associate your preferences and optional server-side data with your account."
                ])
            }

            legalSection(number: "2", title: "Acceptance of Terms; Eligibility") {
                paragraphs([
                    "2.1 Binding Agreement. By downloading, installing, accessing, or using the Application, you represent and warrant that: (i) you have the full legal capacity and authority to enter into this Agreement; (ii) you are at least seventeen (17) years of age; (iii) your use of the Application does not violate any applicable law or regulation; and (iv) all information you provide in connection with your use of the Application is accurate, current, and complete.",
                    "2.2 Minor Users. The Application is not directed at children under the age of 17. If you are under 17 years of age, you are not permitted to use the Application.",
                    "2.3 Modifications. The Company reserves the right, in its sole discretion, to modify this Agreement at any time. Any modification shall become effective upon posting within the Application or notifying you via in-app alert. Your continued use of the Application following the posting of any modification constitutes your irrevocable acceptance of the modified Agreement. If you do not agree to any modification, you must immediately cease use of the Application.",
                    "2.4 Entire Agreement. This Agreement, together with the Privacy Policy and any other agreements incorporated herein by reference, constitutes the entire agreement between you and the Company with respect to the subject matter hereof and supersedes all prior and contemporaneous understandings, agreements, representations, and warranties, whether written or oral."
                ])
            }

            legalSection(number: "3", title: "NOT A MEDICAL DEVICE — CRITICAL HEALTH AND SAFETY DISCLAIMER") {
                warningBox(
                    "⚠️ CRITICAL NOTICE: THUMP IS NOT A MEDICAL DEVICE, CLINICAL INSTRUMENT, DIAGNOSTIC TOOL, MEDICAL SERVICE, TELEHEALTH SERVICE, OR HEALTHCARE PROVIDER OF ANY KIND. THE APPLICATION IS NOT INTENDED TO DIAGNOSE, TREAT, CURE, MONITOR, PREVENT, OR MITIGATE ANY DISEASE, DISORDER, INJURY, OR HEALTH CONDITION. NOTHING IN THIS APPLICATION, ITS OUTPUTS, OR THESE TERMS SHALL CONSTITUTE OR BE CONSTRUED AS THE PRACTICE OF MEDICINE, NURSING, PHARMACY, PSYCHOLOGY, OR ANY OTHER LICENSED HEALTHCARE PROFESSION."
                )
                paragraphs([
                    "3.1 Wellness Purpose Only. The Application is designed exclusively as a general-purpose consumer wellness and fitness companion intended to provide motivational, informational, and educational content. All Outputs — including but not limited to wellness scores, cardio fitness estimates, stress indicators, heart rate variability summaries, recovery ratings, sleep quality assessments, and daily nudges — are generated solely for informational and motivational purposes. They do not constitute, and must not be treated as, clinical assessments, medical diagnoses, or treatment recommendations.",
                    "3.2 No FDA Clearance or Approval. The Application has not been submitted to, reviewed by, or cleared or approved by the United States Food and Drug Administration (FDA), the European Medicines Agency (EMA), the Medicines and Healthcare products Regulatory Agency (MHRA), Health Canada, the Therapeutic Goods Administration (TGA), or any other domestic or foreign regulatory authority as a medical device, Software as a Medical Device (SaMD), or clinical decision-support tool. Biometric estimates displayed by the Application — including resting heart rate, HRV, VO2 max, recovery scores, and stress indices — are consumer wellness estimates derived from consumer-grade wearable sensor hardware and are not equivalent to, nor substitutes for, clinically validated diagnostic measurements.",
                    "3.3 No Substitute for Professional Medical Care. THE OUTPUTS OF THE APPLICATION ARE NOT A SUBSTITUTE FOR THE ADVICE, DIAGNOSIS, EVALUATION, OR TREATMENT OF A LICENSED PHYSICIAN, CARDIOLOGIST, ENDOCRINOLOGIST, PSYCHOLOGIST, OR OTHER QUALIFIED HEALTHCARE PROFESSIONAL. You must not: (a) use the Application as a basis for self-diagnosis or self-treatment; (b) delay, forego, or disregard seeking professional medical advice on the basis of any Output; (c) discontinue, modify, or adjust any prescribed medication, therapy, or treatment plan based on any Output; or (d) make any clinical or health-related decision based on any Output without first consulting a qualified healthcare professional.",
                    "3.4 Sensor Accuracy Limitations. Health Data processed by the Application is sourced from consumer-grade wearable sensors (including Apple Watch) and is subject to substantial limitations, including sensor noise, motion artifacts, individual physiological variability, improper device fit, and software estimation errors. The Company makes no representation, warranty, or guarantee that any Health Data or Output is clinically accurate, complete, timely, or fit for any purpose beyond general wellness awareness.",
                    "3.5 Emergency Situations. THUMP IS NOT AN EMERGENCY SERVICE. IF YOU ARE EXPERIENCING CHEST PAIN, TIGHTNESS, OR PRESSURE; SHORTNESS OF BREATH OR DIFFICULTY BREATHING; IRREGULAR, RAPID, OR ABNORMAL HEARTBEAT; SUDDEN DIZZINESS, LIGHTHEADEDNESS, OR LOSS OF CONSCIOUSNESS; UNEXPLAINED SWEATING, NAUSEA, OR PAIN RADIATING TO YOUR ARM, JAW, NECK, OR BACK; OR ANY OTHER SYMPTOM THAT MAY INDICATE A CARDIAC EVENT, STROKE, OR OTHER MEDICAL EMERGENCY, YOU MUST CALL EMERGENCY SERVICES (9-1-1 IN THE UNITED STATES OR YOUR LOCAL EMERGENCY NUMBER) IMMEDIATELY AND SEEK IN-PERSON EMERGENCY MEDICAL ATTENTION. DO NOT RELY ON OR CONSULT THIS APPLICATION IN AN EMERGENCY."
                ])
            }

            legalSection(number: "4", title: "Disclaimer of Warranties") {
                warningBox(
                    "THE APPLICATION AND ALL OUTPUTS ARE PROVIDED STRICTLY ON AN \"AS IS,\" \"AS AVAILABLE,\" AND \"WITH ALL FAULTS\" BASIS. THE COMPANY EXPRESSLY DISCLAIMS, TO THE FULLEST EXTENT PERMITTED BY APPLICABLE LAW, ALL WARRANTIES OF ANY KIND, WHETHER EXPRESS, IMPLIED, STATUTORY, OR OTHERWISE, INCLUDING BUT NOT LIMITED TO: (I) ANY IMPLIED WARRANTY OF MERCHANTABILITY; (II) ANY IMPLIED WARRANTY OF FITNESS FOR A PARTICULAR PURPOSE; (III) ANY IMPLIED WARRANTY OF TITLE OR NON-INFRINGEMENT; (IV) ANY WARRANTY THAT THE APPLICATION WILL MEET YOUR REQUIREMENTS OR EXPECTATIONS; (V) ANY WARRANTY THAT THE APPLICATION WILL BE UNINTERRUPTED, TIMELY, SECURE, OR ERROR-FREE; (VI) ANY WARRANTY AS TO THE ACCURACY, RELIABILITY, CURRENCY, COMPLETENESS, OR MEDICAL VALIDITY OF ANY OUTPUT; AND (VII) ANY WARRANTY THAT ANY DEFECTS OR ERRORS WILL BE CORRECTED."
                )
                paragraphs([
                    "4.1 No Warranty of Results. The Company does not warrant that use of the Application will result in any improvement in health, fitness, wellness, cardiovascular performance, or any other measurable outcome. Individual results will vary based on numerous factors entirely outside the Company's control, including individual physiology, adherence to wellness practices, pre-existing health conditions, and accuracy of wearable sensor hardware.",
                    "4.2 Third-Party Data. The Application sources Health Data from Apple HealthKit, which is operated by Apple Inc. The Company makes no representation or warranty regarding the accuracy, availability, or reliability of data provided by Apple HealthKit, Apple Watch, or any other third-party hardware or software. The quality and accuracy of Health Data is solely dependent on the performance of third-party hardware and software over which the Company has no control.",
                    "4.3 No Professional-Grade Instrumentation. You expressly acknowledge and agree that the Application is not a medical instrument and does not produce measurements that meet the standards of medical-grade or clinical-grade instrumentation. Outputs must not be used as a substitute for professional clinical evaluation."
                ])
            }

            legalSection(number: "5", title: "Limitation of Liability and Assumption of Risk") {
                warningBox(
                    "TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT SHALL THE COMPANY, ITS PARENT, SUBSIDIARIES, AFFILIATES, OFFICERS, DIRECTORS, SHAREHOLDERS, EMPLOYEES, AGENTS, INDEPENDENT CONTRACTORS, LICENSORS, OR SERVICE PROVIDERS BE LIABLE TO YOU OR ANY THIRD PARTY FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, PUNITIVE, OR ENHANCED DAMAGES OF ANY KIND WHATSOEVER, INCLUDING WITHOUT LIMITATION: DAMAGES FOR PERSONAL INJURY (INCLUDING DEATH); LOSS OF PROFITS; LOSS OF REVENUE; LOSS OF BUSINESS; LOSS OF GOODWILL; LOSS OF DATA; COSTS OF COVER OR SUBSTITUTE GOODS OR SERVICES; OR ANY OTHER PECUNIARY OR NON-PECUNIARY LOSS, ARISING OUT OF OR IN CONNECTION WITH: (A) YOUR USE OF OR INABILITY TO USE THE APPLICATION; (B) ANY OUTPUT GENERATED BY THE APPLICATION; (C) ANY RELIANCE PLACED BY YOU ON THE APPLICATION OR ANY OUTPUT; (D) ANY INACCURACY, ERROR, OR OMISSION IN ANY OUTPUT; (E) ANY DELAY, INTERRUPTION, OR CESSATION OF THE APPLICATION; OR (F) ANY OTHER MATTER RELATING TO THE APPLICATION — REGARDLESS OF THE CAUSE OF ACTION AND WHETHER BASED IN CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY, STATUTE, OR ANY OTHER LEGAL THEORY, AND EVEN IF THE COMPANY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES."
                )
                paragraphs([
                    "5.1 Aggregate Liability Cap. Without limiting the foregoing, and to the maximum extent permitted by applicable law, the Company's total aggregate liability to you for all claims, losses, and causes of action arising out of or relating to this Agreement or your use of the Application — whether in contract, tort, or otherwise — shall not exceed the greater of: (a) the total amount of Subscription fees actually paid by you to the Company during the twelve (12) calendar months immediately preceding the event giving rise to the claim; or (b) fifty United States dollars (US $50.00).",
                    "5.2 Assumption of Risk. YOU EXPRESSLY ACKNOWLEDGE AND AGREE THAT YOUR USE OF THE APPLICATION AND YOUR RELIANCE ON ANY OUTPUT IS ENTIRELY AT YOUR OWN RISK. You assume full and sole responsibility for any and all consequences arising from your use of the Application, including any decisions you make regarding your health, wellness, fitness regimen, diet, sleep habits, stress management, or medical treatment.",
                    "5.3 Jurisdictional Limitations. Certain jurisdictions do not permit the exclusion or limitation of incidental or consequential damages, or the limitation of liability for personal injury or death caused by negligence. To the extent such laws apply to you, some of the above exclusions and limitations may not apply, and the Company's liability shall be limited to the maximum extent permitted under applicable law.",
                    "5.4 Essential Basis. You acknowledge that the limitations of liability set forth in this Section 5 reflect a reasonable allocation of risk and form an essential basis of the bargain between you and the Company. The Company would not have made the Application available to you absent these limitations."
                ])
            }

            legalSection(number: "6", title: "Subscriptions, Billing, and In-App Purchases") {
                paragraphs([
                    "6.1 Subscription Tiers. The Application offers optional paid Subscription tiers (currently designated Pro, Coach, and Family) that provide access to premium features beyond those available in the free tier. Feature availability is subject to change at the Company's discretion.",
                    "6.2 Apple App Store Billing. All Subscriptions and in-app purchases are processed exclusively through Apple's App Store payment infrastructure. The Company does not collect, process, store, or have access to your payment card number, billing address, or other payment instrument details. All billing disputes must be directed to Apple Inc.",
                    "6.3 Automatic Renewal. Subscriptions automatically renew at the end of each billing period (monthly or annual, as selected by you) at the then-current subscription price unless you cancel at least twenty-four (24) hours prior to the end of the then-current billing period. Renewal charges will be applied to the payment method associated with your Apple ID.",
                    "6.4 Cancellation. You may cancel your Subscription at any time through your Apple ID account settings. Cancellation takes effect at the end of the then-current paid billing period. Access to premium features will continue until the end of that period. The Company does not provide partial refunds for unused portions of a billing period.",
                    "6.5 No Refunds. ALL SUBSCRIPTION FEES AND IN-APP PURCHASE CHARGES ARE FINAL AND NON-REFUNDABLE EXCEPT AS EXPRESSLY REQUIRED BY APPLE'S APP STORE REFUND POLICY OR APPLICABLE LAW. To request a refund, you must contact Apple directly via reportaproblem.apple.com. The Company has no authority to issue refunds for App Store purchases.",
                    "6.6 Price Changes. The Company reserves the right to change Subscription prices at any time upon reasonable notice provided through the Application or App Store. Continued use of the Application following a price change constitutes your acceptance of the new pricing.",
                    "6.7 Modification and Discontinuation. The Company reserves the right, in its sole discretion and at any time, with or without notice, to: (a) modify, add, or remove any feature from any Subscription tier; (b) change the features included in any tier; (c) discontinue any tier; or (d) discontinue the Application entirely. The Company shall have no liability to you as a result of any such modification or discontinuation."
                ])
            }

            legalSection(number: "7", title: "License Grant; Restrictions; Intellectual Property") {
                paragraphs([
                    "7.1 Limited License. Subject to your compliance with this Agreement, the Company grants you a limited, personal, non-exclusive, non-transferable, non-sublicensable, revocable license to download, install, and use one (1) copy of the Application on a device you own or control, solely for your personal, non-commercial purposes.",
                    "7.2 Restrictions. You shall not, directly or indirectly: (a) copy, modify, translate, adapt, or create derivative works of the Application or any part thereof; (b) reverse engineer, disassemble, decompile, decode, or otherwise attempt to derive or gain access to the source code of the Application; (c) remove, alter, obscure, or tamper with any proprietary notices, labels, or marks on the Application; (d) use the Application in any manner that violates applicable law; (e) use the Application for commercial purposes, including resale, sublicensing, or providing the Application as a service bureau; (f) circumvent, disable, or interfere with any security feature, access control mechanism, or technical protection measure of the Application; or (g) use the Application to develop a competing product or service.",
                    "7.3 Company Ownership. The Application and all of its content, features, functionality, algorithms, source code, object code, interfaces, data, databases, graphics, logos, trademarks, service marks, and trade names are and shall remain the exclusive property of the Company and its licensors, protected under applicable copyright, trademark, patent, trade secret, and other intellectual property laws. No ownership interest is conveyed to you by this Agreement.",
                    "7.4 Feedback. If you voluntarily provide any suggestions, ideas, comments, or other feedback regarding the Application, you hereby grant the Company an irrevocable, perpetual, royalty-free, worldwide license to use, reproduce, modify, and incorporate such feedback into the Application or any other product or service without any obligation to you."
                ])
            }

            legalSection(number: "8", title: "Third-Party Services and Platforms") {
                paragraphs([
                    "8.1 Apple Ecosystem. The Application is designed to operate within the Apple ecosystem and integrates with Apple HealthKit, Apple's App Store, and Apple's MetricKit diagnostic framework. Your use of Apple's platforms and services is subject to Apple's own terms of service and privacy policy. The Company has no control over, and assumes no responsibility for, the content, terms, privacy practices, or actions of Apple Inc.",
                    "8.2 No Endorsement. The Company's integration with third-party services does not constitute an endorsement, sponsorship, or recommendation of those services.",
                    "8.3 Third-Party Liability. The Company is not responsible and shall not be liable for any harm or loss arising from your use of or interaction with any third-party service, platform, hardware, or software, including Apple Watch hardware limitations that may affect the accuracy of Health Data.",
                    "8.4 MetricKit. The Application may use Apple's MetricKit framework, which provides aggregated, anonymized performance and diagnostic data to the Company. This data is collected, processed, and transmitted by Apple. The Company may receive aggregated, non-personally-identifiable technical reports from Apple through this framework."
                ])
            }

            legalSection(number: "9", title: "User Conduct; Prohibited Uses") {
                paragraphs([
                    "9.1 You agree to use the Application solely for lawful purposes and in strict compliance with this Agreement and all applicable federal, state, local, and international laws and regulations.",
                    "9.2 You are solely and exclusively responsible for all decisions made in reliance on the Application and its Outputs, including without limitation any decisions relating to physical exercise, dietary habits, sleep routines, mental health practices, medication management, and medical treatment.",
                    "9.3 You agree not to use the Application: (a) in any way that violates applicable law or regulation; (b) in any manner that impersonates any person or entity; (c) to transmit any unsolicited or unauthorized advertising or promotional material; (d) to engage in any conduct that restricts or inhibits anyone's use or enjoyment of the Application; or (e) for any fraudulent, deceptive, or harmful purpose."
                ])
            }

            legalSection(number: "10", title: "Indemnification") {
                paragraphs([
                    "10.1 To the fullest extent permitted by applicable law, you shall defend, indemnify, release, and hold harmless the Company and each of its present and former officers, directors, members, employees, agents, independent contractors, licensors, successors, and assigns from and against any and all claims, demands, actions, suits, proceedings, losses, damages, liabilities, costs, and expenses (including reasonable attorneys' fees and court costs) arising out of or relating to: (a) your access to or use of the Application; (b) any Output you relied upon; (c) your violation of any provision of this Agreement; (d) your violation of any applicable law, rule, or regulation; (e) your violation of any rights of any third party, including without limitation any intellectual property rights or privacy rights; or (f) any claim by any third party that your use of the Application caused harm to that third party.",
                    "10.2 The Company reserves the right, at your expense, to assume the exclusive defense and control of any matter subject to indemnification by you hereunder. You agree to cooperate with the Company's defense of any such claim. You agree not to settle any such claim without the prior written consent of the Company."
                ])
            }

            legalSection(number: "11", title: "Governing Law; Mandatory Binding Arbitration; Class Action Waiver") {
                paragraphs([
                    "11.1 Governing Law. This Agreement and all disputes arising out of or relating to this Agreement or the Application shall be governed by and construed in accordance with the laws of the State of California, United States of America, without giving effect to any choice of law or conflict of law rules or provisions that would result in the application of any other law.",
                    "11.2 Mandatory Arbitration. PLEASE READ THIS SECTION CAREFULLY — IT AFFECTS YOUR LEGAL RIGHTS. Except as set forth in Section 11.5, any dispute, controversy, or claim arising out of or relating to this Agreement, the Application, or the breach, termination, or validity thereof, shall be finally resolved by binding arbitration administered by the American Arbitration Association (AAA) in accordance with its Consumer Arbitration Rules then in effect (available at www.adr.org). The arbitration shall be conducted in the English language, seated in San Francisco County, California. The arbitrator's award shall be final and binding and may be confirmed and entered as a judgment in any court of competent jurisdiction.",
                    "11.3 CLASS ACTION WAIVER. YOU AND THE COMPANY AGREE THAT EACH MAY BRING CLAIMS AGAINST THE OTHER ONLY IN YOUR OR ITS INDIVIDUAL CAPACITY AND NOT AS A PLAINTIFF OR CLASS MEMBER IN ANY PURPORTED CLASS, CONSOLIDATED, REPRESENTATIVE, OR PRIVATE ATTORNEY GENERAL ACTION OR PROCEEDING. THE ARBITRATOR MAY NOT CONSOLIDATE MORE THAN ONE PERSON'S CLAIMS AND MAY NOT OTHERWISE PRESIDE OVER ANY FORM OF A REPRESENTATIVE OR CLASS PROCEEDING.",
                    "11.4 Arbitration Fees. If you initiate arbitration, you will be responsible for the AAA's filing fees as set forth in the AAA Consumer Arbitration Rules. If the Company initiates arbitration, the Company will pay all AAA filing and administrative fees.",
                    "11.5 Injunctive Relief Exception. Notwithstanding Section 11.2, either party may seek emergency or preliminary injunctive or other equitable relief from a court of competent jurisdiction solely to prevent actual or threatened infringement, misappropriation, or violation of a party's intellectual property rights or confidential information, pending the resolution of arbitration. The parties submit to the exclusive jurisdiction of the state and federal courts located in San Francisco County, California for such purpose.",
                    "11.6 Jury Trial Waiver. TO THE EXTENT PERMITTED BY APPLICABLE LAW, EACH PARTY HEREBY IRREVOCABLY AND UNCONDITIONALLY WAIVES ANY RIGHT TO A TRIAL BY JURY IN ANY PROCEEDING ARISING OUT OF OR RELATING TO THIS AGREEMENT OR THE APPLICATION."
                ])
            }

            legalSection(number: "12", title: "Account Deletion and Termination") {
                paragraphs([
                    "12.1 Account Deletion by User. You may delete your account at any time through the Application's Settings screen by selecting \"Delete Account.\" Account deletion permanently removes all data associated with your account from the Company's servers, including telemetry traces, analytics events, bug reports, and feature requests. Account deletion also clears your Sign in with Apple credential and resets all local Application data. This action is irreversible.",
                    "12.2 Termination by Company. The Company may, in its sole discretion, at any time and without prior notice or liability, terminate or suspend your access to or use of the Application, or any portion thereof, for any reason or no reason, including if the Company reasonably believes you have violated any provision of this Agreement.",
                    "12.3 Effect of Termination. Upon any termination of this Agreement or your access to the Application: (a) all licenses and rights granted to you hereunder shall immediately cease; (b) you must cease all use of the Application and delete all copies from your devices; and (c) you shall have no right to any refund of prepaid Subscription fees, except as required by Apple's App Store policy or applicable law.",
                    "12.4 Survival. The following provisions shall survive termination of this Agreement: Sections 1 (Definitions), 3 (Medical Disclaimer), 4 (Disclaimer of Warranties), 5 (Limitation of Liability), 7.3-7.4 (Intellectual Property), 10 (Indemnification), 11 (Governing Law; Arbitration; Class Action Waiver), and 13 (Miscellaneous)."
                ])
            }

            legalSection(number: "13", title: "Miscellaneous") {
                paragraphs([
                    "13.1 Severability. If any provision of this Agreement is held to be invalid, illegal, or unenforceable by a court of competent jurisdiction, such provision shall be modified to the minimum extent necessary to make it enforceable, and the remaining provisions shall continue in full force and effect.",
                    "13.2 Waiver. The Company's failure to enforce any right or provision of this Agreement shall not constitute a waiver of such right or provision. No waiver shall be effective unless made in writing and signed by an authorized representative of the Company.",
                    "13.3 Assignment. You may not assign or transfer any of your rights or obligations under this Agreement without the prior written consent of the Company. The Company may freely assign this Agreement, including in connection with a merger, acquisition, or sale of assets, without restriction.",
                    "13.4 Force Majeure. The Company shall not be liable for any delay or failure in performance resulting from causes beyond its reasonable control, including acts of God, natural disasters, war, terrorism, riots, embargoes, acts of civil or military authorities, fire, floods, epidemics, pandemic, power outages, or telecommunications failures.",
                    "13.5 Notices. All notices to you may be provided via in-app notification, email to the address associated with your account (if any), or by updating this Agreement. Notices from you to the Company must be sent to \(contactEmail).",
                    "13.6 Contact Information. For legal inquiries:\n\(companyName)\nAttn: Legal Department\nSan Francisco, California, USA\nEmail: \(contactEmail)"
                ])
            }

            Text("Effective Date: \(effectiveDate) · \(companyName) · All rights reserved.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }
}

// MARK: - Privacy Policy Content

struct PrivacyPolicyContent: View {

    private let effectiveDate = "March 29, 2026"
    private let appName = "Thump"
    private let companyName = "Thump App, Inc."
    private let contactEmail = "privacy@thump.app"

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            legalHeader(
                title: "Privacy Policy",
                effectiveDate: effectiveDate
            )

            // Preamble
            paragraphs([
                "This Privacy Policy (\"Policy\") is entered into by and between you (\"User,\" \"you,\" or \"your\") and \(companyName) (\"Company,\" \"we,\" \"us,\" or \"our\") and governs the collection, use, storage, processing, disclosure, and protection of personal data and other information in connection with your use of the \(appName) mobile application (the \"Application\").",
                "BY USING THE APPLICATION, YOU CONSENT TO THE COLLECTION AND USE OF INFORMATION AS DESCRIBED IN THIS POLICY. IF YOU DO NOT AGREE WITH THIS POLICY IN ITS ENTIRETY, YOU MUST DISCONTINUE ALL USE OF THE APPLICATION IMMEDIATELY.",
                "This Policy is incorporated by reference into the \(appName) Terms of Service Agreement. Capitalized terms not defined herein shall have the meanings ascribed to them in the Terms of Service."
            ])

            legalSection(number: "1", title: "Scope and Applicability") {
                paragraphs([
                    "1.1 This Policy applies to all Users of the Application on iOS and watchOS devices. It governs data processing activities conducted by or on behalf of the Company in connection with the Application.",
                    "1.2 This Policy does not apply to third-party services, platforms, or applications to which the Application may link or with which it may integrate, including but not limited to Apple HealthKit, Apple App Store, and Apple's MetricKit diagnostic service. Those services are governed by their own privacy policies, and the Company assumes no responsibility for their privacy practices.",
                    "1.3 This Policy is effective as of the Effective Date stated above. We will notify Users of material changes as described in Section 12 below."
                ])
            }

            legalSection(number: "2", title: "Categories of Information We Collect") {
                legalSubheading("2.1 Health and Biometric Data (Apple HealthKit)")
                paragraphs([
                    "The Application requests access to specific categories of health and fitness data stored in Apple HealthKit solely with your express prior authorization. The data categories we request read access to include:",
                    "• Resting heart rate (beats per minute, BPM)\n• Heart rate variability using SDNN methodology (milliseconds, ms)\n• Post-exercise heart rate recovery (1-minute and 2-minute post-exertion drop values)\n• Cardiorespiratory fitness estimated as VO2 max (milliliters per kilogram per minute, mL/kg/min)\n• Daily step count totals\n• Walking and running distance and duration (minutes)\n• Workout session type, duration, and associated activity metrics\n• Sleep duration and sleep stage classification\n• Heart rate zone distribution (minutes per intensity zone)",
                    "ALL HEALTH AND BIOMETRIC DATA IS PROCESSED ON YOUR DEVICE. Health Data read from HealthKit is not transmitted to the Company's servers during normal use of the Application.",
                    "Exception — Bug Reports With Consent: If you file a bug report and explicitly opt in to including health metrics (via a toggle in the bug report form), a snapshot of your current health metrics and engine scores may be transmitted to the Company's servers to assist with issue reproduction. This transmission occurs only with your express per-report consent. Your age and biological sex are never included in bug reports. You may file bug reports without including any health data.",
                    "The Application does not write any data to Apple HealthKit."
                ])

                legalSubheading("2.2 Usage Analytics and Telemetry Data")
                paragraphs([
                    "To evaluate Application performance and improve the accuracy of our wellness algorithms, we may collect and transmit pseudonymized usage and telemetry data when you opt in via the \"Share Engine Insights\" toggle in Settings. Telemetry is off by default and requires your explicit consent. This data is associated with a SHA-256-hashed version of your Apple Sign-In identifier (a pseudonymous key that cannot be reversed to your Apple ID) and includes:",
                    "• Engine pipeline traces: computed wellness scores, confidence levels, and processing timing from the Application's internal engines — never raw HealthKit values (heart rate, HRV, steps, etc.)\n• Feature interaction events (e.g., which application screens are accessed, nudge completions, sign-in events)\n• Performance diagnostics including crash logs, application hang reports, memory utilization metrics, and battery impact data, collected via Apple's MetricKit framework and transmitted through Apple's infrastructure\n• Device model, iOS version, and Application version for compatibility diagnostics",
                    "This telemetry data: (a) is pseudonymized using a one-way hash of your Apple Sign-In identifier; (b) does not contain raw health metrics; (c) is stored in Firebase Firestore under the Company's control; and (d) can be permanently deleted via the Account Deletion feature in Settings.",
                    "You retain the right to opt out of all analytics and telemetry collection at any time through the Settings screen of the Application. Opting out will not impair the Application's core health monitoring functionality.",
                    "The Company collects this data pursuant to the following lawful bases: (i) our legitimate interest in maintaining Application stability and improving algorithmic accuracy; and (ii) your consent, which you may withdraw at any time as described herein."
                ])

                legalSubheading("2.3 Account and Profile Information")
                paragraphs([
                    "The Application uses Sign in with Apple for authentication. During sign-in, Apple may share your name and email address with the Application (you control what Apple shares via the sign-in prompt). This information is stored in encrypted local storage on your device for personalization (e.g., displaying your name on the dashboard). Your name and email are not transmitted to the Company's servers.",
                    "Your Apple-issued user identifier is stored in the device Keychain and is used to generate a SHA-256 hash for pseudonymous server-side data association (telemetry, bug reports). The original identifier is never transmitted — only the irreversible hash.",
                    "You may also enter a date of birth and biological sex in Settings to enable age-adjusted wellness ranges and Bio Age estimation. These values are stored locally and are not transmitted to the Company's servers.",
                    "Bug Reports and Feature Requests: When you submit a bug report or feature request through Settings, the text you enter, your app version, device model, and iOS version are transmitted to Firebase Firestore. If you opt in to including health metrics in a bug report, those metrics are also transmitted. Your age and biological sex are never included."
                ])

                legalSubheading("2.4 Subscription and Transaction Data")
                paragraphs([
                    "All in-app purchases and Subscription transactions are processed exclusively through Apple's App Store payment infrastructure pursuant to Apple's Terms of Service and Apple's Privacy Policy. The Company does not collect, process, store, or have access to your: name, Apple ID email address, payment card number, bank account information, billing address, or any other financial instrument details. The Company receives only the minimum entitlement information necessary to validate your current Subscription status (specifically: product identifier strings and entitlement validity status)."
                ])

                legalSubheading("2.5 Device Diagnostic and Technical Identifiers")
                paragraphs([
                    "For the purpose of diagnosing software defects and maintaining Application compatibility, the Application records technical diagnostic identifiers including: device hardware model designation, iOS and watchOS version numbers, and Application version and build numbers. When telemetry is enabled, this information is associated with your pseudonymous hashed user identifier. In bug reports, this information is associated with the same pseudonymous identifier."
                ])
            }

            legalSection(number: "3", title: "Purposes and Legal Bases for Processing") {
                paragraphs([
                    "The Company processes the data described in Section 2 for the following specific, explicit, and legitimate purposes:",
                    "• Provision of Core Services: To compute and render wellness scores, trend analyses, stress indicators, cardiovascular recovery assessments, and motivational nudges within the Application — processed entirely on-device without transmission to Company servers.\n• Algorithm Improvement: To evaluate, validate, refine, and improve the accuracy and reliability of the Application's wellness algorithms, scoring models, and data processing pipelines, using pseudonymized telemetry data only (as described in Section 2.2).\n• Application Performance and Stability: To identify, diagnose, and remediate software defects, performance degradations, and compatibility issues.\n• Subscription Management: To validate and enforce Subscription entitlements and gate access to premium features.\n• Legal Compliance: To fulfill obligations imposed by applicable law, regulation, court order, or governmental authority.\n• Fraud Prevention and Security: To detect, investigate, and prevent fraudulent activity, security incidents, and violations of our Terms of Service.",
                    "The Company does not process Health Data for: advertising, behavioral profiling, sale to data brokers, marketing purposes, or any purpose other than those enumerated above."
                ])
            }

            legalSection(number: "4", title: "On-Device Processing; Data Storage; Security") {
                paragraphs([
                    "4.1 On-Device Processing. All Health Data is processed on-device by the Application during normal use. The Company does not operate cloud infrastructure for the routine storage or processing of User Health Data. Health metrics are transmitted to the Company's servers only when you explicitly opt in via the bug report health data consent toggle, as described in Section 2.1.",
                    "4.2 Local Storage. Your wellness history, computed scores, correlation results, and user preferences are stored in encrypted local storage on your iPhone and Apple Watch, utilizing Apple's Data Protection APIs. The Application implements the strongest available data protection class (NSFileProtectionCompleteUntilFirstUserAuthentication) for health-related records stored on-device.",
                    "4.3 Encryption. Locally persisted health records are encrypted using AES-256 symmetric encryption. Encryption keys are managed by the device's Secure Enclave hardware where supported and are bound to your device's passcode authentication. The Company does not have access to, nor does it hold a copy of, your encryption keys.",
                    "4.4 No Cloud Sync. The Company does not operate cloud backup or synchronization services for Health Data. The Application does not store Health Data in iCloud. Pseudonymized telemetry data, bug reports, and feature requests are stored in Google Firebase Firestore, a cloud database operated by Google LLC. Firebase's data processing is governed by Google's Cloud Data Processing Addendum. Health metrics included in bug reports (with your consent) are stored in Firestore and can be deleted via the Account Deletion feature.",
                    "4.5 Security Limitations. Notwithstanding the foregoing security measures, no security measure is infallible or impenetrable. THE COMPANY DOES NOT WARRANT OR GUARANTEE THE ABSOLUTE SECURITY OF ANY DATA STORED ON YOUR DEVICE OR TRANSMITTED THROUGH THIRD-PARTY DIAGNOSTIC CHANNELS. You are solely responsible for maintaining the physical security of your device, the confidentiality of your device passcode and Apple ID credentials, and for promptly reporting any loss or unauthorized access to your device to Apple and relevant authorities.",
                    "4.6 Data Deletion. You may delete your account and all associated server-side data at any time via Settings > Data > Delete Account. This permanently removes all Firestore-stored telemetry, analytics events, bug reports, and feature requests. Deleting the Application from your device will remove all locally stored Application data from that device. Both actions are irreversible. The Company has no ability to recover deleted data on your behalf."
                ])
            }

            legalSection(number: "5", title: "Disclosure and Sharing of Data") {
                warningBox(
                    "THE COMPANY DOES NOT SELL, RENT, LEASE, TRADE, OR BARTER YOUR PERSONAL DATA OR HEALTH DATA TO ANY THIRD PARTY FOR ANY COMMERCIAL PURPOSE WHATSOEVER."
                )
                paragraphs([
                    "5.1 Permitted Disclosures. The Company may disclose User data only in the following strictly limited circumstances:",
                    "a) Apple Inc.: Health Data, performance diagnostics, and subscription entitlement data are transmitted to and processed by Apple Inc. pursuant to Apple's integration frameworks (HealthKit, MetricKit, App Store). Such transmission is governed by Apple's Privacy Policy. The Company has no control over Apple's data processing practices.\n\nb) Google LLC (Firebase): Pseudonymized telemetry traces, analytics events, bug reports, and feature requests are stored in Google Firebase Firestore. Google processes this data pursuant to the Google Cloud Data Processing Addendum. The data is associated with a hashed user identifier and does not include raw HealthKit values unless you opt in via the bug report consent toggle. Google does not use Firestore data for advertising purposes.\n\nc) Legal and Regulatory Obligations: The Company may disclose data to the extent required by applicable federal, state, or foreign law, regulation, subpoena, court order, or directive from a government authority with jurisdiction. Where legally permitted, the Company will endeavor to provide you with advance notice of such disclosure.\n\nd) Protection of Rights, Property, and Safety: The Company may disclose data where reasonably necessary to enforce this Policy or the Terms of Service, to protect the rights, property, or safety of the Company, its users, or third parties, or to prevent, detect, or investigate fraud, security incidents, or illegal activity.\n\ne) Business Transfers and Reorganizations: In the event of a merger, acquisition, reorganization, divestiture, bankruptcy, dissolution, or sale of all or a material portion of the Company's assets, User data may be transferred to the acquiring or successor entity as part of that transaction. Any such successor shall be obligated to honor this Policy with respect to your data, or shall provide you with advance notice and an opportunity to object before your data is processed under materially different terms.\n\nf) With Your Explicit Consent: The Company may share your data for other purposes with your express, informed, prior consent, which you may withdraw at any time.",
                    "5.2 No Aggregate De-Anonymization. The Company will not attempt to re-identify or de-anonymize any anonymized dataset derived from User data, and will contractually prohibit any third party from doing so."
                ])
            }

            legalSection(number: "6", title: "Data Retention") {
                paragraphs([
                    "6.1 On-Device Health Data. Health Data is retained on your device for as long as the Application remains installed and you do not exercise your deletion rights. You retain full control over this data at all times.",
                    "6.2 Anonymized Analytics Data. Anonymized, aggregated telemetry data retained by the Company may be stored for a period not exceeding twenty-four (24) months from the date of collection, after which it is permanently and irreversibly deleted from all Company systems.",
                    "6.3 Subscription Transaction Records. Subscription transaction and entitlement records are retained for the period required by applicable law and generally accepted accounting practices, which is typically not less than seven (7) years, to satisfy financial reporting, tax, and audit obligations.",
                    "6.4 Residual Copies. Following deletion, residual copies of data may persist in backup or disaster recovery systems for a limited period, consistent with industry-standard data lifecycle management practices. Such residual copies are subject to the same security and confidentiality protections as live data."
                ])
            }

            legalSection(number: "7", title: "Your Rights and Controls") {
                legalSubheading("7.1 HealthKit Access Revocation")
                paragraphs([
                    "You may revoke the Application's authorization to read HealthKit data at any time by navigating to Settings > Privacy & Security > Health on your iPhone and modifying the Application's permissions. Revocation takes effect immediately. After revocation, the Application will no longer be able to read new health metrics, though previously computed on-device scores may remain stored locally until you delete the Application or exercise your deletion rights."
                ])

                legalSubheading("7.2 Analytics Opt-Out")
                paragraphs([
                    "You may opt out of all pseudonymized analytics and telemetry collection by toggling the \"Share Engine Insights\" control within the Application's Settings screen. Upon opt-out, no further telemetry data will be generated or transmitted to the Company's servers. Opting out will not affect the Application's core wellness monitoring functionality, which operates entirely on-device."
                ])

                legalSubheading("7.3 Data Deletion and Account Deletion")
                paragraphs([
                    "You may delete your account and all associated server-side data at any time through the Application's Settings screen by selecting \"Delete Account\" in the Data section. This permanently deletes all Firestore-stored data (telemetry, analytics, bug reports, feature requests), removes your Apple Sign-In credential from the device Keychain, and resets all local Application data.",
                    "Alternatively, you may delete all locally stored Application data by uninstalling the Application from your device. Uninstallation removes all on-device data but does not delete server-side data — use the in-app Account Deletion feature to remove both."
                ])

                legalSubheading("7.4 Rights Under California Law (CCPA/CPRA)")
                paragraphs([
                    "If you are a California resident, you may have the following rights under the California Consumer Privacy Act, as amended by the California Privacy Rights Act (collectively, \"CCPA/CPRA\"): (a) the right to know what personal information the Company collects, uses, discloses, or sells; (b) the right to delete personal information the Company has collected from you, subject to certain exceptions; (c) the right to correct inaccurate personal information; (d) the right to opt out of the sale or sharing of personal information (the Company does not sell personal information); (e) the right to non-discrimination for exercising your CCPA/CPRA rights; and (f) the right to limit the use of sensitive personal information. To submit a verifiable consumer request, contact us at \(contactEmail)."
                ])

                legalSubheading("7.5 Rights Under European Law (GDPR)")
                paragraphs([
                    "If you are located in the European Economic Area, United Kingdom, or Switzerland, you may have rights under the General Data Protection Regulation (GDPR) or applicable national implementation, including: (a) the right of access; (b) the right to rectification; (c) the right to erasure (\"right to be forgotten\"); (d) the right to restriction of processing; (e) the right to data portability; (f) the right to object to processing; and (g) rights in relation to automated decision-making and profiling. To exercise these rights, contact our Data Protection contact at \(contactEmail). You also have the right to lodge a complaint with a supervisory authority in your jurisdiction."
                ])

                legalSubheading("7.6 Response Timeframe")
                paragraphs([
                    "The Company will respond to verifiable rights requests within thirty (30) calendar days of receipt. In cases of complexity or high volume, the Company may extend this period by an additional thirty (30) days, with notice to you."
                ])
            }

            legalSection(number: "8", title: "Children's Privacy") {
                paragraphs([
                    "8.1 The Application is not directed at, designed for, or marketed to children under the age of thirteen (13), or such higher age as required by applicable law in the User's jurisdiction.",
                    "8.2 The Company does not knowingly collect, solicit, or process personal information from children under 13. If the Company becomes aware that it has inadvertently collected personal information from a child under 13, it will take immediate steps to delete such information from its systems.",
                    "8.3 If you believe that the Company may have collected personal information from a child under 13, please notify us immediately at \(contactEmail)."
                ])
            }

            legalSection(number: "9", title: "International Data Transfers") {
                paragraphs([
                    "9.1 The Company is based in the United States. If you are accessing the Application from outside the United States, please be aware that any pseudonymized telemetry data transmitted to the Company may be transferred to, processed in, and stored in the United States (in Google Firebase Firestore), where data protection laws may differ from those in your jurisdiction.",
                    "9.2 By using the Application, you consent to the transfer of any applicable data to the United States as described in this Policy. Where required by applicable law (e.g., GDPR), the Company will implement appropriate safeguards for international data transfers, including standard contractual clauses approved by the relevant supervisory authority."
                ])
            }

            legalSection(number: "10", title: "Third-Party Links and Integrations") {
                paragraphs([
                    "10.1 The Application may contain links to external websites or integrate with third-party services. The Company is not responsible for the privacy practices or content of any third-party service, and this Policy does not apply to any third-party service.",
                    "10.2 We strongly encourage you to review the privacy policies of any third-party services you access through or in connection with the Application, including Apple's Privacy Policy available at apple.com/privacy."
                ])
            }

            legalSection(number: "11", title: "Health Data — Special Category Notice") {
                warningBox(
                    "HEALTH AND BIOMETRIC DATA IS RECOGNIZED AS A SPECIAL, SENSITIVE CATEGORY OF PERSONAL DATA UNDER MANY APPLICABLE LAWS, INCLUDING THE GDPR AND CCPA/CPRA. THE COMPANY TREATS HEALTH DATA WITH THE HIGHEST LEVEL OF PROTECTION. HEALTH DATA IS PROCESSED ON YOUR DEVICE DURING NORMAL USE AND IS TRANSMITTED TO THE COMPANY'S SERVERS ONLY WHEN YOU EXPLICITLY OPT IN VIA THE BUG REPORT HEALTH DATA CONSENT TOGGLE."
                )
                paragraphs([
                    "The Company does not use Health Data to make automated decisions that produce legal or similarly significant effects on you. The Company does not use Health Data to infer other sensitive categories of information (e.g., race, ethnicity, religion, sexual orientation, or immigration status). Health Data included in bug reports is used solely for the purpose of reproducing and diagnosing reported issues and is permanently deleted when you use the Account Deletion feature."
                ])
            }

            legalSection(number: "12", title: "Changes to This Privacy Policy") {
                paragraphs([
                    "12.1 The Company reserves the right to amend this Policy at any time. When we make material changes to this Policy, we will provide notice through an in-app notification and/or by updating the Effective Date at the top of this Policy.",
                    "12.2 Your continued use of the Application after the effective date of any revised Policy constitutes your acceptance of the revised Policy. If you do not agree to the revised Policy, you must discontinue use of the Application.",
                    "12.3 For changes that, in the Company's reasonable judgment, materially and adversely affect your rights, we will endeavor to provide no less than thirty (30) days' advance notice before the revised Policy takes effect."
                ])
            }

            legalSection(number: "13", title: "Contact; Data Protection Officer") {
                paragraphs([
                    "For questions, concerns, complaints, or requests relating to this Policy or the processing of your data, please contact:",
                    "Privacy and Data Protection Team\n\(companyName)\nAttn: Privacy Officer\nSan Francisco, California, USA\nEmail: \(contactEmail)",
                    "For matters relating to EU/UK data protection rights, the above contact also serves as the Company's designated data protection point of contact."
                ])
            }

            Text("Effective Date: \(effectiveDate) · \(companyName) · All rights reserved.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }
}

// MARK: - Shared Legal Layout Helpers

private func legalHeader(title: String, effectiveDate: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(.primary)

        Text("Effective Date: \(effectiveDate)")
            .font(.caption)
            .foregroundStyle(.secondary)

        Divider()
            .padding(.top, 4)
    }
}

private func legalSection<Content: View>(
    number: String,
    title: String,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        Text("\(number). \(title)")
            .font(.headline)
            .foregroundStyle(.primary)

        content()
    }
}

private func legalSubheading(_ text: String) -> some View {
    Text(text)
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundStyle(.primary)
        .padding(.top, 4)
}

private func paragraphs(_ texts: [String]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(texts, id: \.self) { text in
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private func warningBox(_ text: String) -> some View {
    Text(text)
        .font(.footnote)
        .fontWeight(.medium)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
        )
}

// MARK: - Preview

#Preview("Legal Gate") {
    LegalGateView(onAccepted: {})
}

#Preview("Terms Sheet") {
    TermsOfServiceSheet()
}

#Preview("Privacy Sheet") {
    PrivacyPolicySheet()
}
