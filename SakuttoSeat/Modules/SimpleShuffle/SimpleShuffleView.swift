//
//  SimpleShuffleView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/07.
//

import SwiftUI

struct SimpleShuffleView: View {
    @ObservedObject var presenter: SimpleShufflePresenter
    
    private var shareText: String {
        var text = "【サクッと席決め】シャッフル結果\n"
        for (index, name) in presenter.attendees.enumerated() {
            text += "\(index + 1)番席: \(name)\n"
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(presenter.attendees, id: \.self) { name in
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                if let index = presenter.attendees.firstIndex(of: "\(name)") {
                                    Text("\(index + 1)")
                                        .font(.system(.subheadline, design: .rounded))
                                        .bold()
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Text(name)
                                .font(.body)
                                .padding(.leading, 8)
                            
                            Spacer()
                            
                            Text("番席")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("シャッフル結果")
                } footer: {
                    Text("この番号の席に座ってもらいましょう。")
                }
            }
            
            AdBannerView()
                .frame(width: 320, height: 50)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("番号札モード")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    presentShareSheet(with: shareText)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 4)
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presenter.didTapShuffleButton()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 4)
                }
            }
        }
    }
    
    private func presentShareSheet(with text: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = rootViewController.view
            popoverController.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        rootViewController.present(activityVC, animated: true, completion: nil)
    }
}
