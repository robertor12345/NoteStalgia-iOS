import XCTest
@testable import NoteStalgia_iOS

/// The same cases as the Worker's `test/validate.test.ts`: the app and the server must agree on what
/// a name, a postcode or an email looks like.
final class InputRulesTests: XCTestCase {
    func testPersonNamesFromManyLanguages() {
        for name in ["Sam Jones", "Mary-Jane O’Neil", "Zoë Nuñez", "Łukasz Kowalski", "J. R. Tolkien", "Li Wei", "Siobhán Ní Bhriain"] {
            XCTAssertNil(InputRules.personName(name), name)
        }
    }

    func testPersonNamesRefuseDigitsSymbolsAndMarkup() {
        for name in ["Sam2", "<b>Sam</b>", "sam@home", "R2-D2", "S", "---"] {
            XCTAssertNotNil(InputRules.personName(name), name)
        }
        XCTAssertNotNil(InputRules.personName(String(repeating: "a", count: 81)))
    }

    func testPersonNameRequiredOnlyWhenAsked() {
        XCTAssertNil(InputRules.personName(""))
        XCTAssertEqual(InputRules.personName("   ", required: true), "Enter a name.")
        XCTAssertEqual(InputRules.personName("", required: true, label: "Your name"), "Enter your name.")
    }

    func testBusinessNames() {
        for name in ["Willow Care Group", "St. Mary’s Lodge", "Smith & Sons (Care) Ltd", "Wing 2", "Page Lodge · Day room", "24/7 Care"] {
            XCTAssertNil(InputRules.businessName(name, label: "the name"), name)
        }
        for name in ["<script>", "Care*Home", "12345", "!!"] {
            XCTAssertNotNil(InputRules.businessName(name, label: "the name"), name)
        }
        XCTAssertEqual(InputRules.businessName("", label: "the home’s name", required: true), "Enter the home’s name.")
        XCTAssertNotNil(InputRules.businessName("A", label: "the name"))
        XCTAssertNotNil(InputRules.businessName(String(repeating: "x", count: 61), label: "the label", max: 60))
    }

    func testPostcodes() {
        XCTAssertEqual(InputRules.normalisePostcode("sk11aa"), "SK1 1AA")
        XCTAssertEqual(InputRules.normalisePostcode(" M1  1AE "), "M1 1AE")
        XCTAssertEqual(InputRules.normalisePostcode("EC1A 1BB"), "EC1A 1BB")
        XCTAssertNil(InputRules.normalisePostcode("12345"))
        XCTAssertNil(InputRules.normalisePostcode("SK1 1A"))
        XCTAssertEqual(InputRules.postcode("nonsense"), "A UK postcode looks like SK1 1AA.")
        XCTAssertNil(InputRules.postcode(""))
        XCTAssertEqual(InputRules.postcode("", required: true), "Enter a postcode like SK1 1AA.")
    }

    func testAddressAndTown() {
        XCTAssertNil(InputRules.addressLine("1 Willow Street"))
        XCTAssertNil(InputRules.addressLine("Flat 2, 10 St. John’s Rd"))
        XCTAssertNotNil(InputRules.addressLine("<x>"))
        XCTAssertEqual(InputRules.addressLine("", label: "The first address line", required: true), "Enter the first address line.")
        XCTAssertNil(InputRules.town("Stockport"))
        XCTAssertNil(InputRules.town("Stoke-on-Trent"))
        XCTAssertNotNil(InputRules.town("Stock3port"))
        XCTAssertEqual(InputRules.town("", required: true), "Enter the town.")
    }

    func testPhone() {
        for phone in ["0161 000 0000", "+44 161 000 0000", "(0161) 000-0000", ""] { XCTAssertNil(InputRules.phone(phone), phone) }
        for phone in ["abc", "12345", "0161 000 0000 ext 4"] { XCTAssertNotNil(InputRules.phone(phone), phone) }
    }

    func testBeds() {
        for beds in ["", "1", "40", "2000"] { XCTAssertNil(InputRules.beds(beds), beds) }
        for beds in ["0", "2001", "4.5", "forty", "40 beds", "-3"] { XCTAssertNotNil(InputRules.beds(beds), beds) }
    }

