import Testing
@testable import CodeField

@Suite("Sanitizing")
struct SanitizingTests {
    @Test func digitsDropEverythingElse() {
        #expect(CodeInput.sanitize("12a-3 4.5b6", characterSet: .digits) == "123456")
        #expect(CodeInput.sanitize("", characterSet: .digits) == "")
        #expect(CodeInput.sanitize("abc", characterSet: .digits) == "")
    }

    @Test func otherScriptDigitsBecomeASCII() {
        #expect(CodeInput.sanitize("１２３", characterSet: .digits) == "123")    // full-width
        #expect(CodeInput.sanitize("٤٥٦", characterSet: .digits) == "456")      // Arabic-Indic
        #expect(CodeInput.sanitize("½", characterSet: .digits) == "")           // not a whole digit
    }

    @Test func alphanumericUppercasesASCIILetters() {
        #expect(CodeInput.sanitize("ab-12 cD", characterSet: .alphanumeric) == "AB12CD")
        #expect(CodeInput.sanitize("éß!Z9", characterSet: .alphanumeric) == "Z9")
    }

    @Test func lengthIsClampedToSupportedRange() {
        #expect(CodeInput.clampedLength(2) == 4)
        #expect(CodeInput.clampedLength(6) == 6)
        #expect(CodeInput.clampedLength(12) == 8)
        #expect(CodeInput(length: 0).length == 4)
        #expect(CodeInput(length: 99).slots.count == 8)
    }

    @Test func initialValueIsSanitizedAndClamped() {
        let input = CodeInput(length: 4, value: "1a2b3c4d5")
        #expect(input.value == "1234")
        #expect(input.isComplete)
    }
}

@Suite("Typing")
struct TypingTests {
    @Test func typedCharactersAreAppended() {
        var input = CodeInput(length: 4)
        #expect(input.replace(with: "1") == false)
        #expect(input.replace(with: "12") == false)
        #expect(input.value == "12")
        #expect(input.activeIndex == 2)
    }

    @Test func rejectedCharactersAreIgnored() {
        var input = CodeInput(length: 4, value: "12")
        input.replace(with: "12x")
        #expect(input.value == "12")
    }

    @Test func extraCharactersAfterCompletionAreDropped() {
        var input = CodeInput(length: 4, value: "1234")
        #expect(input.replace(with: "12345") == false)
        #expect(input.value == "1234")
    }

    @Test func completionIsReportedOnce() {
        var input = CodeInput(length: 4, value: "123")
        #expect(input.replace(with: "1234") == true)
        #expect(input.replace(with: "12345") == false)
        #expect(input.isComplete)
    }

    @Test func backspaceMovesBackOneBox() {
        var input = CodeInput(length: 6, value: "1234")
        input.replace(with: "123")
        #expect(input.value == "123")
        #expect(input.slot(at: 3) == .active)

        input.deleteBackward()
        input.deleteBackward()
        #expect(input.value == "1")
        input.deleteBackward()
        input.deleteBackward()
        #expect(input.isEmpty)
    }

    @Test func appendingSingleCharacters() {
        var input = CodeInput(length: 4, characterSet: .alphanumeric)
        #expect(input.append("a") == false)
        #expect(input.append("-") == false)
        input.append("1")
        input.append("b")
        #expect(input.append("2") == true)
        #expect(input.append("3") == false)
        #expect(input.value == "A1B2")
    }

    @Test func clearRemovesEverything() {
        var input = CodeInput(length: 4, value: "1234")
        input.clear()
        #expect(input.value.isEmpty)
        #expect(input.activeIndex == 0)
    }
}

@Suite("Paste and autofill")
struct PasteTests {
    @Test func fullCodeFillsEveryBox() {
        var input = CodeInput(length: 6)
        #expect(input.replace(with: "482913") == true)
        #expect(input.value == "482913")
    }

    @Test func groupedCodeIsJoined() {
        var input = CodeInput(length: 6)
        input.paste("482 913")
        #expect(input.value == "482913")

        var dashed = CodeInput(length: 6)
        dashed.paste("482-913")
        #expect(dashed.value == "482913")
    }

    @Test func codeIsFoundInsideAMessage() {
        var input = CodeInput(length: 6)
        input.paste("Your Acme code is 482913. It expires in 10 minutes.")
        #expect(input.value == "482913")
    }

    @Test func alphanumericCodePrefersWordsWithDigitsAndCapitals() {
        var input = CodeInput(length: 6, characterSet: .alphanumeric)
        input.paste("Please enter AB12CD within 5 minutes")
        #expect(input.value == "AB12CD")

        var letters = CodeInput(length: 4, characterSet: .alphanumeric)
        letters.paste("Your code WXYZ")
        #expect(letters.value == "WXYZ")
    }

    @Test func fullCodeReplacesPartialInput() {
        // The user typed a digit, then tapped the SMS suggestion above the keyboard.
        var input = CodeInput(length: 6, value: "7")
        #expect(input.replace(with: "7482913") == true)
        #expect(input.value == "482913")
    }

    @Test func fullCodeReplacesCompleteInput() {
        var input = CodeInput(length: 4, value: "1111")
        input.replace(with: "11112222")
        #expect(input.value == "2222")
    }

    @Test func partialPasteIsAppendedAndClamped() {
        var input = CodeInput(length: 6, value: "12")
        input.paste("34")
        #expect(input.value == "1234")

        input.paste("5678")
        #expect(input.value == "123456")
    }

    @Test func textWithoutAFullCodeFallsBackToFiltering() {
        var input = CodeInput(length: 6)
        input.replace(with: "12 ab")
        #expect(input.value == "12")
    }

    @Test func extractCodeReturnsNilWhenNothingFits() {
        #expect(CodeInput.extractCode(from: "no code here", length: 6, characterSet: .digits) == nil)
        #expect(CodeInput.extractCode(from: "12345", length: 6, characterSet: .digits) == nil)
        #expect(CodeInput.extractCode(from: "Code: 1234", length: 4, characterSet: .digits) == "1234")
    }
}

@Suite("Slots and accessibility")
struct SlotTests {
    @Test func slotsDescribeEachBox() {
        let input = CodeInput(length: 4, value: "12")
        #expect(input.slots == [.filled("1"), .filled("2"), .active, .empty])
    }

    @Test func completeCodeHasNoActiveBox() {
        let input = CodeInput(length: 4, value: "1234")
        #expect(input.activeIndex == nil)
        #expect(!input.slots.contains(.active))
    }

    @Test func outOfRangeSlotsAreEmpty() {
        let input = CodeInput(length: 4, value: "1234")
        #expect(input.slot(at: -1) == .empty)
        #expect(input.slot(at: 4) == .empty)
    }

    @Test func accessibilityValueCountsWithoutRevealingTheCode() {
        #expect(CodeInput(length: 6, value: "123").accessibilityValue == "3 of 6 digits entered")
        #expect(CodeInput(length: 4, characterSet: .alphanumeric).accessibilityValue == "0 of 4 characters entered")
        #expect(!CodeInput(length: 6, value: "482913").accessibilityValue.contains("482913"))
    }
}
