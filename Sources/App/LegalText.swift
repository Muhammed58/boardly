import Foundation

/// In-app legal copy. Boardly is fully on-device with no accounts, so the
/// privacy policy is short and the terms defer to Apple's standard EULA.
enum LegalText {
    static let supportEmail = "sencesaglik@gmail.com"
    static let appleEULA = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    static let privacyPolicyURL = "https://www.indiesoftwaredev.com/app/boardly?tab=privacy"
    static let supportURL = "https://www.indiesoftwaredev.com/app/boardly?tab=contact"
    static let termsURL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

    static let privacy = """
Privacy Policy

Last updated: July 2026

Boardly is designed to be private by default. Everything you do in Boardly happens entirely on your device.

WHAT WE COLLECT
Nothing. Boardly has no account system, no analytics, and no tracking. We do not collect, store, or transmit any personal data.

YOUR PHOTOS & SCREENSHOTS
Images you import stay on your device. They are only used to create your edits and are never uploaded to us or any third party. Photo library access is used solely to let you pick images to edit and to save your exports back to Photos, with your permission.

DATA SHARING
We do not share any data because we do not collect any.

CONTACT
Questions? Email us at \(supportEmail).
"""

    static let terms = """
Terms of Use

Boardly is provided under Apple's Standard End User License Agreement (EULA), which you can read at:
\(appleEULA)

In short:
• Boardly is licensed to you, not sold.
• You are responsible for the content you create and share with Boardly.
• The app is provided "as is" without warranties.
• You agree to use Boardly in compliance with all applicable laws.

For support, contact \(supportEmail).
"""
}
