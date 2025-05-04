import SwiftUI
import MarkdownUI

struct AcknowledgementsView: View {
    
    // MARK: Properties
    
    private let markdownURL = Bundle.main.url(forResource: "licenses", withExtension: "md")
    
    // MARK: Body

    var body: some View {
        VStack {
            if let u = markdownURL, let md = try? String(contentsOf: u) {
                ScrollView {
                    Markdown(MarkdownContent(md))
                        .padding()
                }
            } else {
                Text(L10n.Acknowledgements.empty)
            }
        }
        .navigationTitle(L10n.Toolbar.Help.acknowledgements)
    }
}
