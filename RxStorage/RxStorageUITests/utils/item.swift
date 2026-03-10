//
//  item.swift
//  RxStorage
//
//  Created by Qiwei Li on 2/3/26.
//
import XCTest

extension XCUIApplication {
    // MARK: - Navigation

    var itemsTab: XCUIElement {
        buttons["Items"].firstMatch
    }

    // MARK: - Item List

    var newItemButton: XCUIElement {
        buttons["item-list-new-button"].firstMatch
    }

    var itemRow: XCUIElement {
        staticTexts["item-row"]
    }

    // MARK: - Item Form

    var itemTitleField: XCUIElement {
        textFields["item-form-title-field"].firstMatch
    }

    var itemDescriptionField: XCUIElement {
        textFields["item-form-description-field"].firstMatch
    }

    var itemPriceField: XCUIElement {
        textFields["item-form-price-field"].firstMatch
    }

    var itemFormSubmitButton: XCUIElement {
        buttons["item-form-submit-button"].firstMatch
    }

    // MARK: - Item Detail

    var itemDetailTitle: XCUIElement {
        staticTexts["item-detail-title"].firstMatch
    }

    var appClipsSignInRequired: XCUIElement {
        staticTexts["app-clips-sign-in-required"].firstMatch
    }

    var appClipsAccessDenined: XCUIElement {
        staticTexts["app-clips-access-denied"].firstMatch
    }

    var appClipsSignOutButton: XCUIElement {
        buttons["app-clips-sign-out-button"].firstMatch
    }

    var appClipsMoreMenu: XCUIElement {
        buttons["app-clips-more-menu"].firstMatch
    }

    // MARK: - Deep Link

    var deepLinkErrorAlert: XCUIElement {
        alerts["Deep Link Error"].firstMatch
    }

    var deepLinkLoadingOverlay: XCUIElement {
        staticTexts["Loading item..."].firstMatch
    }

    var deepLinkErrorOKButton: XCUIElement {
        alerts["Deep Link Error"].buttons["OK"].firstMatch
    }

    // MARK: - QR Code Scanner

    var qrScannerButton: XCUIElement {
        buttons["qr-scanner-button"].firstMatch
    }

    var qrCodeLoadingOverlay: XCUIElement {
        staticTexts["Loading item from QR code.."].firstMatch
    }

    // MARK: - Error Alert (for QR scan tests)

    // Note: These are aliases to the deep link error alert selectors for semantic clarity

    var errorAlert: XCUIElement {
        alerts["Deep Link Error"].firstMatch
    }

    var errorAlertOKButton: XCUIElement {
        alerts["Deep Link Error"].buttons["OK"].firstMatch
    }

    // MARK: - Entity Detail Navigation

    var tagDetailTitle: XCUIElement {
        staticTexts["tag-detail-title"].firstMatch
    }

    var categoryDetailTitle: XCUIElement {
        staticTexts["category-detail-title"].firstMatch
    }

    var locationDetailTitle: XCUIElement {
        staticTexts["location-detail-title"].firstMatch
    }

    var authorDetailTitle: XCUIElement {
        staticTexts["author-detail-title"].firstMatch
    }

    var detailCategoryLink: XCUIElement {
        staticTexts["detail-category-link"].firstMatch
    }

    var detailLocationLink: XCUIElement {
        staticTexts["detail-location-link"].firstMatch
    }

    var detailAuthorLink: XCUIElement {
        staticTexts["detail-author-link"].firstMatch
    }

    // MARK: - Image Picker & Camera

    var addImagesButton: XCUIElement {
        buttons["add-image"].firstMatch
    }

    var chooseFromLibraryButton: XCUIElement {
        buttons["item-form-choose-from-library"].firstMatch
    }

    var takePhotoButton: XCUIElement {
        buttons["Take Photo"].firstMatch
    }

    var pendingUploadRow: XCUIElement {
        otherElements["item-form-pending-upload"].firstMatch
    }

    var uploadedStatus: XCUIElement {
        staticTexts["item-form-uploaded-status"].firstMatch
    }
}
