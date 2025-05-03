// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {
  internal enum Common {
    /// Back to App
    internal static let backToAppButton = L10n.tr("Localizable", "Common.backToAppButton", fallback: "Back to App")
    /// Cancel
    internal static let cancelButton = L10n.tr("Localizable", "Common.cancelButton", fallback: "Cancel")
    /// OK
    internal static let okButton = L10n.tr("Localizable", "Common.okButton", fallback: "OK")
    /// Common
    internal static let retryButton = L10n.tr("Localizable", "Common.retryButton", fallback: "Retry")
  }
  internal enum SetupView {
    /// Change Model
    internal static let changeModelButton = L10n.tr("Localizable", "SetupView.changeModelButton", fallback: "Change Model")
    /// Current Model: %@
    internal static func currentModelLabel(_ p1: Any) -> String {
      return L10n.tr("Localizable", "SetupView.currentModelLabel", String(describing: p1), fallback: "Current Model: %@")
    }
    /// You can change the Whisper model used for transcription.
    /// Accuracy and processing speed vary depending on the model.
    internal static let description = L10n.tr("Localizable", "SetupView.description", fallback: "You can change the Whisper model used for transcription.\nAccuracy and processing speed vary depending on the model.")
    /// SetupView
    internal static let title = L10n.tr("Localizable", "SetupView.title", fallback: "Change Audio Transcription Model")
  }
  internal enum SetupViewModel {
    /// Failed to change model: %@
    internal static func changeModelErrorFormat(_ p1: Any) -> String {
      return L10n.tr("Localizable", "SetupViewModel.changeModelErrorFormat", String(describing: p1), fallback: "Failed to change model: %@")
    }
    /// SetupViewModel
    internal static func changingDescriptionFormat(_ p1: Any) -> String {
      return L10n.tr("Localizable", "SetupViewModel.changingDescriptionFormat", String(describing: p1), fallback: "Changing to %@...")
    }
  }
  internal enum TranscriptionView {
    /// Copy
    internal static let copy = L10n.tr("Localizable", "TranscriptionView.copy", fallback: "Copy")
    /// Drag & Drop Audio File
    internal static let dragAndDropAudioFile = L10n.tr("Localizable", "TranscriptionView.dragAndDropAudioFile", fallback: "Drag & Drop Audio File")
    /// Drop audio file here
    internal static let dropAudioFile = L10n.tr("Localizable", "TranscriptionView.dropAudioFile", fallback: "Drop audio file here")
    /// Drop audio file here
    internal static let dropAudioFileHere = L10n.tr("Localizable", "TranscriptionView.dropAudioFileHere", fallback: "Drop audio file here")
    /// Transcription failed: %@
    internal static func errorMessageFormat(_ p1: Any) -> String {
      return L10n.tr("Localizable", "TranscriptionView.errorMessageFormat", String(describing: p1), fallback: "Transcription failed: %@")
    }
    /// Error
    internal static let errorTitle = L10n.tr("Localizable", "TranscriptionView.errorTitle", fallback: "Error")
    /// Export
    internal static let export = L10n.tr("Localizable", "TranscriptionView.export", fallback: "Export")
    /// Failed to export the file.
    internal static let exportErrorMessage = L10n.tr("Localizable", "TranscriptionView.exportErrorMessage", fallback: "Failed to export the file.")
    /// Failed to save the file: %@
    internal static func exportErrorMessageFormat(_ p1: Any) -> String {
      return L10n.tr("Localizable", "TranscriptionView.exportErrorMessageFormat", String(describing: p1), fallback: "Failed to save the file: %@")
    }
    /// Export Error
    internal static let exportErrorTitle = L10n.tr("Localizable", "TranscriptionView.exportErrorTitle", fallback: "Export Error")
    /// The file has been exported successfully.
    internal static let exportSuccessMessage = L10n.tr("Localizable", "TranscriptionView.exportSuccessMessage", fallback: "The file has been exported successfully.")
    /// Export Successful
    internal static let exportSuccessTitle = L10n.tr("Localizable", "TranscriptionView.exportSuccessTitle", fallback: "Export Successful")
    /// File selection error: %@
    internal static func fileSelectionErrorFormat(_ p1: Any) -> String {
      return L10n.tr("Localizable", "TranscriptionView.fileSelectionErrorFormat", String(describing: p1), fallback: "File selection error: %@")
    }
    /// Find
    internal static let find = L10n.tr("Localizable", "TranscriptionView.find", fallback: "Find")
    /// No results found for your search.
    internal static let noSearchResults = L10n.tr("Localizable", "TranscriptionView.noSearchResults", fallback: "No results found for your search.")
    /// No transcription available
    internal static let noTranscription = L10n.tr("Localizable", "TranscriptionView.noTranscription", fallback: "No transcription available")
    /// or
    internal static let or = L10n.tr("Localizable", "TranscriptionView.or", fallback: "or")
    /// Reset
    internal static let reset = L10n.tr("Localizable", "TranscriptionView.reset", fallback: "Reset")
    /// Reset
    internal static let resetConfirmationButton = L10n.tr("Localizable", "TranscriptionView.resetConfirmationButton", fallback: "Reset")
    /// Do you want to reset the file and transcription?
    internal static let resetConfirmationMessage = L10n.tr("Localizable", "TranscriptionView.resetConfirmationMessage", fallback: "Do you want to reset the file and transcription?")
    /// Retranscribe
    internal static let retranscribe = L10n.tr("Localizable", "TranscriptionView.retranscribe", fallback: "Retranscribe")
    /// Retranscribe
    internal static let retranscribeConfirmationButton = L10n.tr("Localizable", "TranscriptionView.retranscribeConfirmationButton", fallback: "Retranscribe")
    /// Do you want to re-run the transcription? The current transcription result will be erased.
    internal static let retranscribeConfirmationMessage = L10n.tr("Localizable", "TranscriptionView.retranscribeConfirmationMessage", fallback: "Do you want to re-run the transcription? The current transcription result will be erased.")
    /// Retranscribe the audio file
    internal static let retranscribeHelp = L10n.tr("Localizable", "TranscriptionView.retranscribeHelp", fallback: "Retranscribe the audio file")
    /// Save as Text File
    internal static let saveAsTextFile = L10n.tr("Localizable", "TranscriptionView.saveAsTextFile", fallback: "Save as Text File")
    /// Search Transcription
    internal static let searchPlaceholder = L10n.tr("Localizable", "TranscriptionView.searchPlaceholder", fallback: "Search Transcription")
    /// TranscriptionView
    internal static let selectAudioFile = L10n.tr("Localizable", "TranscriptionView.selectAudioFile", fallback: "Select Audio File")
    /// Select Model
    internal static let selectModel = L10n.tr("Localizable", "TranscriptionView.selectModel", fallback: "Select Model")
    /// Select transcription model
    internal static let selectModelHelp = L10n.tr("Localizable", "TranscriptionView.selectModelHelp", fallback: "Select transcription model")
    /// Show Current Location
    internal static let showCurrentLocation = L10n.tr("Localizable", "TranscriptionView.showCurrentLocation", fallback: "Show Current Location")
    /// Start Transcription
    internal static let startTranscription = L10n.tr("Localizable", "TranscriptionView.startTranscription", fallback: "Start Transcription")
    /// %d min %02d sec
    internal static func timeFormat(_ p1: Int, _ p2: Int) -> String {
      return L10n.tr("Localizable", "TranscriptionView.timeFormat", p1, p2, fallback: "%d min %02d sec")
    }
    /// Transcribe
    internal static let transcribe = L10n.tr("Localizable", "TranscriptionView.transcribe", fallback: "Transcribe")
    /// Transcribing...
    internal static let transcribing = L10n.tr("Localizable", "TranscriptionView.transcribing", fallback: "Transcribing...")
    /// untitled
    internal static let untitled = L10n.tr("Localizable", "TranscriptionView.untitled", fallback: "untitled")
  }
  internal enum WhisperError {
    /// Failed to load audio file
    internal static let audioFileLoadFailed = L10n.tr("Localizable", "WhisperError.audioFileLoadFailed", fallback: "Failed to load audio file")
    /// Failed to initialize Whisper
    internal static let failedToInitialize = L10n.tr("Localizable", "WhisperError.failedToInitialize", fallback: "Failed to initialize Whisper")
    /// WhisperError
    internal static let fileNotFound = L10n.tr("Localizable", "WhisperError.fileNotFound", fallback: "File not found")
    /// Transcription failed
    internal static let transcriptionFailed = L10n.tr("Localizable", "WhisperError.transcriptionFailed", fallback: "Transcription failed")
    /// Whisper is not initialized
    internal static let uninitialized = L10n.tr("Localizable", "WhisperError.uninitialized", fallback: "Whisper is not initialized")
    /// Unsupported file format
    internal static let unsupportedFormat = L10n.tr("Localizable", "WhisperError.unsupportedFormat", fallback: "Unsupported file format")
    /// Unsupported model name
    internal static let unsupportedModel = L10n.tr("Localizable", "WhisperError.unsupportedModel", fallback: "Unsupported model name")
  }
  internal enum WhisperInitializeStatus {
    /// Checking model...
    internal static let checkingModel = L10n.tr("Localizable", "WhisperInitializeStatus.checkingModel", fallback: "Checking model...")
    /// Downloading model... %@%%
    internal static func downloadingModelFormat(_ p1: Any) -> String {
      return L10n.tr("Localizable", "WhisperInitializeStatus.downloadingModelFormat", String(describing: p1), fallback: "Downloading model... %@%%")
    }
    /// Loading model...
    internal static let loadingModel = L10n.tr("Localizable", "WhisperInitializeStatus.loadingModel", fallback: "Loading model...")
    /// WhisperKit is ready
    internal static let ready = L10n.tr("Localizable", "WhisperInitializeStatus.ready", fallback: "WhisperKit is ready")
    /// WhisperInitializeStatus
    internal static let uninitialized = L10n.tr("Localizable", "WhisperInitializeStatus.uninitialized", fallback: "WhisperKit is not initialized")
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