    func testEmails() {
        for email in ["sam@willow-care.co.uk", "sam.jones+rota@willow.care", "o'brien@care.org"] {
            XCTAssertTrue(InputRules.isValidEmail(email), email)
        }
        for email in ["", "sam", "sam@", "@care.co.uk", "sam@care", "sam@care.", "sam@.care.co.uk", "sam jones@care.co.uk", "sam@@care.co.uk", "sam..jones@care.co.uk", ".sam@care.co.uk", "sam@care.c", "sam@care_home.co.uk"] {
            XCTAssertFalse(InputRules.isValidEmail(email), email)
        }
        XCTAssertEqual(InputRules.email("  "), "Enter a work email address.")
        XCTAssertNil(InputRules.email("  Sam@Care.co.uk "))
    }

    func testCqcIds() {
        XCTAssertNil(InputRules.cqcId("", kind: "provider"))
        XCTAssertNil(InputRules.cqcId("1-123456789", kind: "provider"))
        XCTAssertNil(InputRules.cqcId("1-1234567890", kind: "location"))
        XCTAssertEqual(InputRules.cqcId("ABC", kind: "location"), "A CQC location ID looks like 1-123456789.")
    }

    func testDomains() {
        XCTAssertEqual(InputRules.normaliseDomain(" https://www.Willow-Care.co.uk/about?x=1 "), "www.willow-care.co.uk")
        XCTAssertEqual(InputRules.normaliseDomain("@willow-care.co.uk."), "willow-care.co.uk")
        XCTAssertNil(InputRules.domain("willow-care.co.uk"))
        XCTAssertNil(InputRules.domain("@Willow-Care.co.uk"))
        for bad in ["", "willow", "willow care.co.uk", "-willow.co.uk", "willow.c", "wil_low.co.uk"] { XCTAssertNotNil(InputRules.domain(bad), bad) }
    }

    func testFreeText() {
        XCTAssertNil(InputRules.freeText("Two homes in Stockport, opening a third in spring.\nThanks!", label: "notes", max: 1000))
        XCTAssertNotNil(InputRules.freeText("<script>alert(1)</script>", label: "notes", max: 1000))
        XCTAssertNotNil(InputRules.freeText(String(repeating: "a", count: 1001), label: "notes", max: 1000))
    }

    func testWings() {
        XCTAssertNil(InputRules.wings(["Residential", "Memory care"]))
        XCTAssertNotNil(InputRules.wings(["Garden", "garden "]))
        XCTAssertNotNil(InputRules.wings(["<b>"]))
    }

    func testFiltersKeepOnlyPlausibleCharacters() {
        XCTAssertEqual(InputFilter.digits(max: 4).apply("4a0 b2x1999"), "4021")
        XCTAssertEqual(InputFilter.cqcId.apply("1-12 3a456789"), "1-123456789")
        XCTAssertEqual(InputFilter.phone.apply("0161 abc 000-0000"), "0161  000-0000")
        XCTAssertEqual(InputFilter.postcode.apply("sk1 1aa!"), "SK1 1AA")
        XCTAssertEqual(InputFilter.email.apply(" Sam@Care.co.uk "), "sam@care.co.uk")
        XCTAssertEqual(InputFilter.domain.apply("Willow-Care .co.uk"), "willow-care.co.uk")
    }

    func testMarkupAndControlCharactersAreDropped() {
        XCTAssertEqual(InputFilter.withoutMarkup("<b>1 Willow</b>", allowsLineBreaks: false), "b1 Willow/b")
        XCTAssertEqual(InputFilter.withoutMarkup("a\tb\u{7}c\nd", allowsLineBreaks: false), "abcd")
        XCTAssertEqual(InputFilter.withoutMarkup("one\ntwo", allowsLineBreaks: true), "one\ntwo")
    }

    func testTidyCollapsesWhitespace() {
        XCTAssertEqual(InputRules.tidy("  Sam   \n Jones "), "Sam Jones")
    }
}
